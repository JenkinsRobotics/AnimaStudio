import XCTest

@testable import AnimaModel

final class RigAuthoringTests: XCTestCase {
  func testRigPartsAndJointConnectionsRoundTrip() throws {
    let base = RigPartDefinition(displayName: "Base", primitiveKind: .box)
    let head = RigPartDefinition(
      displayName: "Head",
      primitiveKind: .sphere,
      positionMeters: RigVector3(x: 0, y: 0.8, z: 0),
      rotationEulerRadians: RigVector3(x: 0.1, y: 0.2, z: 0.3)
    )
    let joint = JointDefinition(
      id: "head_yaw",
      displayName: "Head Yaw",
      axis: .y,
      minimumRadians: -.pi / 2,
      maximumRadians: .pi / 2,
      parentPartID: base.id,
      childPartID: head.id
    )
    let project = AnimaProject(
      name: "Round Trip",
      rig: CharacterRig(parts: [base, head], joints: [joint]),
      clips: []
    )

    let encoded = try JSONEncoder().encode(project)
    let decoded = try JSONDecoder().decode(AnimaProject.self, from: encoded)

    XCTAssertEqual(decoded, project)
    XCTAssertEqual(decoded.rig.joints.first?.parentPartID, base.id)
    XCTAssertEqual(decoded.rig.joints.first?.childPartID, head.id)
    XCTAssertEqual(decoded.rig.parts[1].rotationEulerRadians, head.rotationEulerRadians)
  }

  func testLegacyPartWithoutRestTransformDecodesAtWorkspaceOrigin() throws {
    let part = RigPartDefinition(displayName: "Legacy", primitiveKind: .box)
    let data = try JSONEncoder().encode(part)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object.removeValue(forKey: "positionMeters")
    object.removeValue(forKey: "rotationEulerRadians")

    let legacyData = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(RigPartDefinition.self, from: legacyData)

    XCTAssertEqual(decoded.positionMeters, RigVector3())
    XCTAssertEqual(decoded.rotationEulerRadians, RigVector3())
  }

  func testEveryPrimitiveKindHasAStableRawValue() {
    XCTAssertEqual(
      RigPrimitiveKind.allCases.map(\.rawValue),
      ["box", "cylinder", "sphere", "locator", "mesh"]
    )
  }

  func testMeshKindIsImportOnlyAndNotOfferedByThePalette() {
    XCTAssertFalse(RigPrimitiveKind.creatableCases.contains(.mesh))
    XCTAssertEqual(RigPrimitiveKind.creatableCases, [.box, .cylinder, .sphere, .locator])
  }

  func testJointConnectorFramesRoundTripAndRemainOptional() throws {
    let connector = MateConnectorDefinition(
      originMeters: RigVector3(x: 0.1, y: 0.2, z: 0.3),
      primaryAxis: RigVector3(x: 0, y: 1, z: 0),
      secondaryAxis: RigVector3(x: 1, y: 0, z: 0)
    )
    let joint = JointDefinition(
      id: "connector_joint",
      displayName: "Connector Joint",
      axis: .z,
      minimumRadians: -1,
      maximumRadians: 1,
      parentConnector: connector,
      childConnector: connector
    )

    let encoded = try JSONEncoder().encode(joint)
    let decoded = try JSONDecoder().decode(JointDefinition.self, from: encoded)

    XCTAssertEqual(decoded.parentConnector, connector)
    XCTAssertEqual(decoded.childConnector, connector)
  }
}
