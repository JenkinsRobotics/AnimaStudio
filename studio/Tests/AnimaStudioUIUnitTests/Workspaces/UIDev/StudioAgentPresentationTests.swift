import XCTest

@testable import AnimaStudioUI

final class StudioAgentPresentationTests: XCTestCase {
  func testAgentUsesTheConstrainedInAppPanelPattern() {
    XCTAssertEqual(UIDevAgentPanelDescriptor.title, "Anima Agent")
    XCTAssertEqual(UIDevAgentPanelDescriptor.width, 360)
    XCTAssertTrue(UIDevAgentPanelDescriptor.isDocked)
    XCTAssertFalse(
      UIDevUtilityWindowKind.allCases.contains { $0.title == UIDevAgentPanelDescriptor.title }
    )
  }

  func testFloatingToolsHaveAnExplicitSeparateTemplate() {
    XCTAssertTrue(UIDevUtilityWindowKind.floatingTemplate.isUtilityPanel)
    XCTAssertEqual(UIDevUtilityWindowKind.floatingTemplate.title, "Floating Template")
  }
}
