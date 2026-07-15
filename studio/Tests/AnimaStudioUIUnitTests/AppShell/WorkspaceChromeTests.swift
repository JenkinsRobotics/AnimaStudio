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
      .compact
    )

    for workspace in StudioWorkspaceKind.allCases where workspace != .rig {
      XCTAssertEqual(
        WorkspaceRibbonPresentation.resolve(
          workspace: workspace,
          showsRigCreationTools: true
        ),
        .compact
      )
    }
  }
}
