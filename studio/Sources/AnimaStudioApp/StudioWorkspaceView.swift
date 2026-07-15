import AnimaCore
import RealityKitViewport
import SwiftUI
import UniformTypeIdentifiers

struct StudioWorkspaceView: View {
  let closeProject: () -> Void

  @State private var workspace = StudioWorkspaceModel()
  @State private var isImportingModel = false

  var body: some View {
    VStack(spacing: 0) {
      WorkspaceModeBar(workspace: workspace, closeProject: closeProject)
      Divider()
      WorkspaceToolBar(
        workspace: workspace,
        importModel: { isImportingModel = true }
      )
      Divider()

      workspaceCanvas

      if workspace.mode == .animate {
        Divider()
        TimelineEditorView(workspace: workspace)
          .frame(minHeight: 220, idealHeight: 270, maxHeight: 340)
      }
    }
    .background(StudioPalette.canvas)
    .preferredColorScheme(.dark)
    .fileImporter(
      isPresented: $isImportingModel,
      allowedContentTypes: Self.modelContentTypes,
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          Task { @MainActor in
            await workspace.importModel(from: url)
          }
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

  private var workspaceCanvas: some View {
    ZStack {
      if workspace.mode == .hardware {
        hardwareWorkspace
      } else {
        viewport
      }

      HStack(alignment: .top, spacing: 16) {
        ProjectNavigatorView(
          workspace: workspace,
          importModel: { isImportingModel = true }
        )
        .frame(width: 290)

        Spacer(minLength: 360)

        InspectorView(workspace: workspace)
          .frame(width: 300)
      }
      .padding(16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }

  private var viewport: some View {
    ZStack(alignment: .top) {
      RobotPreviewView(
        frame: workspace.evaluatedFrame,
        modelURL: workspace.importedModelURL
      )
      .frame(minWidth: 520, minHeight: 420)

      HStack(spacing: 6) {
        Image(systemName: workspace.mode.systemImage)
        Text(workspace.mode == .importAssets ? "IMPORT PREVIEW" : "3D VIEW")
      }
      .font(.caption2.weight(.bold))
      .tracking(1)
      .foregroundStyle(StudioPalette.muted)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.ultraThinMaterial, in: Capsule())
      .padding(.top, 12)
    }
  }

  private var hardwareWorkspace: some View {
    ZStack {
      StudioPalette.canvas
      ContentUnavailableView(
        "Hardware Safely Offline",
        systemImage: "powerplug",
        description: Text(
          "The protocol simulator exists, but Studio connection and arming controls are not wired yet."
        )
      )
      .frame(maxWidth: 420)
    }
  }

  private static let modelContentTypes: [UTType] = [
    "usd", "usda", "usdc", "usdz", "reality",
  ].compactMap { UTType(filenameExtension: $0) }
}
