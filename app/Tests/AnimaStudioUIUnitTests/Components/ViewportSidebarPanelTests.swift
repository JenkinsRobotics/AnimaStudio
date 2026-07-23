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
    XCTAssertEqual(
      Set(ViewportControlPlacement.viewSidebar).intersection(
        ViewportControlPlacement.environmentSidebar
      ),
      []
    )
    XCTAssertEqual(
      Set(ViewportControlPlacement.viewportHUD).intersection(
        ViewportControlPlacement.viewSidebar + ViewportControlPlacement.environmentSidebar
      ),
      []
    )
  }

  func testFormerHUDControlsAreOwnedByTheRightSidebar() {
    XCTAssertTrue(ViewportControlPlacement.viewSidebar.contains(.display))
    XCTAssertTrue(ViewportControlPlacement.viewSidebar.contains(.mouseSettings))
    XCTAssertTrue(ViewportControlPlacement.viewSidebar.contains(.cameraHelp))
    XCTAssertTrue(ViewportControlPlacement.environmentSidebar.contains(.visualization))
  }
}
