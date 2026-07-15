import AppKit
import XCTest

@testable import AnimaStudioUI

@MainActor
final class StudioAgentPanelTests: XCTestCase {
  func testAgentLauncherReusesOneFloatingUtilityPanel() {
    StudioAgentPanel.show()

    let firstMatch = matchingPanels
    XCTAssertEqual(firstMatch.count, 1)
    XCTAssertTrue(firstMatch[0].isFloatingPanel)
    XCTAssertFalse(firstMatch[0].isReleasedWhenClosed)
    XCTAssertGreaterThanOrEqual(firstMatch[0].contentMinSize.width, 320)
    XCTAssertGreaterThanOrEqual(firstMatch[0].contentMinSize.height, 520)

    StudioAgentPanel.show()
    XCTAssertEqual(matchingPanels.count, 1)
    firstMatch[0].orderOut(nil)
  }

  private var matchingPanels: [NSPanel] {
    NSApp.windows.compactMap { window in
      guard window.title == "Anima Agent" else { return nil }
      return window as? NSPanel
    }
  }
}
