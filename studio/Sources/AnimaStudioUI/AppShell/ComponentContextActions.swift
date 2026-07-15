import AnimaCore
import Foundation

enum ComponentContextLockScope: Equatable {
  case unlocked
  case component
  case group(UUID)
}

struct ComponentContextMenuState: Equatable {
  let partID: PartID
  let displayName: String
  let primitiveKind: RigPrimitiveKind
  let lockScope: ComponentContextLockScope
  let isVisible: Bool

  var isLocked: Bool {
    lockScope != .unlocked
  }

  var lockActionTitle: String {
    switch lockScope {
    case .unlocked:
      "Lock Component"
    case .component:
      "Unlock Component"
    case .group:
      "Unlock Group"
    }
  }

  var lockActionSystemImage: String {
    isLocked ? "lock.open" : "lock"
  }
}

extension StudioWorkspaceModel {
  var selectedComponentContextMenuState: ComponentContextMenuState? {
    guard let partID = selectedPartID,
      let part = project.rig.parts.first(where: { $0.id == partID }),
      let appearance = componentAppearance(for: partID)
    else { return nil }

    let lockScope: ComponentContextLockScope
    if isComponentIndividuallyLocked(partID) {
      lockScope = .component
    } else if let group = componentGroup(containing: partID), group.isLocked {
      lockScope = .group(group.id)
    } else {
      lockScope = .unlocked
    }

    return ComponentContextMenuState(
      partID: partID,
      displayName: part.displayName,
      primitiveKind: part.primitiveKind,
      lockScope: lockScope,
      isVisible: appearance.isVisible
    )
  }

  func showComponentInspector(_ tab: ComponentInspectorTab) {
    guard selectedPartID != nil else { return }
    componentInspectorTab = tab
    if !activePresentation.showsInspector {
      toggleInspector()
    }
  }

  func toggleSelectedComponentVisibility() {
    guard let state = selectedComponentContextMenuState,
      var appearance = componentAppearance(for: state.partID)
    else { return }
    appearance.isVisible.toggle()
    setComponentAppearance(id: state.partID, to: appearance)
  }

  func toggleSelectedComponentLock() {
    guard let state = selectedComponentContextMenuState else { return }
    switch state.lockScope {
    case .unlocked, .component:
      toggleComponentLock(state.partID)
    case .group(let groupID):
      toggleComponentGroupLock(groupID)
    }
  }

  func resetSelectedComponentPosition() {
    guard let partID = selectedPartID else { return }
    setPartPosition(id: partID, to: RigVector3())
  }

  func resetSelectedComponentRotation() {
    guard let partID = selectedPartID else { return }
    setPartRotation(id: partID, to: RigVector3())
  }

  func resetSelectedComponentTransform() {
    resetSelectedComponentPosition()
    resetSelectedComponentRotation()
  }
}
