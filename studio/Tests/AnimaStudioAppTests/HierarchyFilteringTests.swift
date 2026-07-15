import RealityKitViewport
import XCTest

@testable import AnimaStudioApp

final class HierarchyFilteringTests: XCTestCase {
  func testFilterKeepsAncestorsOfMatchingNode() throws {
    let hierarchy = node(
      "Robot", 0,
      children: [
        node("Head", 0, children: [node("Left Eye", 0)]),
        node("Torso", 1),
      ])

    let filtered = try XCTUnwrap(hierarchy.filtered(matching: "eye"))

    XCTAssertEqual(filtered.displayName, "Robot")
    XCTAssertEqual(filtered.children.map(\.displayName), ["Head"])
    XCTAssertEqual(filtered.children.first?.children.map(\.displayName), ["Left Eye"])
  }

  func testMatchingParentKeepsItsCompleteSubtree() throws {
    let hierarchy = node(
      "Robot", 0,
      children: [
        node("Head", 0, children: [node("Left Eye", 0), node("Right Eye", 1)]),
        node("Torso", 1),
      ])

    let filtered = try XCTUnwrap(hierarchy.filtered(matching: "head"))

    XCTAssertEqual(filtered.children.first?.children.count, 2)
  }

  func testBlankFilterReturnsOriginalHierarchy() {
    let hierarchy = node("Robot", 0, children: [node("Head", 0)])

    XCTAssertEqual(hierarchy.filtered(matching: "   "), hierarchy)
  }

  func testFilterReturnsNilWithoutMatch() {
    let hierarchy = node("Robot", 0, children: [node("Head", 0)])

    XCTAssertNil(hierarchy.filtered(matching: "wheel"))
  }

  private func node(
    _ name: String,
    _ index: Int,
    children: [ModelHierarchyNode] = []
  ) -> ModelHierarchyNode {
    ModelHierarchyNode(
      id: ModelEntityPath(
        components: [ModelEntityPathComponent(name: name, siblingIndex: index)]
      ),
      name: name,
      children: children
    )
  }
}
