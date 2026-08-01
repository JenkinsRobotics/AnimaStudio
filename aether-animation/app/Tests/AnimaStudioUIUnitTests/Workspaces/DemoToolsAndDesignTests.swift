import XCTest

@testable import AnimaStudioUI

@MainActor
final class DemoToolsAndDesignTests: XCTestCase {
  func testDemoCatalogCoversEveryRequestedWorkspaceFamily() {
    for workspace in [
      StudioWorkspaceKind.assets, .rig, .animate, .show, .hardware, .design,
    ] {
      let groups = DemoWorkspaceToolCatalog.groups(for: workspace)
      XCTAssertFalse(groups.isEmpty, "\(workspace) must retain the Demo catalog")
      XCTAssertTrue(groups.allSatisfy { !$0.tools.isEmpty })
    }
    XCTAssertTrue(DemoWorkspaceToolCatalog.groups(for: .nodes).isEmpty)
  }

  func testProductionMergePreservesCommandsAndDoesNotDuplicateLabelsInsideAGroup() {
    let groups = StudioWorkspaceToolCatalog.groups(for: .assets)
    let importGroup = groups.first { $0.title == "Import" }
    XCTAssertEqual(importGroup?.tools.filter { $0.title == "3D Model" }.count, 1)
    guard
      case .command(.importModel) = importGroup?.tools.first(where: { $0.title == "3D Model" })?
        .behavior
    else {
      return XCTFail("The real model-import command must win over the Demo specimen")
    }
  }

  func testDesignUsesAllSixFusionStyleCategoriesAndTypedPlaceholderPayloads() {
    XCTAssertEqual(
      DemoWorkspaceToolCatalog.designCategories.map(\.title),
      ["Design", "Sketch", "Surface", "Mesh", "Sheet Metal", "Assemble"]
    )
    let extrude = DemoWorkspaceToolCatalog.designCategories
      .flatMap(\.groups).flatMap(\.tools).first { $0.title == "Extrude" }
    guard case .arm(.designPlaceholder(let toolID)) = extrude?.behavior else {
      return XCTFail("Design tools need a typed placeholder payload")
    }
    XCTAssertEqual(toolID, "Extrude")
  }

  func testRigCategoryRibbonActuallyExposesAdditiveDemoConcepts() {
    let workspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)
    let tools = StudioWorkspaceToolCatalog.rigCategories(workspace: workspace)
      .flatMap(\.groups).flatMap(\.tools)

    XCTAssertNotNil(tools.first { $0.title == "Locator" })
    XCTAssertNotNil(tools.first { $0.title == "Measure" })
    XCTAssertNotNil(tools.first { $0.title == "Section" })
    XCTAssertNotNil(tools.first { $0.title == "Limits" })
    XCTAssertEqual(tools.filter { $0.title == "Box" }.count, 1)
  }

  func testDesignSandboxPlacesUpdatesAndDeletesDeterministically() throws {
    let model = StudioDesignSandboxModel.shared
    model.shapes = []
    model.selectedShapeID = nil

    model.place(toolName: "Extrude", at: CGPoint(x: 120, y: 160))
    var shape = try XCTUnwrap(model.selectedShape)
    XCTAssertEqual(shape.name, "Extrude 1")
    XCTAssertEqual(shape.position, CGPoint(x: 120, y: 160))

    shape.material = "Aluminum"
    model.update(shape)
    XCTAssertEqual(model.selectedShape?.material, "Aluminum")

    model.deleteSelection()
    XCTAssertTrue(model.shapes.isEmpty)
    XCTAssertNil(model.selectedShapeID)
  }

  func testDemoUIKitIsAStableDiscoverableSection() {
    XCTAssertTrue(UIDevSection.allCases.contains(.demoUIKit))
    XCTAssertFalse(UIDevSection.demoUIKit.title.isEmpty)
    XCTAssertFalse(UIDevSection.demoUIKit.purpose.isEmpty)
  }
}
