import AnimaEvaluation
import AnimaModel
import Foundation
import RealityKitViewport

enum ComponentContextLockScope: Equatable {
  case unlocked
  case component
  case group(UUID)
}

struct ComponentContextDependency: Equatable, Identifiable {
  let id: JointID
  let displayName: String
}

struct ComponentContextMenuState: Equatable {
  let partID: PartID
  let displayName: String
  let primitiveKind: RigPrimitiveKind
  let lockScope: ComponentContextLockScope
  let isVisible: Bool
  let isIsolated: Bool
  let hasActiveIsolation: Bool
  let isTransparent: Bool
  let dependencies: [ComponentContextDependency]

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
  var viewportPartAppearances: [PartID: PreviewPartAppearance] {
    Dictionary(
      uniqueKeysWithValues: project.rig.parts.compactMap { part in
        guard var appearance = componentAppearance(for: part.id) else { return nil }
        if enginePart(for: part.id)?.isSuppressed == true {
          appearance.isVisible = false
        }
        if let isolatedComponentID, part.id != isolatedComponentID {
          appearance.isVisible = false
        }
        if transparentComponentIDs.contains(part.id) {
          appearance.opacity = min(appearance.opacity, 0.28)
        }
        return (part.id, appearance)
      }
    )
  }

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
    let dependencies: [ComponentContextDependency] = project.rig.joints.compactMap { joint in
      guard joint.parentPartID == partID || joint.childPartID == partID else { return nil }
      return ComponentContextDependency(id: joint.id, displayName: joint.displayName)
    }

    return ComponentContextMenuState(
      partID: partID,
      displayName: part.displayName,
      primitiveKind: part.primitiveKind,
      lockScope: lockScope,
      isVisible: appearance.isVisible,
      isIsolated: isolatedComponentID == partID,
      hasActiveIsolation: isolatedComponentID != nil,
      isTransparent: transparentComponentIDs.contains(partID),
      dependencies: dependencies
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

  func toggleSelectedComponentIsolation() {
    guard let partID = selectedPartID else { return }
    isolatedComponentID = isolatedComponentID == partID ? nil : partID
  }

  func toggleSelectedComponentTransparency() {
    guard let partID = selectedPartID, !isComponentLocked(partID) else { return }
    if transparentComponentIDs.contains(partID) {
      transparentComponentIDs.remove(partID)
    } else {
      transparentComponentIDs.insert(partID)
    }
  }

  func selectAttachedMate(_ id: JointID) {
    guard let partID = selectedPartID,
      project.rig.joints.contains(where: {
        $0.id == id && ($0.parentPartID == partID || $0.childPartID == partID)
      })
    else { return }
    selection = [.joint(id)]
  }

  func selectAllComponents() {
    selection = Set(project.rig.parts.map { NavigatorItem.part($0.id) })
  }

  func showHomeView() {
    setCameraViewpoint(.home)
  }

  func showAllComponents() {
    isolatedComponentID = nil
    for part in project.rig.parts where !isComponentLocked(part.id) {
      guard var appearance = componentAppearance(for: part.id) else { continue }
      appearance.isVisible = true
      setComponentAppearance(id: part.id, to: appearance)
    }
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
