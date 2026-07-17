import AppKit
import Metal
import RealityKit
import simd

@MainActor
enum ViewportSectionFactory {
  static let handleName = "viewportSectionHandle"
  static let planeName = "viewportSectionPlane"
  private static var shader: CustomMaterial.SurfaceShader?

  static var isClipShaderAvailable: Bool { clippingShader() != nil }

  static func apply(_ section: ViewportSectionPlane, to characterRoot: Entity) {
    guard section.isEnabled else { return }
    refreshClippingMaterials(section, below: characterRoot)
    characterRoot.addChild(makePlane(section))
  }

  static func refreshClippingMaterials(
    _ section: ViewportSectionPlane,
    below root: Entity
  ) {
    guard section.isEnabled, let shader = clippingShader() else { return }
    let plane = planeVector(section)
    for entity in modelEntities(below: root) where entity.name != planeName {
      guard var model = entity.components[ModelComponent.self] else { continue }
      model.materials = model.materials.map { source in
        guard var material = try? CustomMaterial(from: source, surfaceShader: shader) else {
          return source
        }
        material.custom.value = plane
        material.blending = .transparent(opacity: .init(scale: 1))
        material.opacityThreshold = 0.001
        return material
      }
      entity.components.set(model)
    }
  }

  private static func clippingShader() -> CustomMaterial.SurfaceShader? {
    if let shader { return shader }
    guard let device = MTLCreateSystemDefaultDevice(),
      let library = try? device.makeDefaultLibrary(bundle: .main)
    else { return nil }
    let compiled = CustomMaterial.SurfaceShader(named: "anima_section_surface", in: library)
    shader = compiled
    return compiled
  }

  private static func planeVector(_ section: ViewportSectionPlane) -> SIMD4<Float> {
    let axis: SIMD3<Float> =
      switch section.axis {
      case .x: SIMD3<Float>(1, 0, 0)
      case .y: SIMD3<Float>(0, 1, 0)
      case .z: SIMD3<Float>(0, 0, 1)
      }
    return SIMD4<Float>(axis, Float(section.positionMeters))
  }

  private static func makePlane(_ section: ViewportSectionPlane) -> Entity {
    let color: NSColor =
      switch section.axis {
      case .x: .systemRed
      case .y: .systemGreen
      case .z: .systemBlue
      }
    let material = UnlitMaterial(color: color.withAlphaComponent(0.13))
    let entity = ModelEntity(
      mesh: .generatePlane(width: 4, depth: 4),
      materials: [material]
    )
    entity.name = planeName
    switch section.axis {
    case .x:
      entity.position.x = Float(section.positionMeters)
      entity.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1))
    case .y:
      entity.position.y = Float(section.positionMeters)
    case .z:
      entity.position.z = Float(section.positionMeters)
      entity.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
    }
    let handle = ModelEntity(
      mesh: .generateSphere(radius: 0.075),
      materials: [UnlitMaterial(color: color)]
    )
    handle.name = handleName
    handle.position = SIMD3<Float>(0.65, 0, 0.65)
    handle.components.set(InputTargetComponent())
    handle.generateCollisionShapes(recursive: false)
    entity.addChild(handle)
    return entity
  }

  static func contains(_ entity: Entity) -> Bool {
    var candidate: Entity? = entity
    while let current = candidate {
      if current.name == handleName { return true }
      candidate = current.parent
    }
    return false
  }

  static func axisVector(_ axis: ViewportSectionAxis) -> SIMD3<Float> {
    switch axis {
    case .x: SIMD3<Float>(1, 0, 0)
    case .y: SIMD3<Float>(0, 1, 0)
    case .z: SIMD3<Float>(0, 0, 1)
    }
  }

  private static func modelEntities(below root: Entity) -> [Entity] {
    var result: [Entity] = []
    var stack = [root]
    while let entity = stack.popLast() {
      if entity.components[ModelComponent.self] != nil { result.append(entity) }
      stack.append(contentsOf: entity.children)
    }
    return result
  }
}
