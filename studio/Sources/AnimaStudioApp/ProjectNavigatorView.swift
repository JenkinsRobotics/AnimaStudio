import AnimaCore
import SwiftUI

struct ProjectNavigatorView: View {
  @Bindable var workspace: StudioWorkspaceModel

  var body: some View {
    List(selection: $workspace.selection) {
      Section("Project") {
        Label(workspace.project.name, systemImage: "shippingbox")
          .tag(NavigatorItem.project)
      }

      Section("Assets") {
        if workspace.project.assets.isEmpty {
          ContentUnavailableView(
            "No Models",
            systemImage: "cube.transparent",
            description: Text("Use Import Model to add USD content.")
          )
        } else {
          ForEach(workspace.project.assets) { asset in
            Label(asset.name, systemImage: "cube")
              .tag(NavigatorItem.asset(asset.id))
          }
        }
      }

      Section("Structure") {
        Label("Sample Mechanism", systemImage: "square.3.layers.3d")
          .tag(NavigatorItem.structure)
          .badge("2 parts")
      }

      Section("Joints") {
        ForEach(workspace.project.rig.joints, id: \.id) { joint in
          Label(joint.displayName, systemImage: "rotate.3d")
            .tag(NavigatorItem.joint(joint.id))
        }
      }

      Section("Animations") {
        ForEach(workspace.project.clips, id: \.name) { clip in
          Label(clip.name, systemImage: "timeline.selection")
            .tag(NavigatorItem.animation(clip.name))
        }
      }
    }
    .navigationTitle("Anima Studio")
    .navigationSplitViewColumnWidth(min: 210, ideal: 250)
  }
}
