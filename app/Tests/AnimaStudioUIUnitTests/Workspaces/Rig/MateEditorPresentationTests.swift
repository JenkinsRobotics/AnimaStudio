import XCTest

@testable import AnimaStudioUI

final class MateEditorPresentationTests: XCTestCase {
  func testEveryMateMapsToTheSharedContractDofOrder() {
    XCTAssertEqual(MateCreationToolKind.fastened.editorDegreesOfFreedom, [])
    XCTAssertEqual(
      MateCreationToolKind.parallel.editorDegreesOfFreedom,
      [.translationX, .translationY, .translationZ, .rotationZ]
    )
    XCTAssertEqual(MateCreationToolKind.slider.editorDegreesOfFreedom, [.translationZ])
    XCTAssertEqual(MateCreationToolKind.revolute.editorDegreesOfFreedom, [.rotationZ])
    XCTAssertEqual(
      MateCreationToolKind.cylindrical.editorDegreesOfFreedom,
      [.rotationZ, .translationZ]
    )
    XCTAssertEqual(
      MateCreationToolKind.pinSlot.editorDegreesOfFreedom,
      [.rotationZ, .translationX]
    )
    XCTAssertEqual(
      MateCreationToolKind.planar.editorDegreesOfFreedom,
      [.translationX, .translationY, .rotationZ]
    )
    XCTAssertEqual(
      MateCreationToolKind.ball.editorDegreesOfFreedom,
      [.rotationX, .rotationY, .rotationZ]
    )
  }

  func testOnlyMotionBearingMatesExposeLimits() {
    XCTAssertFalse(MateCreationToolKind.fastened.supportsLimits)
    for kind in MateCreationToolKind.allCases where kind != .fastened {
      XCTAssertTrue(kind.supportsLimits, "\(kind.title) should expose Limits")
    }
  }

  func testSliderOffsetsOnlyConstrainedTranslationAxes() {
    XCTAssertEqual(MateCreationToolKind.slider.offsetTranslationAxes, [.x, .y])
    XCTAssertEqual(MateCreationToolKind.slider.offsetRotationAxes, [.x, .y, .z])
  }

  func testPlanarOffsetsAndLimitsMatchItsFreedoms() {
    XCTAssertEqual(MateCreationToolKind.planar.offsetTranslationAxes, [.z])
    XCTAssertEqual(MateCreationToolKind.planar.offsetRotationAxes, [.x, .y])
    XCTAssertEqual(
      MateCreationToolKind.planar.editorDegreesOfFreedom.map(\.unitLabel),
      ["mm", "mm", "deg"]
    )
  }

  func testBallHasNoRotationalOffsetButHasThreeRotationLimits() {
    XCTAssertEqual(MateCreationToolKind.ball.offsetTranslationAxes, [.x, .y, .z])
    XCTAssertTrue(MateCreationToolKind.ball.offsetRotationAxes.isEmpty)
    XCTAssertEqual(
      MateCreationToolKind.ball.editorDegreesOfFreedom.map(\.motionKind),
      [.rotation, .rotation, .rotation]
    )
  }
}
