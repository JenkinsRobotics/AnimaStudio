import AnimaCore
import RealityKitViewport
import SwiftUI

struct InspectorView: View {
  @Bindable var workspace: StudioWorkspaceModel

  var body: some View {
    VStack(spacing: 0) {
      WorkspacePanelHeader(title: panelTitle, systemImage: panelSystemImage)

      Form {
        if workspace.mode == .animate {
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

        if let selectedAsset {
          Section("Model Asset") {
            LabeledContent("Name", value: selectedAsset.name)
            LabeledContent("Type", value: "USD / RealityKit")
            LabeledContent("Source", value: selectedAsset.sourcePath)
              .lineLimit(3)
          }
        } else if let selectedModelNode {
          Section("Model Node") {
            LabeledContent("Name", value: selectedModelNode.displayName)
            LabeledContent("Children", value: "\(selectedModelNode.children.count)")
            LabeledContent("Subtree", value: "\(selectedModelNode.nodeCount) nodes")
            LabeledContent("Path", value: selectedModelNode.id.displayString)
              .lineLimit(4)
            LabeledContent("Semantic Part", value: "Not mapped")
              .foregroundStyle(.secondary)
          }
        } else {
          jointInspector
        }

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
    .background(StudioPalette.panel)
    .clipShape(RoundedRectangle(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
  }

  @ViewBuilder
  private var jointInspector: some View {
    let joint = workspace.project.rig.joints[0]
    Section("Joint") {
      LabeledContent("Name", value: joint.displayName)
      LabeledContent("Axis", value: joint.axis.rawValue.uppercased())
      LabeledContent(
        "Angle",
        value: workspace.evaluatedFrame.jointAnglesRadians[joint.id, default: 0]
          .formatted(.number.precision(.fractionLength(3))) + " rad"
      )
      LabeledContent(
        "Limits",
        value:
          "\(joint.minimumRadians.formatted(.number.precision(.fractionLength(2)))) … \(joint.maximumRadians.formatted(.number.precision(.fractionLength(2)))) rad"
      )
    }
  }

  private var selectedAsset: ProjectAsset? {
    guard case .asset(let selectedID) = workspace.selection else { return nil }
    return workspace.project.assets.first { $0.id == selectedID }
  }

  private var selectedModelNode: ModelHierarchyNode? {
    guard case .modelNode(let selectedPath) = workspace.selection else {
      return nil
    }
    return workspace.importedModelHierarchy?.node(at: selectedPath)
  }

  private var panelTitle: String {
    workspace.mode == .animate ? "Animations" : "Inspector"
  }

  private var panelSystemImage: String {
    workspace.mode == .animate ? "play.circle.fill" : "slider.horizontal.3"
  }
}
