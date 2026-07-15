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
    XCTAssertEqual(part.positionMeters, RigVector3())
    XCTAssertEqual(part.rotationEulerRadians, RigVector3())
    XCTAssertEqual(model.selection, [.part(part.id)])
    XCTAssertTrue(model.canCreateRevoluteJoint)
  }

  func testViewportStylePartSelectionAndTransformEditSharedCoreState() {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let first = model.project.rig.parts[0]
    model.addPart(kind: .sphere)
    let second = model.project.rig.parts[1]

    model.selectPart(id: first.id, extendingSelection: false)
    XCTAssertEqual(model.selectedPartID, first.id)
    XCTAssertEqual(model.selection, [.part(first.id)])

    model.selectPart(id: second.id, extendingSelection: true)
    XCTAssertEqual(model.selection, [.part(first.id), .part(second.id)])
    XCTAssertNil(model.selectedPartID)

    let position = RigVector3(x: 1.25, y: -0.5, z: 2)
    let rotation = RigVector3(x: 0.1, y: 0.2, z: 0.3)
    model.setPartPosition(id: first.id, to: position)
    model.setPartRotation(id: first.id, to: rotation)
    XCTAssertEqual(model.project.rig.parts[0].positionMeters, position)
    XCTAssertEqual(model.project.rig.parts[0].rotationEulerRadians, rotation)
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
