import AnimaEvaluation
import AnimaModel
import RealityKitViewport
import SwiftUI

struct InspectorView: View {
  @Bindable var workspace: StudioWorkspaceModel

  var body: some View {
    VStack(spacing: 0) {
      WorkspacePanelHeader(
        title: panelTitle,
        systemImage: panelSystemImage,
        closeAction: clearSelectionAction
      )

      Form {
        workspaceSummary
        modeSummary
        selectionConfiguration
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
      .background(StudioPalette.panel)

      panelFooter
    }
    .studioPanelSurface()
  }

  private var workspaceSummary: some View {
    Section("Workspace") {
      LabeledContent("Workspace", value: workspace.activeWorkspace.descriptor.title)
      Text(workspace.activeWorkspace.descriptor.purpose)
        .font(.caption)
        .foregroundStyle(.secondary)
      LabeledContent(
        "Time",
        value: workspace.playheadSeconds.formatted(
          .number.precision(.fractionLength(3))
        ) + " s"
      )
      Label("Kinematic preview", systemImage: "figure.walk.motion")
      Label("Physics simulation deferred", systemImage: "archivebox")
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var modeSummary: some View {
    switch workspace.activeWorkspace {
    case .hardware:
      Section("Safety State") {
        LabeledContent("Connection", value: "Offline")
        LabeledContent("Configured Drivers", value: "0")
        LabeledContent("Master Live", value: "Disarmed")
        Label("Output remains disabled", systemImage: "lock.shield")
          .foregroundStyle(.secondary)
      }
    case .animate:
      animationInspector(workspace.activeClip)
    case .show:
      Section("Show Document") {
        LabeledContent("Status", value: "Not created")
        LabeledContent("Characters", value: "1 preview")
        LabeledContent("Tracks", value: "0")
        Label("Scene persistence is required before cue editing", systemImage: "info.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    case .assets:
      Section("Asset Library") {
        LabeledContent("Imported", value: "\(workspace.project.assets.count)")
        LabeledContent("Missing", value: "0")
      }
    case .rig:
      EmptyView()
    case .nodes:
      EmptyView()
    }
  }

  @ViewBuilder
  private var selectionConfiguration: some View {
    if workspace.activeWorkspace == .hardware {
      EmptyView()
    } else if let selectedAnimation, workspace.activeWorkspace != .animate {
      animationInspector(selectedAnimation)
    } else if let selectedAsset {
      assetInspector(selectedAsset)
    } else if let selectedComponentGroup {
      componentGroupInspector(selectedComponentGroup)
    } else if let selectedPart {
      if workspace.isComponentLocked(selectedPart.id) {
        if let lockedGroup = workspace.componentGroup(containing: selectedPart.id),
          lockedGroup.isLocked
        {
          lockedEditingSection(unlockTitle: "Unlock Group") {
            workspace.toggleComponentGroupLock(lockedGroup.id)
          }
        } else {
          lockedEditingSection(unlockTitle: "Unlock Component") {
            workspace.toggleComponentLock(selectedPart.id)
          }
        }
      }
      componentTabPicker
      Group {
        switch workspace.componentInspectorTab {
        case .properties:
          featureReadout(for: selectedPart)
          partInspector(selectedPart)
        case .appearance:
          ComponentAppearanceEditor(workspace: workspace, part: selectedPart)
        }
      }
      .disabled(workspace.isComponentLocked(selectedPart.id))
    } else if let selectedModelNode {
      modelNodeInspector(selectedModelNode)
    } else if let selectedEngineMate = workspace.selectedEngineMate {
      EngineMateInspectorView(
        mate: selectedEngineMate,
        mateType: workspace.engineMateType(for: selectedEngineMate)
      )
    } else if let selectedJoint {
      if workspace.isMateLocked(selectedJoint.id) {
        lockedEditingSection(unlockTitle: "Unlock Mate") {
          workspace.toggleMateLock(selectedJoint.id)
        }
      }
      Group {
        jointInspector(selectedJoint)
      }
      .disabled(workspace.isMateLocked(selectedJoint.id))
    } else if workspace.selectionCount > 1 {
      Section("Multiple Selection") {
        LabeledContent("Selected", value: "\(workspace.selectionCount) items")
        Text("Only operations shared by every selected item will appear here.")
          .foregroundStyle(.secondary)
      }
    } else if workspace.activeWorkspace == .rig || workspace.activeWorkspace == .assets {
      Section("Selection") {
        Text("Select a component, model node, group, or mate to configure it.")
          .foregroundStyle(.secondary)
      }
    }
  }

  private var componentTabPicker: some View {
    Section {
      Picker("Component Inspector", selection: $workspace.componentInspectorTab) {
        ForEach(ComponentInspectorTab.allCases) { tab in
          Label(tab.title, systemImage: tab.systemImage).tag(tab)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .accessibilityLabel("Component inspector tab")
    }
  }

  @ViewBuilder
  private var panelFooter: some View {
    switch workspace.activeWorkspace {
    case .animate:
      Divider()
      Button("Create Animation", systemImage: "plus.circle.fill") {}
        .buttonStyle(.borderedProminent)
        .disabled(true)
        .help("Animation creation lands with editable clips")
        .padding(12)
    case .show:
      Divider()
      Button("Create Scene", systemImage: "plus.circle.fill") {}
        .buttonStyle(.borderedProminent)
        .disabled(true)
        .help("Scene documents are not wired yet")
        .padding(12)
    case .assets, .rig, .nodes, .hardware:
      EmptyView()
    }
  }

  @ViewBuilder
  private func assetInspector(_ asset: ProjectAsset) -> some View {
    Section("Model Asset") {
      if workspace.activeWorkspace == .assets {
        StudioTextFieldRow(
          title: "Name",
          text: Binding(
            get: { asset.name },
            set: { workspace.renameAsset(id: asset.id, to: $0) }
          ),
          placeholder: "Model name",
          help: "The human-readable asset name stored in this project."
        )
      } else {
        LabeledContent("Name", value: asset.name)
      }
      LabeledContent("Type", value: "USD / RealityKit")
      LabeledContent("Source", value: asset.sourcePath)
        .lineLimit(3)
    }
  }

  @ViewBuilder
  private func modelNodeInspector(_ node: ModelHierarchyNode) -> some View {
    Section("Model Node") {
      Label("Source-owned hierarchy", systemImage: "lock.fill")
        .foregroundStyle(StudioPalette.sourceModel)
      LabeledContent("Name", value: node.displayName)
      LabeledContent("Ownership", value: "Imported source (read only)")
      LabeledContent("Children", value: "\(node.children.count)")
      LabeledContent("Subtree", value: "\(node.nodeCount) nodes")
      LabeledContent("Path", value: node.id.displayString)
        .lineLimit(4)
      LabeledContent("Appearance", value: "Rendered from source asset")
      LabeledContent("Semantic Part", value: "Not mapped")
        .foregroundStyle(.secondary)
      Label(
        "Edit hierarchy, pivots, and materials in the source model. Map a node to an Anima part before assigning mate connectors or animation.",
        systemImage: "info.circle"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }

    Section("Source Actions") {
      Button("Map to Semantic Part", systemImage: "arrow.triangle.branch") {}
        .disabled(true)
        .help("Available after persistent semantic parts are implemented")
      Button("Reimport from Source", systemImage: "arrow.clockwise") {}
        .disabled(true)
        .help("Available after durable asset identity and source bookmarks are implemented")
    }
  }

  /// Read-only summary of the standing sub-object (face/edge/corner)
  /// selection made in the viewport. Kept outside the lock-disabled group
  /// because inspecting a feature edits nothing.
  @ViewBuilder
  private func featureReadout(for part: RigPartDefinition) -> some View {
    if let feature = workspace.selectedFeature, feature.partID == part.id {
      Section("Feature") {
        LabeledContent("Component", value: part.displayName)
        LabeledContent("Feature", value: feature.displayName)
        LabeledContent("Kind", value: feature.featureKind.displayName)
        LabeledContent("Local Origin", value: connectorOrigin(feature.connector))
      }
    }
  }

  @ViewBuilder
  private func partInspector(_ part: RigPartDefinition) -> some View {
    Section("Component") {
      StudioTextFieldRow(
        title: "Name",
        text: Binding(
          get: { part.displayName },
          set: { workspace.renamePart(id: part.id, to: $0) }
        ),
        placeholder: "Part name",
        help: "The project-owned name used by the rig and later mappings."
      )
      LabeledContent("Proxy Shape", value: part.primitiveKind.displayName)
      Label("Project-owned rig proxy", systemImage: "pencil.and.outline")
        .foregroundStyle(StudioPalette.semanticPart)
    }

    Section("Position") {
      StudioNumberFieldRow(
        title: "X",
        value: partPositionBinding(part.id, keyPath: \.x),
        unit: "m"
      )
      StudioNumberFieldRow(
        title: "Y",
        value: partPositionBinding(part.id, keyPath: \.y),
        unit: "m"
      )
      StudioNumberFieldRow(
        title: "Z",
        value: partPositionBinding(part.id, keyPath: \.z),
        unit: "m"
      )
    }

    Section("Rest Rotation") {
      StudioNumberFieldRow(
        title: "X",
        value: partRotationDegreesBinding(part.id, keyPath: \.x),
        unit: "°"
      )
      StudioNumberFieldRow(
        title: "Y",
        value: partRotationDegreesBinding(part.id, keyPath: \.y),
        unit: "°"
      )
      StudioNumberFieldRow(
        title: "Z",
        value: partRotationDegreesBinding(part.id, keyPath: \.z),
        unit: "°"
      )
    }

    Section("Workflow") {
      Text(
        "Use proxy components to establish the rig and mates. Imported production geometry can be mapped to the same semantic component later."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  /// Onshape-style mate type selector. Every mate kind in the family is
  /// listed; only kinds with landed motion logic are selectable, so the
  /// menu never lies about capability. Binds to the joint's typed kind
  /// once the typed-mate backend lands — today every mate is revolute.
  private var mateTypeRow: some View {
    VStack(alignment: .leading, spacing: 6) {
      StudioFieldLabel(
        title: "Type",
        help: "The mate kind defines which degrees of freedom this mate allows."
      )
      Menu {
        ForEach(MateCreationToolKind.allCases) { kind in
          Button {
            // Only the implemented kind is selectable; it is already
            // the current kind, so selection is a no-op until the
            // typed-mate backend adds kind switching.
          } label: {
            if kind == .revolute {
              Label(kind.title, systemImage: "checkmark")
            } else {
              Text(kind.title)
            }
          }
          .disabled(!kind.isImplemented)
          .help(kind.motionSummary)
        }
      } label: {
        HStack(spacing: 7) {
          Image(systemName: MateCreationToolKind.revolute.systemImage)
          Text(MateCreationToolKind.revolute.title)
          Spacer(minLength: 8)
          Image(systemName: "chevron.up.chevron.down")
            .font(.caption2)
            .foregroundStyle(StudioPalette.muted)
        }
        .padding(.horizontal, 9)
        .frame(
          maxWidth: .infinity, minHeight: StudioMetrics.fieldHeight,
          alignment: .leading
        )
        .background(
          StudioPalette.panelInset,
          in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 7)
            .stroke(StudioPalette.border, lineWidth: 1)
        }
      }
      .menuStyle(.borderlessButton)
      .accessibilityLabel("Mate type")
      Text("Other mate types unlock with the typed-mate backend.")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
    }
  }

  @ViewBuilder
  private func jointInspector(_ joint: JointDefinition) -> some View {
    Section("Mate") {
      if workspace.activeWorkspace == .rig {
        mateTypeRow
      } else {
        LabeledContent("Type", value: "\(MateCreationToolKind.revolute.title) Mate")
      }
      LabeledContent(
        "Degrees of Freedom", value: MateCreationToolKind.revolute.dofSummary)
      if workspace.activeWorkspace == .rig {
        StudioTextFieldRow(
          title: "Name",
          text: Binding(
            get: { joint.displayName },
            set: { workspace.renameJoint(id: joint.id, to: $0) }
          ),
          placeholder: "Mate name",
          help: "The readable mate name shown throughout the rig and timeline."
        )
        if joint.parentConnector != nil, joint.childConnector != nil {
          LabeledContent("Rotation Axis", value: "Connector Z")
        } else {
          StudioPickerRow(
            title: "Rotation Axis",
            selection: Binding(
              get: { joint.axis },
              set: { workspace.setJointAxis(id: joint.id, to: $0) }
            ),
            help: "The axis of this first revolute degree of freedom."
          ) {
            Text("X").tag(JointAxis.x)
            Text("Y").tag(JointAxis.y)
            Text("Z").tag(JointAxis.z)
          }
        }
      } else {
        LabeledContent("Name", value: joint.displayName)
        LabeledContent("Axis", value: joint.axis.rawValue.uppercased())
      }
      LabeledContent("Parent", value: partName(joint.parentPartID) ?? "World")
      LabeledContent("Child", value: partName(joint.childPartID) ?? "Unassigned")
    }

    if let parentConnector = joint.parentConnector,
      let childConnector = joint.childConnector
    {
      Section("Attachment") {
        LabeledContent("Parent Local Origin", value: connectorOrigin(parentConnector))
        LabeledContent("Child Local Origin", value: connectorOrigin(childConnector))
        LabeledContent("Alignment", value: "Primary axes opposed")
        Text(
          "The connector origins stay coincident. Revolute motion occurs about the connector's primary Z axis, not the component origin."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }

    Section("Limits") {
      if workspace.activeWorkspace == .rig {
        StudioNumberFieldRow(
          title: "Minimum",
          value: jointMinimumDegreesBinding(joint.id),
          unit: "°",
          help: "Minimum permitted revolute angle."
        )
        StudioNumberFieldRow(
          title: "Maximum",
          value: jointMaximumDegreesBinding(joint.id),
          unit: "°",
          help: "Maximum permitted revolute angle."
        )
      }
      StudioReadoutRow(
        title: "Evaluated Angle",
        value: workspace.evaluatedFrame.jointAnglesRadians[joint.id, default: 0]
          .formatted(.number.precision(.fractionLength(3))),
        unit: "rad"
      )
      StudioReadoutRow(
        title: "Allowed Range",
        value:
          "\(joint.minimumRadians.formatted(.number.precision(.fractionLength(2)))) … \(joint.maximumRadians.formatted(.number.precision(.fractionLength(2))))",
        unit: "rad",
        help: "Motion is clamped to these rig-defined limits."
      )
    }
  }

  @ViewBuilder
  private func componentGroupInspector(_ group: NavigatorComponentGroup) -> some View {
    Section("Component Group") {
      StudioTextFieldRow(
        title: "Name",
        text: Binding(
          get: { group.displayName },
          set: { workspace.renameComponentGroup(id: group.id, to: $0) }
        ),
        placeholder: "Group name",
        help: "A navigator group organizes related components without changing mate behavior."
      )
      .disabled(group.isLocked)
      LabeledContent("Components", value: "\(group.componentIDs.count)")
      LabeledContent("State", value: group.isLocked ? "Locked" : "Editable")
    }

    Section("Group Actions") {
      Button(
        group.isLocked ? "Unlock Group" : "Lock Group",
        systemImage: group.isLocked ? "lock.open" : "lock"
      ) {
        workspace.toggleComponentGroupLock(group.id)
      }
      Button("Dissolve Group", systemImage: "folder.badge.minus") {
        workspace.dissolveComponentGroup(id: group.id)
      }
      .disabled(group.isLocked)
    }
  }

  private func lockedEditingSection(
    unlockTitle: String,
    unlock: @escaping () -> Void
  ) -> some View {
    Section("Editing Locked") {
      Label("Transforms and configuration are protected.", systemImage: "lock.fill")
        .foregroundStyle(StudioPalette.muted)
      Button(unlockTitle, systemImage: "lock.open", action: unlock)
    }
  }

  private func animationInspector(_ clip: AnimationClip) -> some View {
    Section("Active Animation") {
      LabeledContent("Name", value: clip.name)
      LabeledContent(
        "Duration",
        value: clip.durationSeconds.formatted(
          .number.precision(.fractionLength(2))
        ) + " s"
      )
      LabeledContent("Tracks", value: "\(clip.jointTracks.count)")
    }
  }

  private var selectedAsset: ProjectAsset? {
    guard case .asset(let selectedID) = workspace.primarySelection else { return nil }
    return workspace.project.assets.first { $0.id == selectedID }
  }

  private var selectedPart: RigPartDefinition? {
    guard case .part(let selectedID) = workspace.primarySelection else { return nil }
    return workspace.project.rig.parts.first { $0.id == selectedID }
  }

  private var selectedComponentGroup: NavigatorComponentGroup? {
    guard case .componentGroup(let selectedID) = workspace.primarySelection else { return nil }
    return workspace.componentGroups.first { $0.id == selectedID }
  }

  private var selectedModelNode: ModelHierarchyNode? {
    guard case .modelNode(let selectedPath) = workspace.primarySelection else {
      return nil
    }
    return workspace.importedModelHierarchy?.node(at: selectedPath)
  }

  private var selectedJoint: JointDefinition? {
    guard case .joint(let selectedID) = workspace.primarySelection else { return nil }
    return workspace.project.rig.joints.first { $0.id == selectedID }
  }

  private var selectedAnimation: AnimationClip? {
    guard case .animation(let name) = workspace.primarySelection else { return nil }
    return workspace.project.clips.first { $0.name == name }
  }

  private var panelTitle: String {
    switch workspace.activeWorkspace {
    case .assets: "Asset Inspector"
    case .rig: "Rig Inspector"
    case .animate: "Animation Inspector"
    case .show: "Show Inspector"
    case .nodes: "Node Inspector"
    case .hardware: "Hardware Status"
    }
  }

  private var clearSelectionAction: (() -> Void)? {
    guard !workspace.selection.isEmpty else { return nil }
    return { workspace.clearSelection() }
  }

  private var panelSystemImage: String {
    workspace.activeWorkspace.descriptor.systemImage
  }

  private func partPositionBinding(
    _ id: PartID,
    keyPath: WritableKeyPath<RigVector3, Double>
  ) -> Binding<Double> {
    Binding(
      get: {
        workspace.project.rig.parts.first { $0.id == id }?.positionMeters[keyPath: keyPath] ?? 0
      },
      set: { value in
        guard
          var position = workspace.project.rig.parts.first(where: { $0.id == id })?
            .positionMeters
        else { return }
        position[keyPath: keyPath] = value
        workspace.setPartPosition(id: id, to: position)
      }
    )
  }

  private func partRotationDegreesBinding(
    _ id: PartID,
    keyPath: WritableKeyPath<RigVector3, Double>
  ) -> Binding<Double> {
    Binding(
      get: {
        guard let part = workspace.project.rig.parts.first(where: { $0.id == id }) else {
          return 0
        }
        let radians = part.rotationEulerRadians[keyPath: keyPath]
        return radians * 180 / .pi
      },
      set: { degrees in
        guard
          var rotation = workspace.project.rig.parts.first(where: { $0.id == id })?
            .rotationEulerRadians
        else { return }
        rotation[keyPath: keyPath] = degrees * .pi / 180
        workspace.setPartRotation(id: id, to: rotation)
      }
    )
  }

  private func jointMinimumDegreesBinding(_ id: JointID) -> Binding<Double> {
    Binding(
      get: {
        (workspace.project.rig.joints.first { $0.id == id }?.minimumRadians ?? 0)
          * 180 / .pi
      },
      set: { degrees in
        guard let joint = workspace.project.rig.joints.first(where: { $0.id == id }) else { return }
        workspace.setJointRange(
          id: id,
          minimumRadians: degrees * .pi / 180,
          maximumRadians: joint.maximumRadians
        )
      }
    )
  }

  private func jointMaximumDegreesBinding(_ id: JointID) -> Binding<Double> {
    Binding(
      get: {
        (workspace.project.rig.joints.first { $0.id == id }?.maximumRadians ?? 0)
          * 180 / .pi
      },
      set: { degrees in
        guard let joint = workspace.project.rig.joints.first(where: { $0.id == id }) else { return }
        workspace.setJointRange(
          id: id,
          minimumRadians: joint.minimumRadians,
          maximumRadians: degrees * .pi / 180
        )
      }
    )
  }

  private func partName(_ id: PartID?) -> String? {
    guard let id else { return nil }
    return workspace.project.rig.parts.first { $0.id == id }?.displayName
  }

  private func connectorOrigin(_ connector: MateConnectorDefinition) -> String {
    let origin = connector.originMeters
    return [origin.x, origin.y, origin.z]
      .map { $0.formatted(.number.precision(.fractionLength(3))) }
      .joined(separator: ", ") + " m"
  }
}
