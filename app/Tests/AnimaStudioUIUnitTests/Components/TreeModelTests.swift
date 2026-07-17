import XCTest

@testable import AnimaStudioUI

final class TreeModelTests: XCTestCase {
  func testMoveReordersAndReparentsWithoutLosingIdentity() {
    var model = TreeModel(roots: [
      TestTreeNode(id: "a"),
      TestTreeNode(id: "folder", acceptsChildren: true),
      TestTreeNode(id: "b"),
    ])

    XCTAssertTrue(model.move("b", onto: "a", placement: .before))
    XCTAssertEqual(model.roots.map(\.id), ["b", "a", "folder"])
    XCTAssertTrue(model.move("a", onto: "folder", placement: .inside))
    XCTAssertEqual(model.roots.map(\.id), ["b", "folder"])
    XCTAssertEqual(model.node(id: "folder")?.children.map(\.id), ["a"])
  }

  func testGroupingCondensesSelectedNodesIntoProvidedFolder() {
    var model = TreeModel(roots: [
      TestTreeNode(id: "a"), TestTreeNode(id: "b"), TestTreeNode(id: "c"),
    ])

    XCTAssertTrue(
      model.group(
        ["a", "c"],
        using: TestTreeNode(id: "group", acceptsChildren: true)
      )
    )
    XCTAssertEqual(model.roots.map(\.id), ["b", "group"])
    XCTAssertEqual(model.node(id: "group")?.children.map(\.id), ["a", "c"])
  }

  func testFilterRetainsAncestorsAndCombinesNameWithStateTokens() {
    let hiddenArm = TestTreeNode(
      id: "arm",
      filterText: "Left Arm semantic part",
      filterTokens: [.part, .hidden]
    )
    let model = TreeModel(roots: [
      TestTreeNode(
        id: "folder",
        children: [hiddenArm],
        filterText: "Mechanism",
        filterTokens: [.part],
        acceptsChildren: true
      ),
      TestTreeNode(id: "mate", filterText: "Shoulder revolute", filterTokens: [.mate]),
    ])

    let filtered = model.filtered(by: TreeFilterQuery("arm :part :hidden"))
    XCTAssertEqual(filtered.roots.map(\.id), ["folder"])
    XCTAssertEqual(filtered.roots.first?.children.map(\.id), ["arm"])
    XCTAssertTrue(model.filtered(by: TreeFilterQuery(":suppressed")).roots.isEmpty)
  }

  func testDropValidationRejectsLocksAndFolderIntoDescendant() {
    let child = TestTreeNode(id: "child", acceptsChildren: true)
    let folder = TestTreeNode(id: "folder", children: [child], acceptsChildren: true)
    let locked = TestTreeNode(id: "locked", isLocked: true)
    let leaf = TestTreeNode(id: "leaf")
    let model = TreeModel(roots: [folder, locked, leaf])

    XCTAssertFalse(model.canDrop(sourceID: "folder", onto: "child", placement: .inside))
    XCTAssertFalse(model.canDrop(sourceID: "locked", onto: "leaf", placement: .before))
    XCTAssertFalse(model.canDrop(sourceID: "leaf", onto: "locked", placement: .after))
    XCTAssertFalse(model.canDrop(sourceID: "leaf", onto: "leaf", placement: .inside))
    XCTAssertTrue(model.canDrop(sourceID: "leaf", onto: "folder", placement: .inside))
  }

  func testFlattenAndAncestorsDriveDisclosureAndReveal() {
    let model = TreeModel(roots: [
      TestTreeNode(
        id: "root",
        children: [
          TestTreeNode(id: "nested", children: [TestTreeNode(id: "target")])
        ],
        acceptsChildren: true
      )
    ])

    XCTAssertEqual(model.ancestorIDs(of: "target"), ["root", "nested"])
    XCTAssertEqual(model.flattened(expandedIDs: []).map(\.id), ["root"])
    XCTAssertEqual(
      model.flattened(expandedIDs: ["root", "nested"]).map(\.id),
      ["root", "nested", "target"]
    )
  }
}

private struct TestTreeNode: TreeNode {
  var id: String
  var selectionValue: String { id }
  var children: [TestTreeNode] = []
  var filterText: String = ""
  var filterTokens: Set<TreeFilterToken> = []
  var isLocked = false
  var acceptsChildren = false
}
