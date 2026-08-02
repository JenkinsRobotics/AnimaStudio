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
    XCTAssertEqual(MateCreationToolKind.width.editorDegreesOfFreedom, [])
    XCTAssertEqual(MateCreationToolKind.tangent.editorDegreesOfFreedom, [])
  }

  func testOnlyMotionBearingMatesExposeLimits() {
    XCTAssertFalse(MateCreationToolKind.fastened.supportsLimits)
    for kind in MateCreationToolKind.allCases
    where ![.fastened, .width, .tangent].contains(kind) {
      XCTAssertTrue(kind.supportsLimits, "\(kind.title) should expose Limits")
    }
    XCTAssertFalse(MateCreationToolKind.width.supportsLimits)
    XCTAssertFalse(MateCreationToolKind.tangent.supportsLimits)
  }

  func testGeometryMatesSuppressOffsetAndUseTheCorrectSelectionModel() {
    XCTAssertFalse(MateCreationToolKind.width.supportsOffset)
    XCTAssertFalse(MateCreationToolKind.width.usesTangentSurfaceSelections)
    XCTAssertTrue(MateCreationToolKind.width.isGeometryConstraint)
    XCTAssertFalse(MateCreationToolKind.tangent.supportsOffset)
    XCTAssertTrue(MateCreationToolKind.tangent.usesTangentSurfaceSelections)
    XCTAssertTrue(MateCreationToolKind.tangent.isGeometryConstraint)
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
