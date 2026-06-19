import SwiftUI
import RealityKit
import ARKit
import simd

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

    /// Edge length of the occlusion ground plane (metres).
    private static let groundSize: Float = 8

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
        /// Large occlusion plane that receives the shadow + shows the camera.
        private var groundPlane: ModelEntity?

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

            // Occlusion ground plane that receives the directional shadow and
            // shows the real camera image beneath the parasol.
            let plane = ModelEntity(
                mesh: .generatePlane(width: groundSize, depth: groundSize),
                materials: [OcclusionMaterial()]
            )
            plane.position = SIMD3<Float>(0, 0, 0)
            groundPlane = plane
            anchor.addChild(plane)

            // Hide the whole anchor until placed so it doesn't float at origin.
            anchor.isEnabled = false
            arView.scene.addAnchor(anchor)
        }

        // MARK: State synchronisation

        /// Re-applies the current `ParasolState` to geometry and light.
        func applyState() {
            parasol.update(from: state)
            sunLight.light.intensity = Self.intensity(for: state)
            orientSunLight()
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

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView else { return }
            let point = gesture.location(in: arView)
            if let pos = worldPosition(at: point) {
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
