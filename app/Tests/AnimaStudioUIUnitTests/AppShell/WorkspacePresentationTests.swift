import XCTest

@testable import AnimaStudioUI

@MainActor
final class WorkspacePresentationTests: XCTestCase {
  func testBuiltInWorkspaceOrderAndNamesAreStable() {
    XCTAssertEqual(
      StudioWorkspaceKind.allCases.map(\.descriptor.title),
      ["Character", "Rig", "Animate", "2D", "Show", "Nodes", "Hardware", "Design"]
    )
    XCTAssertEqual(StudioWorkspaceKind.rig.shortcutNumber, 2)
    XCTAssertEqual(StudioWorkspaceKind.nodes.shortcutNumber, 5)
    XCTAssertEqual(StudioWorkspaceKind.hardware.shortcutNumber, 6)
    XCTAssertEqual(StudioWorkspaceKind.design.shortcutNumber, 7)
  }

  func testEachWorkspaceRestoresItsOwnPresentation() {
    let model = StudioWorkspaceModel()
    XCTAssertEqual(model.activeWorkspace, .assets)
    XCTAssertTrue(model.activePresentation.showsNavigator)

    model.toggleNavigator()
    XCTAssertFalse(model.activePresentation.showsNavigator)

    model.switchWorkspace(to: .rig)
    XCTAssertTrue(model.activePresentation.showsNavigator)
    model.toggleInspector()
    XCTAssertFalse(model.activePresentation.showsInspector)

    model.switchWorkspace(to: .assets)
    XCTAssertFalse(model.activePresentation.showsNavigator)
    XCTAssertTrue(model.activePresentation.showsInspector)

    model.resetActivePresentation()
    XCTAssertEqual(
      model.activePresentation,
      StudioWorkspaceKind.assets.descriptor.defaultPresentation
    )
  }

  func testStartupWorkspaceCanBeProvidedByFuturePreferences() {
    let model = StudioWorkspaceModel(startupWorkspace: .animate)

    XCTAssertEqual(model.activeWorkspace, .animate)
    XCTAssertEqual(
      model.activePresentation,
      StudioWorkspaceKind.animate.descriptor.defaultPresentation
    )
  }

  func testLeavingAnimateStopsPlayback() {
    let model = StudioWorkspaceModel()
    model.switchWorkspace(to: .animate)
    model.isPlaying = true

    model.switchWorkspace(to: .show)

    XCTAssertFalse(model.isPlaying)
  }

  func testTimelineRibbonTogglesFullHeightCenterRepresentations() {
    let model = StudioWorkspaceModel()
    XCTAssertFalse(model.activePresentation.showsBottomEditor)
    model.toggleBottomEditor()
    XCTAssertEqual(model.activeCenterView, .threeD)

    model.switchWorkspace(to: .animate)
    XCTAssertEqual(model.activeCenterView, .threeD)
    model.toggleBottomEditor()
    XCTAssertEqual(model.activeCenterView, .dopeSheet)
    model.toggleBottomEditor()
    XCTAssertEqual(model.activeCenterView, .threeD)

    model.switchWorkspace(to: .show)
    XCTAssertEqual(model.activeCenterView, .nodeGraph)
    model.selectCenterView(.table)
    model.switchWorkspace(to: .animate)
    model.selectCenterView(.curves)
    XCTAssertEqual(model.timelineEditorMode, .graph)
    model.switchWorkspace(to: .show)
    XCTAssertEqual(model.activeCenterView, .table)
  }

  func testInspectableSelectionRevealsTheRightInspector() throws {
    StudioViewSidebarState.shared.panels.closeAll()
    defer { StudioViewSidebarState.shared.panels.closeAll() }
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let part = try XCTUnwrap(model.project.rig.parts.first)
    model.toggleInspector()
    XCTAssertFalse(model.activePresentation.showsInspector)

    model.selectPart(id: part.id, extendingSelection: false)

    XCTAssertTrue(model.activePresentation.showsInspector)
    XCTAssertTrue(
      StudioViewSidebarState.shared.panels.isEnabled(StudioViewSidebarTab.inspector.rawValue)
    )
  }
}
