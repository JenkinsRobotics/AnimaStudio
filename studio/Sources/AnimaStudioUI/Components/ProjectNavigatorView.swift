import AnimaCore
import RealityKitViewport
import SwiftUI

struct ProjectNavigatorView: View {
  @Bindable var workspace: StudioWorkspaceModel
  let importModel: () -> Void
  @State private var filterText = ""

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
              isSourceLocked: true
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
    Section("Semantic Rig") {
      if workspace.project.rig.parts.isEmpty {
        Label("No parts yet", systemImage: "cube.transparent")
          .foregroundStyle(.secondary)
      } else {
        ForEach(filteredParts) { part in
          PartTreeRow(
            title: part.displayName,
            role: .semanticPart,
            detail: part.primitiveKind.displayName
          )
          .tag(NavigatorItem.part(part.id))
        }
        if filteredParts.isEmpty {
          noFilterResults
        }
      }
    }
  }

  private var jointSection: some View {
    Section("Joints") {
      ForEach(filteredJoints, id: \.id) { joint in
        PartTreeRow(title: joint.displayName, role: .joint)
          .tag(NavigatorItem.joint(joint.id))
      }
      if workspace.project.rig.joints.isEmpty {
        Label("No joints yet", systemImage: "rotate.3d")
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
        Button("Create Semantic Part", systemImage: "plus.circle.fill") {
          workspace.showCreationTools()
        }
        .buttonStyle(.borderedProminent)
        .help("Open the rig creation palette")
        Label(
          "Proxy parts are editable. Imported source nodes remain locked.",
          systemImage: "info.circle"
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

  private var filteredAssets: [ProjectAsset] {
    workspace.project.assets.filter { matchesFilter($0.name) }
  }

  private var filteredJoints: [JointDefinition] {
    workspace.project.rig.joints.filter { matchesFilter($0.displayName) }
  }

  private var filteredParts: [RigPartDefinition] {
    workspace.project.rig.parts.filter { matchesFilter($0.displayName) }
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
}
