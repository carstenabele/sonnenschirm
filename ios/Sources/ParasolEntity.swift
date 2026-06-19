import RealityKit
import simd
import Foundation

/// A RealityKit `Entity` that visualises a parasol (mast + canopy).
///
/// The local origin is the ground point (mast base at y = 0).
/// Calling `update(from:)` is idempotent — it reconfigures existing child
/// entities or rebuilds them if they are missing.
///
/// API availability notes:
/// - `MeshResource.generateCylinder` requires iOS 18. On iOS 17 the mast and
///   round canopy fall back to `generateBox` / `generateSphere` approximations.
/// - `GroundingShadowComponent` requires iOS 18; on iOS 17 the per-entity cast
///   flag is silently skipped (Task 5 installs the scene-level shadow technique).
final class ParasolEntity: Entity {

    // MARK: - Private child entities

    /// Vertical mast, centred at half-height.
    private var mastEntity: ModelEntity?

    /// Canopy for a rectangular parasol.
    private var rectCanopy: ModelEntity?

    /// Canopy for a round parasol.
    private var roundCanopy: ModelEntity?

    /// Pivot entity placed at the mast top; receives the yaw/tilt orientation.
    private var pivotEntity: Entity?

    // MARK: - Materials

    private static let canopyMaterial: SimpleMaterial = {
        SimpleMaterial(
            color: .init(red: 0.84, green: 0.29, blue: 0.25, alpha: 1),
            isMetallic: false
        )
    }()

    private static let mastMaterial: SimpleMaterial = {
        SimpleMaterial(color: .init(white: 0.55, alpha: 1), isMetallic: false)
    }()

    // MARK: - Required init

    required init() {
        super.init()
    }

    // MARK: - Public API

    /// Rebuilds or reconfigures mast + canopy and applies the pivot transform.
    /// Safe to call on every frame update.
    func update(from state: ParasolState) {
        let h = Float(state.height)

        // ── Mast ────────────────────────────────────────────────────────────
        let mast = getOrCreateMast()
        let mastMesh = makeCylinder(height: h, radius: 0.03)
        mast.model = ModelComponent(mesh: mastMesh, materials: [Self.mastMaterial])
        applyGroundingShadow(to: mast)
        mast.position = SIMD3<Float>(0, h / 2, 0)

        // ── Pivot at mast top ────────────────────────────────────────────────
        let pivot = getOrCreatePivot()
        pivot.position = SIMD3<Float>(0, h, 0)

        // Apply transform order: Yaw(+Y) · TiltDir(+Y) · Tilt(+X)
        let yawRad = Float(state.yawDeg) * .pi / 180
        let tiltDirRad = Float(state.tiltDirDeg) * .pi / 180
        let tiltRad = Float(state.tiltDeg) * .pi / 180

        let qYaw = simd_quatf(angle: yawRad, axis: SIMD3<Float>(0, 1, 0))
        let qTiltDir = simd_quatf(angle: tiltDirRad, axis: SIMD3<Float>(0, 1, 0))
        let qTilt = simd_quatf(angle: tiltRad, axis: SIMD3<Float>(1, 0, 0))

        pivot.orientation = qYaw * qTiltDir * qTilt

        // ── Canopies ─────────────────────────────────────────────────────────
        switch state.shape {
        case .rect:
            let rect = getOrCreateRectCanopy()
            let boxMesh = MeshResource.generateBox(
                size: SIMD3<Float>(Float(state.length), 0.08, Float(state.width))
            )
            rect.model = ModelComponent(mesh: boxMesh, materials: [Self.canopyMaterial])
            applyGroundingShadow(to: rect)
            rect.isEnabled = true
            roundCanopy?.isEnabled = false

        case .round:
            let round = getOrCreateRoundCanopy()
            let radius = Float(sqrt(state.area / .pi))
            let cylinderMesh = makeCylinder(height: 0.1, radius: radius)
            round.model = ModelComponent(mesh: cylinderMesh, materials: [Self.canopyMaterial])
            applyGroundingShadow(to: round)
            round.isEnabled = true
            rectCanopy?.isEnabled = false
        }
    }

    // MARK: - Mesh helpers

    /// Returns a cylinder mesh on iOS 18+; falls back to a thin box on iOS 17.
    private func makeCylinder(height: Float, radius: Float) -> MeshResource {
        if #available(iOS 18.0, *) {
            return MeshResource.generateCylinder(height: height, radius: radius)
        } else {
            // Approximate: box with the same height and diameter as the cylinder
            let diameter = radius * 2
            return MeshResource.generateBox(size: SIMD3<Float>(diameter, height, diameter))
        }
    }

    // MARK: - Shadow helper

    /// Attaches `GroundingShadowComponent` on iOS 18+; no-op on earlier OS.
    private func applyGroundingShadow(to entity: ModelEntity) {
        if #available(iOS 18.0, *) {
            entity.components.set(GroundingShadowComponent(castsShadow: true))
        }
    }

    // MARK: - Lazy child-entity helpers

    private func getOrCreateMast() -> ModelEntity {
        if let existing = mastEntity { return existing }
        let e = ModelEntity()
        mastEntity = e
        addChild(e)
        return e
    }

    private func getOrCreatePivot() -> Entity {
        if let existing = pivotEntity { return existing }
        let e = Entity()
        pivotEntity = e
        addChild(e)
        return e
    }

    private func getOrCreateRectCanopy() -> ModelEntity {
        if let existing = rectCanopy { return existing }
        let e = ModelEntity()
        rectCanopy = e
        pivotEntity?.addChild(e)
        return e
    }

    private func getOrCreateRoundCanopy() -> ModelEntity {
        if let existing = roundCanopy { return existing }
        let e = ModelEntity()
        roundCanopy = e
        pivotEntity?.addChild(e)
        return e
    }
}
