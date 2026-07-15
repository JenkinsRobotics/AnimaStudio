import XCTest

@testable import AnimaStudioUI

@MainActor
final class WorkspacePresentationTests: XCTestCase {
  func testBuiltInWorkspaceOrderAndNamesAreStable() {
    XCTAssertEqual(
      StudioWorkspaceKind.allCases.map(\.descriptor.title),
      ["Assets", "Rig", "Animate", "Show", "Hardware"]
    )
    XCTAssertEqual(StudioWorkspaceKind.rig.shortcutNumber, 2)
    XCTAssertEqual(StudioWorkspaceKind.hardware.shortcutNumber, 5)
  }

  func testEachWorkspaceRestoresItsOwnPresentation() {
    let model = StudioWorkspaceModel()
    XCTAssertEqual(model.activeWorkspace, .rig)
    XCTAssertTrue(model.activePresentation.showsNavigator)

    model.toggleNavigator()
    XCTAssertFalse(model.activePresentation.showsNavigator)

    model.switchWorkspace(to: .assets)
    XCTAssertTrue(model.activePresentation.showsNavigator)
    model.toggleInspector()
    XCTAssertFalse(model.activePresentation.showsInspector)

    model.switchWorkspace(to: .rig)
    XCTAssertFalse(model.activePresentation.showsNavigator)
    XCTAssertTrue(model.activePresentation.showsInspector)

    model.resetActivePresentation()
    XCTAssertEqual(
      model.activePresentation,
      StudioWorkspaceKind.rig.descriptor.defaultPresentation
    )
  }

  func testLeavingAnimateStopsPlayback() {
    let model = StudioWorkspaceModel()
    model.switchWorkspace(to: .animate)
    model.isPlaying = true

    model.switchWorkspace(to: .show)

    XCTAssertFalse(model.isPlaying)
  }

  func testBottomEditorOnlyChangesInTimelineWorkspaces() {
    let model = StudioWorkspaceModel()
    XCTAssertFalse(model.activePresentation.showsBottomEditor)
    model.toggleBottomEditor()
    XCTAssertFalse(model.activePresentation.showsBottomEditor)

    model.switchWorkspace(to: .animate)
    XCTAssertTrue(model.activePresentation.showsBottomEditor)
    model.toggleBottomEditor()
    XCTAssertFalse(model.activePresentation.showsBottomEditor)
  }

  func testInspectableSelectionRevealsTheRightInspector() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let part = try XCTUnwrap(model.project.rig.parts.first)
    model.toggleInspector()
    XCTAssertFalse(model.activePresentation.showsInspector)

    model.selectPart(id: part.id, extendingSelection: false)

    XCTAssertTrue(model.activePresentation.showsInspector)
  }
}
