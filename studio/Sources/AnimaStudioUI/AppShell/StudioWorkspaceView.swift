import AnimaCore
import AppKit
import RealityKitViewport
import SwiftUI
import UniformTypeIdentifiers

struct StudioWorkspaceView: View {
  let closeProject: () -> Void

  @State private var workspace = StudioWorkspaceModel()
  @State private var isImportingModel = false
  @AppStorage("viewportAppearance") private var viewportAppearanceRawValue =
    PreviewAppearance.midnight.rawValue

  var body: some View {
    VStack(spacing: 0) {
      WorkspaceSwitcherBar(
        workspace: workspace,
        viewportAppearance: viewportAppearanceBinding,
        closeProject: closeProject
      )
      Divider()
      WorkspaceToolBar(
        workspace: workspace,
        importModel: { isImportingModel = true }
      )
      Divider()

      workspaceCanvas

      bottomEditor
    }
    .background(StudioPalette.canvas)
    .preferredColorScheme(.dark)
    .onExitCommand {
      workspace.clearSelection()
    }
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

  @ViewBuilder
  private var bottomEditor: some View {
    if workspace.activePresentation.showsBottomEditor {
      switch workspace.activeWorkspace {
      case .animate:
        Divider()
        TimelineEditorView(workspace: workspace)
          .frame(minHeight: 260, idealHeight: 340, maxHeight: 440)
      case .show:
        Divider()
        ShowTimelineView(workspace: workspace)
          .frame(minHeight: 210, idealHeight: 250, maxHeight: 320)
      case .assets, .rig, .hardware:
        EmptyView()
      }
    }
  }

  private var workspaceCanvas: some View {
    ZStack {
      if workspace.activeWorkspace == .hardware {
        HardwareWorkspaceView()
      } else {
        viewport
      }

      HStack(alignment: .top, spacing: 16) {
        if workspace.activePresentation.showsNavigator {
          ProjectNavigatorView(
            workspace: workspace,
            importModel: { isImportingModel = true }
          )
          .frame(width: StudioMetrics.navigatorWidth)
        }

        Spacer(minLength: 320)

        if showsInspector {
          InspectorView(workspace: workspace)
            .frame(width: StudioMetrics.inspectorWidth)
        }
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
        rig: workspace.project.rig,
        modelURL: workspace.importedModelURL,
        showsGrid: workspace.showsPreviewGrid,
        projection: workspace.cameraProjection,
        viewpoint: workspace.cameraViewpoint,
        cameraCommandRevision: workspace.cameraCommandRevision,
        focusedModelPath: workspace.selectedModelPath,
        importedHierarchyRootPath: workspace.importedModelHierarchy?.id,
        rigGuideVisibility: workspace.activeWorkspace == .rig
          ? workspace.rigGuideVisibility : .hidden,
        appearance: viewportAppearance,
        onSelectModelPath: { path in
          let modifiers = NSEvent.modifierFlags
          workspace.selectModelNode(
            at: path,
            extendingSelection: modifiers.contains(.command) || modifiers.contains(.shift)
          )
        }
      )
      .frame(minWidth: 520, minHeight: 420)

      viewportTitle
      cameraControls

      if workspace.activeWorkspace == .rig && workspace.isRigEmpty {
        EmptyRigWorkspaceView(showCreationTools: workspace.showCreationTools)
      }

      if workspace.activeWorkspace == .rig {
        VStack {
          Spacer()
          if workspace.showsCreationPalette {
            CreationPaletteView(workspace: workspace)
          } else if !workspace.project.rig.joints.isEmpty {
            RigGuideOverlay(workspace: workspace)
          }
        }
        .padding(
          .leading,
          workspace.activePresentation.showsNavigator
            ? StudioMetrics.navigatorWidth + 32 : 18
        )
        .padding(.trailing, showsInspector ? StudioMetrics.inspectorWidth + 32 : 18)
        .padding(.bottom, 16)
      }
    }
  }

  private var viewportTitle: some View {
    HStack(spacing: 6) {
      Image(systemName: workspace.activeWorkspace.descriptor.systemImage)
      Text(workspace.activeWorkspace.descriptor.viewportLabel)
    }
    .font(.caption2.weight(.bold))
    .tracking(1)
    .foregroundStyle(StudioPalette.muted)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(.ultraThinMaterial, in: Capsule())
    .padding(.top, 12)
  }

  private var cameraControls: some View {
    HStack {
      Spacer()
      ViewportCameraControls(workspace: workspace)
        .padding(.trailing, showsInspector ? StudioMetrics.inspectorWidth + 32 : 16)
    }
    .padding(.top, 10)
  }

  private var showsInspector: Bool {
    guard workspace.activePresentation.showsInspector else { return false }
    return switch workspace.activeWorkspace {
    case .assets, .animate, .show, .hardware:
      true
    case .rig:
      switch workspace.primarySelection {
      case .asset, .part, .modelNode, .joint:
        true
      case .project, .structure, .animation, nil:
        false
      }
    }
  }

  private var viewportAppearance: PreviewAppearance {
    PreviewAppearance(rawValue: viewportAppearanceRawValue) ?? .midnight
  }

  private var viewportAppearanceBinding: Binding<PreviewAppearance> {
    Binding(
      get: { viewportAppearance },
      set: { viewportAppearanceRawValue = $0.rawValue }
    )
  }

  private static let modelContentTypes: [UTType] = [
    "usd", "usda", "usdc", "usdz", "reality",
  ].compactMap { UTType(filenameExtension: $0) }
}
