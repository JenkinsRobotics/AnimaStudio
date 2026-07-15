import XCTest

@testable import AnimaStudioUI

final class WorkspaceChromeTests: XCTestCase {
  func testRigUsesCreationRibbonWhenToolsAreExpanded() {
    XCTAssertEqual(
      WorkspaceRibbonPresentation.resolve(
        workspace: .rig,
        showsRigCreationTools: true
      ),
      .rigCreation
    )
  }

  func testCollapsedRigAndOtherWorkspacesUseCompactRibbon() {
    XCTAssertEqual(
      WorkspaceRibbonPresentation.resolve(
        workspace: .rig,
        showsRigCreationTools: false
      ),
      .compactRig
    )

    for workspace in StudioWorkspaceKind.allCases where workspace != .rig {
      XCTAssertEqual(
        WorkspaceRibbonPresentation.resolve(
          workspace: workspace,
          showsRigCreationTools: true
        ),
        .workspaceTools
      )
    }
  }

  func testExpandedWorkspaceRibbonsUseTheFullHeight() {
    XCTAssertEqual(
      WorkspaceRibbonPresentation.rigCreation.height,
      StudioMetrics.rigCreationRibbonHeight
    )
    XCTAssertEqual(
      WorkspaceRibbonPresentation.workspaceTools.height,
      StudioMetrics.rigCreationRibbonHeight
    )
    XCTAssertEqual(
      WorkspaceRibbonPresentation.compactRig.height,
      StudioMetrics.compactRibbonHeight
    )
  }

  func testWorkspaceSelectorKeepsAReadableMinimumWidth() {
    XCTAssertGreaterThanOrEqual(WorkspaceSelectorMetrics.minimumWidth, 220)
    XCTAssertGreaterThanOrEqual(
      WorkspaceSelectorMetrics.idealWidth,
      WorkspaceSelectorMetrics.minimumWidth
    )
    XCTAssertGreaterThanOrEqual(
      WorkspaceSelectorMetrics.maximumWidth,
      WorkspaceSelectorMetrics.idealWidth
    )
    XCTAssertGreaterThanOrEqual(
      WorkspaceSelectorMetrics.menuWidth,
      WorkspaceSelectorMetrics.minimumWidth
    )
  }
}
