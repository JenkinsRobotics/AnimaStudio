import AnimaCore
import RealityKitViewport
import SwiftUI

struct ProjectNavigatorView: View {
  @Bindable var workspace: StudioWorkspaceModel
  let importModel: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      WorkspacePanelHeader(title: panelTitle, systemImage: panelSystemImage)

      List(selection: $workspace.selection) {
        Section("Project") {
          Label(workspace.project.name, systemImage: "shippingbox")
            .tag(NavigatorItem.project)
        }

        if workspace.mode == .importAssets || !workspace.project.assets.isEmpty {
          Section("Assets") {
            if workspace.project.assets.isEmpty {
              ContentUnavailableView(
                "No Models",
                systemImage: "cube.transparent",
                description: Text("Import USD content to begin.")
              )
            } else {
              ForEach(workspace.project.assets) { asset in
                Label(asset.name, systemImage: "cube")
                  .tag(NavigatorItem.asset(asset.id))
              }
            }
          }
        }

        Section("Structure") {
          if workspace.isLoadingModelHierarchy {
            HStack {
              ProgressView()
                .controlSize(.small)
              Text("Reading model hierarchy…")
                .foregroundStyle(.secondary)
            }
          } else if let hierarchy = workspace.importedModelHierarchy {
            OutlineGroup([hierarchy], children: \.outlineChildren) { node in
              Label(
                node.displayName,
                systemImage: node.children.isEmpty ? "cube" : "square.3.layers.3d"
              )
              .tag(NavigatorItem.modelNode(node.id))
            }
          } else {
            Label("Sample Mechanism", systemImage: "square.3.layers.3d")
              .tag(NavigatorItem.structure)
              .badge("2")
          }
        }

        Section("Joints") {
          ForEach(workspace.project.rig.joints, id: \.id) { joint in
            Label(joint.displayName, systemImage: "rotate.3d")
              .tag(NavigatorItem.joint(joint.id))
          }
        }

        if workspace.mode == .animate {
          Section("Animations") {
            ForEach(workspace.project.clips, id: \.name) { clip in
              Label(clip.name, systemImage: "timeline.selection")
                .tag(NavigatorItem.animation(clip.name))
            }
          }
        }
      }
      .listStyle(.sidebar)
      .scrollContentBackground(.hidden)
      .background(StudioPalette.panel)
      .accessibilityLabel("Project parts and assets")

      Divider()
      panelFooter
    }
    .studioPanelSurface()
  }

  @ViewBuilder
  private var panelFooter: some View {
    switch workspace.mode {
    case .importAssets:
      Button(action: importModel) {
        Label("Import Model", systemImage: "plus.circle.fill")
      }
      .buttonStyle(StudioPrimaryButtonStyle())
      .disabled(workspace.isLoadingModelHierarchy)
      .padding(12)
    case .build:
      Button("Create Semantic Part", systemImage: "plus.circle.fill") {}
        .buttonStyle(.borderedProminent)
        .disabled(true)
        .help("Part creation follows durable project persistence")
        .padding(12)
    case .animate:
      Text(selectionGuidance)
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
        .padding(12)
    case .hardware:
      Label("No hardware drivers configured", systemImage: "powerplug")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
        .padding(12)
    }
  }

  private var selectionGuidance: String {
    if workspace.selectionCount > 1 {
      return "\(workspace.selectionCount) items selected. Command-click or Shift-click to adjust."
    }
    return "Select a joint or model node. Command-click or Shift-click selects multiple."
  }

  private var panelTitle: String {
    switch workspace.mode {
    case .build, .animate: "Parts"
    case .importAssets: "Imported Assets"
    case .hardware: "Hardware"
    }
  }

  private var panelSystemImage: String {
    switch workspace.mode {
    case .build, .animate: "point.3.connected.trianglepath.dotted"
    case .importAssets: "square.and.arrow.down"
    case .hardware: "cable.connector"
    }
  }
}
