import SwiftUI
import RealityKit
import ARKit
import simd
import Combine

/// SwiftUI wrapper around an ARKit/RealityKit `ARView` for the Schattenwerfer
/// app. It places the parasol on a detected horizontal plane, casts a
/// sun-driven directional light, and shows the resulting shadow on the real
/// floor via an occlusion plane.
///
/// World alignment is `.gravityAndHeading`, giving a north-aligned world that
/// matches `SunMath.vector`: +X East, +Y up, −Z North.
///
/// Interaction:
/// - Tap: raycast against detected/estimated horizontal planes and place (or
///   move) the parasol anchor at the hit point.
/// - Pan: continuously raycast and move the anchor while dragging.
///
/// Robustness: if `ARWorldTrackingConfiguration` is unsupported (e.g. the
/// simulator), `makeUIView` logs and returns a plain placeholder `ARView`
/// without running a session, so the app does not crash.
struct ARSceneView: UIViewRepresentable {

    /// Shared parasol state. SwiftUI re-invokes `updateUIView` when it changes.
    @ObservedObject var state: ParasolState

    // MARK: - Tuning constants

    /// Directional light intensity (lux) when the sun is above the horizon.
    private static let sunIntensity: Float = 8_000

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.arView = arView

        guard ARWorldTrackingConfiguration.isSupported else {
            // Simulator / unsupported hardware: present a non-AR placeholder
            // instead of crashing on session.run.
            NSLog("[ARSceneView] ARWorldTrackingConfiguration not supported — "
                + "running without an AR session (e.g. simulator).")
            return arView
        }

        // ── AR session configuration ───────────────────────────────────────
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.worldAlignment = .gravityAndHeading
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            // Optional: better occlusion if a LiDAR mesh is available.
            config.sceneReconstruction = .mesh
        }
        config.environmentTexturing = .automatic
        arView.session.run(config)

        // ── Coaching overlay (guides the user to find a horizontal plane) ───
        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.frame = arView.bounds
        arView.addSubview(coaching)

        // ── Scene graph setup (anchor + parasol + light + ground) ───────────
        context.coordinator.setupScene()

        // ── Gestures ────────────────────────────────────────────────────────
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        arView.addGestureRecognizer(pan)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // ParasolState changed: rebuild the parasol geometry and re-orient /
        // re-intensify the sun light to match the new sun position.
        context.coordinator.state = state
        context.coordinator.syncResetIfNeeded()
        context.coordinator.applyState()
    }

    // MARK: - Coordinator

    /// Holds long-lived references to the ARView and scene entities, and owns
    /// the gesture handling and state synchronisation.
    ///
    /// Marked `@MainActor` because RealityKit entities (`AnchorEntity`,
    /// `DirectionalLight`, `ParasolEntity`) are main-actor isolated; all of this
    /// coordinator's work (scene setup, gestures, state sync) runs on the main
    /// thread anyway.
    @MainActor
    final class Coordinator: NSObject {

        weak var arView: ARView?
        var state: ParasolState

        /// Root anchor for everything we place. Re-positioned on tap/pan.
        private let anchor = AnchorEntity(world: .zero)
        /// The parasol model. Child of `anchor`, local origin at ground.
        private let parasol = ParasolEntity()
        /// Sun directional light. Child of `anchor`.
        private let sunLight = DirectionalLight()
        /// Flat, semi-transparent polygon drawn on the floor to show where the
        /// shadow falls. Computed explicitly from `SunMath` (directionally
        /// correct), independent of RealityKit's shadow pipeline.
        private let shadowDecal = ModelEntity()

        /// Floor reticle (ring) at the screen-centre raycast hit — the aiming
        /// indicator for clean placement. Its own anchor, independent of the
        /// parasol (which may not be placed yet).
        private let reticleAnchor = AnchorEntity(world: .zero)
        private let reticle = ModelEntity()
        /// Latest screen-centre floor hit (world position), or nil if none.
        private var centerHit: SIMD3<Float>?
        /// Per-frame update subscription (keeps the reticle on the floor).
        private var frameSub: (any Cancellable)?
        /// Last seen reset token, to detect reset requests in `updateUIView`.
        private var lastResetToken = 0

        /// Whether the anchor has been placed on a detected plane yet.
        private var isPlaced = false

        init(state: ParasolState) {
            self.state = state
            super.init()
        }

        // MARK: Scene construction

        /// Builds the anchor's child hierarchy. The anchor stays at the world
        /// origin (hidden) until the first placement.
        func setupScene() {
            guard let arView else { return }

            // Parasol
            parasol.update(from: state)
            anchor.addChild(parasol)

            // Sun directional light + its shadow.
            sunLight.light.intensity = Self.intensity(for: state)
            sunLight.light.color = .white
            if #available(iOS 18.0, *) {
                sunLight.shadow = DirectionalLightComponent.Shadow()
            } else {
                sunLight.shadow = .init()
            }
            orientSunLight()
            anchor.addChild(sunLight)

            // Explicit shadow polygon on the floor (sibling of the parasol).
            anchor.addChild(shadowDecal)
            updateShadowDecal()

            // Hide the whole anchor until placed so it doesn't float at origin.
            anchor.isEnabled = false
            arView.scene.addAnchor(anchor)

            // Floor reticle (aiming ring) on its own anchor.
            if let ring = Self.makeRingMesh(innerR: 0.085, outerR: 0.12, segments: 48) {
                var mat = UnlitMaterial()
                mat.color = .init(tint: .white)
                mat.blending = .transparent(opacity: .init(floatLiteral: 0.9))
                reticle.model = ModelComponent(mesh: ring, materials: [mat])
            }
            reticleAnchor.addChild(reticle)
            reticleAnchor.isEnabled = false
            arView.scene.addAnchor(reticleAnchor)

            // Keep the reticle glued to the screen-centre floor hit each frame.
            frameSub = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
                self?.updateReticle()
            }
        }

        /// Raycasts from the screen centre each frame and parks the reticle on
        /// the floor there, recording the hit for tap placement.
        private func updateReticle() {
            guard let arView else { return }
            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            let results = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .horizontal)
            if let t = results.first?.worldTransform {
                let pos = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
                centerHit = pos
                reticleAnchor.position = pos
                reticleAnchor.isEnabled = true
            } else {
                centerHit = nil
                reticleAnchor.isEnabled = false
            }
        }

        /// Picks the parasol up so it can be re-placed (placement-only reset).
        func resetPlacement() {
            isPlaced = false
            anchor.isEnabled = false
        }

        // MARK: State synchronisation

        /// Re-applies the current `ParasolState` to geometry, light and shadow.
        func applyState() {
            parasol.update(from: state)
            sunLight.light.intensity = Self.intensity(for: state)
            orientSunLight()
            updateShadowDecal()
        }

        // MARK: Shadow decal

        /// Smallest sun altitude (radians) for which we draw a shadow. Below a
        /// few degrees the projected shadow is impractically long/unstable.
        private static let minShadowAltitude = 3.0 * Double.pi / 180.0

        /// Rebuilds the floor shadow polygon from the current sun + parasol.
        private func updateShadowDecal() {
            let s = state.sun()
            guard s.altitude > Self.minShadowAltitude else {
                shadowDecal.isEnabled = false
                return
            }
            let isRound = state.shape == .round
            let outline = SunMath.shadowGroundOutline(
                isRound: isRound,
                L: state.length, B: state.width, area: state.area,
                yawDeg: state.yawDeg, tiltDeg: state.tiltDeg, tiltDirDeg: state.tiltDirDeg,
                height: state.height, eye: 0, front: 0,
                azimuth: s.azimuth, altitude: s.altitude,
                segments: isRound ? 48 : 4
            )
            guard outline.count >= 3, let mesh = Self.makeShadowMesh(outline: outline) else {
                shadowDecal.isEnabled = false
                return
            }
            var material = UnlitMaterial()
            material.color = .init(tint: .black)
            material.blending = .transparent(opacity: .init(floatLiteral: 0.45))
            shadowDecal.model = ModelComponent(mesh: mesh, materials: [material])
            shadowDecal.isEnabled = true
        }

        /// Builds a flat, double-sided polygon mesh ~1 cm above the floor from
        /// projected ground points (x,z). Triangle fan; both windings so it is
        /// visible regardless of view angle.
        private static func makeShadowMesh(outline: [SIMD2<Double>]) -> MeshResource? {
            let y: Float = 0.012
            let positions = outline.map { SIMD3<Float>(Float($0.x), y, Float($0.y)) }
            let n = positions.count
            guard n >= 3 else { return nil }
            var indices: [UInt32] = []
            for i in 1..<(n - 1) {
                let a: UInt32 = 0, b = UInt32(i), c = UInt32(i + 1)
                indices.append(contentsOf: [a, b, c, a, c, b])
            }
            var md = MeshDescriptor(name: "shadow")
            md.positions = MeshBuffers.Positions(positions)
            md.primitives = .triangles(indices)
            return try? MeshResource.generate(from: [md])
        }

        /// Builds a flat ring (annulus) mesh in the XZ plane, double-sided.
        private static func makeRingMesh(innerR: Float, outerR: Float, segments: Int) -> MeshResource? {
            let y: Float = 0.006
            var positions: [SIMD3<Float>] = []
            for i in 0..<segments {
                let a = 2 * Float.pi * Float(i) / Float(segments)
                let c = cos(a), s = sin(a)
                positions.append(SIMD3(outerR * c, y, outerR * s))
                positions.append(SIMD3(innerR * c, y, innerR * s))
            }
            var indices: [UInt32] = []
            for i in 0..<segments {
                let o0 = UInt32(2 * i), i0 = UInt32(2 * i + 1)
                let o1 = UInt32(2 * ((i + 1) % segments)), i1 = UInt32(2 * ((i + 1) % segments) + 1)
                indices.append(contentsOf: [o0, i0, o1, o1, i0, i1])   // front
                indices.append(contentsOf: [o0, o1, i0, o1, i1, i0])   // back
            }
            var md = MeshDescriptor(name: "reticle")
            md.positions = MeshBuffers.Positions(positions)
            md.primitives = .triangles(indices)
            return try? MeshResource.generate(from: [md])
        }

        /// Intensity is the configured value when the sun is up, else 0 (night).
        private static func intensity(for state: ParasolState) -> Float {
            let altitude = state.sun().altitude
            return altitude > 0 ? sunIntensity : 0
        }

        /// Orients the directional light so its forward axis points along
        /// `-sunVector` — i.e. light travels from the sun toward the scene.
        ///
        /// A `DirectionalLight`'s emission direction is its local −Z axis, so we
        /// rotate the entity such that −Z maps onto `-sunVector`, which means Z
        /// maps onto `+sunVector` (toward the sun).
        private func orientSunLight() {
            let s = state.sun()
            let v = SunMath.vector(azimuth: s.azimuth, altitude: s.altitude)
            let sunDir = SIMD3<Float>(Float(v.x), Float(v.y), Float(v.z))

            // Guard against a degenerate (zero) vector.
            guard length(sunDir) > 1e-5 else { return }
            let towardSun = normalize(sunDir)

            // Local +Z should point toward the sun (so −Z = light direction).
            let forward = SIMD3<Float>(0, 0, 1)
            sunLight.orientation = simd_quatf(from: forward, to: towardSun)
        }

        // MARK: Placement

        /// Raycasts from a screen point onto a horizontal plane and returns the
        /// world position of the first hit, if any.
        private func worldPosition(at point: CGPoint) -> SIMD3<Float>? {
            guard let arView else { return nil }
            let results = arView.raycast(
                from: point,
                allowing: .estimatedPlane,
                alignment: .horizontal
            )
            guard let first = results.first else { return nil }
            let t = first.worldTransform
            return SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        }

        /// Moves the anchor to a world position, placing it (and enabling it) on
        /// first use.
        private func move(to worldPos: SIMD3<Float>) {
            anchor.position = worldPos
            if !isPlaced {
                isPlaced = true
                anchor.isEnabled = true
            }
        }

        // MARK: Gestures

        /// Applies a placement reset when the state's token advances.
        func syncResetIfNeeded() {
            if state.placementResetToken != lastResetToken {
                lastResetToken = state.placementResetToken
                resetPlacement()
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // Place at the centre reticle (the aiming indicator) for clean,
            // predictable placement; fall back to the tapped point if needed.
            if let pos = centerHit {
                move(to: pos)
            } else if let arView, let pos = worldPosition(at: gesture.location(in: arView)) {
                move(to: pos)
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let arView, isPlaced else {
                // Allow a pan to also place the parasol if not yet placed.
                if gesture.state == .began || gesture.state == .changed,
                   let arView,
                   let pos = worldPosition(at: gesture.location(in: arView)) {
                    move(to: pos)
                }
                return
            }
            switch gesture.state {
            case .began, .changed, .ended:
                let point = gesture.location(in: arView)
                if let pos = worldPosition(at: point) {
                    move(to: pos)
                }
            default:
                break
            }
        }
    }
}
