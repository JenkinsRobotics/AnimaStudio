import AnimaCore
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
        modeSummary
        selectionConfiguration
        workspaceSummary
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
      .background(StudioPalette.panel)

      if workspace.mode == .animate {
        Divider()
        Button("Create Animation", systemImage: "plus.circle.fill") {}
          .buttonStyle(.borderedProminent)
          .disabled(true)
          .help("Animation creation lands with editable clips")
          .padding(12)
      }
    }
    .studioPanelSurface()
  }

  @ViewBuilder
  private var modeSummary: some View {
    if workspace.mode == .hardware {
      Section("Driver Status") {
        LabeledContent("Connection", value: "Offline")
        LabeledContent("Configured Drivers", value: "0")
        LabeledContent("Master Live", value: "Disarmed")
        Label("Output remains disabled", systemImage: "lock.shield")
          .foregroundStyle(.secondary)
      }
    } else if workspace.mode == .animate {
      Section("Active Animation") {
        LabeledContent("Name", value: workspace.activeClip.name)
        LabeledContent(
          "Duration",
          value: workspace.activeClip.durationSeconds.formatted(
            .number.precision(.fractionLength(2))
          ) + " s"
        )
        LabeledContent("Tracks", value: "\(workspace.activeClip.jointTracks.count)")
      }
    }
  }

  @ViewBuilder
  private var selectionConfiguration: some View {
    if workspace.mode == .hardware {
      EmptyView()
    } else if let selectedAsset {
      assetInspector(selectedAsset)
    } else if let selectedModelNode {
      modelNodeInspector(selectedModelNode)
    } else if let selectedJoint {
      jointInspector(selectedJoint)
    } else if workspace.selectionCount > 1 {
      Section("Multiple Selection") {
        LabeledContent("Selected", value: "\(workspace.selectionCount) items")
        Text("Configuration is available when one item is selected.")
          .foregroundStyle(.secondary)
      }
    } else if workspace.mode != .animate {
      Section("Selection") {
        Text("Select an asset, model node, or joint to configure it.")
          .foregroundStyle(.secondary)
      }
    }
  }

  private var workspaceSummary: some View {
    Section("Workspace") {
      LabeledContent("Mode", value: workspace.mode.rawValue)
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

  private func assetInspector(_ asset: ProjectAsset) -> some View {
    Section("Model Asset") {
      StudioTextFieldRow(
        title: "Name",
        text: Binding(
          get: { asset.name },
          set: { workspace.renameAsset(id: asset.id, to: $0) }
        ),
        placeholder: "Model name",
        help: "The human-readable asset name stored in this project."
      )
      LabeledContent("Type", value: "USD / RealityKit")
      LabeledContent("Source", value: asset.sourcePath)
        .lineLimit(3)
    }
  }

  private func modelNodeInspector(_ node: ModelHierarchyNode) -> some View {
    Section("Model Node") {
      LabeledContent("Name", value: node.displayName)
      LabeledContent("Children", value: "\(node.children.count)")
      LabeledContent("Subtree", value: "\(node.nodeCount) nodes")
      LabeledContent("Path", value: node.id.displayString)
        .lineLimit(4)
      LabeledContent("Semantic Part", value: "Not mapped")
        .foregroundStyle(.secondary)
      Label(
        "Imported hierarchy nodes remain read-only until mapped to a semantic part.",
        systemImage: "info.circle"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private func jointInspector(_ joint: JointDefinition) -> some View {
    Section("Joint") {
      StudioTextFieldRow(
        title: "Name",
        text: Binding(
          get: { joint.displayName },
          set: { workspace.renameJoint(id: joint.id, to: $0) }
        ),
        placeholder: "Joint name",
        help: "The readable name shown throughout the rig and timeline."
      )
      StudioPickerRow(
        title: "Rotation Axis",
        selection: Binding(
          get: { joint.axis },
          set: { workspace.setJointAxis(id: joint.id, to: $0) }
        ),
        help: "The local axis driven by this rotational joint."
      ) {
        Text("X").tag(JointAxis.x)
        Text("Y").tag(JointAxis.y)
        Text("Z").tag(JointAxis.z)
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

  private var selectedAsset: ProjectAsset? {
    guard case .asset(let selectedID) = workspace.primarySelection else { return nil }
    return workspace.project.assets.first { $0.id == selectedID }
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

  private var panelTitle: String {
    switch workspace.mode {
    case .animate: "Animations"
    case .hardware: "Hardware Status"
    case .build, .importAssets: "Inspector"
    }
  }

  private var clearSelectionAction: (() -> Void)? {
    guard !workspace.selection.isEmpty else { return nil }
    return { workspace.clearSelection() }
  }

  private var panelSystemImage: String {
    switch workspace.mode {
    case .animate: "play.circle.fill"
    case .hardware: "cable.connector"
    case .build, .importAssets: "slider.horizontal.3"
    }
  }
}
