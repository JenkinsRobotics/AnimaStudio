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
      .orbit(deltaX: 3, deltaY: -2)
    )
  }

  func testDefaultProfileUsesTheOnshapeStyleMapping() {
    XCTAssertEqual(
      action(button: .right, profile: .default),
      .orbit(deltaX: 3, deltaY: -2)
    )
    XCTAssertEqual(
      action(button: .middle, profile: .default),
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
      .pan(deltaX: 3, deltaY: -2)
    )
    XCTAssertNil(action(button: .right, profile: .solidWorks))
  }

  func testFusion360UsesShiftMiddleOrbitAndMiddlePan() {
    XCTAssertEqual(
      action(button: .middle, shift: true, profile: .fusion360),
      .orbit(deltaX: 3, deltaY: -2)
    )
    XCTAssertEqual(
      action(button: .middle, profile: .fusion360),
      .pan(deltaX: 3, deltaY: -2)
    )
  }

  func testCustomProfileUsesEditableConflictFreeBindings() {
    let mapping = CustomNavigationMapping(
      rotateDrag: .controlRightMouse,
      panDrag: .shiftMiddleMouse
    )

    XCTAssertEqual(
      action(button: .right, control: true, profile: .custom, customMapping: mapping),
      .orbit(deltaX: 3, deltaY: -2)
    )
    XCTAssertEqual(
      action(button: .middle, shift: true, profile: .custom, customMapping: mapping),
      .pan(deltaX: 3, deltaY: -2)
    )
    XCTAssertNil(action(button: .middle, profile: .custom, customMapping: mapping))

    let conflict = CustomNavigationMapping(
      rotateDrag: .middleMouse,
      panDrag: .middleMouse
    )
    XCTAssertNotEqual(conflict.rotateDrag, conflict.panDrag)
  }

  func testNavigationProfileMenuOrderIsStable() {
    XCTAssertEqual(
      PreviewNavigationProfile.allCases.map(\.rawValue),
      ["default", "solidWorks", "onshape", "fusion360", "custom"]
    )
  }

  func testNavigationSpeedOrderAndDefaultZoomAreStable() {
    XCTAssertEqual(
      PreviewNavigationSpeed.allCases,
      [.slow, .reduced, .standard, .fast, .veryFast]
    )
    let sensitivity = PreviewNavigationSensitivity()
    XCTAssertEqual(sensitivity.orbit, .standard)
    XCTAssertEqual(sensitivity.pan, .standard)
    XCTAssertEqual(sensitivity.zoom, .reduced)
    XCTAssertLessThan(sensitivity.zoom.multiplier, sensitivity.orbit.multiplier)
  }

  func testNavigationActionsScaleEachAxisIndependently() {
    let sensitivity = PreviewNavigationSensitivity(
      orbit: .fast,
      pan: .slow,
      zoom: .reduced
    )

    XCTAssertEqual(
      CADNavigationAction.orbit(deltaX: 10, deltaY: -4).scaled(by: sensitivity),
      .orbit(deltaX: 13.5, deltaY: -5.4)
    )
    XCTAssertEqual(
      CADNavigationAction.pan(deltaX: 10, deltaY: -4).scaled(by: sensitivity),
      .pan(deltaX: 4, deltaY: -1.6)
    )
    XCTAssertEqual(
      CADNavigationAction.zoom(delta: 10).scaled(by: sensitivity),
      .zoom(delta: 6.5)
    )
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

  func testDiscreteMouseWheelIsClassifiedAsZoomInput() {
    XCTAssertEqual(
      CADScrollInputClassifier.button(
        hasPreciseScrollingDeltas: false,
        hasGesturePhase: false,
        hasMomentumPhase: false,
        deltaX: 0
      ),
      .scroll
    )
    XCTAssertEqual(
      CADScrollInputClassifier.button(
        hasPreciseScrollingDeltas: true,
        hasGesturePhase: false,
        hasMomentumPhase: false,
        deltaX: 0
      ),
      .scroll
    )
  }

  func testTrackpadScrollPhasesRemainPanInput() {
    XCTAssertEqual(
      CADScrollInputClassifier.button(
        hasPreciseScrollingDeltas: true,
        hasGesturePhase: true,
        hasMomentumPhase: false,
        deltaX: 0
      ),
      .trackpadPan
    )
    XCTAssertEqual(
      CADScrollInputClassifier.button(
        hasPreciseScrollingDeltas: true,
        hasGesturePhase: false,
        hasMomentumPhase: true,
        deltaX: 0
      ),
      .trackpadPan
    )
  }

  private func action(
    button: CADNavigationMouseButton,
    control: Bool = false,
    shift: Bool = false,
    profile: PreviewNavigationProfile,
    customMapping: CustomNavigationMapping = CustomNavigationMapping()
  ) -> CADNavigationAction? {
    CADNavigationMapping.action(
      for: CADNavigationInput(
        button: button,
        deltaX: 3,
        deltaY: -2,
        isControlDown: control,
        isShiftDown: shift
      ),
      profile: profile,
      customMapping: customMapping
    )
  }
}
