import RealityKit
import XCTest

@testable import RealityKitViewport

final class RealityKitModelLoadingTests: XCTestCase {
  @MainActor
  func testLoadsUSDHierarchyFromDisk() async throws {
    let modelURL = try XCTUnwrap(
      Bundle.module.url(
        forResource: "SimpleRobot",
        withExtension: "usda",
        subdirectory: "Fixtures"
      )
    )

    let model = try await Entity(contentsOf: modelURL)

    XCTAssertNotNil(model.findEntity(named: "Body"))
    XCTAssertNotNil(model.findEntity(named: "HeadYaw"))
    XCTAssertNotNil(model.findEntity(named: "Head"))
  }

  @MainActor
  func testProjectsLoadedUSDIntoInspectableValueHierarchy() async throws {
    let modelURL = try XCTUnwrap(
      Bundle.module.url(
        forResource: "SimpleRobot",
        withExtension: "usda",
        subdirectory: "Fixtures"
      )
    )

    let hierarchy = try await RealityKitModelHierarchy.load(contentsOf: modelURL)
    let nodes = hierarchy.flattened

    XCTAssertTrue(nodes.contains { $0.name == "Body" })
    XCTAssertTrue(nodes.contains { $0.name == "HeadYaw" })
    XCTAssertTrue(nodes.contains { $0.name == "Head" })
    XCTAssertEqual(Set(nodes.map(\.id)).count, nodes.count)

    let head = try XCTUnwrap(nodes.first { $0.name == "Head" })
    XCTAssertEqual(hierarchy.node(at: head.id), head)
    XCTAssertTrue(head.id.displayString.contains("Head"))
    XCTAssertTrue(head.id.modelNodeReference.hasSuffix("HeadYaw/Head"))
  }

  @MainActor
  func testModelIOLoadsSTLAndScalesMillimetersToMeters() async throws {
    let modelURL = try XCTUnwrap(
      Bundle.module.url(
        forResource: "MillimeterTriangle",
        withExtension: "stl",
        subdirectory: "Fixtures"
      )
    )

    let model = try await RealityKitModelLoader.load(
      contentsOf: modelURL,
      unitScaleToMeters: 0.001
    )
    let bounds = model.visualBounds(relativeTo: nil)

    XCTAssertEqual(bounds.extents.x, 1, accuracy: 0.0001)
    XCTAssertEqual(bounds.extents.y, 1, accuracy: 0.0001)
  }

  @MainActor
  func testModelIOLoadsOBJAndScalesCentimetersToMeters() async throws {
    let modelURL = try XCTUnwrap(
      Bundle.module.url(
        forResource: "CentimeterTriangle",
        withExtension: "obj",
        subdirectory: "Fixtures"
      )
    )

    let model = try await RealityKitModelLoader.load(
      contentsOf: modelURL,
      unitScaleToMeters: 0.01
    )
    let bounds = model.visualBounds(relativeTo: nil)

    XCTAssertEqual(bounds.extents.x, 1, accuracy: 0.0001)
    XCTAssertEqual(bounds.extents.y, 1, accuracy: 0.0001)
  }

  @MainActor
  func testModelLoaderRejectsSTEPInsteadOfPretendingItIsRenderable() async {
    do {
      _ = try await RealityKitModelLoader.load(
        contentsOf: URL(fileURLWithPath: "/tmp/model.step")
      )
      XCTFail("Expected STEP to remain an honest unsupported format")
    } catch let RealityKitModelLoadingError.unsupportedFileType(fileExtension) {
      XCTAssertEqual(fileExtension, "step")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  @MainActor
  func testDuplicateAndUnnamedEntitiesReceiveDistinctPaths() throws {
    let root = Entity()
    root.name = "Root"

    let firstLink = Entity()
    firstLink.name = "Link"
    root.addChild(firstLink)

    let secondLink = Entity()
    secondLink.name = "Link"
    root.addChild(secondLink)

    let unnamed = Entity()
    secondLink.addChild(unnamed)

    let hierarchy = RealityKitModelHierarchy.inspect(root)
    let links = hierarchy.flattened.filter { $0.name == "Link" }
    let unnamedNode = try XCTUnwrap(
      hierarchy.flattened.first { $0.name.isEmpty }
    )

    XCTAssertEqual(links.count, 2)
    XCTAssertNotEqual(links[0].id, links[1].id)
    XCTAssertEqual(unnamedNode.displayName, "Unnamed Entity")
    XCTAssertEqual(hierarchy.nodeCount, 4)
  }

  @MainActor
  func testHierarchyMarksNodesThatOwnRenderableGeometry() throws {
    let root = Entity()
    root.name = "Root"
    let renderable = ModelEntity(
      mesh: .generateBox(size: 0.1),
      materials: [SimpleMaterial()]
    )
    renderable.name = "Renderable Part"
    root.addChild(renderable)

    let hierarchy = RealityKitModelHierarchy.inspect(root)
    let part = try XCTUnwrap(hierarchy.flattened.first { $0.name == "Renderable Part" })

    XCTAssertFalse(hierarchy.hasRenderableGeometry)
    XCTAssertTrue(part.hasRenderableGeometry)
  }
}
