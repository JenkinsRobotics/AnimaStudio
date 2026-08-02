import AppKit
import RealityKit

@MainActor
enum ArmIKTargetFactory {
  static let name = "armIKTarget"
  private static let markerName = "armIKTargetMarker"

  static func apply(
    pose: EngineResolvedPartPose?,
    isUnreachable: Bool,
    to root: Entity
  ) {
    guard let characterRoot = root.findEntity(named: "animaCharacterRoot") else { return }
    guard let pose else {
      characterRoot.findEntity(named: name)?.removeFromParent()
      return
    }

    let target: Entity
    if let existing = characterRoot.findEntity(named: name) {
      target = existing
    } else {
      target = make()
      characterRoot.addChild(target)
    }
    target.transform = pose.realityKitTransform
    updateMarker(isUnreachable: isUnreachable, in: target)
  }

  static func contains(_ entity: Entity) -> Bool {
    var candidate: Entity? = entity
    while let current = candidate {
      if current.name == name { return true }
      candidate = current.parent
    }
    return false
  }

  private static func make() -> Entity {
    let root = Entity()
    root.name = name
    root.addChild(makeMarker(color: .systemCyan))
    let gizmo = TransformGizmoFactory.make()
    gizmo.scale = SIMD3<Float>(repeating: 0.7)
    root.addChild(gizmo)
    return root
  }

  private static func makeMarker(color: NSColor) -> ModelEntity {
    var material = UnlitMaterial()
    material.color = .init(tint: color.withAlphaComponent(0.8))
    material.blending = .transparent(opacity: 0.8)
    let marker = ModelEntity(
      mesh: .generateSphere(radius: 0.055),
      materials: [material]
    )
    marker.name = markerName
    marker.components.set(InputTargetComponent(allowedInputTypes: .indirect))
    marker.generateCollisionShapes(recursive: false)
    return marker
  }

  private static func updateMarker(isUnreachable: Bool, in target: Entity) {
    target.findEntity(named: markerName)?.removeFromParent()
    target.addChild(makeMarker(color: isUnreachable ? .systemOrange : .systemCyan))
  }
}
