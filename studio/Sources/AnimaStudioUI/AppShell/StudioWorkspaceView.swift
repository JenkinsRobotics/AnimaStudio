import AnimaCore
import AppKit
import RealityKitViewport
import SwiftUI
import UniformTypeIdentifiers

struct StudioWorkspaceView: View {
  let closeProject: () -> Void
  @Binding var designProfile: StudioDesignProfile

  @State private var workspace = StudioWorkspaceModel()
  @State private var isImportingModel = false
  @State private var isUIDevWorkspace = false
  @State private var uiDevSection = UIDevSection.designKit
  @State private var showsUIDevAgentPanel = false
  @AppStorage("viewportAppearance") private var viewportAppearanceRawValue =
    PreviewAppearance.midnight.rawValue
  @AppStorage("viewportNavigationProfile") private var viewportNavigationProfileRawValue =
    PreviewNavigationProfile.default.rawValue
  @AppStorage("viewportCustomRotateDrag") private var viewportCustomRotateDragRawValue =
    NavigationDragBinding.rightMouse.rawValue
  @AppStorage("viewportCustomPanDrag") private var viewportCustomPanDragRawValue =
    NavigationDragBinding.middleMouse.rawValue
  @AppStorage("viewportRenderStyle") private var viewportRenderStyleRawValue =
    ViewportRenderStyle.shaded.rawValue
  @AppStorage("viewportEdgeDisplay") private var viewportEdgeDisplayRawValue =
    ViewportEdgeDisplay.mesh.rawValue
  @AppStorage("viewportLightingPreset") private var viewportLightingPresetRawValue =
    ViewportLightingPreset.balanced.rawValue
  @AppStorage("viewportMaterialFinish") private var viewportMaterialFinishRawValue =
    ViewportMaterialFinish.satin.rawValue
  @AppStorage("viewportReflectionMode") private var viewportReflectionModeRawValue =
    ViewportReflectionMode.subtle.rawValue
  @AppStorage("viewportShowsShadows") private var viewportShowsShadows = true
  @AppStorage("viewportFieldOfViewDegrees") private var viewportFieldOfViewDegrees = 60.0

  init(
    designProfile: Binding<StudioDesignProfile> = .constant(.standard),
    closeProject: @escaping () -> Void
  ) {
    _designProfile = designProfile
    self.closeProject = closeProject
  }

  var body: some View {
    VStack(spacing: 0) {
      StudioDocumentBar(
        workspace: workspace,
        closeProject: closeProject
      )
      Divider()
      WorkspaceToolBar(
        workspace: workspace,
        viewportAppearance: viewportAppearanceBinding,
        isUIDevWorkspace: $isUIDevWorkspace,
        uiDevSection: $uiDevSection,
        importModel: { isImportingModel = true },
        toggleAgentPanel: { showsUIDevAgentPanel.toggle() }
      )
      Divider()

      workspaceCanvas

      bottomEditor
    }
    .background(StudioPalette.canvas)
    .preferredColorScheme(.dark)
    .onExitCommand {
      if workspace.matePlacement != nil {
        workspace.cancelMatePlacement()
      } else {
        workspace.clearSelection()
      }
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
    if !isUIDevWorkspace && workspace.activePresentation.showsBottomEditor {
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

  @ViewBuilder
  private var workspaceCanvas: some View {
    if isUIDevWorkspace {
      HStack(spacing: 0) {
        UIDevWorkspaceView(
          selectedSection: $uiDevSection,
          designProfile: $designProfile,
          showAgentPanel: { showsUIDevAgentPanel = true }
        )

        if showsUIDevAgentPanel {
          Divider()
          StudioAgentPanelView {
            showsUIDevAgentPanel = false
          }
          .frame(width: UIDevAgentPanelDescriptor.width)
          .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
      .animation(.easeInOut(duration: 0.18), value: showsUIDevAgentPanel)
    } else {
      authoringWorkspaceCanvas
    }
  }

  private var authoringWorkspaceCanvas: some View {
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
        cameraState: workspace.cameraState,
        navigationProfile: viewportNavigationProfile,
        customNavigationMapping: viewportCustomNavigationMapping,
        focusedModelPath: workspace.selectedModelPath,
        focusedPartID: workspace.selectedPartID,
        focusedPartIsLocked: workspace.selectedPartID.map(workspace.isComponentLocked) ?? false,
        mateCandidatePartIDs: workspace.mateCandidatePartIDs,
        selectedMateCandidate: workspace.matePlacement?.sourceCandidate,
        importedHierarchyRootPath: workspace.importedModelHierarchy?.id,
        rigGuideVisibility: workspace.activeWorkspace == .rig
          ? workspace.rigGuideVisibility : .hidden,
        appearance: viewportAppearance,
        renderStyle: viewportRenderStyle,
        edgeDisplay: viewportEdgeDisplay,
        lightingPreset: viewportLightingPreset,
        materialFinish: viewportMaterialFinish,
        reflectionMode: viewportReflectionMode,
        showsShadows: viewportShowsShadows,
        fieldOfViewDegrees: Float(viewportFieldOfViewDegrees),
        onSelectModelPath: { path in
          let modifiers = NSEvent.modifierFlags
          workspace.selectModelNode(
            at: path,
            extendingSelection: modifiers.contains(.command) || modifiers.contains(.shift)
          )
        },
        onSelectPartID: { id in
          let modifiers = NSEvent.modifierFlags
          workspace.selectPart(
            id: id,
            extendingSelection: modifiers.contains(.command) || modifiers.contains(.shift)
          )
        },
        onSetPartPosition: { id, position in
          workspace.setPartPosition(id: id, to: position)
        },
        onSetPartRotation: { id, rotation in
          workspace.setPartRotation(id: id, to: rotation)
        },
        onSelectMateCandidate: { candidate in
          workspace.selectMateConnector(candidate)
        },
        onCameraStateChange: { state in
          workspace.reportCameraState(state)
        }
      )
      .frame(minWidth: 520, minHeight: 420)

      viewportTitle
      cameraHUD

      if let matePlacement = workspace.matePlacement {
        MatePlacementOverlay(
          session: matePlacement,
          cancel: workspace.cancelMatePlacement
        )
        .padding(.top, 50)
      }

      if workspace.activeWorkspace == .rig && workspace.isRigEmpty {
        EmptyRigWorkspaceView(showCreationTools: workspace.showCreationTools)
      }

      if workspace.activeWorkspace == .rig {
        VStack {
          Spacer()
          if !workspace.showsCreationPalette && !workspace.project.rig.joints.isEmpty {
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

  private var cameraHUD: some View {
    HStack {
      Spacer()
      ViewportCameraHUD(
        workspace: workspace,
        projection: cameraProjectionBinding,
        renderStyle: viewportRenderStyleBinding,
        edgeDisplay: viewportEdgeDisplayBinding,
        lightingPreset: viewportLightingPresetBinding,
        materialFinish: viewportMaterialFinishBinding,
        reflectionMode: viewportReflectionModeBinding,
        showsShadows: $viewportShowsShadows,
        showsGrid: previewGridBinding,
        appearance: viewportAppearanceBinding,
        fieldOfViewDegrees: viewportFieldOfViewBinding,
        navigationProfile: viewportNavigationProfileBinding,
        customRotateDrag: viewportCustomRotateDragBinding,
        customPanDrag: viewportCustomPanDragBinding
      )
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
      case .asset, .part, .componentGroup, .modelNode, .joint:
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

  private var viewportNavigationProfile: PreviewNavigationProfile {
    PreviewNavigationProfile(rawValue: viewportNavigationProfileRawValue) ?? .default
  }

  private var viewportNavigationProfileBinding: Binding<PreviewNavigationProfile> {
    Binding(
      get: { viewportNavigationProfile },
      set: { viewportNavigationProfileRawValue = $0.rawValue }
    )
  }

  private var viewportCustomRotateDrag: NavigationDragBinding {
    NavigationDragBinding(rawValue: viewportCustomRotateDragRawValue) ?? .rightMouse
  }

  private var viewportCustomPanDrag: NavigationDragBinding {
    NavigationDragBinding(rawValue: viewportCustomPanDragRawValue) ?? .middleMouse
  }

  private var viewportCustomNavigationMapping: CustomNavigationMapping {
    CustomNavigationMapping(
      rotateDrag: viewportCustomRotateDrag,
      panDrag: viewportCustomPanDrag
    )
  }

  private var viewportCustomRotateDragBinding: Binding<NavigationDragBinding> {
    Binding(
      get: { viewportCustomRotateDrag },
      set: { newValue in
        let previousValue = viewportCustomRotateDrag
        if newValue == viewportCustomPanDrag {
          viewportCustomPanDragRawValue = previousValue.rawValue
        }
        viewportCustomRotateDragRawValue = newValue.rawValue
      }
    )
  }

  private var viewportCustomPanDragBinding: Binding<NavigationDragBinding> {
    Binding(
      get: { viewportCustomPanDrag },
      set: { newValue in
        let previousValue = viewportCustomPanDrag
        if newValue == viewportCustomRotateDrag {
          viewportCustomRotateDragRawValue = previousValue.rawValue
        }
        viewportCustomPanDragRawValue = newValue.rawValue
      }
    )
  }

  private var viewportRenderStyle: ViewportRenderStyle {
    ViewportRenderStyle(rawValue: viewportRenderStyleRawValue) ?? .shaded
  }

  private var viewportRenderStyleBinding: Binding<ViewportRenderStyle> {
    Binding(
      get: { viewportRenderStyle },
      set: { viewportRenderStyleRawValue = $0.rawValue }
    )
  }

  private var viewportEdgeDisplay: ViewportEdgeDisplay {
    ViewportEdgeDisplay(rawValue: viewportEdgeDisplayRawValue) ?? .mesh
  }

  private var viewportEdgeDisplayBinding: Binding<ViewportEdgeDisplay> {
    Binding(
      get: { viewportEdgeDisplay },
      set: { viewportEdgeDisplayRawValue = $0.rawValue }
    )
  }

  private var viewportLightingPreset: ViewportLightingPreset {
    ViewportLightingPreset(rawValue: viewportLightingPresetRawValue) ?? .balanced
  }

  private var viewportLightingPresetBinding: Binding<ViewportLightingPreset> {
    Binding(
      get: { viewportLightingPreset },
      set: { viewportLightingPresetRawValue = $0.rawValue }
    )
  }

  private var viewportMaterialFinish: ViewportMaterialFinish {
    ViewportMaterialFinish(rawValue: viewportMaterialFinishRawValue) ?? .satin
  }

  private var viewportMaterialFinishBinding: Binding<ViewportMaterialFinish> {
    Binding(
      get: { viewportMaterialFinish },
      set: { viewportMaterialFinishRawValue = $0.rawValue }
    )
  }

  private var viewportReflectionMode: ViewportReflectionMode {
    ViewportReflectionMode(rawValue: viewportReflectionModeRawValue) ?? .subtle
  }

  private var viewportReflectionModeBinding: Binding<ViewportReflectionMode> {
    Binding(
      get: { viewportReflectionMode },
      set: { viewportReflectionModeRawValue = $0.rawValue }
    )
  }

  private var viewportFieldOfViewBinding: Binding<Float> {
    Binding(
      get: { Float(viewportFieldOfViewDegrees) },
      set: { viewportFieldOfViewDegrees = Double($0) }
    )
  }

  private var cameraProjectionBinding: Binding<PreviewCameraProjection> {
    Binding(
      get: { workspace.cameraProjection },
      set: { workspace.cameraProjection = $0 }
    )
  }

  private var previewGridBinding: Binding<Bool> {
    Binding(
      get: { workspace.showsPreviewGrid },
      set: { workspace.showsPreviewGrid = $0 }
    )
  }

  private static let modelContentTypes: [UTType] = [
    "usd", "usda", "usdc", "usdz", "reality",
  ].compactMap { UTType(filenameExtension: $0) }
}
