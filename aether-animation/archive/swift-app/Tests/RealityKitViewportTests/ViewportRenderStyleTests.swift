import AppKit
import RealityKit
import XCTest

@testable import RealityKitViewport

@MainActor
final class ViewportRenderStyleTests: XCTestCase {
  func testRenderStyleIdentifiersRemainStable() {
    XCTAssertEqual(
      ViewportRenderStyle.allCases.map(\.rawValue),
      ["shaded", "shadedWithEdges", "wireframe", "unshaded", "translucent"]
    )
    XCTAssertEqual(ViewportEdgeDisplay.allCases.map(\.rawValue), ["hidden", "mesh"])
    XCTAssertEqual(
      ViewportMaterialFinish.allCases.map(\.rawValue),
      ["matte", "satin", "glossy", "metallic"]
    )
  }

  func testShadedWithEdgesAddsANoninteractiveMeshOverlay() {
    let entity = ModelEntity(
      mesh: .generateBox(size: 1),
      materials: [SimpleMaterial(color: .systemTeal, isMetallic: false)]
    )

    ViewportRenderStyleApplier.addMeshEdgeOverlayIfNeeded(
      .mesh,
      renderStyle: .shaded,
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

    ViewportRenderStyleApplier.apply(.wireframe, edgeDisplay: .mesh, to: entity)

    let model = try XCTUnwrap(entity.components[ModelComponent.self])
    let material = try XCTUnwrap(model.materials.first as? UnlitMaterial)
    XCTAssertEqual(material.triangleFillMode, .lines)
  }

  func testTranslucentAppliesOpacityAtTheRenderRoot() {
    let entity = Entity()

    ViewportRenderStyleApplier.apply(.translucent, edgeDisplay: .hidden, to: entity)

    XCTAssertEqual(entity.components[OpacityComponent.self]?.opacity, 0.38)
  }

  func testHiddenEdgesDoNotAddAnOverlay() {
    let entity = ModelEntity(
      mesh: .generateBox(size: 1),
      materials: [SimpleMaterial(color: .systemTeal, isMetallic: false)]
    )

    ViewportRenderStyleApplier.apply(.shaded, edgeDisplay: .hidden, to: entity)

    XCTAssertNil(entity.findEntity(named: ViewportRenderStyleApplier.meshEdgeOverlayName))
  }

  func testShadedProxyUsesPBRFinishParameters() throws {
    let material = ViewportRenderStyleApplier.partMaterial(
      .shaded,
      finish: .metallic,
      baseColor: .systemTeal
    )

    let pbr = try XCTUnwrap(material as? PhysicallyBasedMaterial)
    XCTAssertEqual(pbr.metallic.scale, 0.92)
    XCTAssertEqual(pbr.roughness.scale, 0.24)
    XCTAssertEqual(pbr.clearcoat.scale, 0.08)
  }

  func testUnshadedProxyUsesLightingIndependentMaterial() {
    let material = ViewportRenderStyleApplier.partMaterial(
      .unshaded,
      baseColor: .systemTeal
    )
    XCTAssertTrue(material is UnlitMaterial)
  }

  func testShadedWithEdgesForcesOverlayWhenGeneralEdgesAreHidden() {
    let entity = ModelEntity(
      mesh: .generateBox(size: 1),
      materials: [SimpleMaterial(color: .systemTeal, isMetallic: false)]
    )
    ViewportRenderStyleApplier.apply(.shadedWithEdges, edgeDisplay: .hidden, to: entity)
    XCTAssertNotNil(entity.findEntity(named: ViewportRenderStyleApplier.meshEdgeOverlayName))
  }

  func testSectionViewInstallsInteractivePlaneAndHandle() throws {
    let root = Entity()
    let box = ModelEntity(
      mesh: .generateBox(size: 1),
      materials: [
        ViewportRenderStyleApplier.partMaterial(.shaded, baseColor: .systemTeal)
      ]
    )
    root.addChild(box)

    ViewportSectionFactory.apply(
      ViewportSectionPlane(isEnabled: true, axis: .z, positionMeters: 0.25),
      to: root
    )

    XCTAssertNotNil(root.findEntity(named: ViewportSectionFactory.planeName))
    let handle = try XCTUnwrap(root.findEntity(named: ViewportSectionFactory.handleName))
    XCTAssertNotNil(handle.components[InputTargetComponent.self])
  }
}
