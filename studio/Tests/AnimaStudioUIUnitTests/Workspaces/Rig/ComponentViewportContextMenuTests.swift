import AnimaCore
import RealityKitViewport
import XCTest

@testable import AnimaStudioUI

@MainActor
final class ComponentViewportContextMenuTests: XCTestCase {
  func testContextStateRequiresOneSelectedSemanticComponent() throws {
    let model = StudioWorkspaceModel()
    XCTAssertNil(model.selectedComponentContextMenuState)

    model.addPart(kind: .cylinder)
    let part = try XCTUnwrap(model.project.rig.parts.first)
    let state = try XCTUnwrap(model.selectedComponentContextMenuState)

    XCTAssertEqual(state.partID, part.id)
    XCTAssertEqual(state.displayName, part.displayName)
    XCTAssertEqual(state.primitiveKind, .cylinder)
    XCTAssertEqual(state.lockScope, .unlocked)
    XCTAssertTrue(state.isVisible)

    model.clearSelection()
    XCTAssertNil(model.selectedComponentContextMenuState)
  }

  func testContextMenuCanOpenTheRequestedInspectorTab() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    model.toggleInspector()
    XCTAssertFalse(model.activePresentation.showsInspector)

    model.showComponentInspector(.appearance)

    XCTAssertEqual(model.componentInspectorTab, .appearance)
    XCTAssertTrue(model.activePresentation.showsInspector)
  }

  func testVisibilityActionPreservesAppearanceAndHonorsLocks() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .sphere)
    let part = try XCTUnwrap(model.project.rig.parts.first)
    let custom = try XCTUnwrap(
      PreviewPartAppearance(hexRGB: "#9DCFED", opacity: 0.65, isVisible: true)
    )
    model.setComponentAppearance(id: part.id, to: custom)

    model.toggleSelectedComponentVisibility()
    let hidden = try XCTUnwrap(model.componentAppearance(for: part.id))
    XCTAssertEqual(hidden.hexRGB, custom.hexRGB)
    XCTAssertEqual(hidden.opacity, custom.opacity)
    XCTAssertFalse(hidden.isVisible)

    model.toggleSelectedComponentLock()
    model.toggleSelectedComponentVisibility()
    XCTAssertFalse(try XCTUnwrap(model.componentAppearance(for: part.id)).isVisible)
  }

  func testLockActionUnlocksTheOwningGroupWhenThatIsTheLockSource() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let part = try XCTUnwrap(model.project.rig.parts.first)
    let groupID = model.createComponentGroup(named: "Head")
    model.toggleComponentGroupLock(groupID)
    model.selectPart(id: part.id, extendingSelection: false)

    let lockedState = try XCTUnwrap(model.selectedComponentContextMenuState)
    XCTAssertEqual(lockedState.lockScope, .group(groupID))
    XCTAssertEqual(lockedState.lockActionTitle, "Unlock Group")

    model.toggleSelectedComponentLock()
    XCTAssertFalse(model.isComponentLocked(part.id))
  }

  func testTransformResetCommandsAreModelGuarded() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let part = try XCTUnwrap(model.project.rig.parts.first)
    let position = RigVector3(x: 1, y: 2, z: 3)
    let rotation = RigVector3(x: 0.1, y: 0.2, z: 0.3)
    model.setPartPosition(id: part.id, to: position)
    model.setPartRotation(id: part.id, to: rotation)

    model.resetSelectedComponentPosition()
    XCTAssertEqual(try XCTUnwrap(model.project.rig.parts.first).positionMeters, RigVector3())
    XCTAssertEqual(try XCTUnwrap(model.project.rig.parts.first).rotationEulerRadians, rotation)

    model.toggleSelectedComponentLock()
    model.resetSelectedComponentRotation()
    XCTAssertEqual(try XCTUnwrap(model.project.rig.parts.first).rotationEulerRadians, rotation)

    model.toggleSelectedComponentLock()
    model.resetSelectedComponentTransform()
    let resetPart = try XCTUnwrap(model.project.rig.parts.first)
    XCTAssertEqual(resetPart.positionMeters, RigVector3())
    XCTAssertEqual(resetPart.rotationEulerRadians, RigVector3())
  }

  func testIsolationAndTransparencyAreReversibleViewportPresentation() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let selectedPart = try XCTUnwrap(model.project.rig.parts.first)
    model.addPart(kind: .sphere)
    let otherPart = try XCTUnwrap(model.project.rig.parts.last)
    model.selectPart(id: selectedPart.id, extendingSelection: false)

    model.toggleSelectedComponentIsolation()
    model.toggleSelectedComponentTransparency()

    let activeState = try XCTUnwrap(model.selectedComponentContextMenuState)
    XCTAssertTrue(activeState.isIsolated)
    XCTAssertTrue(activeState.hasActiveIsolation)
    XCTAssertTrue(activeState.isTransparent)
    XCTAssertTrue(try XCTUnwrap(model.viewportPartAppearances[selectedPart.id]).isVisible)
    XCTAssertEqual(try XCTUnwrap(model.viewportPartAppearances[selectedPart.id]).opacity, 0.28)
    XCTAssertFalse(try XCTUnwrap(model.viewportPartAppearances[otherPart.id]).isVisible)

    model.toggleSelectedComponentIsolation()
    model.toggleSelectedComponentTransparency()

    XCTAssertNil(model.isolatedComponentID)
    XCTAssertFalse(model.transparentComponentIDs.contains(selectedPart.id))
    XCTAssertTrue(try XCTUnwrap(model.viewportPartAppearances[otherPart.id]).isVisible)
  }

  func testLockedComponentRejectsTransparencyButCanBeIsolatedForInspection() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let part = try XCTUnwrap(model.project.rig.parts.first)
    model.toggleComponentLock(part.id)

    model.toggleSelectedComponentTransparency()
    model.toggleSelectedComponentIsolation()

    XCTAssertFalse(model.transparentComponentIDs.contains(part.id))
    XCTAssertEqual(model.isolatedComponentID, part.id)
  }

  func testDependencyMenuSelectsOnlyAnAttachedMate() throws {
    let parent = RigPartDefinition(displayName: "Base", primitiveKind: .box)
    let part = RigPartDefinition(displayName: "Head", primitiveKind: .sphere)
    let attachedMate = JointDefinition(
      id: "head_yaw",
      displayName: "Head Yaw",
      axis: .z,
      minimumRadians: -.pi,
      maximumRadians: .pi,
      parentPartID: parent.id,
      childPartID: part.id
    )
    let model = StudioWorkspaceModel(
      project: AnimaProject(
        name: "Context Menu Test",
        rig: CharacterRig(parts: [parent, part], joints: [attachedMate]),
        clips: []
      )
    )
    model.selectPart(id: part.id, extendingSelection: false)

    let state = try XCTUnwrap(model.selectedComponentContextMenuState)
    XCTAssertTrue(state.dependencies.contains(where: { $0.id == attachedMate.id }))

    model.selectAttachedMate(attachedMate.id)
    XCTAssertEqual(model.primarySelection, .joint(attachedMate.id))
  }

  func testSelectAllAndHomeViewCommandsUseSharedWorkspaceState() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    model.addPart(kind: .sphere)
    model.cameraViewpoint = .custom

    model.selectAllComponents()
    model.showHomeView()

    XCTAssertEqual(model.selectedComponentIDs.count, 2)
    XCTAssertEqual(model.cameraViewpoint, .home)
  }
}
