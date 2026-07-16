import XCTest
import simd

@testable import RealityKitViewport

@MainActor
final class MateMotionTests: XCTestCase {
  func testEnginePoseProjectsQuaternionRealComponentLast() throws {
    let pose = try XCTUnwrap(
      EngineResolvedPartPose(
        positionMeters: [1, 2, 3],
        orientationImaginaryReal: [0, 0, sin(.pi / 4), cos(.pi / 4)]
      )
    )
    let transform = pose.realityKitTransform
    let rotatedX = transform.rotation.act(SIMD3<Float>(1, 0, 0))

    XCTAssertEqual(transform.translation.x, 1, accuracy: 1e-5)
    XCTAssertEqual(transform.translation.y, 2, accuracy: 1e-5)
    XCTAssertEqual(transform.translation.z, 3, accuracy: 1e-5)
    XCTAssertEqual(rotatedX.x, 0, accuracy: 1e-5)
    XCTAssertEqual(rotatedX.y, 1, accuracy: 1e-5)
    XCTAssertEqual(rotatedX.z, 0, accuracy: 1e-5)
  }

  func testEnginePoseRejectsMalformedOrNonFiniteBridgeValues() {
    XCTAssertNil(
      EngineResolvedPartPose(
        positionMeters: [0, 0],
        orientationImaginaryReal: [0, 0, 0, 1]
      )
    )
    XCTAssertNil(
      EngineResolvedPartPose(
        positionMeters: [0, .infinity, 0],
        orientationImaginaryReal: [0, 0, 0, 1]
      )
    )
  }
}
