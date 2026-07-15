import AppKit
import RealityKit

public enum ViewportRenderStyle: String, CaseIterable, Identifiable, Sendable {
  case shaded
  case shadedWithMeshEdges
  case wireframe
  case translucent

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .shaded: "Shaded"
    case .shadedWithMeshEdges: "Shaded + Mesh Edges"
    case .wireframe: "Wireframe"
    case .translucent: "Translucent"
    }
  }

  public var systemImage: String {
    switch self {
    case .shaded: "cube.fill"
    case .shadedWithMeshEdges: "cube"
    case .wireframe: "square.grid.3x3"
    case .translucent: "cube.transparent"
    }
  }

  public var detail: String {
    switch self {
    case .shaded: "Source materials and normal lighting"
    case .shadedWithMeshEdges: "Shaded surfaces with triangle mesh edges"
    case .wireframe: "Triangle mesh lines without filled surfaces"
    case .translucent: "Shaded surfaces at reduced opacity"
    }
  }
}

@MainActor
enum ViewportRenderStyleApplier {
  static let meshEdgeOverlayName = "viewportMeshEdgeOverlay"

  static func partMaterial(
    _ style: ViewportRenderStyle,
    baseColor: NSColor
  ) -> any Material {
    switch style {
    case .shaded, .shadedWithMeshEdges:
      return SimpleMaterial(color: baseColor, isMetallic: false)
    case .wireframe:
      return lineMaterial(color: baseColor)
    case .translucent:
      return SimpleMaterial(
        color: baseColor.withAlphaComponent(0.34),
        isMetallic: false
      )
    }
  }

  static func apply(_ style: ViewportRenderStyle, to root: Entity) {
    switch style {
    case .shaded:
      return
    case .translucent:
      root.components.set(OpacityComponent(opacity: 0.38))
    case .wireframe:
      for entity in modelEntities(below: root) {
        guard var model = entity.components[ModelComponent.self] else { continue }
        let count = max(model.materials.count, 1)
        model.materials = Array(
          repeating: lineMaterial(color: .labelColor),
          count: count
        )
        entity.components.set(model)
      }
    case .shadedWithMeshEdges:
      for entity in modelEntities(below: root) {
        addMeshEdgeOverlayIfNeeded(style, to: entity)
      }
    }
  }

  static func addMeshEdgeOverlayIfNeeded(
    _ style: ViewportRenderStyle,
    to entity: Entity
  ) {
    guard style == .shadedWithMeshEdges,
      entity.findEntity(named: meshEdgeOverlayName) == nil,
      let model = entity.components[ModelComponent.self]
    else { return }

    let materialCount = max(model.materials.count, 1)
    let overlay = ModelEntity(
      mesh: model.mesh,
      materials: Array(
        repeating: lineMaterial(color: NSColor.labelColor.withAlphaComponent(0.58)),
        count: materialCount
      )
    )
    overlay.name = meshEdgeOverlayName
    overlay.scale = SIMD3<Float>(repeating: 1.002)
    entity.addChild(overlay)
  }

  private static func lineMaterial(color: NSColor) -> UnlitMaterial {
    var material = UnlitMaterial()
    material.color = .init(tint: color)
    material.triangleFillMode = .lines
    return material
  }

  private static func modelEntities(below root: Entity) -> [Entity] {
    var result: [Entity] = []
    var stack = [root]
    while let entity = stack.popLast() {
      if entity.name != meshEdgeOverlayName,
        entity.components[ModelComponent.self] != nil
      {
        result.append(entity)
      }
      stack.append(contentsOf: entity.children)
    }
    return result
  }
}
