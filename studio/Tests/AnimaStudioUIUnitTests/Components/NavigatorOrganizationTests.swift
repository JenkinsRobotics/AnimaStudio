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

  func testOrderingCanMoveAValueBeforeADestination() {
    XCTAssertEqual(
      NavigatorOrdering.moving(["A", "B", "C", "D"], value: "D", before: "B"),
      ["A", "D", "B", "C"]
    )
    XCTAssertEqual(
      NavigatorOrdering.moving(["A", "B", "C"], value: "A", before: "C"),
      ["B", "A", "C"]
    )
    XCTAssertEqual(
      NavigatorOrdering.moving(["A", "B"], value: "A", before: "A"),
      ["A", "B"]
    )
    XCTAssertEqual(
      NavigatorOrdering.moving(
        ["A", "B", "C", "D"],
        value: "A",
        relativeTo: "C",
        placement: .after
      ),
      ["B", "C", "A", "D"]
    )
  }

  func testDropBehaviorUsesLinesAtRowEdgesAndGroupTargetAtCenter() {
    let payload = NavigatorDragPayload.component(PartID())

    XCTAssertEqual(
      NavigatorDropBehavior.component.intent(
        for: payload,
        verticalPosition: 2,
        rowHeight: 24
      ),
      .before
    )
    XCTAssertEqual(
      NavigatorDropBehavior.component.intent(
        for: payload,
        verticalPosition: 12,
        rowHeight: 24
      ),
      .group
    )
    XCTAssertEqual(
      NavigatorDropBehavior.component.intent(
        for: payload,
        verticalPosition: 22,
        rowHeight: 24
      ),
      .after
    )
  }

  func testGroupAndMateTargetsOnlyAcceptTheirSupportedPayloads() {
    let component = NavigatorDragPayload.component(PartID())
    let group = NavigatorDragPayload.componentGroup(UUID())
    let mate = NavigatorDragPayload.mate("mate_1")

    XCTAssertEqual(
      NavigatorDropBehavior.componentGroup.intent(
        for: component,
        verticalPosition: 2,
        rowHeight: 24
      ),
      .group
    )
    XCTAssertEqual(
      NavigatorDropBehavior.componentGroup.intent(
        for: group,
        verticalPosition: 20,
        rowHeight: 24
      ),
      .after
    )
    XCTAssertEqual(
      NavigatorDropBehavior.mate.intent(for: mate, verticalPosition: 2, rowHeight: 24),
      .before
    )
    XCTAssertNil(
      NavigatorDropBehavior.mate.intent(for: component, verticalPosition: 2, rowHeight: 24)
    )
  }

  func testDragPayloadsRoundTripWithoutConflatingTreeItemKinds() {
    let componentID = PartID()
    let groupID = UUID()
    let mateID = JointID(rawValue: "neck:yaw:1")
    let payloads: [NavigatorDragPayload] = [
      .component(componentID),
      .componentGroup(groupID),
      .mate(mateID),
    ]

    for payload in payloads {
      XCTAssertEqual(NavigatorDragPayload(encodedValue: payload.encodedValue), payload)
    }
    XCTAssertNil(NavigatorDragPayload(encodedValue: "unknown:item"))
    XCTAssertNil(NavigatorDragPayload(encodedValue: "anima-mate:"))
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
  func testGroupCreationUsesEverySelectedUnlockedComponent() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    model.addPart(kind: .sphere)
    model.addPart(kind: .cylinder)
    let ids = model.project.rig.parts.map(\.id)
    let lockedID = try XCTUnwrap(ids.dropFirst().first)
    model.toggleComponentLock(lockedID)
    model.selection = Set(ids.map(NavigatorItem.part))

    XCTAssertEqual(model.selectedComponentIDs, ids)
    XCTAssertEqual(model.selectedUnlockedComponentIDs, [ids[0], ids[2]])

    let groupID = model.createComponentGroup(named: "Selected")
    XCTAssertEqual(model.componentGroup(containing: ids[0])?.id, groupID)
    XCTAssertNil(model.componentGroup(containing: lockedID))
    XCTAssertEqual(model.componentGroup(containing: ids[2])?.id, groupID)
  }

  @MainActor
  func testComponentsAndGroupsCanMoveByDragDestination() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    model.addPart(kind: .sphere)
    model.addPart(kind: .cylinder)
    model.addPart(kind: .locator)
    let ids = model.project.rig.parts.map(\.id)

    model.selection = [.part(ids[0]), .part(ids[1])]
    let firstGroupID = model.createComponentGroup(named: "First")
    model.selection = [.part(ids[2])]
    let secondGroupID = model.createComponentGroup(named: "Second")

    XCTAssertTrue(model.moveComponent(ids[1], before: ids[0]))
    XCTAssertEqual(model.componentGroups[0].componentIDs, [ids[1], ids[0]])

    XCTAssertTrue(model.moveComponent(ids[3], toGroup: secondGroupID))
    XCTAssertTrue(model.moveComponent(ids[1], before: ids[2]))
    XCTAssertEqual(model.componentGroups[0].componentIDs, [ids[0]])
    XCTAssertEqual(model.componentGroups[1].componentIDs, [ids[1], ids[2], ids[3]])

    XCTAssertTrue(model.moveComponentGroup(secondGroupID, before: firstGroupID))
    XCTAssertEqual(model.componentGroups.map(\.id), [secondGroupID, firstGroupID])

    XCTAssertTrue(model.moveComponent(ids[1], toGroup: nil))
    XCTAssertNil(model.componentGroup(containing: ids[1]))
  }

  @MainActor
  func testCenterDropCreatesAGroupFromTheActiveComponentSelection() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    model.addPart(kind: .sphere)
    model.addPart(kind: .cylinder)
    let ids = model.project.rig.parts.map(\.id)
    model.selection = [.part(ids[0]), .part(ids[1])]

    let groupID = try XCTUnwrap(model.groupComponents(draggedID: ids[0], onto: ids[2]))

    XCTAssertEqual(model.componentGroups.first?.componentIDs, ids)
    XCTAssertEqual(model.selection, [.componentGroup(groupID)])
  }

  @MainActor
  func testCenterDropOntoGroupedComponentAddsSelectionToExistingFolder() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    model.addPart(kind: .sphere)
    model.addPart(kind: .cylinder)
    let ids = model.project.rig.parts.map(\.id)
    model.selection = [.part(ids[2])]
    let groupID = model.createComponentGroup(named: "Existing")
    model.selection = [.part(ids[0]), .part(ids[1])]

    XCTAssertEqual(model.groupComponents(draggedID: ids[0], onto: ids[2]), groupID)
    XCTAssertEqual(model.componentGroups.first?.componentIDs, [ids[2], ids[0], ids[1]])
    XCTAssertEqual(model.selection, [.componentGroup(groupID)])
  }

  @MainActor
  func testInsertionDropCanPlaceAComponentAfterItsTarget() {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    model.addPart(kind: .sphere)
    model.addPart(kind: .cylinder)
    let ids = model.project.rig.parts.map(\.id)

    XCTAssertTrue(model.moveComponent(ids[0], relativeTo: ids[1], placement: .after))
    XCTAssertEqual(model.project.rig.parts.map(\.id), [ids[1], ids[0], ids[2]])
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
  func testMatesCanMoveByDragDestinationUnlessLocked() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    model.addPart(kind: .sphere)
    model.addPart(kind: .cylinder)
    model.createRevoluteJoint()
    model.createRevoluteJoint()
    model.createRevoluteJoint()
    let mateIDs = model.project.rig.joints.map(\.id)

    XCTAssertTrue(model.moveMate(mateIDs[2], before: mateIDs[0]))
    XCTAssertEqual(model.project.rig.joints.map(\.id), [mateIDs[2], mateIDs[0], mateIDs[1]])

    model.toggleMateLock(mateIDs[0])
    XCTAssertFalse(model.moveMate(mateIDs[1], before: mateIDs[0]))
    XCTAssertEqual(model.project.rig.joints.map(\.id), [mateIDs[2], mateIDs[0], mateIDs[1]])
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
