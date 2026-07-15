import AnimaCore
import SwiftUI

struct InspectorView: View {
  @Bindable var workspace: StudioWorkspaceModel

  var body: some View {
    Form {
      if let selectedAsset {
        Section("Model Asset") {
          LabeledContent("Name", value: selectedAsset.name)
          LabeledContent("Type", value: "USD / RealityKit")
          LabeledContent("Source", value: selectedAsset.sourcePath)
            .lineLimit(3)
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
}
