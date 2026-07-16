import AnimaDocument
import AnimaEvaluation
import AnimaModel
import AppKit
import RealityKitViewport
import SwiftUI
import UniformTypeIdentifiers

struct StudioWorkspaceView: View {
  @Binding var session: StudioProjectSession
  let closeProject: () -> Void
  let newProject: () -> Void
  let openProject: () -> Void
  let didPersistProject: (StudioProjectSession) -> Void
  @Binding var designProfile: StudioDesignProfile

  @State private var workspace: StudioWorkspaceModel
  @State private var isImportingModel = false
  @State private var pendingModelImportURLs: [URL] = []
  @State private var stepConversionMessage: String?
  @State private var showsNewCharacterSheet = false
  @State private var isCreatingCharacter = false
  @State private var showsCharacterLoadingStage = false
  @State private var characterImportProgress: CharacterImportProgress?
  @State private var characterImportErrorMessage: String?
  @State private var isSwitchingCharacter = false
  @State private var characterEditorMetadata = CharacterEditorMetadata()
  @State private var activeImportedModelReference: String?
  @State private var isImportingAnimaCharacter = false
  @State private var isUIDevWorkspace = false
  @State private var uiDevSection = UIDevSection.templateMatrix
  @State private var showsUIDevAgentPanel = false
  @State private var viewportPointerTarget = ViewportPointerTarget.canvas
  @State private var viewportContextMenuRequest: ViewportContextMenuRequest?
  @State private var showsMouseNavigationSettings = false
  @State private var lifecycleErrorMessage: String?
  @State private var isSavingProject = false
  @State private var didLoadIndexedCharacter = false
  @AppStorage("viewportAppearance") private var viewportAppearanceRawValue =
    PreviewAppearance.midnight.rawValue
  @AppStorage("viewportNavigationProfile") private var viewportNavigationProfileRawValue =
    PreviewNavigationProfile.default.rawValue
  @AppStorage("viewportCustomRotateDrag") private var viewportCustomRotateDragRawValue =
    NavigationDragBinding.rightMouse.rawValue
  @AppStorage("viewportCustomPanDrag") private var viewportCustomPanDragRawValue =
    NavigationDragBinding.middleMouse.rawValue
  @AppStorage("viewportCustomPreciseZoomDrag") private var viewportCustomPreciseZoomDragRawValue =
    NavigationDragBinding.shiftMiddleMouse.rawValue
  @AppStorage("viewportOrbitSpeed") private var viewportOrbitSpeedRawValue =
    PreviewNavigationSpeed.standard.rawValue
  @AppStorage("viewportPanSpeed") private var viewportPanSpeedRawValue =
    PreviewNavigationSpeed.standard.rawValue
  @AppStorage("viewportZoomSpeed") private var viewportZoomSpeedRawValue =
    PreviewNavigationSpeed.reduced.rawValue
  @AppStorage("viewportReversesWheelZoom") private var viewportReversesWheelZoom = false
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
    session: Binding<StudioProjectSession>,
    designProfile: Binding<StudioDesignProfile> = .constant(.standard),
    newProject: @escaping () -> Void = {},
    openProject: @escaping () -> Void = {},
    didPersistProject: @escaping (StudioProjectSession) -> Void = { _ in },
    closeProject: @escaping () -> Void
  ) {
    _session = session
    _designProfile = designProfile
    _workspace = State(
      initialValue: StudioWorkspaceModel(project: session.wrappedValue.document.project)
    )
    self.newProject = newProject
    self.openProject = openProject
    self.didPersistProject = didPersistProject
    self.closeProject = closeProject
  }

  /// Preview/test convenience. Production always supplies a folder-backed
  /// session from `AnimaStudioRootView`.
  init(
    designProfile: Binding<StudioDesignProfile> = .constant(.standard),
    closeProject: @escaping () -> Void
  ) {
    let previewSession = StudioProjectSession(
      document: ProjectLifecycle.makeEmptyDocument(name: "Untitled Character"),
      projectURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("AnimaStudio-Preview", isDirectory: true)
    )
    self.init(
      session: .constant(previewSession),
      designProfile: designProfile,
      closeProject: closeProject
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      StudioDocumentBar(
        workspace: workspace,
        isSaving: isSavingProject,
        newProject: newProject,
        openProject: openProject,
        saveProject: { Task { await saveProject() } },
        saveProjectAs: { Task { await saveProjectAs() } },
        closeProject: closeProject
      )
      Divider()
      WorkspaceToolBar(
        workspace: workspace,
        viewportAppearance: viewportAppearanceBinding,
        isUIDevWorkspace: $isUIDevWorkspace,
        uiDevSection: $uiDevSection,
        importModel: { isImportingModel = true },
        importAnimaCharacter: { isImportingAnimaCharacter = true },
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
      allowsMultipleSelection: true
    ) { result in
      switch result {
      case .success(let urls):
        beginModelImport(from: urls)
      case .failure(let error):
        presentModelImportError(error.localizedDescription)
      }
    }
    .sheet(
      isPresented: Binding(
        get: { !pendingModelImportURLs.isEmpty },
        set: { if !$0 { pendingModelImportURLs.removeAll() } }
      )
    ) {
      if !pendingModelImportURLs.isEmpty {
        ModelImportUnitsSheet(
          urls: pendingModelImportURLs,
          cancel: { pendingModelImportURLs.removeAll() },
          importModels: { requests in
            pendingModelImportURLs.removeAll()
            Task { await importModels(requests) }
          }
        )
      }
    }
    .sheet(isPresented: $showsNewCharacterSheet) {
      NewCharacterSheet(
        existingCharacters: session.document.characters,
        isCreating: isCreatingCharacter,
        cancel: { showsNewCharacterSheet = false },
        create: { name in Task { await createCharacter(named: name) } }
      )
    }
    .alert(
      "STEP Needs Conversion",
      isPresented: Binding(
        get: { stepConversionMessage != nil },
        set: { if !$0 { stepConversionMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(stepConversionMessage ?? "Export this model as STL or USD from your CAD tool.")
    }
    .fileImporter(
      isPresented: $isImportingAnimaCharacter,
      allowedContentTypes: Self.animaCharacterContentTypes,
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          Task { @MainActor in
            await workspace.importAnimaCharacter(from: url)
            registerLoadedCharacter(markDirty: true)
          }
        }
      case .failure(let error):
        workspace.animaCoreErrorMessage = error.localizedDescription
      }
    }
    .alert(
      "Could Not Import Model",
      isPresented: Binding(
        get: { workspace.importErrorMessage != nil && workspace.activeWorkspace != .assets },
        set: { if !$0 { workspace.importErrorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(workspace.importErrorMessage ?? "Unknown model import error")
    }
    .alert(
      "AnimaCore Could Not Load the Character",
      isPresented: Binding(
        get: { workspace.animaCoreErrorMessage != nil },
        set: { if !$0 { workspace.animaCoreErrorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(workspace.animaCoreErrorMessage ?? "Unknown engine error")
    }
    .alert(
      "Project Could Not Be Saved",
      isPresented: Binding(
        get: { lifecycleErrorMessage != nil },
        set: { if !$0 { lifecycleErrorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(lifecycleErrorMessage ?? "Unknown project error")
    }
    .task {
      await workspace.connectToAnimaCore()
      await loadIndexedCharacterIfNeeded()
    }
    .task(id: workspace.isPlaying) {
      guard workspace.isPlaying else { return }
      let clock = ContinuousClock()
      while !Task.isCancelled && workspace.isPlaying {
        try? await clock.sleep(for: .milliseconds(16))
        workspace.advancePlayback(by: 1.0 / 60.0)
      }
    }
    .task(id: workspace.playheadSeconds) {
      await workspace.refreshAnimaCoreFrameAtPlayhead()
    }
    .onDisappear {
      Task { await workspace.shutdownAnimaCore() }
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
      case .assets, .rig, .nodes, .hardware:
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
    Group {
      if workspace.activeWorkspace == .assets {
        AssetsWorkspaceView(
          projectName: session.document.displayName,
          characters: session.document.characters,
          activeCharacterID: session.document.activeCharacter?.id,
          activePartCount: workspace.engineParts.count,
          showsLoadingStage: showsCharacterLoadingStage || workspace.engineParts.isEmpty,
          importProgress: characterImportProgress,
          importErrorMessage: characterImportErrorMessage,
          isSwitchingCharacter: isSwitchingCharacter,
          newCharacter: { showsNewCharacterSheet = true },
          selectCharacter: { character in
            Task { await selectCharacter(character) }
          },
          importModels: { isImportingModel = true },
          dropModels: beginModelImport
        )
      } else {
        viewportWorkspaceCanvas
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }

  private var viewportWorkspaceCanvas: some View {
    ZStack {
      if workspace.activeWorkspace == .nodes {
        NodeWorkspaceView()
      } else if workspace.activeWorkspace == .hardware {
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
          InspectorView(
            workspace: workspace,
            mapModelNode: { node in
              Task { await createRigidPart(from: node) }
            }
          )
          .frame(width: StudioMetrics.inspectorWidth)
        }
      }
      .padding(16)
    }
  }

  private var viewport: some View {
    ZStack(alignment: .top) {
      RobotPreviewView(
        rig: workspace.project.rig,
        engineResolvedPartPoses: workspace.engineResolvedPartPoses,
        partModelSources: workspace.enginePartModelSources,
        modelURL: workspace.importedModelURL,
        showsGrid: workspace.showsPreviewGrid,
        projection: workspace.cameraProjection,
        viewpoint: workspace.cameraViewpoint,
        cameraCommandRevision: workspace.cameraCommandRevision,
        cameraState: workspace.cameraState,
        navigationProfile: viewportNavigationProfile,
        customNavigationMapping: viewportCustomNavigationMapping,
        navigationSensitivity: viewportNavigationSensitivity,
        reversesWheelZoom: viewportReversesWheelZoom,
        focusedModelPath: workspace.selectedModelPath,
        focusedPartID: workspace.selectedPartID,
        highlightedPartIDs: workspace.viewportHighlightedPartIDs,
        selectionCount: workspace.selectionCount,
        partAppearances: workspace.viewportPartAppearances,
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
          viewportContextMenuRequest = nil
          workspace.selectModelNode(
            at: path,
            extendingSelection: true
          )
        },
        onSelectPartID: { id in
          viewportContextMenuRequest = nil
          workspace.selectPart(
            id: id,
            extendingSelection: true
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
        },
        onPointerTargetChange: { target in
          viewportPointerTarget = target
        },
        onContextMenuRequest: { location, target in
          viewportContextMenuRequest = ViewportContextMenuRequest(
            location: location,
            pointerTarget: target
          )
        },
        onFrameAll: workspace.showHomeView,
        onBoxSelectPartIDs: workspace.selectParts
      )
      .frame(minWidth: 520, minHeight: 420)

      viewportTitle
      cameraHUD

      if let engineEvaluationTimeSeconds = workspace.engineEvaluationTimeSeconds {
        engineFrameBadge(timeSeconds: engineEvaluationTimeSeconds)
      }

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

      if let viewportContextMenuRequest {
        ComponentViewportContextMenuOverlay(
          workspace: workspace,
          request: viewportContextMenuRequest,
          dismiss: { self.viewportContextMenuRequest = nil }
        )
      }
    }
    .sheet(isPresented: $showsMouseNavigationSettings) {
      MouseNavigationSettingsView(
        profile: viewportNavigationProfileBinding,
        customRotateDrag: viewportCustomRotateDragBinding,
        customPanDrag: viewportCustomPanDragBinding,
        customPreciseZoomDrag: viewportCustomPreciseZoomDragBinding,
        orbitSpeed: viewportOrbitSpeedBinding,
        panSpeed: viewportPanSpeedBinding,
        zoomSpeed: viewportZoomSpeedBinding,
        reversesWheelZoom: $viewportReversesWheelZoom
      )
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

  private func engineFrameBadge(timeSeconds: Double) -> some View {
    HStack(spacing: 7) {
      Image(systemName: "checkmark.seal.fill")
        .foregroundStyle(StudioPalette.hardware)
      Text("ANIMACORE FRAME")
        .font(.caption2.weight(.bold))
        .tracking(0.8)
      Text(timeSeconds, format: .number.precision(.fractionLength(3)))
        .font(.caption.monospacedDigit())
      Text("s")
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(.ultraThinMaterial, in: Capsule())
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .padding(.bottom, 16)
    .allowsHitTesting(false)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("AnimaCore evaluated frame")
    .accessibilityValue("\(timeSeconds) seconds")
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
        customPanDrag: viewportCustomPanDragBinding,
        customPreciseZoomDrag: viewportCustomPreciseZoomDragBinding,
        orbitSpeed: viewportOrbitSpeedBinding,
        panSpeed: viewportPanSpeedBinding,
        zoomSpeed: viewportZoomSpeedBinding,
        reversesWheelZoom: $viewportReversesWheelZoom,
        showMouseSettings: { showsMouseNavigationSettings = true }
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
    case .nodes:
      false
    case .rig:
      switch workspace.primarySelection {
      case .asset, .part, .componentGroup, .modelNode, .joint, .relation:
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
      panDrag: viewportCustomPanDrag,
      preciseZoomDrag: viewportCustomPreciseZoomDrag
    )
  }

  private var viewportCustomPreciseZoomDrag: NavigationDragBinding {
    NavigationDragBinding(rawValue: viewportCustomPreciseZoomDragRawValue) ?? .shiftMiddleMouse
  }

  private var viewportNavigationSensitivity: PreviewNavigationSensitivity {
    PreviewNavigationSensitivity(
      orbit: viewportOrbitSpeed,
      pan: viewportPanSpeed,
      zoom: viewportZoomSpeed
    )
  }

  private var viewportOrbitSpeed: PreviewNavigationSpeed {
    PreviewNavigationSpeed(rawValue: viewportOrbitSpeedRawValue) ?? .standard
  }

  private var viewportPanSpeed: PreviewNavigationSpeed {
    PreviewNavigationSpeed(rawValue: viewportPanSpeedRawValue) ?? .standard
  }

  private var viewportZoomSpeed: PreviewNavigationSpeed {
    PreviewNavigationSpeed(rawValue: viewportZoomSpeedRawValue) ?? .reduced
  }

  private var viewportOrbitSpeedBinding: Binding<PreviewNavigationSpeed> {
    Binding(
      get: { viewportOrbitSpeed },
      set: { viewportOrbitSpeedRawValue = $0.rawValue }
    )
  }

  private var viewportPanSpeedBinding: Binding<PreviewNavigationSpeed> {
    Binding(
      get: { viewportPanSpeed },
      set: { viewportPanSpeedRawValue = $0.rawValue }
    )
  }

  private var viewportZoomSpeedBinding: Binding<PreviewNavigationSpeed> {
    Binding(
      get: { viewportZoomSpeed },
      set: { viewportZoomSpeedRawValue = $0.rawValue }
    )
  }

  private var viewportCustomRotateDragBinding: Binding<NavigationDragBinding> {
    Binding(
      get: { viewportCustomRotateDrag },
      set: { newValue in
        let previousValue = viewportCustomRotateDrag
        if newValue == viewportCustomPanDrag {
          viewportCustomPanDragRawValue = previousValue.rawValue
        } else if newValue == viewportCustomPreciseZoomDrag {
          viewportCustomPreciseZoomDragRawValue = previousValue.rawValue
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
        } else if newValue == viewportCustomPreciseZoomDrag {
          viewportCustomPreciseZoomDragRawValue = previousValue.rawValue
        }
        viewportCustomPanDragRawValue = newValue.rawValue
      }
    )
  }

  private var viewportCustomPreciseZoomDragBinding: Binding<NavigationDragBinding> {
    Binding(
      get: { viewportCustomPreciseZoomDrag },
      set: { newValue in
        if newValue == viewportCustomRotateDrag {
          viewportCustomRotateDragRawValue = viewportCustomPreciseZoomDrag.rawValue
        } else if newValue == viewportCustomPanDrag {
          viewportCustomPanDragRawValue = viewportCustomPreciseZoomDrag.rawValue
        }
        viewportCustomPreciseZoomDragRawValue = newValue.rawValue
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
    "usd", "usda", "usdc", "usdz", "reality", "stl", "obj", "step", "stp",
  ].compactMap { UTType(filenameExtension: $0) }

  private static let animaCharacterContentTypes: [UTType] = [
    UTType(filenameExtension: "anima") ?? .data
  ]

  @MainActor
  private func loadIndexedCharacterIfNeeded() async {
    guard !didLoadIndexedCharacter, let character = session.document.activeCharacter else {
      return
    }
    didLoadIndexedCharacter = true
    _ = await loadCharacter(character, markDirty: false)
  }

  @MainActor
  @discardableResult
  private func loadCharacter(
    _ character: ProjectCharacterReference,
    markDirty: Bool
  ) async -> Bool {
    do {
      let projectURL = try session.resolvedProjectURL()
      let accessed = projectURL.startAccessingSecurityScopedResource()
      defer { if accessed { projectURL.stopAccessingSecurityScopedResource() } }
      await workspace.importAnimaCharacter(
        from: projectURL.appendingPathComponent(character.characterPath)
      )
      guard workspace.animaCoreErrorMessage == nil else { return false }
      let editorURL = projectURL.appendingPathComponent(character.editorPath)
      if let data = try? Data(contentsOf: editorURL),
        let metadata = try? CharacterEditorMetadata.decode(data)
      {
        characterEditorMetadata = metadata
      } else {
        characterEditorMetadata = CharacterEditorMetadata()
      }
      workspace.configurePartModelSources(
        characterDirectoryURL: projectURL.appendingPathComponent(
          character.directoryPath,
          isDirectory: true
        ),
        editorMetadata: characterEditorMetadata
      )
      workspace.project.name = session.document.displayName
      var updated = session
      updated.document.editorState.activeCharacterFolderName = character.folderName
      updated.document.project = workspace.project
      updated.document.project.name = session.document.displayName
      updated.isDirty = markDirty
      session = updated
      showsCharacterLoadingStage = workspace.engineParts.isEmpty
      return workspace.animaCoreErrorMessage == nil
    } catch {
      lifecycleErrorMessage = error.localizedDescription
      return false
    }
  }

  @MainActor
  private func registerLoadedCharacter(markDirty: Bool) {
    guard workspace.animaCoreErrorMessage == nil,
      let character = workspace.currentCharacterReference
    else { return }
    var updated = session
    let projectName = updated.document.displayName
    if let index = updated.document.characters.firstIndex(where: {
      $0.folderName == character.folderName
    }) {
      updated.document.characters[index] = character
    } else {
      updated.document.characters.append(character)
    }
    updated.document.editorState.activeCharacterFolderName = character.folderName
    updated.document.project = workspace.project
    updated.document.project.name = projectName
    workspace.project.name = projectName
    updated.isDirty = markDirty
    session = updated
  }

  @MainActor
  @discardableResult
  private func saveProject() async -> Bool {
    guard !isSavingProject else { return false }
    isSavingProject = true
    defer { isSavingProject = false }
    do {
      var updated = session
      updated.document.project.name = workspace.project.name
      let writes = try await projectFileWrites(updating: &updated.document)
      let projectURL = try updated.resolvedProjectURL()
      let accessed = projectURL.startAccessingSecurityScopedResource()
      defer { if accessed { projectURL.stopAccessingSecurityScopedResource() } }
      updated.document = try ProjectLifecycle.store.save(
        updated.document,
        to: projectURL,
        fileWrites: writes
      )
      updated.projectURL = projectURL
      updated.bookmarkData = ProjectLifecycle.bookmark(for: projectURL)
      updated.isDirty = false
      session = updated
      didPersistProject(updated)
      return true
    } catch {
      lifecycleErrorMessage = error.localizedDescription
      return false
    }
  }

  @MainActor
  private func saveProjectAs() async {
    guard !isSavingProject,
      let destinationURL = ProjectLifecycle.chooseSaveAsURL(
        currentName: session.document.displayName
      )
    else { return }
    isSavingProject = true
    defer { isSavingProject = false }
    do {
      var updated = session
      updated.document.project.name = destinationURL.lastPathComponent
      workspace.project.name = updated.document.project.name
      let writes = try await projectFileWrites(updating: &updated.document)
      let sourceURL = try updated.resolvedProjectURL()
      let accessedSource = sourceURL.startAccessingSecurityScopedResource()
      let accessedDestination = destinationURL.startAccessingSecurityScopedResource()
      defer {
        if accessedSource { sourceURL.stopAccessingSecurityScopedResource() }
        if accessedDestination { destinationURL.stopAccessingSecurityScopedResource() }
      }
      updated.document = try ProjectLifecycle.store.saveAs(
        updated.document,
        from: sourceURL,
        to: destinationURL,
        fileWrites: writes
      )
      updated.projectURL = destinationURL
      updated.bookmarkData = ProjectLifecycle.bookmark(for: destinationURL)
      updated.isDirty = false
      session = updated
      didPersistProject(updated)
    } catch {
      lifecycleErrorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func projectFileWrites(
    updating document: inout AnimaStudioDocument
  ) async throws -> [ProjectFileWrite] {
    guard workspace.hasSerializableCharacter else { return [] }
    guard let character = workspace.currentCharacterReference else {
      throw ProjectLifecycleError.noCharacterLoaded
    }
    if let index = document.characters.firstIndex(where: {
      $0.folderName == character.folderName
    }) {
      document.characters[index] = character
    } else {
      document.characters.append(character)
    }
    document.editorState.activeCharacterFolderName = character.folderName
    let canonicalText = try await workspace.serializedCharacterText()
    return [
      ProjectFileWrite(relativePath: character.characterPath, text: canonicalText),
      ProjectFileWrite(
        relativePath: character.editorPath,
        data: try characterEditorMetadata.encodedData()
      ),
    ]
  }

  @MainActor
  private func beginModelImport(from urls: [URL]) {
    guard !urls.isEmpty else { return }
    let stepFiles = urls.filter { ["step", "stp"].contains($0.pathExtension.lowercased()) }
    if !stepFiles.isEmpty {
      let filenames = stepFiles.map(\.lastPathComponent).joined(separator: ", ")
      let message =
        "STEP needs conversion. Export \(filenames) as STL or USD from SolidWorks, Onshape, Fusion 360, or your CAD tool, then import the converted files."
      if workspace.activeWorkspace == .assets {
        characterImportErrorMessage = message
      } else {
        stepConversionMessage = message
      }
      return
    }
    characterImportErrorMessage = nil
    pendingModelImportURLs = urls
  }

  @MainActor
  private func importModels(_ requests: [ModelImportRequest]) async {
    guard !requests.isEmpty else { return }
    guard session.document.activeCharacter != nil else {
      presentModelImportError("Create a 3D character before importing model parts.")
      return
    }
    characterImportErrorMessage = nil
    for (index, request) in requests.enumerated() {
      characterImportProgress = CharacterImportProgress(
        completedFiles: index,
        totalFiles: requests.count,
        currentFilename: request.url.lastPathComponent
      )
      let succeeded = await importModel(from: request.url, sourceUnit: request.unit)
      guard succeeded else {
        characterImportProgress = nil
        if session.isDirty { _ = await saveProject() }
        return
      }
    }
    characterImportProgress = CharacterImportProgress(
      completedFiles: requests.count,
      totalFiles: requests.count,
      currentFilename: "Finishing assembly"
    )
    let saved = await saveProject()
    characterImportProgress = nil
    guard saved else { return }
    showsCharacterLoadingStage = false
    workspace.activeWorkspace = .rig
  }

  @MainActor
  @discardableResult
  private func importModel(from sourceURL: URL, sourceUnit: ModelImportUnit) async -> Bool {
    guard let character = session.document.activeCharacter else {
      presentModelImportError("Create a 3D character before importing model parts.")
      return false
    }
    await workspace.importModel(
      from: sourceURL,
      unitScaleToMeters: sourceUnit.scaleToMeters
    )
    guard workspace.importErrorMessage == nil else {
      presentModelImportError(workspace.importErrorMessage ?? "The model could not be loaded.")
      return false
    }
    let importedHierarchy = workspace.importedModelHierarchy
    do {
      var updated = session
      let projectURL = try updated.resolvedProjectURL()
      let accessedProject = projectURL.startAccessingSecurityScopedResource()
      let accessedSource = sourceURL.startAccessingSecurityScopedResource()
      defer {
        if accessedProject { projectURL.stopAccessingSecurityScopedResource() }
        if accessedSource { sourceURL.stopAccessingSecurityScopedResource() }
      }
      updated.document = try ProjectLifecycle.store.embedAsset(
        from: sourceURL,
        into: projectURL,
        document: updated.document,
        characterFolderName: character.folderName,
        kind: "model3D"
      )
      if let asset = updated.document.assets.last,
        case .embedded(let relativePath) = asset.storage
      {
        let prefix = character.directoryPath + "/"
        guard relativePath.hasPrefix(prefix) else {
          throw AnimaDocumentError.pathTraversal(path: relativePath)
        }
        let modelReference = String(relativePath.dropFirst(prefix.count))
        let copiedURL = projectURL.appendingPathComponent(relativePath)
        characterEditorMetadata.modelImports[modelReference] = ModelImportMetadata(
          unitName: sourceUnit.rawValue,
          unitScaleToMeters: sourceUnit.scaleToMeters
        )
        _ = try await workspace.authorImportedModel(
          modelReference: modelReference,
          suggestedPartName: sourceURL.deletingPathExtension().lastPathComponent
        )
        let fileExtension = sourceURL.pathExtension.lowercased()
        let renderableNodes = importedHierarchy?.flattened.filter(\.hasRenderableGeometry) ?? []
        if ["usd", "usda", "usdc", "usdz", "reality"].contains(fileExtension),
          renderableNodes.count > 1
        {
          for node in renderableNodes {
            _ = try await workspace.authorImportedModel(
              modelReference: modelReference,
              modelNode: node.id.modelNodeReference,
              suggestedPartName: node.displayName
            )
          }
        }
        activeImportedModelReference = modelReference
        workspace.importedModelURL = copiedURL
        workspace.importedModelHierarchy = importedHierarchy
        workspace.configurePartModelSources(
          characterDirectoryURL: projectURL.appendingPathComponent(
            character.directoryPath,
            isDirectory: true
          ),
          editorMetadata: characterEditorMetadata
        )
      }
      workspace.project.name = updated.document.displayName
      updated.isDirty = true
      session = updated
      return true
    } catch {
      presentModelImportError(error.localizedDescription)
      return false
    }
  }

  @MainActor
  private func presentModelImportError(_ message: String) {
    workspace.importErrorMessage = nil
    if workspace.activeWorkspace == .assets {
      characterImportErrorMessage = message
    } else {
      workspace.importErrorMessage = message
    }
  }

  @MainActor
  private func createCharacter(named displayName: String) async {
    guard !isCreatingCharacter else { return }
    isCreatingCharacter = true
    defer { isCreatingCharacter = false }
    do {
      let reference = try ProjectCharacterNaming.reference(
        for: displayName,
        existingCharacters: session.document.characters
      )
      let canonicalText = try await workspace.serializedEmptyCharacterText(
        name: reference.folderName,
        displayName: reference.displayName
      )

      var updated = session
      var writes = try await projectFileWrites(updating: &updated.document)
      updated.document.characters.append(reference)
      updated.document.editorState.activeCharacterFolderName = reference.folderName
      let emptyEditorMetadata = CharacterEditorMetadata()
      writes.append(ProjectFileWrite(relativePath: reference.characterPath, text: canonicalText))
      writes.append(
        ProjectFileWrite(
          relativePath: reference.editorPath,
          data: try emptyEditorMetadata.encodedData()
        )
      )

      let projectURL = try updated.resolvedProjectURL()
      let accessed = projectURL.startAccessingSecurityScopedResource()
      defer { if accessed { projectURL.stopAccessingSecurityScopedResource() } }
      updated.document = try ProjectLifecycle.store.save(
        updated.document,
        to: projectURL,
        fileWrites: writes
      )
      try await workspace.loadSerializedCharacter(text: canonicalText)
      workspace.project.name = updated.document.displayName
      characterEditorMetadata = emptyEditorMetadata
      activeImportedModelReference = nil
      workspace.configurePartModelSources(
        characterDirectoryURL: projectURL.appendingPathComponent(
          reference.directoryPath,
          isDirectory: true
        ),
        editorMetadata: emptyEditorMetadata
      )
      updated.projectURL = projectURL
      updated.bookmarkData = ProjectLifecycle.bookmark(for: projectURL)
      updated.isDirty = false
      session = updated
      didPersistProject(updated)
      characterImportErrorMessage = nil
      showsCharacterLoadingStage = true
      showsNewCharacterSheet = false
    } catch {
      lifecycleErrorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func selectCharacter(_ character: ProjectCharacterReference) async {
    guard character.id != session.document.activeCharacter?.id else {
      showsCharacterLoadingStage = workspace.engineParts.isEmpty
      return
    }
    guard !isSwitchingCharacter else { return }
    isSwitchingCharacter = true
    defer { isSwitchingCharacter = false }
    if session.isDirty {
      guard await saveProject() else { return }
    }
    characterImportErrorMessage = nil
    _ = await loadCharacter(character, markDirty: true)
  }

  @MainActor
  private func createRigidPart(from node: ModelHierarchyNode) async {
    guard let character = session.document.activeCharacter,
      let modelReference = activeImportedModelReference
    else {
      workspace.importErrorMessage = "Import a model before mapping one of its nodes."
      return
    }
    let hierarchy = workspace.importedModelHierarchy
    let importedURL = workspace.importedModelURL
    do {
      _ = try await workspace.authorImportedModel(
        modelReference: modelReference,
        modelNode: node.id.modelNodeReference,
        suggestedPartName: node.displayName
      )
      workspace.importedModelHierarchy = hierarchy
      workspace.importedModelURL = importedURL
      let projectURL = try session.resolvedProjectURL()
      workspace.configurePartModelSources(
        characterDirectoryURL: projectURL.appendingPathComponent(
          character.directoryPath,
          isDirectory: true
        ),
        editorMetadata: characterEditorMetadata
      )
      workspace.project.name = session.document.displayName
      var updated = session
      updated.isDirty = true
      session = updated
    } catch {
      workspace.importErrorMessage = error.localizedDescription
    }
  }
}
