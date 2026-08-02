import XCTest

@testable import AnimaStudioUI

final class ViewportSidebarPanelTests: XCTestCase {
  func testViewportHUDKeepsOnlySpatialControls() {
    XCTAssertEqual(
      ViewportControlPlacement.viewportHUD,
      [.viewCube, .home]
    )
  }

  func testConfigurationControlsHaveOneSidebarOwner() {
    let sidebarControls =
      ViewportControlPlacement.viewSidebar
      + ViewportControlPlacement.environmentSidebar
      + ViewportControlPlacement.performanceSidebar
    XCTAssertEqual(
      Set(ViewportControlPlacement.viewSidebar).intersection(
        ViewportControlPlacement.environmentSidebar
          + ViewportControlPlacement.performanceSidebar
      ),
      []
    )
    XCTAssertEqual(
      Set(ViewportControlPlacement.viewportHUD).intersection(
        sidebarControls
      ),
      []
    )
  }

  func testFormerHUDControlsAreOwnedByTheRightSidebar() {
    XCTAssertTrue(ViewportControlPlacement.viewSidebar.contains(.display))
    XCTAssertTrue(ViewportControlPlacement.viewSidebar.contains(.mouseSettings))
    XCTAssertTrue(ViewportControlPlacement.viewSidebar.contains(.cameraHelp))
    XCTAssertTrue(ViewportControlPlacement.environmentSidebar.contains(.visualization))
    XCTAssertTrue(ViewportControlPlacement.performanceSidebar.contains(.performance))
  }

  func testPerformanceHUDUsesItsOwnViewportCorner() {
    XCTAssertEqual(
      StudioViewSidebarTab.allCases,
      [.view, .environment, .appearance, .performance, .inspector]
    )
    XCTAssertEqual(
      ViewportPerformanceHUDLayout.trailingPadding(hasFloatingRightPanel: false),
      16
    )
    XCTAssertGreaterThan(
      ViewportPerformanceHUDLayout.trailingPadding(hasFloatingRightPanel: true),
      ViewportPerformanceHUDLayout.trailingPadding(hasFloatingRightPanel: false)
    )
    XCTAssertEqual(
      ViewportPerformanceHUDLayout.detailedMetricsBottomPadding(
        showsCompactHUD: true,
        hasEvaluatedFrame: true
      ),
      104
    )
  }
}
