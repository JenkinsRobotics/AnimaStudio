import XCTest

@testable import RealityKitViewport

final class CADNavigationTests: XCTestCase {
  func testOnshapeMouseProfileUsesRightOrbitAndMiddlePan() {
    XCTAssertEqual(
      action(button: .right, profile: .onshape),
      .orbit(deltaX: 3, deltaY: -2)
    )
    XCTAssertEqual(
      action(button: .middle, profile: .onshape),
      .pan(deltaX: 3, deltaY: -2)
    )
    XCTAssertEqual(
      action(button: .right, control: true, profile: .onshape),
      .pan(deltaX: 3, deltaY: -2)
    )
  }

  func testSolidWorksMouseProfileUsesMiddleButtonModifiers() {
    XCTAssertEqual(
      action(button: .middle, profile: .solidWorks),
      .orbit(deltaX: 3, deltaY: -2)
    )
    XCTAssertEqual(
      action(button: .middle, control: true, profile: .solidWorks),
      .pan(deltaX: 3, deltaY: -2)
    )
    XCTAssertEqual(
      action(button: .middle, shift: true, profile: .solidWorks),
      .zoom(delta: -2)
    )
    XCTAssertNil(action(button: .right, profile: .solidWorks))
  }

  func testTrackpadPanAndZoomAreProfileIndependent() {
    for profile in PreviewNavigationProfile.allCases {
      XCTAssertEqual(
        action(button: .trackpadPan, profile: profile),
        .pan(deltaX: 3, deltaY: -2)
      )
      XCTAssertEqual(
        action(button: .scroll, profile: profile),
        .zoom(delta: -2)
      )
      XCTAssertEqual(
        action(button: .magnify, profile: profile),
        .zoom(delta: -2)
      )
    }
  }

  private func action(
    button: CADNavigationMouseButton,
    control: Bool = false,
    shift: Bool = false,
    profile: PreviewNavigationProfile
  ) -> CADNavigationAction? {
    CADNavigationMapping.action(
      for: CADNavigationInput(
        button: button,
        deltaX: 3,
        deltaY: -2,
        isControlDown: control,
        isShiftDown: shift
      ),
      profile: profile
    )
  }
}
