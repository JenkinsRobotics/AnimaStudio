import AppKit
import RealityKit
import XCTest

@testable import RealityKitViewport

@MainActor
final class ViewportRenderStyleTests: XCTestCase {
  func testRenderStyleIdentifiersRemainStable() {
    XCTAssertEqual(
      ViewportRenderStyle.allCases.map(\.rawValue),
      ["shaded", "shadedWithMeshEdges", "wireframe", "translucent"]
    )
  }

  func testShadedWithEdgesAddsANoninteractiveMeshOverlay() {
    let entity = ModelEntity(
      mesh: .generateBox(size: 1),
      materials: [SimpleMaterial(color: .systemTeal, isMetallic: false)]
    )

    ViewportRenderStyleApplier.addMeshEdgeOverlayIfNeeded(
      .shadedWithMeshEdges,
      to: entity
    )

    XCTAssertNotNil(
      entity.findEntity(named: ViewportRenderStyleApplier.meshEdgeOverlayName)
    )
  }

  func testWireframeReplacesModelMaterialsWithLineFill() throws {
    let entity = ModelEntity(
      mesh: .generateSphere(radius: 1),
      materials: [SimpleMaterial(color: .systemTeal, isMetallic: false)]
    )

    ViewportRenderStyleApplier.apply(.wireframe, to: entity)

    let model = try XCTUnwrap(entity.components[ModelComponent.self])
    let material = try XCTUnwrap(model.materials.first as? UnlitMaterial)
    XCTAssertEqual(material.triangleFillMode, .lines)
  }

  func testTranslucentAppliesOpacityAtTheRenderRoot() {
    let entity = Entity()

    ViewportRenderStyleApplier.apply(.translucent, to: entity)

    XCTAssertEqual(entity.components[OpacityComponent.self]?.opacity, 0.38)
  }
}
