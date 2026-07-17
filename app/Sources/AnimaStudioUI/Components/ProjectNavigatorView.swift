import AnimaCoreClient
import AnimaEvaluation
import AnimaModel
import RealityKitViewport
import SwiftUI

struct ProjectNavigatorView: View {
  @Bindable var workspace: StudioWorkspaceModel
  let importModel: () -> Void
  @State private var filterText = ""
  @State private var renameTarget: NavigatorRenameTarget?
  @State private var renameText = ""
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
      if instanceTreeNodes.isEmpty {
        Label("No components yet", systemImage: "cube.transparent")
          .foregroundStyle(.secondary)
      } else {
        TreeView(
          nodes: instanceTreeNodes,
          filterText: filterText,
          expandedIDs: instanceExpandedIDs,
          activeDragPayload: $activeDragPayload,
          revealRequest: instanceRevealRequest,
          rowContent: navigatorTreeRow,
          dragPayload: \.payload,
          dropBehavior: \.behavior,
          canDrop: canDropInTree,
          onDrop: handleTreeDrop
        )
        if TreeModel(roots: instanceTreeNodes).filtered(by: TreeFilterQuery(filterText)).roots
          .isEmpty
        {
          noFilterResults
        }
      }
    } header: {
      HStack(spacing: 6) {
        Text("Instances")
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
    Section("Mate Features") {
      if mateTreeNodes.isEmpty {
        Label("No mates yet", systemImage: "rotate.3d")
          .foregroundStyle(.secondary)
      } else {
        TreeView(
          nodes: mateTreeNodes,
          filterText: filterText,
          expandedIDs: mateExpandedIDs,
          activeDragPayload: $activeDragPayload,
          revealRequest: mateRevealRequest,
          rowContent: navigatorTreeRow,
          dragPayload: \.payload,
          dropBehavior: \.behavior,
          canDrop: canDropInTree,
          onDrop: handleTreeDrop
        )
        if TreeModel(roots: mateTreeNodes).filtered(by: TreeFilterQuery(filterText)).roots.isEmpty {
          noFilterResults
        }
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

  private var filteredEngineMates: [AnimaCoreJointSummary] {
    workspace.engineMates.filter { mate in
      matchesFilter(mate.id)
        || matchesFilter(mate.name)
        || matchesFilter(mateTypeLabel(for: mate))
    }
  }

  private var filteredEngineRelations: [AnimaCoreRelationSummary] {
    workspace.engineRelations.filter { relation in
      matchesFilter(relationTypeLabel(for: relation))
        || matchesFilter(relation.driver)
        || matchesFilter(relation.driven)
    }
  }

  private func mateTypeLabel(for mate: AnimaCoreJointSummary) -> String {
    workspace.engineMateType(for: mate)?.label
      ?? mate.type.replacingOccurrences(
        of: "_",
        with: " "
      ).capitalized
  }

  private func relationTypeLabel(for relation: AnimaCoreRelationSummary) -> String {
    workspace.engineRelationType(for: relation)?.label
      ?? relation.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
  }

  private var instanceTreeNodes: [NavigatorTreeNode] {
    let groupedIDs = Set(workspace.componentGroups.flatMap(\.componentIDs))
    let groups = workspace.componentGroups.map { group in
      NavigatorTreeNode(
        id: .group(group.id),
        selectionValue: .componentGroup(group.id),
        title: group.displayName,
        role: .componentGroup,
        detail: "\(group.componentIDs.count)",
        states: group.isLocked ? [.locked] : [],
        children: group.componentIDs.compactMap { id in
          workspace.project.rig.parts.first(where: { $0.id == id }).map(partTreeNode)
        },
        filterTokens: group.isLocked ? [.part, .locked] : [.part],
        isLocked: group.isLocked,
        acceptsChildren: true,
        payload: .componentGroup(group.id),
        behavior: .componentGroup
      )
    }
    let ungrouped = workspace.project.rig.parts
      .filter { !groupedIDs.contains($0.id) }
      .map(partTreeNode)
    return groups + ungrouped
  }

  private var mateTreeNodes: [NavigatorTreeNode] {
    if !workspace.engineMates.isEmpty || !workspace.engineRelations.isEmpty {
      let mates = workspace.engineMates.map { mate in
        let id = JointID(rawValue: mate.selectionKey)
        let states = navigatorStates(
          locked: workspace.isMateLocked(id),
          suppressed: mate.isSuppressed
        )
        return NavigatorTreeNode(
          id: .mate(mate.selectionKey),
          selectionValue: .joint(id),
          title: mate.id.isEmpty ? mate.name : mate.id,
          role: .joint,
          detail: mateTypeLabel(for: mate),
          states: states,
          children: [],
          filterTokens: treeTokens(type: .mate, states: states),
          isLocked: workspace.isMateLocked(id),
          acceptsChildren: false,
          payload: nil,
          behavior: nil
        )
      }
      let relations = workspace.engineRelations.map { relation in
        let states: [NavigatorRowState] = relation.isSuppressed ? [.suppressed] : []
        return NavigatorTreeNode(
          id: .relation(relation.id),
          selectionValue: .relation(relation.id),
          title: relationTypeLabel(for: relation),
          role: .joint,
          detail: relation.isReversed ? "Reversed" : "Coupled",
          states: states,
          children: [],
          filterTokens: treeTokens(type: .mate, states: states),
          isLocked: false,
          acceptsChildren: false,
          payload: nil,
          behavior: nil
        )
      }
      return mates + relations
    }

    return workspace.project.rig.joints.map { joint in
      let states = navigatorStates(locked: workspace.isMateLocked(joint.id))
      return NavigatorTreeNode(
        id: .mate(joint.id.rawValue),
        selectionValue: .joint(joint.id),
        title: joint.displayName,
        role: .joint,
        detail: "Revolute",
        states: states,
        children: [],
        filterTokens: treeTokens(type: .mate, states: states),
        isLocked: workspace.isMateLocked(joint.id),
        acceptsChildren: false,
        payload: .mate(joint.id),
        behavior: .mate
      )
    }
  }

  private func partTreeNode(_ part: RigPartDefinition) -> NavigatorTreeNode {
    let enginePart = workspace.enginePart(for: part.id)
    let appearance = workspace.componentAppearance(for: part.id)
    let states = navigatorStates(
      locked: workspace.isComponentLocked(part.id),
      hidden: appearance?.isVisible == false,
      suppressed: enginePart?.isSuppressed == true,
      grounded: enginePart?.isGrounded == true
    )
    return NavigatorTreeNode(
      id: .component(part.id),
      selectionValue: .part(part.id),
      title: part.displayName,
      role: .semanticPart,
      detail: part.primitiveKind.displayName,
      states: states,
      children: [],
      filterTokens: treeTokens(type: .part, states: states),
      isLocked: workspace.isComponentLocked(part.id),
      acceptsChildren: false,
      payload: .component(part.id),
      behavior: .component
    )
  }

  private func navigatorStates(
    locked: Bool = false,
    hidden: Bool = false,
    suppressed: Bool = false,
    grounded: Bool = false
  ) -> [NavigatorRowState] {
    NavigatorRowState.allCases.filter { state in
      switch state {
      case .locked: locked
      case .hidden: hidden
      case .suppressed: suppressed
      case .grounded: grounded
      }
    }
  }

  private func treeTokens(
    type: TreeFilterToken,
    states: [NavigatorRowState]
  ) -> Set<TreeFilterToken> {
    var tokens: Set<TreeFilterToken> = [type]
    for state in states {
      switch state {
      case .locked: tokens.insert(.locked)
      case .hidden: tokens.insert(.hidden)
      case .suppressed: tokens.insert(.suppressed)
      case .grounded: tokens.insert(.grounded)
      }
    }
    return tokens
  }

  private var instanceExpandedIDs: Binding<Set<NavigatorTreeNodeID>> {
    expansionBinding(for: instanceTreeNodes)
  }

  private var mateExpandedIDs: Binding<Set<NavigatorTreeNodeID>> {
    expansionBinding(for: mateTreeNodes)
  }

  private func expansionBinding(
    for nodes: [NavigatorTreeNode]
  ) -> Binding<Set<NavigatorTreeNodeID>> {
    let allIDs = Set(flattenedTreeIDs(nodes))
    return Binding(
      get: {
        Set(allIDs.filter { workspace.navigatorExpandedNodeKeys.contains($0.persistenceKey) })
      },
      set: { expanded in
        let currentKeys = Set(allIDs.map(\.persistenceKey))
        var keys = workspace.navigatorExpandedNodeKeys.subtracting(currentKeys)
        keys.formUnion(expanded.map(\.persistenceKey))
        workspace.setNavigatorExpandedNodeKeys(keys)
      }
    )
  }

  private func flattenedTreeIDs(_ nodes: [NavigatorTreeNode]) -> [NavigatorTreeNodeID] {
    nodes.flatMap { [$0.id] + flattenedTreeIDs($0.children) }
  }

  private var instanceRevealRequest: TreeRevealRequest<NavigatorTreeNodeID>? {
    guard let item = workspace.navigatorRevealItem else { return nil }
    let id: NavigatorTreeNodeID
    switch item {
    case .part(let partID): id = .component(partID)
    case .componentGroup(let groupID): id = .group(groupID)
    default: return nil
    }
    return TreeRevealRequest(id: id, revision: workspace.navigatorRevealRevision)
  }

  private var mateRevealRequest: TreeRevealRequest<NavigatorTreeNodeID>? {
    guard let item = workspace.navigatorRevealItem else { return nil }
    let id: NavigatorTreeNodeID
    switch item {
    case .joint(let jointID): id = .mate(jointID.rawValue)
    case .relation(let relationID): id = .relation(relationID)
    default: return nil
    }
    return TreeRevealRequest(id: id, revision: workspace.navigatorRevealRevision)
  }

  @ViewBuilder
  private func navigatorTreeRow(_ node: NavigatorTreeNode) -> some View {
    switch node.id {
    case .component(let id):
      if let part = workspace.project.rig.parts.first(where: { $0.id == id }) {
        PartTreeRow(
          title: node.title,
          role: node.role,
          detail: node.detail,
          states: node.states
        )
        .contextMenu { componentActions(part) }
      }
    case .group(let id):
      if let group = workspace.componentGroups.first(where: { $0.id == id }) {
        PartTreeRow(
          title: node.title,
          role: node.role,
          detail: node.detail,
          states: node.states
        )
        .contextMenu { componentGroupActions(group) }
      }
    case .mate(let id):
      PartTreeRow(
        title: node.title,
        role: node.role,
        detail: node.detail,
        states: node.states
      )
      .contextMenu {
        if let mate = workspace.engineMates.first(where: { $0.selectionKey == id }) {
          engineMateActions(mate)
        } else if let mate = workspace.project.rig.joints.first(where: { $0.id.rawValue == id }) {
          mateActions(mate)
        }
      }
    case .relation(let id):
      PartTreeRow(
        title: node.title,
        role: node.role,
        detail: node.detail,
        states: node.states
      )
      .contextMenu {
        if let relation = workspace.engineRelations.first(where: { $0.id == id }) {
          relationActions(relation)
        }
      }
    }
  }

  private func handleTreeDrop(
    _ payload: NavigatorDragPayload,
    intent: NavigatorDropIntent,
    destination: NavigatorTreeNode
  ) -> Bool {
    switch destination.id {
    case .component(let id):
      return handleComponentDrop(payload, intent: intent, relativeTo: id)
    case .group(let id):
      guard let group = workspace.componentGroups.first(where: { $0.id == id }) else {
        return false
      }
      return handleDrop(payload, intent: intent, onto: group)
    case .mate(let id):
      return handleMateDrop(payload, intent: intent, relativeTo: JointID(rawValue: id))
    case .relation:
      return false
    }
  }

  private func canDropInTree(
    _ payload: NavigatorDragPayload,
    intent: NavigatorDropIntent,
    destination: NavigatorTreeNode
  ) -> Bool {
    guard !destination.isLocked else { return false }
    switch (payload, destination.id) {
    case (.component(let source), .component(let destinationID)):
      return source != destinationID && !workspace.isComponentLocked(source)
    case (.component(let source), .group):
      return intent == .group && !workspace.isComponentLocked(source)
    case (.componentGroup(let source), .group(let destinationID)):
      return source != destinationID && intent != .group
    case (.mate(let source), .mate(let destinationID)):
      return source.rawValue != destinationID
        && intent != .group
        && !workspace.isMateLocked(source)
    default:
      return false
    }
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
      expandGroup(groupID)
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
      if didMove { expandGroup(group.id) }
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
    Button("Go to Item in List", systemImage: "list.bullet.rectangle") {
      workspace.requestNavigatorReveal(.part(part.id))
    }

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

    if let enginePart = workspace.enginePart(for: part.id) {
      Divider()
      Button(
        enginePart.isSuppressed ? "Unsuppress" : "Suppress",
        systemImage: enginePart.isSuppressed ? "checkmark.circle" : "nosign"
      ) {
        Task { await workspace.togglePartSuppressed(part.id) }
      }
      Button(
        enginePart.isGrounded ? "Unground" : "Ground",
        systemImage: enginePart.isGrounded ? "pin.slash" : "pin"
      ) {
        Task { await workspace.togglePartGrounded(part.id) }
      }
    }
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

  @ViewBuilder
  private func engineMateActions(_ mate: AnimaCoreJointSummary) -> some View {
    Button("Go to Item in List", systemImage: "list.bullet.rectangle") {
      workspace.requestNavigatorReveal(.joint(JointID(rawValue: mate.selectionKey)))
    }
    Button(
      mate.isSuppressed ? "Unsuppress Mate" : "Suppress Mate",
      systemImage: mate.isSuppressed ? "checkmark.circle" : "nosign"
    ) {
      Task { await workspace.toggleMateSuppressed(mate) }
    }
    Divider()
    Button(
      workspace.isMateLocked(JointID(rawValue: mate.selectionKey)) ? "Unlock" : "Lock",
      systemImage: workspace.isMateLocked(JointID(rawValue: mate.selectionKey))
        ? "lock.open" : "lock"
    ) {
      workspace.toggleMateLock(JointID(rawValue: mate.selectionKey))
    }
  }

  @ViewBuilder
  private func relationActions(_ relation: AnimaCoreRelationSummary) -> some View {
    Button("Go to Item in List", systemImage: "list.bullet.rectangle") {
      workspace.requestNavigatorReveal(.relation(relation.id))
    }
    Button(
      relation.isSuppressed ? "Unsuppress Relation" : "Suppress Relation",
      systemImage: relation.isSuppressed ? "checkmark.circle" : "nosign"
    ) {
      Task { await workspace.toggleRelationSuppressed(relation) }
    }
  }

  private var renameIsPresented: Binding<Bool> {
    Binding(
      get: { renameTarget != nil },
      set: { isPresented in
        if !isPresented { renameTarget = nil }
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
    expandGroup(groupID)
  }

  private func expandGroup(_ id: UUID) {
    var keys = workspace.navigatorExpandedNodeKeys
    keys.insert(NavigatorTreeNodeID.group(id).persistenceKey)
    workspace.setNavigatorExpandedNodeKeys(keys)
  }
}

private enum NavigatorRenameTarget {
  case component(PartID)
  case group(UUID)
  case mate(JointID)
}
