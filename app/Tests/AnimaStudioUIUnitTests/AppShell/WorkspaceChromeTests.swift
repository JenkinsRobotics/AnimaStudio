import XCTest

@testable import AnimaStudioUI

final class WorkspaceChromeTests: XCTestCase {
  func testWindowHeaderDoubleClickFollowsMacOSPreference() {
    XCTAssertEqual(StudioWindowDoubleClickAction.resolve(preference: nil), .zoom)
    XCTAssertEqual(StudioWindowDoubleClickAction.resolve(preference: "Maximize"), .zoom)
    XCTAssertEqual(StudioWindowDoubleClickAction.resolve(preference: "Minimize"), .minimize)
    XCTAssertEqual(StudioWindowDoubleClickAction.resolve(preference: "None"), .none)
  }

  func testCenteredWorkspaceNavigatorKeepsAReadableWidth() {
    XCTAssertGreaterThanOrEqual(WorkspaceSelectorMetrics.minimumWidth, 280)
    XCTAssertGreaterThanOrEqual(
      WorkspaceSelectorMetrics.idealWidth,
      WorkspaceSelectorMetrics.minimumWidth
    )
    XCTAssertGreaterThanOrEqual(
      WorkspaceSelectorMetrics.maximumWidth,
      WorkspaceSelectorMetrics.idealWidth
    )
    XCTAssertLessThan(WorkspaceSelectorMetrics.menuWidth, WorkspaceSelectorMetrics.minimumWidth)
    XCTAssertLessThanOrEqual(WorkspaceSelectorMetrics.maximumWidth, 440)
  }

  func testStudioModesUseOperatorFacingNamesAndCycleInOrder() {
    XCTAssertEqual(StudioLayoutPreset.floating.title, "Floating")
    XCTAssertEqual(StudioLayoutPreset.docked.title, "Docked")
    XCTAssertEqual(StudioLayoutPreset.canvas.title, "Canvas")
    XCTAssertEqual(StudioLayoutPreset.floating.next, .docked)
    XCTAssertEqual(StudioLayoutPreset.docked.next, .canvas)
    XCTAssertEqual(StudioLayoutPreset.canvas.next, .floating)
  }

  func testDocumentBarUsesStableResponsiveDensities() {
    XCTAssertEqual(StudioDocumentBarDensity.resolve(width: 1_800), .expanded)
    XCTAssertEqual(StudioDocumentBarDensity.resolve(width: 1_420), .expanded)
    XCTAssertEqual(StudioDocumentBarDensity.resolve(width: 1_419), .compact)
    XCTAssertEqual(StudioDocumentBarDensity.resolve(width: 1_180), .compact)
    XCTAssertEqual(StudioDocumentBarDensity.resolve(width: 1_179), .minimal)

    XCTAssertEqual(
      StudioDocumentBarDensity.expanded.selectorWidth,
      WorkspaceSelectorMetrics.maximumWidth
    )
    XCTAssertEqual(
      StudioDocumentBarDensity.compact.selectorWidth,
      WorkspaceSelectorMetrics.idealWidth
    )
    XCTAssertEqual(
      StudioDocumentBarDensity.minimal.selectorWidth,
      WorkspaceSelectorMetrics.minimumWidth
    )
  }

  func testProjectIdentityNameWidthFollowsContentAndStaysBounded() {
    let shortNameWidth = StudioProjectIdentityMetrics.projectNameWidth(
      for: "Test",
      density: .expanded
    )
    let mediumNameWidth = StudioProjectIdentityMetrics.projectNameWidth(
      for: "Atlas Animatronic",
      density: .expanded
    )
    let longNameWidth = StudioProjectIdentityMetrics.projectNameWidth(
      for: String(repeating: "Character", count: 30),
      density: .expanded
    )

    XCTAssertLessThan(shortNameWidth, mediumNameWidth)
    XCTAssertLessThan(mediumNameWidth, longNameWidth)
    XCTAssertEqual(longNameWidth, 170)
  }

  @MainActor
  func testLayoutPresetsConfigurePanelsAndRibbonTogether() {
    let workspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)

    workspace.applyLayoutPreset(.docked)
    XCTAssertEqual(workspace.navigatorPlacement, .docked)
    XCTAssertEqual(workspace.inspectorPlacement, .docked)
    XCTAssertEqual(workspace.ribbonPlacement, .docked)

    workspace.applyLayoutPreset(.floating)
    XCTAssertEqual(workspace.navigatorPlacement, .floating)
    XCTAssertEqual(workspace.inspectorPlacement, .floating)
    XCTAssertEqual(workspace.ribbonPlacement, .floating)

    workspace.applyLayoutPreset(.canvas)
    XCTAssertEqual(workspace.navigatorPlacement, .hidden)
    XCTAssertEqual(workspace.inspectorPlacement, .hidden)
    XCTAssertEqual(workspace.ribbonPlacement, .floating)
  }
}
