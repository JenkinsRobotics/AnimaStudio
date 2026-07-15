import AnimaCore
import XCTest

@testable import AnimaStudioUI

@MainActor
final class RigCreationTests: XCTestCase {
  func testNewProjectStartsWithAnEmptyRigAndCreationTools() {
    let model = StudioWorkspaceModel()

    XCTAssertTrue(model.project.rig.parts.isEmpty)
    XCTAssertTrue(model.project.rig.joints.isEmpty)
    XCTAssertTrue(model.project.clips.isEmpty)
    XCTAssertTrue(model.isRigEmpty)
    XCTAssertTrue(model.showsCreationPalette)
    XCTAssertFalse(model.canCreateRevoluteJoint)
  }

  func testAddingPartCreatesCoreRigDataAndSelectsIt() {
    let model = StudioWorkspaceModel()

    model.addPart(kind: .cylinder)

    let part = try! XCTUnwrap(model.project.rig.parts.first)
    XCTAssertEqual(part.primitiveKind, .cylinder)
    XCTAssertEqual(part.displayName, "Cylinder 1")
    XCTAssertEqual(model.selection, [.part(part.id)])
    XCTAssertTrue(model.canCreateRevoluteJoint)
  }

  func testNewJointConnectsSelectedPartAndCanBeConfigured() {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let base = model.project.rig.parts[0]
    model.addPart(kind: .sphere)
    let child = model.project.rig.parts[1]

    model.createRevoluteJoint()

    let joint = try! XCTUnwrap(model.project.rig.joints.first)
    XCTAssertEqual(joint.parentPartID, base.id)
    XCTAssertEqual(joint.childPartID, child.id)
    XCTAssertEqual(model.selection, [.joint(joint.id)])

    model.setJointAxis(id: joint.id, to: .z)
    model.setJointRange(id: joint.id, minimumRadians: -0.5, maximumRadians: 0.75)
    XCTAssertEqual(model.project.rig.joints[0].axis, .z)
    XCTAssertEqual(model.project.rig.joints[0].minimumRadians, -0.5)
    XCTAssertEqual(model.project.rig.joints[0].maximumRadians, 0.75)
  }
}
