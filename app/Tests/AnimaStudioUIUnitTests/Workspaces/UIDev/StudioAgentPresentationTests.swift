import XCTest

@testable import AnimaStudioUI

final class StudioAgentPresentationTests: XCTestCase {
  func testAgentUsesTheConstrainedInAppPanelPattern() {
    XCTAssertEqual(UIDevAgentPanelDescriptor.title, "Anima Agent")
    XCTAssertEqual(UIDevAgentPanelDescriptor.width, 360)
    XCTAssertTrue(UIDevAgentPanelDescriptor.isDocked)
    XCTAssertNotEqual(UIDevAgentPanelDescriptor.title, UIDevDetachedWindowDescriptor.title)
  }

  func testFloatingToolsHaveAnExplicitSeparateTemplate() {
    XCTAssertEqual(UIDevDetachedWindowDescriptor.title, "Detached Window")
    XCTAssertGreaterThan(UIDevDetachedWindowDescriptor.minimumSize.width, 0)
  }
}
