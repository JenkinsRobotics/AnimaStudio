import AnimaCore
import RealityKitViewport
import SwiftUI

struct ProjectNavigatorView: View {
  @Bindable var workspace: StudioWorkspaceModel
  let importModel: () -> Void
  @State private var filterText = ""
  @State private var renameTarget: NavigatorRenameTarget?
  @State private var renameText = ""
  @State private var collapsedGroupIDs: Set<UUID> = []
  @State private var activeDragPayload: NavigatorDragPayload?

  var body: some View {
    VStack(spacing: 0) {
      WorkspacePanelHeader(
        title: panelTitle,
        systemImage: workspace.activeWorkspace.descriptor.systemImage
      )

      StudioSearchField(prompt: "Filter \(panelTitle)", text: $filterText)
        .padding(.horizontal, 10)
        .padding(.bottom, 8)

      List(selection: $workspace.selection) {
        navigatorContent
      }
      .listStyle(.sidebar)
      .scrollContentBackground(.hidden)
      .background(StudioPalette.panel)
      .accessibilityLabel(panelTitle)

      Divider()
      panelFooter
    }
    .studioPanelSurface()
    .onChange(of: workspace.activeWorkspace) {
      filterText = ""
    }
    .alert(renamePrompt, isPresented: renameIsPresented) {
      TextField("Name", text: $renameText)
      Button("Cancel", role: .cancel) {
        renameTarget = nil
      }
      Button("Rename") {
        commitRename()
      }
      .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    } message: {
      Text("Names are stored with the project-owned rig data.")
    }
  }

  @ViewBuilder
  private var navigatorContent: some View {
    switch workspace.activeWorkspace {
    case .assets:
      projectSection
      assetSection
      sourceHierarchySection
    case .rig:
      projectSection
      semanticRigSection
      jointSection
      sourceHierarchySection
    case .animate:
      animationSection
      semanticRigSection
      jointSection
      sourceHierarchySection
    case .show:
      showSection
      animationSection
      mediaSection
    case .nodes:
      EmptyView()
    case .hardware:
      hardwareSection
    }
  }

  private var projectSection: some View {
    Section("Project") {
      Label(workspace.project.name, systemImage: "shippingbox")
        .tag(NavigatorItem.project)
    }
  }

  @ViewBuilder
  private var assetSection: some View {
    Section("Assets") {
      if workspace.project.assets.isEmpty {
        Label("No imported assets", systemImage: "cube.transparent")
          .foregroundStyle(.secondary)
      } else {
        ForEach(filteredAssets) { asset in
          PartTreeRow(title: asset.name, role: .sourceNode, detail: "Asset")
            .tag(NavigatorItem.asset(asset.id))
        }
        if filteredAssets.isEmpty {
          noFilterResults
        }
      }
    }
  }

  @ViewBuilder
  private var sourceHierarchySection: some View {
    if workspace.importedModelHierarchy != nil || workspace.isLoadingModelHierarchy {
      Section("Source Model · Read Only") {
        if workspace.isLoadingModelHierarchy {
          HStack {
            ProgressView()
              .controlSize(.small)
            Text("Reading model hierarchy…")
              .foregroundStyle(.secondary)
          }
        } else if let hierarchy = filteredModelHierarchy {
          OutlineGroup([hierarchy], children: \.outlineChildren) { node in
            PartTreeRow(
              title: node.displayName,
              role: node.children.isEmpty ? .sourceNode : .sourceAssembly,
              isLocked: true,
              lockHelp:
                "Source-owned hierarchy. Map it into the semantic rig before editing relationships."
            )
            .tag(NavigatorItem.modelNode(node.id))
          }
        } else {
          noFilterResults
        }
      }
    }
  }

  private var semanticRigSection: some View {
    Section {
      if workspace.project.rig.parts.isEmpty && workspace.componentGroups.isEmpty {
        Label("No components yet", systemImage: "cube.transparent")
          .foregroundStyle(.secondary)
      } else {
        ForEach(filteredComponentGroups) { group in
          DisclosureGroup(isExpanded: groupExpansionBinding(group.id)) {
            ForEach(filteredParts(in: group)) { part in
              componentRow(part)
            }
          } label: {
            PartTreeRow(
              title: group.displayName,
              role: .componentGroup,
              detail: "\(group.componentIDs.count)",
              isLocked: group.isLocked
            )
            .navigatorDragSource(
              .componentGroup(group.id),
              activePayload: $activeDragPayload
            )
            .navigatorDropTarget(
              activePayload: $activeDragPayload,
              behavior: .componentGroup
            ) { payload, intent in
              handleDrop(payload, intent: intent, onto: group)
            }
          }
          .tag(NavigatorItem.componentGroup(group.id))
          .contextMenu {
            componentGroupActions(group)
          }
        }

        ForEach(filteredUngroupedParts) { part in
          componentRow(part)
        }

        if filteredComponentGroups.isEmpty && filteredUngroupedParts.isEmpty {
          noFilterResults
        }
      }
    } header: {
      HStack(spacing: 6) {
        Text("Components")
        Spacer(minLength: 4)
        Image(systemName: "tray.and.arrow.down")
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
      .navigatorTopLevelDropTarget(activePayload: $activeDragPayload) { sourceID in
        workspace.moveDraggedComponents(startingWith: sourceID, toGroup: nil)
      }
      .help("Drop a component here to move it out of a group")
    }
  }

  private var jointSection: some View {
    Section("Mates") {
      ForEach(filteredJoints, id: \.id) { joint in
        PartTreeRow(
          title: joint.displayName,
          role: .joint,
          detail: "Revolute",
          isLocked: workspace.isMateLocked(joint.id)
        )
        .tag(NavigatorItem.joint(joint.id))
        .contextMenu {
          mateActions(joint)
        }
        .navigatorDragSource(.mate(joint.id), activePayload: $activeDragPayload)
        .navigatorDropTarget(activePayload: $activeDragPayload, behavior: .mate) {
          payload, intent in
          handleMateDrop(payload, intent: intent, relativeTo: joint.id)
        }
      }
      if workspace.project.rig.joints.isEmpty {
        Label("No mates yet", systemImage: "rotate.3d")
          .foregroundStyle(.secondary)
      } else if filteredJoints.isEmpty {
        noFilterResults
      }
    }
  }

  private var animationSection: some View {
    Section("Animations") {
      ForEach(filteredClips, id: \.name) { clip in
        Label(clip.name, systemImage: "timeline.selection")
          .tag(NavigatorItem.animation(clip.name))
      }
      if filteredClips.isEmpty {
        noFilterResults
      }
    }
  }

  private var showSection: some View {
    Section("Show") {
      Label("No scene document", systemImage: "sparkles.rectangle.stack")
        .foregroundStyle(.secondary)
    }
  }

  private var mediaSection: some View {
    Section("Media & Effects") {
      Label("No audio, screens, lights, or events", systemImage: "waveform.badge.plus")
        .foregroundStyle(.secondary)
    }
  }

  private var hardwareSection: some View {
    Group {
      Section("Drivers") {
        Label("No configured drivers", systemImage: "powerplug")
          .foregroundStyle(.secondary)
      }
      Section("Actuator Mappings") {
        Label("No output mappings", systemImage: "arrow.triangle.branch")
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var panelFooter: some View {
    switch workspace.activeWorkspace {
    case .assets:
      Button(action: importModel) {
        Label("Import Model", systemImage: "plus.circle.fill")
      }
      .buttonStyle(StudioPrimaryButtonStyle())
      .disabled(workspace.isLoadingModelHierarchy)
      .padding(12)
    case .rig:
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Button("Add", systemImage: "plus.circle.fill") {
            workspace.showCreationTools()
          }
          .buttonStyle(.borderedProminent)
          .help("Open the component and mate creation palette")

          Button(groupButtonTitle, systemImage: "folder.badge.plus") {
            createGroupFromSelection()
          }
          .buttonStyle(.borderedProminent)
          .help(groupButtonHelp)
        }
        Label(
          groupSelectionGuidance,
          systemImage: workspace.selectedComponentIDs.isEmpty ? "info.circle" : "checkmark.circle"
        )
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      }
      .padding(12)
    case .animate:
      Text(selectionGuidance)
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
        .padding(12)
    case .show:
      Label("Scene documents are not wired yet", systemImage: "lock")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
        .padding(12)
    case .nodes:
      EmptyView()
    case .hardware:
      Label("Hardware output is safely offline", systemImage: "lock.shield")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
        .padding(12)
    }
  }

  private var selectionGuidance: String {
    if workspace.selectionCount > 1 {
      return "\(workspace.selectionCount) items selected. Command-click or Shift-click to adjust."
    }
    return "Select a mate or model node. Command-click or Shift-click selects multiple."
  }

  private var groupButtonTitle: String {
    let count = workspace.selectedUnlockedComponentIDs.count
    return count > 0 ? "Group Selected (\(count))" : "New Empty Group"
  }

  private var groupButtonHelp: String {
    workspace.selectedUnlockedComponentIDs.isEmpty
      ? "Create an empty component group"
      : "Create a group containing the selected unlocked components"
  }

  private var groupSelectionGuidance: String {
    let selectedCount = workspace.selectedComponentIDs.count
    let unlockedCount = workspace.selectedUnlockedComponentIDs.count
    if selectedCount == 0 {
      return
        "Command-click or Shift-click components, then choose Group Selected. You can also drag rows."
    }
    if unlockedCount == 0 {
      return "The selected components are locked. Unlock them before grouping."
    }
    if unlockedCount < selectedCount {
      return
        "\(unlockedCount) unlocked selected components will be grouped; locked components stay in place."
    }
    return "\(unlockedCount) selected component\(unlockedCount == 1 ? "" : "s") will be grouped."
  }

  private var panelTitle: String {
    switch workspace.activeWorkspace {
    case .assets: "Assets"
    case .rig, .animate: "Components"
    case .show: "Show Contents"
    case .nodes: "Nodes"
    case .hardware: "Hardware"
    }
  }

  private var filteredAssets: [ProjectAsset] {
    workspace.project.assets.filter { matchesFilter($0.name) }
  }

  private var filteredJoints: [JointDefinition] {
    workspace.project.rig.joints.filter { matchesFilter($0.displayName) }
  }

  private var filteredComponentGroups: [NavigatorComponentGroup] {
    workspace.componentGroups.filter { group in
      matchesFilter(group.displayName)
        || parts(in: group).contains { matchesFilter($0.displayName) }
    }
  }

  private var filteredUngroupedParts: [RigPartDefinition] {
    workspace.project.rig.parts.filter { part in
      workspace.componentGroup(containing: part.id) == nil && matchesFilter(part.displayName)
    }
  }

  private func parts(in group: NavigatorComponentGroup) -> [RigPartDefinition] {
    group.componentIDs.compactMap { componentID in
      workspace.project.rig.parts.first { $0.id == componentID }
    }
  }

  private func filteredParts(in group: NavigatorComponentGroup) -> [RigPartDefinition] {
    let groupParts = parts(in: group)
    return matchesFilter(group.displayName)
      ? groupParts
      : groupParts.filter { matchesFilter($0.displayName) }
  }

  private var filteredClips: [AnimationClip] {
    workspace.project.clips.filter { matchesFilter($0.name) }
  }

  private var filteredModelHierarchy: ModelHierarchyNode? {
    workspace.importedModelHierarchy?.filtered(matching: filterText)
  }

  private func matchesFilter(_ value: String) -> Bool {
    let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
    return query.isEmpty || value.localizedStandardContains(query)
  }

  private var noFilterResults: some View {
    Label("No matching items", systemImage: "line.3.horizontal.decrease.circle")
      .font(.caption)
      .foregroundStyle(StudioPalette.muted)
  }

  private func componentRow(_ part: RigPartDefinition) -> some View {
    PartTreeRow(
      title: part.displayName,
      role: .semanticPart,
      detail: part.primitiveKind.displayName,
      isLocked: workspace.isComponentLocked(part.id)
    )
    .tag(NavigatorItem.part(part.id))
    .contextMenu {
      componentActions(part)
    }
    .navigatorDragSource(.component(part.id), activePayload: $activeDragPayload)
    .navigatorDropTarget(activePayload: $activeDragPayload, behavior: .component) {
      payload, intent in
      handleComponentDrop(payload, intent: intent, relativeTo: part.id)
    }
  }

  private func handleComponentDrop(
    _ payload: NavigatorDragPayload,
    intent: NavigatorDropIntent,
    relativeTo destinationID: PartID
  ) -> Bool {
    guard case .component(let sourceID) = payload else { return false }
    switch intent {
    case .before:
      return workspace.moveComponent(sourceID, relativeTo: destinationID, placement: .before)
    case .group:
      guard let groupID = workspace.groupComponents(draggedID: sourceID, onto: destinationID)
      else { return false }
      collapsedGroupIDs.remove(groupID)
      return true
    case .after:
      return workspace.moveComponent(sourceID, relativeTo: destinationID, placement: .after)
    }
  }

  private func handleDrop(
    _ payload: NavigatorDragPayload,
    intent: NavigatorDropIntent,
    onto group: NavigatorComponentGroup
  ) -> Bool {
    switch payload {
    case .component(let sourceID):
      guard intent == .group else { return false }
      let didMove = workspace.moveDraggedComponents(startingWith: sourceID, toGroup: group.id)
      if didMove { collapsedGroupIDs.remove(group.id) }
      return didMove
    case .componentGroup(let sourceID):
      guard intent != .group else { return false }
      return workspace.moveComponentGroup(
        sourceID,
        relativeTo: group.id,
        placement: intent == .before ? .before : .after
      )
    case .mate:
      return false
    }
  }

  private func handleMateDrop(
    _ payload: NavigatorDragPayload,
    intent: NavigatorDropIntent,
    relativeTo destinationID: JointID
  ) -> Bool {
    guard case .mate(let sourceID) = payload, intent != .group else { return false }
    return workspace.moveMate(
      sourceID,
      relativeTo: destinationID,
      placement: intent == .before ? .before : .after
    )
  }

  @ViewBuilder
  private func componentActions(_ part: RigPartDefinition) -> some View {
    Button("Rename", systemImage: "pencil") {
      beginRename(.component(part.id), currentName: part.displayName)
    }
    .disabled(workspace.isComponentLocked(part.id))

    Button(contextGroupButtonTitle, systemImage: "folder.badge.plus") {
      createGroupFromSelection()
    }
    .disabled(workspace.selectedUnlockedComponentIDs.isEmpty)

    if workspace.isComponentLockedByGroup(part.id) {
      Button("Locked by Group", systemImage: "lock.fill") {}
        .disabled(true)
    } else {
      Button(
        workspace.isComponentIndividuallyLocked(part.id) ? "Unlock" : "Lock",
        systemImage: workspace.isComponentIndividuallyLocked(part.id) ? "lock.open" : "lock"
      ) {
        workspace.toggleComponentLock(part.id)
      }
    }

    Divider()

    Button("Move Up", systemImage: "arrow.up") {
      workspace.moveComponent(part.id, direction: .up)
    }
    .disabled(workspace.isComponentLocked(part.id))
    Button("Move Down", systemImage: "arrow.down") {
      workspace.moveComponent(part.id, direction: .down)
    }
    .disabled(workspace.isComponentLocked(part.id))

    Menu("Move to Group", systemImage: "folder") {
      Button("Top Level", systemImage: "tray") {
        workspace.moveComponent(part.id, toGroup: nil)
      }
      Divider()
      ForEach(workspace.componentGroups) { group in
        Button(group.displayName, systemImage: "folder") {
          workspace.moveComponent(part.id, toGroup: group.id)
        }
        .disabled(group.isLocked || group.componentIDs.contains(part.id))
      }
    }
    .disabled(workspace.isComponentLocked(part.id) || workspace.componentGroups.isEmpty)
  }

  @ViewBuilder
  private func componentGroupActions(_ group: NavigatorComponentGroup) -> some View {
    Button("Rename", systemImage: "pencil") {
      beginRename(.group(group.id), currentName: group.displayName)
    }
    .disabled(group.isLocked)

    Button(
      group.isLocked ? "Unlock Group" : "Lock Group",
      systemImage: group.isLocked ? "lock.open" : "lock"
    ) {
      workspace.toggleComponentGroupLock(group.id)
    }

    Divider()

    Button("Move Up", systemImage: "arrow.up") {
      workspace.moveComponentGroup(group.id, direction: .up)
    }
    .disabled(group.isLocked)
    Button("Move Down", systemImage: "arrow.down") {
      workspace.moveComponentGroup(group.id, direction: .down)
    }
    .disabled(group.isLocked)
    Button("Dissolve Group", systemImage: "folder.badge.minus") {
      workspace.dissolveComponentGroup(id: group.id)
    }
    .disabled(group.isLocked)
  }

  @ViewBuilder
  private func mateActions(_ mate: JointDefinition) -> some View {
    Button("Rename", systemImage: "pencil") {
      beginRename(.mate(mate.id), currentName: mate.displayName)
    }
    .disabled(workspace.isMateLocked(mate.id))

    Button(
      workspace.isMateLocked(mate.id) ? "Unlock" : "Lock",
      systemImage: workspace.isMateLocked(mate.id) ? "lock.open" : "lock"
    ) {
      workspace.toggleMateLock(mate.id)
    }

    Divider()

    Button("Move Up", systemImage: "arrow.up") {
      workspace.moveMate(mate.id, direction: .up)
    }
    .disabled(workspace.isMateLocked(mate.id))
    Button("Move Down", systemImage: "arrow.down") {
      workspace.moveMate(mate.id, direction: .down)
    }
    .disabled(workspace.isMateLocked(mate.id))
  }

  private var renameIsPresented: Binding<Bool> {
    Binding(
      get: { renameTarget != nil },
      set: { isPresented in
        if !isPresented { renameTarget = nil }
      }
    )
  }

  private func groupExpansionBinding(_ id: UUID) -> Binding<Bool> {
    Binding(
      get: { !collapsedGroupIDs.contains(id) || !filterText.isEmpty },
      set: { isExpanded in
        if isExpanded {
          collapsedGroupIDs.remove(id)
        } else {
          collapsedGroupIDs.insert(id)
        }
      }
    )
  }

  private var renamePrompt: String {
    switch renameTarget {
    case .component: "Rename Component"
    case .group: "Rename Group"
    case .mate: "Rename Mate"
    case nil: "Rename"
    }
  }

  private func beginRename(_ target: NavigatorRenameTarget, currentName: String) {
    renameText = currentName
    renameTarget = target
  }

  private func commitRename() {
    guard let renameTarget else { return }
    switch renameTarget {
    case .component(let id): workspace.renamePart(id: id, to: renameText)
    case .group(let id): workspace.renameComponentGroup(id: id, to: renameText)
    case .mate(let id): workspace.renameJoint(id: id, to: renameText)
    }
    self.renameTarget = nil
  }

  private var contextGroupButtonTitle: String {
    let count = workspace.selectedUnlockedComponentIDs.count
    return count > 0 ? "Group Selected (\(count))" : "Group Selected"
  }

  private func createGroupFromSelection() {
    let groupID = workspace.createComponentGroup()
    collapsedGroupIDs.remove(groupID)
  }
}

private enum NavigatorRenameTarget {
  case component(PartID)
  case group(UUID)
  case mate(JointID)
}
