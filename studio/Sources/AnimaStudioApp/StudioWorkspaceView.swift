import AnimaCore
import RealityKitViewport
import SwiftUI
import UniformTypeIdentifiers

struct StudioWorkspaceView: View {
  @State private var workspace = StudioWorkspaceModel()
  @State private var isImportingModel = false

  var body: some View {
    NavigationSplitView {
      ProjectNavigatorView(workspace: workspace)
    } detail: {
      VStack(spacing: 0) {
        HSplitView {
          viewport
          InspectorView(workspace: workspace)
            .frame(minWidth: 250, idealWidth: 290, maxWidth: 340)
        }

        Divider()
        TimelineEditorView(workspace: workspace)
          .frame(minHeight: 180, idealHeight: 210, maxHeight: 300)
      }
      .navigationTitle(workspace.project.name)
      .toolbar { workspaceToolbar }
    }
    .fileImporter(
      isPresented: $isImportingModel,
      allowedContentTypes: Self.modelContentTypes,
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          workspace.importModel(from: url)
        }
      case .failure(let error):
        workspace.importErrorMessage = error.localizedDescription
      }
    }
    .alert(
      "Could Not Import Model",
      isPresented: Binding(
        get: { workspace.importErrorMessage != nil },
        set: { if !$0 { workspace.importErrorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(workspace.importErrorMessage ?? "Unknown model import error")
    }
    .task(id: workspace.isPlaying) {
      guard workspace.isPlaying else { return }
      let clock = ContinuousClock()
      while !Task.isCancelled && workspace.isPlaying {
        try? await clock.sleep(for: .milliseconds(16))
        workspace.advancePlayback(by: 1.0 / 60.0)
      }
    }
  }

  private var viewport: some View {
    ZStack(alignment: .topLeading) {
      RobotPreviewView(
        frame: workspace.evaluatedFrame,
        modelURL: workspace.importedModelURL
      )
      .frame(minWidth: 520, minHeight: 420)

      VStack(alignment: .leading, spacing: 4) {
        Label("3D View", systemImage: "view.3d")
          .font(.caption.weight(.semibold))
        if let modelURL = workspace.importedModelURL {
          Text(modelURL.lastPathComponent)
            .font(.caption2)
            .foregroundStyle(.secondary)
        } else {
          Text("Sample mechanism")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .padding(8)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
      .padding(10)
    }
  }

  @ToolbarContentBuilder
  private var workspaceToolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .primaryAction) {
      Picker("Mode", selection: $workspace.mode) {
        ForEach(WorkspaceMode.allCases) { mode in
          Text(mode.rawValue).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 180)

      Button {
        isImportingModel = true
      } label: {
        Label("Import Model", systemImage: "square.and.arrow.down")
      }
    }
  }

  private static let modelContentTypes: [UTType] = [
    "usd", "usda", "usdc", "usdz", "reality",
  ].compactMap { UTType(filenameExtension: $0) }
}
