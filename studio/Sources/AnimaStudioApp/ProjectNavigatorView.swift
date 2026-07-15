import AnimaCore
import RealityKitViewport
import SwiftUI

struct ProjectNavigatorView: View {
  @Bindable var workspace: StudioWorkspaceModel
  let importModel: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      WorkspacePanelHeader(
        title: panelTitle,
        systemImage: workspace.activeWorkspace.descriptor.systemImage
      )

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
  }

  @ViewBuilder
  private var navigatorContent: some View {
    switch workspace.activeWorkspace {
    case .assets:
      projectSection
      assetSection
      importedHierarchySection
    case .rig:
      projectSection
      structureSection
      jointSection
    case .animate:
      animationSection
      structureSection
      jointSection
    case .show:
      showSection
      animationSection
      mediaSection
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
        ForEach(workspace.project.assets) { asset in
          Label(asset.name, systemImage: "cube")
            .tag(NavigatorItem.asset(asset.id))
        }
      }
    }
  }

  @ViewBuilder
  private var importedHierarchySection: some View {
    if workspace.importedModelHierarchy != nil || workspace.isLoadingModelHierarchy {
      structureSection
    }
  }

  @ViewBuilder
  private var structureSection: some View {
    Section("Parts & Structure") {
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
  }

  private var jointSection: some View {
    Section("Joints") {
      ForEach(workspace.project.rig.joints, id: \.id) { joint in
        Label(joint.displayName, systemImage: "rotate.3d")
          .tag(NavigatorItem.joint(joint.id))
      }
    }
  }

  private var animationSection: some View {
    Section("Animations") {
      ForEach(workspace.project.clips, id: \.name) { clip in
        Label(clip.name, systemImage: "timeline.selection")
          .tag(NavigatorItem.animation(clip.name))
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
      Button("Create Semantic Part", systemImage: "plus.circle.fill") {}
        .buttonStyle(.borderedProminent)
        .disabled(true)
        .help("Part creation follows the typed-joint project contract")
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
    return "Select a joint or model node. Command-click or Shift-click selects multiple."
  }

  private var panelTitle: String {
    switch workspace.activeWorkspace {
    case .assets: "Assets"
    case .rig, .animate: "Parts"
    case .show: "Show Contents"
    case .hardware: "Hardware"
    }
  }
}
