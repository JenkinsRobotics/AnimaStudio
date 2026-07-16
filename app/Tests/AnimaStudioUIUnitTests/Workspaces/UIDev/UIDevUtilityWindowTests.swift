import AppKit
import XCTest

@testable import AnimaStudioUI

@MainActor
final class UIDevUtilityWindowTests: XCTestCase {
  func testOnlyTheExplicitDetachedTemplateDefinesAWindow() {
    XCTAssertEqual(UIDevDetachedWindowDescriptor.title, "Detached Window")
    XCTAssertFalse(UIDevDetachedWindowDescriptor.systemImage.isEmpty)
    XCTAssertGreaterThanOrEqual(
      UIDevDetachedWindowDescriptor.contentSize.width,
      UIDevDetachedWindowDescriptor.minimumSize.width
    )
    XCTAssertGreaterThanOrEqual(
      UIDevDetachedWindowDescriptor.contentSize.height,
      UIDevDetachedWindowDescriptor.minimumSize.height
    )
  }

  func testDetachedLauncherReusesOneFloatingPanel() {
    defer { UIDevDetachedWindowRegistry.hide() }

    UIDevDetachedWindowRegistry.show()
    guard let firstWindow = UIDevDetachedWindowRegistry.existingWindow() else {
      return XCTFail("Missing detached UI Dev window")
    }

    XCTAssertEqual(firstWindow.title, UIDevDetachedWindowDescriptor.title)
    XCTAssertFalse(firstWindow.isReleasedWhenClosed)
    XCTAssertTrue(firstWindow.isFloatingPanel)

    UIDevDetachedWindowRegistry.show()
    XCTAssertTrue(UIDevDetachedWindowRegistry.existingWindow() === firstWindow)
  }
}
