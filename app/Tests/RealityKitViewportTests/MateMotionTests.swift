import AnimaEvaluation
import AnimaModel
import XCTest

@testable import RealityKitViewport

@MainActor
final class MateMotionTests: XCTestCase {
  func testRevoluteMotionRotatesChildAroundConnectorInsteadOfPartOrigin() throws {
    let parent = RigPartDefinition(displayName: "Base", primitiveKind: .box)
    var child = RigPartDefinition(displayName: "Arm", primitiveKind: .box)
    let parentConnector = MateConnectorDefinition()
    let childConnector = MateConnectorDefinition(
      originMeters: RigVector3(x: -1, y: 0, z: 0),
      primaryAxis: RigVector3(x: 0, y: 0, z: -1),
      secondaryAxis: RigVector3(x: 1, y: 0, z: 0)
    )
    let neutralTransform = MateConnectorMath.snappedChildTransform(
      childPart: child,
      childConnector: childConnector,
      parentPart: parent,
      parentConnector: parentConnector
    )
    child.positionMeters = neutralTransform.positionMeters
    child.rotationEulerRadians = neutralTransform.rotationEulerRadians
    let joint = JointDefinition(
      id: "hinge",
      displayName: "Hinge",
      axis: .z,
      minimumRadians: -.pi,
      maximumRadians: .pi,
      parentPartID: parent.id,
      childPartID: child.id,
      parentConnector: parentConnector,
      childConnector: childConnector
    )
    let rig = CharacterRig(parts: [parent, child], joints: [joint])
    let frame = EvaluatedFrame(
      timeSeconds: 0,
      jointAnglesRadians: [joint.id: .pi / 2]
    )

    let matrix = try XCTUnwrap(
      RigPoseResolver.matrices(rig: rig, frame: frame)[child.id]
    )

    XCTAssertEqual(matrix.columns.3.x, 0, accuracy: 1e-5)
    XCTAssertEqual(matrix.columns.3.y, 1, accuracy: 1e-5)
    XCTAssertEqual(matrix.columns.3.z, 0, accuracy: 1e-5)
  }
}
