import XCTest

@testable import RealityKitViewport

final class PreviewCameraTests: XCTestCase {
  func testDirectionsAreNormalizedAndZeroFallsBackToFront() {
    let direction = PreviewCameraDirection(x: 4, y: 3, z: 0)

    XCTAssertEqual(direction.x, 0.8, accuracy: 0.0001)
    XCTAssertEqual(direction.y, 0.6, accuracy: 0.0001)
    XCTAssertEqual(direction.z, 0, accuracy: 0.0001)
    XCTAssertEqual(PreviewCameraDirection(x: 0, y: 0, z: 0), .front)
  }

  func testNudgingFrontDirectionUsesWorldYawAndCameraPitch() {
    let right = PreviewCameraDirection.front.nudged(
      horizontalRadians: .pi / 2,
      verticalRadians: 0
    )
    let top = PreviewCameraDirection.front.nudged(
      horizontalRadians: 0,
      verticalRadians: .pi / 2
    )

    XCTAssertEqual(right.x, 1, accuracy: 0.0001)
    XCTAssertEqual(right.y, 0, accuracy: 0.0001)
    XCTAssertEqual(top.y, 1, accuracy: 0.0001)
  }

  func testCameraStateClampsInvalidlySmallDistancesAndScales() {
    let state = PreviewCameraState(distance: 0, orthographicScale: -10)

    XCTAssertEqual(state.distance, 0.001)
    XCTAssertEqual(state.orthographicScale, 0.001)
  }

  func testCameraRollNormalizesAndPreservesLookDirection() {
    let orientation = PreviewCameraOrientation(
      direction: .right,
      rollRadians: .pi * 2.5
    )
    let rolled = orientation.rolled(by: .pi)

    XCTAssertEqual(orientation.direction, .right)
    XCTAssertEqual(orientation.rollRadians, .pi / 2, accuracy: 0.0001)
    XCTAssertEqual(rolled.direction, .right)
    XCTAssertEqual(rolled.rollRadians, -.pi / 2, accuracy: 0.0001)
  }
}
