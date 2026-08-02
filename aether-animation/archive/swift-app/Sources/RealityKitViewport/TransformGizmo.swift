import AnimaEvaluation
import AnimaModel
import AppKit
import RealityKit

enum TransformHandleKind: Equatable {
  case translate(JointAxis)
  case rotate(JointAxis)
}

@MainActor
enum TransformGizmoFactory {
  static let gizmoName = "partTransformGizmo"
  static let selectionHighlightName = "partSelectionHighlight"

  static func make() -> Entity {
    let gizmo = Entity()
    gizmo.name = gizmoName

    for axis in [JointAxis.x, .y, .z] {
      gizmo.addChild(makeTranslationHandle(axis: axis))
      gizmo.addChild(makeRotationHandle(axis: axis))
    }

    gizmo.generateCollisionShapes(recursive: true)
    addInputTargets(to: gizmo)
    return gizmo
  }

  static func makeSelectionHighlight(for kind: RigPrimitiveKind) -> Entity {
    var material = UnlitMaterial()
    material.color = .init(tint: NSColor.systemOrange.withAlphaComponent(0.32))
    material.blending = .transparent(opacity: 0.32)

    let entity: ModelEntity
    switch kind {
    case .box, .mesh:
      // A mesh part uses a bounding-box-style selection highlight.
      entity = ModelEntity(
        mesh: .generateBox(width: 0.57, height: 0.57, depth: 0.57, cornerRadius: 0.04),
        materials: [material]
      )
    case .cylinder:
      entity = ModelEntity(
        mesh: .generateCylinder(height: 0.74, radius: 0.26),
        materials: [material]
      )
    case .sphere:
      entity = ModelEntity(
        mesh: .generateSphere(radius: 0.335),
        materials: [material]
      )
    case .locator:
      entity = ModelEntity(
        mesh: .generateSphere(radius: 0.092),
        materials: [material]
      )
    }
    entity.name = selectionHighlightName
    return entity
  }

  static func handle(from entity: Entity) -> TransformHandleKind? {
    var candidate: Entity? = entity
    while let current = candidate {
      if let handle = parseHandleName(current.name) {
        return handle
      }
      candidate = current.parent
    }
    return nil
  }

  private static func makeTranslationHandle(axis: JointAxis) -> Entity {
    let root = Entity()
    root.name = "transformHandle-translate-\(axis.rawValue)"

    let direction = vector(for: axis)
    let material = SimpleMaterial(color: color(for: axis), isMetallic: false)
    let shaft = ModelEntity(
      mesh: .generateCylinder(height: 0.44, radius: 0.018),
      materials: [material]
    )
    shaft.position = direction * 0.28
    shaft.orientation = orientationFromYAxis(to: direction)
    root.addChild(shaft)

    let head = ModelEntity(
      mesh: .generateCone(height: 0.14, radius: 0.065),
      materials: [material]
    )
    head.position = direction * 0.57
    head.orientation = orientationFromYAxis(to: direction)
    root.addChild(head)

    return root
  }

  private static func makeRotationHandle(axis: JointAxis) -> Entity {
    let root = Entity()
    root.name = "transformHandle-rotate-\(axis.rawValue)"
    let material = SimpleMaterial(
      color: color(for: axis).withAlphaComponent(0.9), isMetallic: false)
    let radius: Float = 0.42
    let segmentCount = 36

    for index in 0..<segmentCount {
      let startAngle = Float(index) / Float(segmentCount) * 2 * .pi
      let endAngle = Float(index + 1) / Float(segmentCount) * 2 * .pi
      let start = ringPoint(axis: axis, angle: startAngle, radius: radius)
      let end = ringPoint(axis: axis, angle: endAngle, radius: radius)
      root.addChild(cylinder(from: start, to: end, radius: 0.009, material: material))
    }

    return root
  }

  private static func cylinder(
    from start: SIMD3<Float>,
    to end: SIMD3<Float>,
    radius: Float,
    material: SimpleMaterial
  ) -> ModelEntity {
    let delta = end - start
    let length = simd_length(delta)
    let segment = ModelEntity(
      mesh: .generateCylinder(height: length, radius: radius),
      materials: [material]
    )
    segment.position = (start + end) / 2
    segment.orientation = orientationFromYAxis(to: simd_normalize(delta))
    return segment
  }

  private static func ringPoint(
    axis: JointAxis,
    angle: Float,
    radius: Float
  ) -> SIMD3<Float> {
    switch axis {
    case .x:
      SIMD3<Float>(0, cos(angle) * radius, sin(angle) * radius)
    case .y:
      SIMD3<Float>(cos(angle) * radius, 0, sin(angle) * radius)
    case .z:
      SIMD3<Float>(cos(angle) * radius, sin(angle) * radius, 0)
    }
  }

  private static func orientationFromYAxis(to direction: SIMD3<Float>) -> simd_quatf {
    simd_quatf(from: SIMD3<Float>(0, 1, 0), to: direction)
  }

  static func vector(for axis: JointAxis) -> SIMD3<Float> {
    switch axis {
    case .x: SIMD3<Float>(1, 0, 0)
    case .y: SIMD3<Float>(0, 1, 0)
    case .z: SIMD3<Float>(0, 0, 1)
    }
  }

  private static func color(for axis: JointAxis) -> NSColor {
    switch axis {
    case .x: .systemRed
    case .y: .systemGreen
    case .z: .systemBlue
    }
  }

  private static func parseHandleName(_ name: String) -> TransformHandleKind? {
    let components = name.split(separator: "-")
    guard components.count == 3,
      components[0] == "transformHandle",
      let axis = JointAxis(rawValue: String(components[2]))
    else { return nil }

    switch components[1] {
    case "translate": return .translate(axis)
    case "rotate": return .rotate(axis)
    default: return nil
    }
  }

  private static func addInputTargets(to entity: Entity) {
    entity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
    for child in entity.children {
      addInputTargets(to: child)
    }
  }
}
