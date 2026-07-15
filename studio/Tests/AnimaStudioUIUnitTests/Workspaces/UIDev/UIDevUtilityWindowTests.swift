import AppKit
import XCTest

@testable import AnimaStudioUI

@MainActor
final class UIDevUtilityWindowTests: XCTestCase {
  func testWindowCatalogSeparatesSidePanelsFromThe3DWorkspace() {
    XCTAssertEqual(
      UIDevUtilityWindowKind.allCases,
      [.navigator, .inspector, .timeline, .workspace3D]
    )
    XCTAssertTrue(UIDevUtilityWindowKind.navigator.isUtilityPanel)
    XCTAssertTrue(UIDevUtilityWindowKind.inspector.isUtilityPanel)
    XCTAssertTrue(UIDevUtilityWindowKind.timeline.isUtilityPanel)
    XCTAssertFalse(UIDevUtilityWindowKind.workspace3D.isUtilityPanel)

    for kind in UIDevUtilityWindowKind.allCases {
      XCTAssertFalse(kind.title.isEmpty)
      XCTAssertFalse(kind.systemImage.isEmpty)
      XCTAssertGreaterThanOrEqual(kind.contentSize.width, kind.minimumSize.width)
      XCTAssertGreaterThanOrEqual(kind.contentSize.height, kind.minimumSize.height)
    }
  }

  func testLaunchersReuseOneCorrectlyTypedWindowPerSurface() {
    defer {
      for kind in UIDevUtilityWindowKind.allCases {
        UIDevUtilityWindowRegistry.hide(kind)
      }
    }

    for kind in UIDevUtilityWindowKind.allCases {
      UIDevUtilityWindowRegistry.show(kind)
      guard let firstWindow = UIDevUtilityWindowRegistry.existingWindow(for: kind) else {
        return XCTFail("Missing \(kind.title) window")
      }

      XCTAssertEqual(firstWindow.title, kind.title)
      XCTAssertFalse(firstWindow.isReleasedWhenClosed)
      XCTAssertGreaterThanOrEqual(firstWindow.contentMinSize.width, kind.minimumSize.width)
      XCTAssertGreaterThanOrEqual(firstWindow.contentMinSize.height, kind.minimumSize.height)
      if kind.isUtilityPanel {
        XCTAssertTrue(firstWindow is NSPanel)
        XCTAssertTrue((firstWindow as? NSPanel)?.isFloatingPanel == true)
      } else {
        XCTAssertFalse(firstWindow is NSPanel)
      }

      UIDevUtilityWindowRegistry.show(kind)
      XCTAssertTrue(UIDevUtilityWindowRegistry.existingWindow(for: kind) === firstWindow)
    }

    for kind in UIDevUtilityWindowKind.allCases {
      XCTAssertTrue(
        UIDevUtilityWindowRegistry.existingWindow(for: kind)?.isVisible == true,
        "Expected \(kind.title) to remain visible while the other UI Dev windows launch"
      )
    }
  }
}
