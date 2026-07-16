import AnimaModel
import XCTest

@testable import AnimaEvaluation

final class MateConnectorMathTests: XCTestCase {
  func testConnectorSnapMovesChildFaceToParentFaceWithOpposingNormals() {
    let parent = RigPartDefinition(
      displayName: "Base",
      primitiveKind: .box,
      positionMeters: RigVector3(x: 1, y: 0, z: 0)
    )
    let child = RigPartDefinition(displayName: "Arm", primitiveKind: .box)
    let parentConnector = MateConnectorDefinition(
      originMeters: RigVector3(x: 0.25, y: 0, z: 0),
      primaryAxis: RigVector3(x: 1, y: 0, z: 0),
      secondaryAxis: RigVector3(x: 0, y: 0, z: 1)
    )
    let childConnector = MateConnectorDefinition(
      originMeters: RigVector3(x: -0.25, y: 0, z: 0),
      primaryAxis: RigVector3(x: -1, y: 0, z: 0),
      secondaryAxis: RigVector3(x: 0, y: 0, z: 1)
    )

    let result = MateConnectorMath.snappedChildTransform(
      childPart: child,
      childConnector: childConnector,
      parentPart: parent,
      parentConnector: parentConnector
    )

    XCTAssertEqual(result.positionMeters.x, 1.5, accuracy: 1e-9)
    XCTAssertEqual(result.positionMeters.y, 0, accuracy: 1e-9)
    XCTAssertEqual(result.positionMeters.z, 0, accuracy: 1e-9)
    XCTAssertEqual(result.rotationEulerRadians.x, 0, accuracy: 1e-9)
    XCTAssertEqual(result.rotationEulerRadians.y, 0, accuracy: 1e-9)
    XCTAssertEqual(result.rotationEulerRadians.z, 0, accuracy: 1e-9)
  }
}
