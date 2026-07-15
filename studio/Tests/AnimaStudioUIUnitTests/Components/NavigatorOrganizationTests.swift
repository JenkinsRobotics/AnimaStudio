import AnimaCore
import XCTest

@testable import AnimaStudioUI

final class NavigatorOrganizationTests: XCTestCase {
  func testOrderingMovesOnlyWithinAvailableBounds() {
    XCTAssertEqual(
      NavigatorOrdering.moved(["A", "B", "C"], value: "B", direction: .up),
      ["B", "A", "C"]
    )
    XCTAssertEqual(
      NavigatorOrdering.moved(["A", "B", "C"], value: "B", direction: .down),
      ["A", "C", "B"]
    )
    XCTAssertEqual(
      NavigatorOrdering.moved(["A", "B", "C"], value: "A", direction: .up),
      ["A", "B", "C"]
    )
  }

  @MainActor
  func testSelectedComponentsCanBeGroupedReorderedAndUngrouped() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let first = try XCTUnwrap(model.project.rig.parts.last?.id)
    model.addPart(kind: .sphere)
    let second = try XCTUnwrap(model.project.rig.parts.last?.id)
    model.selection = [.part(first), .part(second)]

    let groupID = model.createComponentGroup(named: "Head")
    XCTAssertEqual(model.componentGroups.first?.componentIDs, [first, second])
    XCTAssertEqual(model.selection, [.componentGroup(groupID)])

    model.moveComponent(second, direction: .up)
    XCTAssertEqual(model.componentGroups.first?.componentIDs, [second, first])

    model.moveComponent(first, toGroup: nil)
    XCTAssertNil(model.componentGroup(containing: first))
    XCTAssertEqual(model.componentGroup(containing: second)?.id, groupID)

    model.dissolveComponentGroup(id: groupID)
    XCTAssertTrue(model.componentGroups.isEmpty)
    XCTAssertNil(model.componentGroup(containing: second))
  }

  @MainActor
  func testComponentAndGroupLocksGuardEditingAndOrganization() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let componentID = try XCTUnwrap(model.project.rig.parts.first?.id)
    model.selection = [.part(componentID)]
    let groupID = model.createComponentGroup(named: "Locked Group")
    model.toggleComponentGroupLock(groupID)

    model.renamePart(id: componentID, to: "Changed")
    model.setPartPosition(id: componentID, to: RigVector3(x: 2, y: 3, z: 4))
    model.moveComponent(componentID, toGroup: nil)

    XCTAssertTrue(model.isComponentLocked(componentID))
    XCTAssertNotEqual(model.project.rig.parts.first?.displayName, "Changed")
    XCTAssertEqual(model.project.rig.parts.first?.positionMeters, RigVector3())
    XCTAssertEqual(model.componentGroup(containing: componentID)?.id, groupID)

    model.toggleComponentGroupLock(groupID)
    model.renamePart(id: componentID, to: "Changed")
    XCTAssertEqual(model.project.rig.parts.first?.displayName, "Changed")
  }

  @MainActor
  func testMateLocksGuardRenameAxisAndLimits() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    model.createRevoluteJoint()
    let mate = try XCTUnwrap(model.project.rig.joints.first)
    model.toggleMateLock(mate.id)

    model.renameJoint(id: mate.id, to: "Changed")
    model.setJointAxis(id: mate.id, to: .z)
    model.setJointRange(id: mate.id, minimumRadians: -0.25, maximumRadians: 0.25)

    let lockedMate = try XCTUnwrap(model.project.rig.joints.first)
    XCTAssertEqual(lockedMate.displayName, mate.displayName)
    XCTAssertEqual(lockedMate.axis, mate.axis)
    XCTAssertEqual(lockedMate.minimumRadians, mate.minimumRadians)
    XCTAssertEqual(lockedMate.maximumRadians, mate.maximumRadians)
  }

  @MainActor
  func testLockedComponentCannotReceiveANewMate() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let componentID = try XCTUnwrap(model.project.rig.parts.first?.id)
    model.toggleComponentLock(componentID)

    XCTAssertFalse(model.canCreateRevoluteJoint)
    model.createRevoluteJoint()
    XCTAssertTrue(model.project.rig.joints.isEmpty)
  }
}
