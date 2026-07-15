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
}
