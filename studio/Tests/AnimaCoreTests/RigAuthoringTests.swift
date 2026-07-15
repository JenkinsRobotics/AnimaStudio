import XCTest

@testable import AnimaCore

final class RigAuthoringTests: XCTestCase {
  func testRigPartsAndJointConnectionsRoundTrip() throws {
    let base = RigPartDefinition(displayName: "Base", primitiveKind: .box)
    let head = RigPartDefinition(
      displayName: "Head",
      primitiveKind: .sphere,
      positionMeters: RigVector3(x: 0, y: 0.8, z: 0)
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
  }

  func testEveryPrimitiveKindHasAStableRawValue() {
    XCTAssertEqual(
      RigPrimitiveKind.allCases.map(\.rawValue),
      ["box", "cylinder", "sphere", "locator"]
    )
  }
}
