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

  func testDefaultProfileRightOrbitMiddlePan() {
    // Default: right-drag orbits, middle-drag pans, scroll zooms.
    XCTAssertEqual(
      action(button: .right, profile: .default),
      .orbit(deltaX: 3, deltaY: -2)
    )
    XCTAssertEqual(
      action(button: .middle, profile: .default),
      .pan(deltaX: 3, deltaY: -2)
    )
    // Modifiers on middle stay a plain pan in the default profile.
    XCTAssertEqual(
      action(button: .middle, shift: true, profile: .default),
      .pan(deltaX: 3, deltaY: -2)
    )
  }

  func testSolidWorksMouseProfileUsesMiddleButtonModifiers() {
    XCTAssertEqual(
      action(button: .middle, profile: .solidWorks),
      .orbit(deltaX: 3, deltaY: -2)
    )
    XCTAssertEqual(
      action(button: .middle, option: true, profile: .solidWorks),
      .pan(deltaX: 3, deltaY: -2)
    )
    XCTAssertEqual(
      action(button: .middle, shift: true, profile: .solidWorks),
      .preciseZoom(delta: -2)
    )
    XCTAssertEqual(
      action(button: .middle, control: true, profile: .solidWorks),
      .orbit(deltaX: 3, deltaY: -2)
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
      panDrag: .optionMiddleMouse,
      preciseZoomDrag: .shiftMiddleMouse
    )

    XCTAssertEqual(
      action(button: .right, control: true, profile: .custom, customMapping: mapping),
      .orbit(deltaX: 3, deltaY: -2)
    )
    XCTAssertEqual(
      action(button: .middle, option: true, profile: .custom, customMapping: mapping),
      .pan(deltaX: 3, deltaY: -2)
    )
    XCTAssertEqual(
      action(button: .middle, shift: true, profile: .custom, customMapping: mapping),
      .preciseZoom(delta: -2)
    )
    XCTAssertNil(action(button: .middle, profile: .custom, customMapping: mapping))

    let conflict = CustomNavigationMapping(
      rotateDrag: .middleMouse,
      panDrag: .middleMouse,
      preciseZoomDrag: .middleMouse
    )
    XCTAssertNotEqual(conflict.rotateDrag, conflict.panDrag)
    XCTAssertNotEqual(conflict.rotateDrag, conflict.preciseZoomDrag)
    XCTAssertNotEqual(conflict.panDrag, conflict.preciseZoomDrag)
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
    XCTAssertEqual(
      CADNavigationAction.preciseZoom(delta: 10).scaled(by: sensitivity),
      .preciseZoom(delta: 2.275)
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

  func testDiscreteWheelNormalizesAccelerationToOneNotch() {
    XCTAssertEqual(
      CADZoomInputNormalizer.normalizedDelta(
        rawDeltaY: 1,
        hasPreciseScrollingDeltas: false,
        isReversed: false
      ),
      1
    )
    XCTAssertEqual(
      CADZoomInputNormalizer.normalizedDelta(
        rawDeltaY: 48,
        hasPreciseScrollingDeltas: false,
        isReversed: false
      ),
      1
    )
    XCTAssertEqual(
      CADZoomInputNormalizer.normalizedDelta(
        rawDeltaY: -22,
        hasPreciseScrollingDeltas: false,
        isReversed: true
      ),
      1
    )
  }

  func testPreciseScrollIsContinuousClampedAndReversible() {
    XCTAssertEqual(
      CADZoomInputNormalizer.normalizedDelta(
        rawDeltaY: 4,
        hasPreciseScrollingDeltas: true,
        isReversed: false
      ),
      0.14,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      CADZoomInputNormalizer.normalizedDelta(
        rawDeltaY: 100,
        hasPreciseScrollingDeltas: true,
        isReversed: false
      ),
      0.45
    )
    XCTAssertEqual(
      CADZoomInputNormalizer.normalizedDelta(
        rawDeltaY: 4,
        hasPreciseScrollingDeltas: true,
        isReversed: true
      ),
      -0.14,
      accuracy: 0.0001
    )
  }

  func testPresetSummariesMatchExecutableMappings() {
    XCTAssertEqual(PreviewNavigationProfile.default.summary().orbit, "Right drag")
    XCTAssertEqual(PreviewNavigationProfile.default.summary().pan, "Middle drag")
    XCTAssertEqual(PreviewNavigationProfile.solidWorks.summary().pan, "Option + middle drag")
    XCTAssertEqual(PreviewNavigationProfile.onshape.summary().orbit, "Right drag")
    XCTAssertTrue(PreviewNavigationProfile.fusion360.summary().special.contains("Double"))
  }

  func testRightMouseSequenceSeparatesClickFromDrag() {
    var click = CADRightMouseSequence()
    click.begin(at: CGPoint(x: 10, y: 10))
    XCTAssertFalse(click.drag(to: CGPoint(x: 11, y: 11)))
    XCTAssertEqual(click.end(), .openContextMenu)

    var drag = CADRightMouseSequence()
    drag.begin(at: CGPoint(x: 10, y: 10))
    XCTAssertTrue(drag.drag(to: CGPoint(x: 14, y: 10)))
    XCTAssertEqual(drag.end(), .suppressContextMenu)
    XCTAssertEqual(drag.end(), .ignored)
  }

  private func action(
    button: CADNavigationMouseButton,
    control: Bool = false,
    shift: Bool = false,
    option: Bool = false,
    profile: PreviewNavigationProfile,
    customMapping: CustomNavigationMapping = CustomNavigationMapping()
  ) -> CADNavigationAction? {
    CADNavigationMapping.action(
      for: CADNavigationInput(
        button: button,
        deltaX: 3,
        deltaY: -2,
        isControlDown: control,
        isShiftDown: shift,
        isOptionDown: option
      ),
      profile: profile,
      customMapping: customMapping
    )
  }
}
