import AnimaDocument
import AnimaEvaluation
import AnimaModel
import AppKit
import RealityKitViewport
import SwiftUI

struct StudioWorkspaceView: View {
  @Environment(\.openSettings) private var openSettings
  @Binding var session: StudioProjectSession
  let closeProject: () -> Void
  let newProject: () -> Void
  let openProject: () -> Void
  let didPersistProject: (StudioProjectSession) -> Void
  @Binding var designProfile: StudioDesignProfile

  @State private var workspace: StudioWorkspaceModel
  @State private var replacesSelectedPartOnNextImport = false
  @State private var pendingModelImportURLs: [URL] = []
  @State private var showsNewCharacterSheet = false
  @State private var isCreatingCharacter = false
  @State private var showsCharacterLoadingStage = false
  @State private var characterImportProgress: CharacterImportProgress?
  @State private var characterImportErrorMessage: String?
  @State private var isSwitchingCharacter = false
  @State private var characterEditorMetadata = CharacterEditorMetadata()
  @State private var characterLibraryEntries: [CharacterLibraryEntry] = []
  @State private var activeImportedModelReference: String?
  @State private var isUIDevWorkspace = false
  @State private var uiDevSection = UIDevSection.templateMatrix
  @State private var showsUIDevAgentPanel = false
  @State private var showsWorkspaceGuide = false
  @State private var viewportPointerTarget = ViewportPointerTarget.canvas
  @State private var viewportContextMenuRequest: ViewportContextMenuRequest?
  @State private var lifecycleErrorMessage: String?
  @State private var isSavingProject = false
  @State private var didLoadIndexedCharacter = false
  @State private var armIKSolveTask: Task<Void, Never>?
  @AppStorage(StudioPreferenceKey.viewportAppearance) private var viewportAppearanceRawValue =
    PreviewAppearance.midnight.rawValue
  @AppStorage(StudioPreferenceKey.defaultLayoutPreset) private var defaultLayoutPresetRawValue =
    StudioLayoutPreset.floating.rawValue
  @AppStorage(StudioPreferenceKey.viewportNavigationProfile)
  private var viewportNavigationProfileRawValue =
    PreviewNavigationProfile.default.rawValue
  @AppStorage(StudioPreferenceKey.viewportCustomRotateDrag)
  private var viewportCustomRotateDragRawValue =
    NavigationDragBinding.rightMouse.rawValue
  @AppStorage(StudioPreferenceKey.viewportCustomPanDrag) private var viewportCustomPanDragRawValue =
    NavigationDragBinding.middleMouse.rawValue
  @AppStorage(StudioPreferenceKey.viewportCustomPreciseZoomDrag)
  private var viewportCustomPreciseZoomDragRawValue =
    NavigationDragBinding.shiftMiddleMouse.rawValue
  @AppStorage(StudioPreferenceKey.viewportOrbitSpeed) private var viewportOrbitSpeedRawValue =
    PreviewNavigationSpeed.standard.rawValue
  @AppStorage(StudioPreferenceKey.viewportPanSpeed) private var viewportPanSpeedRawValue =
    PreviewNavigationSpeed.standard.rawValue
  @AppStorage(StudioPreferenceKey.viewportZoomSpeed) private var viewportZoomSpeedRawValue =
    PreviewNavigationSpeed.reduced.rawValue
  @AppStorage(StudioPreferenceKey.viewportReversesWheelZoom)
  private var viewportReversesWheelZoom = false
  @AppStorage(StudioPreferenceKey.viewportRenderStyle) private var viewportRenderStyleRawValue =
    ViewportRenderStyle.shaded.rawValue
  @AppStorage(StudioPreferenceKey.viewportEdgeDisplay) private var viewportEdgeDisplayRawValue =
    ViewportEdgeDisplay.mesh.rawValue
  @AppStorage(StudioPreferenceKey.viewportLightingPreset)
  private var viewportLightingPresetRawValue =
    ViewportLightingPreset.balanced.rawValue
  @AppStorage(StudioPreferenceKey.viewportMaterialFinish)
  private var viewportMaterialFinishRawValue =
    ViewportMaterialFinish.satin.rawValue
  @AppStorage(StudioPreferenceKey.viewportReflectionMode)
  private var viewportReflectionModeRawValue =
    ViewportReflectionMode.subtle.rawValue
  @AppStorage(StudioPreferenceKey.viewportShowsShadows) private var viewportShowsShadows = true
  @AppStorage(StudioPreferenceKey.viewportFieldOfViewDegrees)
  private var viewportFieldOfViewDegrees = 60.0
  @AppStorage(StudioPreferenceKey.viewportLightingIntensity)
  private var viewportLightingIntensity = 1.0
  @AppStorage(StudioPreferenceKey.viewportEnvironmentPreset)
  private var viewportEnvironmentPresetRawValue = ViewportEnvironmentPreset.softbox.rawValue
  @AppStorage(StudioPreferenceKey.viewportEnvironmentRotationDegrees)
  private var viewportEnvironmentRotationDegrees = 0.0
  @AppStorage(StudioPreferenceKey.viewportRenderQuality)
  private var viewportRenderQualityRawValue = ViewportRenderQuality.standard.rawValue

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
        isUIDevWorkspace: $isUIDevWorkspace,
        showsWorkspaceGuide: $showsWorkspaceGuide,
        isSaving: isSavingProject,
        isDirty: session.isDirty,
        newProject: newProject,
        openProject: openProject,
        saveProject: { Task { await saveProject() } },
        saveProjectAs: { Task { await saveProjectAs() } },
        closeProject: closeProject
      )

      workspaceShell

      StudioStatusBar(
        workspace: workspace,
        isUIDevWorkspace: isUIDevWorkspace
      )
    }
    .overlay(alignment: .bottom) {
      if showsWorkspaceGuide {
        WorkspaceGuideCard(
          workspace: workspace,
          isUIDevWorkspace: $isUIDevWorkspace,
          dismiss: { showsWorkspaceGuide = false }
        )
        .frame(maxWidth: 760)
        .padding(.horizontal, 20)
        .padding(.bottom, workspace.floatingRibbonEdge == .bottom ? 102 : 34)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(50)
      }
    }
    .background(StudioPalette.canvas)
    .preferredColorScheme(.dark)
    .animation(.spring(response: 0.30, dampingFraction: 0.90), value: workspace.ribbonPlacement)
    .animation(.spring(response: 0.30, dampingFraction: 0.90), value: showsWorkspaceGuide)
    .onExitCommand {
      if StudioToolState.shared.isArmed {
        StudioToolState.shared.disarm()
      } else if workspace.matePlacement != nil {
        workspace.cancelMatePlacement()
      } else {
        workspace.clearSelection()
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
          characters: session.document.characters,
          initialTargetCharacterID: session.document.activeCharacter?.id,
          isReplacingPart: replacesSelectedPartOnNextImport,
          cancel: {
            pendingModelImportURLs.removeAll()
            replacesSelectedPartOnNextImport = false
          },
          importModels: { plan in
            pendingModelImportURLs.removeAll()
            Task { await importModels(plan) }
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
      workspace.applyLayoutPreset(
        StudioLayoutPreset(rawValue: defaultLayoutPresetRawValue) ?? .floating
      )
      await workspace.connectToAnimaCore()
      await loadIndexedCharacterIfNeeded()
      if AssetBuilderFeatureAvailability.showsLibraries {
        refreshCharacterLibrary()
      }
    }
    .onChange(of: workspace.detectedLayoutPreset) { _, preset in
      if let preset {
        defaultLayoutPresetRawValue = preset.rawValue
      }
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
    .onChange(of: workspace.documentEditRevision) { _, _ in
      characterEditorMetadata = workspace.characterEditorMetadata(
        applyingTo: characterEditorMetadata
      )
      var updated = session
      updated.isDirty = true
      session = updated
    }
    .onDisappear {
      armIKSolveTask?.cancel()
      Task { await workspace.shutdownAnimaCore() }
    }
  }

  /// Coalesces high-frequency gizmo updates before they enter the sequential
  /// bridge actor. The target moves immediately; AnimaCore still owns every
  /// solved arm pose.
  private func queueArmIKSolve(for pose: EngineResolvedPartPose) {
    workspace.armIKTargetPose = pose
    armIKSolveTask?.cancel()
    armIKSolveTask = Task {
      try? await Task.sleep(for: .milliseconds(35))
      guard !Task.isCancelled else { return }
      await workspace.solveArmIK(target: pose)
    }
  }

  /// Every authored workspace enters through this one frame. The center owns
  /// the document surface; the left sidebar only changes the working set, and
  /// the right sidebar only changes presentation or inspects the selection.
  private var workspaceShell: some View {
    StudioWorkspaceScaffold(
      workspaceKind: workspace.activeWorkspace,
      toolGroups: workspaceToolGroups,
      toolCategories: workspaceToolCategories,
      leftTabs: StudioWorkspaceSidebarCatalog.tabs(for: workspace.activeWorkspace),
      leftPanels: workspace.activeWorkspaceSidebarPanels,
      didToggleLeftPanel: { tab in
        if workspace.activeWorkspaceSidebarPanels.isEnabled(tab) {
          selectWorkspaceSidebarTab(tab)
        }
      },
      performCommand: performWorkspaceRibbonAction,
      center: {
        VStack(spacing: 0) {
          workspaceCanvas
          bottomEditor
        }
      },
      left: { tab in
        workspaceSidebarContent(tab: tab)
      },
      right: { tab in
        StudioViewSidebarPanel(
          tab: tab,
          viewport: StudioViewportSidebarBindings(
            renderStyle: viewportRenderStyleBinding,
            edgeDisplay: viewportEdgeDisplayBinding,
            showsGrid: Binding(
              get: { workspace.showsPreviewGrid },
              set: { workspace.showsPreviewGrid = $0 }
            ),
            showsShadows: $viewportShowsShadows,
            lightingIntensity: $viewportLightingIntensity,
            appearance: viewportAppearanceBinding
          )
        ) {
          workspaceInspectorContent
        }
      }
    )
  }

  private var workspaceToolGroups: [StudioToolGroup] {
    guard !isUIDevWorkspace, workspace.activeWorkspace != .rig else { return [] }
    return StudioWorkspaceToolCatalog.groups(for: workspace.activeWorkspace)
  }

  private var workspaceToolCategories: [StudioToolCategory] {
    guard !isUIDevWorkspace else { return [] }
    if workspace.activeWorkspace == .rig {
      return StudioWorkspaceToolCatalog.rigCategories(workspace: workspace)
    }
    return StudioWorkspaceToolCatalog.categories(for: workspace.activeWorkspace)
  }

  @ViewBuilder
  private func workspaceSidebarContent(tab: String) -> some View {
    if isUIDevWorkspace {
      ProjectNavigatorView(
        workspace: workspace,
        importModel: presentModelImportPanel
      )
    } else if workspace.activeWorkspace == .assets {
      assetsWorkspaceView(surface: .workspaceSidebar)
    } else {
      ProjectNavigatorView(
        workspace: workspace,
        importModel: presentModelImportPanel
      )
    }
  }

  @ViewBuilder
  private var workspaceInspectorContent: some View {
    if isUIDevWorkspace {
      StudioAgentPanelView { showsUIDevAgentPanel = false }
    } else if workspace.activeWorkspace == .assets {
      assetsWorkspaceView(surface: .viewInspector)
    } else {
      InspectorView(
        workspace: workspace,
        mapModelNode: { node in
          Task { await createRigidPart(from: node) }
        }
      )
    }
  }

  private func selectWorkspaceSidebarTab(_ tab: String) {
    workspace.activeWorkspaceSidebarSelection = tab
    guard workspace.activeWorkspace == .assets else { return }
    switch tab {
    case "Characters":
      workspace.assetBuilderSelection = .characters
    case "Collections":
      if let characterID = session.document.activeCharacter?.id {
        workspace.assetBuilderSelection = .characterCollection(
          characterID: characterID,
          collection: .parts
        )
      }
    default:
      break
    }
  }

  private func performWorkspaceRibbonAction(_ action: WorkspaceRibbonAction) {
    WorkspaceRibbonActionDispatcher.perform(
      action,
      workspace: workspace,
      importModel: presentModelImportPanel,
      importAnimaCharacter: presentAnimaCharacterImportPanel
    )
  }

  /// Applies the currently armed model tool. Camera navigation always disarms
  /// this state before it can reach the center surface.
  private func commitArmedTool() {
    let toolState = StudioToolState.shared
    guard let tool = toolState.armedTool,
      case .arm(let payload) = tool.behavior
    else { return }

    switch payload {
    case .addPart(let kind):
      workspace.addPart(kind: kind)
      toolState.committed()
    case .createRevoluteMate:
      workspace.beginRevoluteMatePlacement()
      toolState.committed()
    case .createRelation(let kindID):
      if let relation = workspace.engineRelationTypes.first(where: {
        $0.kind.rawValue == kindID
      }) {
        workspace.beginRelationDraft(relation)
        toolState.committed()
      }
    }
  }

  @ViewBuilder
  private var bottomEditor: some View {
    if !isUIDevWorkspace && workspace.activePresentation.showsBottomEditor {
      switch workspace.activeWorkspace {
      case .animate:
        TimelineWorkspaceSurface {
          TimelineEditorView(workspace: workspace)
            .frame(minHeight: 260, idealHeight: 340, maxHeight: 440)
        }
      case .show:
        TimelineWorkspaceSurface {
          ShowTimelineView(workspace: workspace)
            .frame(minHeight: 210, idealHeight: 250, maxHeight: 320)
        }
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
        assetsWorkspaceView(surface: .center)
      } else {
        viewportCenterContent
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }

  private func assetsWorkspaceView(surface: AssetsWorkspaceSurface) -> some View {
    AssetsWorkspaceView(
      workspace: workspace,
      surface: surface,
      projectName: session.document.displayName,
      projectRevision: session.document.metadata.revision,
      characters: session.document.characters,
      characterLibrary: characterLibraryEntries,
      projectScenes: session.document.scenes,
      projectAssets: session.document.assets,
      partAssetVersions: characterEditorMetadata.partAssetVersions,
      activeCharacterID: session.document.activeCharacter?.id,
      importProgress: characterImportProgress,
      importErrorMessage: characterImportErrorMessage,
      isSwitchingCharacter: isSwitchingCharacter,
      newCharacter: { showsNewCharacterSheet = true },
      publishActiveCharacter: {
        Task { await publishActiveCharacterToLibrary() }
      },
      addLibraryCharacter: { entry in
        Task { await addLibraryCharacterToProject(entry) }
      },
      selectCharacter: { character in
        Task { await selectCharacter(character) }
      },
      importModels: presentModelImportPanel,
      replaceModel: {
        presentModelImportPanel(replacingSelectedPart: true)
      },
      deleteParts: { ids in
        Task { await deleteParts(ids) }
      },
      dropModels: beginModelImport
    )
  }

  @ViewBuilder
  private var viewportCenterContent: some View {
    if workspace.activeWorkspace == .nodes {
      NodeWorkspaceView()
    } else if workspace.activeWorkspace == .hardware {
      HardwareWorkspaceView()
    } else {
      viewport
    }
  }

  private var showsFloatingNavigator: Bool {
    StudioLayoutState.shared.detectedPreset == .floating
      && workspace.isActiveWorkspaceSidebarOpen
  }

  private var showsFloatingInspector: Bool {
    StudioLayoutState.shared.detectedPreset == .floating
      && StudioViewSidebarState.shared.isOpen
  }

  private var viewport: some View {
    ZStack(alignment: .top) {
      RobotPreviewView(
        rig: workspace.project.rig,
        engineResolvedPartPoses: workspace.engineResolvedPartPoses,
        partModelSources: workspace.enginePartModelSources,
        modelURL: workspace.importedModelURL,
        showsGrid: shellShowsGrid,
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
        focusedPartIsLocked: workspace.selectedPartID.map {
          workspace.isComponentLocked($0) || !workspace.isPartRestTransformEditable($0)
        } ?? false,
        mateCandidatePartIDs: workspace.mateCandidatePartIDs,
        selectedMateCandidate: workspace.matePlacement?.sourceCandidate,
        armIKTargetPose: workspace.activeWorkspace == .rig
          ? workspace.armIKTargetPose : nil,
        armIKTargetIsUnreachable: {
          if case .unreachable = workspace.armIKReachState { return true }
          return false
        }(),
        importedHierarchyRootPath: workspace.importedModelHierarchy?.id,
        rigGuideVisibility: workspace.activeWorkspace == .rig
          ? workspace.rigGuideVisibility : .hidden,
        appearance: workspace.viewportBackground.palette,
        renderStyle: shellRenderStyle,
        edgeDisplay: shellEdgeDisplay,
        lightingPreset: viewportLightingPreset,
        materialFinish: viewportMaterialFinish,
        reflectionMode: viewportReflectionMode,
        lightingIntensity: shellLightingIntensity,
        environmentPreset: viewportEnvironmentPreset,
        environmentRotationDegrees: Float(viewportEnvironmentRotationDegrees),
        renderQuality: viewportRenderQuality,
        backgroundSettings: workspace.viewportBackground,
        sectionPlane: workspace.viewportSectionPlane,
        showsShadows: shellShowsShadows,
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
        onSetArmIKTargetPose: { pose in
          queueArmIKSolve(for: pose)
        },
        onSetSectionPosition: { positionMeters in
          var section = workspace.viewportSectionPlane
          section.positionMeters = positionMeters
          workspace.setViewportSectionPlane(section)
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
        onBackgroundClick: { _ in commitArmedTool() },
        onFrameAll: workspace.showHomeView,
        onBoxSelectPartIDs: workspace.selectParts
      )
      .frame(minWidth: 520, minHeight: 420)

      viewportTitle
      cameraHUD
      visualizationControl

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
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
          showsFloatingNavigator
            ? StudioMetrics.navigatorWidth + 32 : 18
        )
        .padding(.trailing, showsFloatingInspector ? StudioMetrics.inspectorWidth + 32 : 18)
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
        lightingIntensity: $viewportLightingIntensity,
        environmentPreset: viewportEnvironmentPresetBinding,
        environmentRotationDegrees: $viewportEnvironmentRotationDegrees,
        renderQuality: viewportRenderQualityBinding,
        navigationProfile: viewportNavigationProfileBinding,
        customRotateDrag: viewportCustomRotateDragBinding,
        customPanDrag: viewportCustomPanDragBinding,
        customPreciseZoomDrag: viewportCustomPreciseZoomDragBinding,
        orbitSpeed: viewportOrbitSpeedBinding,
        panSpeed: viewportPanSpeedBinding,
        zoomSpeed: viewportZoomSpeedBinding,
        reversesWheelZoom: $viewportReversesWheelZoom,
        showMouseSettings: {
          UserDefaults.standard.set(
            StudioSettingsTab.navigation.rawValue,
            forKey: StudioPreferenceKey.settingsSelectedTab
          )
          openSettings()
        }
      )
      .padding(.trailing, showsFloatingInspector ? StudioMetrics.inspectorWidth + 32 : 16)
    }
    .padding(.top, 10)
  }

  private var visualizationControl: some View {
    ViewportVisualizationControl(
      workspace: workspace,
      lightingIntensity: $viewportLightingIntensity,
      environmentPreset: viewportEnvironmentPresetBinding,
      environmentRotationDegrees: $viewportEnvironmentRotationDegrees
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    .padding(
      .leading,
      showsFloatingNavigator ? StudioMetrics.navigatorWidth + 30 : 16
    )
    .padding(.bottom, 16)
  }

  private var showsInspector: Bool {
    guard workspace.activePresentation.showsInspector else { return false }
    return hasInspectorContent
  }

  private var hasInspectorContent: Bool {
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
      get: { workspace.viewportBackground.preset },
      set: { value in
        viewportAppearanceRawValue = value.rawValue
        var settings = workspace.viewportBackground
        settings.mode = .preset
        settings.preset = value
        workspace.setViewportBackground(settings)
      }
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

  private var shellRenderStyle: ViewportRenderStyle {
    viewportRenderStyle
  }

  private var shellEdgeDisplay: ViewportEdgeDisplay {
    viewportEdgeDisplay
  }

  private var shellShowsGrid: Bool {
    workspace.showsPreviewGrid
  }

  private var shellShowsShadows: Bool {
    viewportShowsShadows
  }

  private var shellLightingIntensity: Float {
    Float(viewportLightingIntensity)
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

  private var viewportEnvironmentPreset: ViewportEnvironmentPreset {
    ViewportEnvironmentPreset(rawValue: viewportEnvironmentPresetRawValue) ?? .softbox
  }

  private var viewportEnvironmentPresetBinding: Binding<ViewportEnvironmentPreset> {
    Binding(
      get: { viewportEnvironmentPreset },
      set: { viewportEnvironmentPresetRawValue = $0.rawValue }
    )
  }

  private var viewportRenderQuality: ViewportRenderQuality {
    ViewportRenderQuality(rawValue: viewportRenderQualityRawValue) ?? .standard
  }

  private var viewportRenderQualityBinding: Binding<ViewportRenderQuality> {
    Binding(
      get: { viewportRenderQuality },
      set: { viewportRenderQualityRawValue = $0.rawValue }
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
      // Hold access for the whole time the project is open — the sandboxed app
      // reads imported meshes lazily during async rendering, long after this
      // load returns, so a defer-scoped access would be gone by then and the
      // viewport would fall back to placeholders.
      workspace.retainProjectAssetAccess(projectURL)
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
      workspace.applyCharacterEditorMetadata(characterEditorMetadata)
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
      let engineReference = workspace.currentCharacterReference
    else { return }
    var updated = session
    let character = preservingIndexedCharacterMetadata(
      for: engineReference,
      in: updated.document
    )
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
    guard let engineReference = workspace.currentCharacterReference else {
      throw ProjectLifecycleError.noCharacterLoaded
    }
    let character = preservingIndexedCharacterMetadata(for: engineReference, in: document)
    if let index = document.characters.firstIndex(where: {
      $0.folderName == character.folderName
    }) {
      document.characters[index] = character
    } else {
      document.characters.append(character)
    }
    document.editorState.activeCharacterFolderName = character.folderName
    let canonicalText = try await workspace.serializedCharacterText()
    characterEditorMetadata = workspace.characterEditorMetadata(
      applyingTo: characterEditorMetadata
    )
    return [
      ProjectFileWrite(relativePath: character.characterPath, text: canonicalText),
      ProjectFileWrite(
        relativePath: character.editorPath,
        data: try characterEditorMetadata.encodedData()
      ),
    ]
  }

  private func preservingIndexedCharacterMetadata(
    for engineReference: ProjectCharacterReference,
    in document: AnimaStudioDocument
  ) -> ProjectCharacterReference {
    guard
      var indexed = document.characters.first(where: {
        $0.folderName == engineReference.folderName
      })
    else { return engineReference }
    indexed.displayName = engineReference.displayName
    return indexed
  }

  @MainActor
  private func refreshCharacterLibrary() {
    let root = characterLibraryRootURL
    characterLibraryEntries = (try? CharacterLibraryStore().list(in: root)) ?? []
  }

  private var characterLibraryRootURL: URL {
    WorkspaceLocationPreference().workspaceRootURL.appendingPathComponent(
      CharacterLibraryStore.directoryName,
      isDirectory: true
    )
  }

  @MainActor
  private func publishActiveCharacterToLibrary() async {
    guard await saveProject(), let activeCharacter = session.document.activeCharacter else {
      return
    }
    do {
      let workspaceRoot = try WorkspaceLocationPreference().ensureWorkspaceRootExists()
      let libraryRoot = workspaceRoot.appendingPathComponent(
        CharacterLibraryStore.directoryName,
        isDirectory: true
      )
      let projectURL = try session.resolvedProjectURL()
      let accessedProject = projectURL.startAccessingSecurityScopedResource()
      let accessedLibrary = libraryRoot.startAccessingSecurityScopedResource()
      defer {
        if accessedProject { projectURL.stopAccessingSecurityScopedResource() }
        if accessedLibrary { libraryRoot.stopAccessingSecurityScopedResource() }
      }
      let publication = try CharacterLibraryStore().publish(
        activeCharacter,
        from: projectURL,
        to: libraryRoot
      )
      var updated = session
      guard
        let index = updated.document.characters.firstIndex(where: {
          $0.id == activeCharacter.id
        })
      else { return }
      updated.document.characters[index] = publication.projectReference
      updated.document = try ProjectLifecycle.store.save(updated.document, to: projectURL)
      updated.bookmarkData = ProjectLifecycle.bookmark(for: projectURL)
      updated.isDirty = false
      session = updated
      characterLibraryEntries = try CharacterLibraryStore().list(in: libraryRoot)
      didPersistProject(updated)
    } catch {
      lifecycleErrorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func addLibraryCharacterToProject(_ entry: CharacterLibraryEntry) async {
    if session.isDirty, !(await saveProject()) { return }
    do {
      let projectURL = try session.resolvedProjectURL()
      let libraryRoot = characterLibraryRootURL
      let accessedProject = projectURL.startAccessingSecurityScopedResource()
      let accessedLibrary = libraryRoot.startAccessingSecurityScopedResource()
      defer {
        if accessedProject { projectURL.stopAccessingSecurityScopedResource() }
        if accessedLibrary { libraryRoot.stopAccessingSecurityScopedResource() }
      }
      let reference = try CharacterLibraryStore().install(
        entry,
        from: libraryRoot,
        into: projectURL,
        existingCharacters: session.document.characters
      )
      var updated = session
      updated.document.characters.append(reference)
      updated.document.editorState.activeCharacterFolderName = reference.folderName
      updated.document = try ProjectLifecycle.store.save(updated.document, to: projectURL)
      updated.bookmarkData = ProjectLifecycle.bookmark(for: projectURL)
      updated.isDirty = false
      session = updated
      didPersistProject(updated)
      _ = await loadCharacter(reference, markDirty: false)
      showsCharacterLoadingStage = workspace.engineParts.isEmpty
    } catch {
      lifecycleErrorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func presentModelImportPanel() {
    presentModelImportPanel(replacingSelectedPart: false)
  }

  @MainActor
  private func presentModelImportPanel(replacingSelectedPart: Bool) {
    guard session.document.activeCharacter != nil else {
      presentModelImportError("Create or select a 3D character before importing model parts.")
      return
    }
    replacesSelectedPartOnNextImport = replacingSelectedPart
    guard
      let urls = NativeImportPanel.chooseFiles(configuration: .models),
      !urls.isEmpty
    else {
      replacesSelectedPartOnNextImport = false
      return
    }
    beginModelImport(from: urls)
  }

  @MainActor
  private func presentAnimaCharacterImportPanel() {
    guard
      let url = NativeImportPanel.chooseFiles(configuration: .animaCharacter)?.first
    else { return }
    Task { @MainActor in
      await workspace.importAnimaCharacter(from: url)
      registerLoadedCharacter(markDirty: true)
    }
  }

  @MainActor
  private func beginModelImport(from urls: [URL]) {
    guard !urls.isEmpty else { return }
    if replacesSelectedPartOnNextImport && urls.count != 1 {
      replacesSelectedPartOnNextImport = false
      presentModelImportError("Replace Part accepts one model file at a time.")
      return
    }
    let unsupportedFiles = urls.filter { !ModelImportFormatSupport.supports($0) }
    if !unsupportedFiles.isEmpty {
      replacesSelectedPartOnNextImport = false
      let filenames = unsupportedFiles.map(\.lastPathComponent).joined(separator: ", ")
      let message =
        "Unsupported model file: \(filenames). Import \(ModelImportFormatSupport.operatorLabel) files only."
      if workspace.activeWorkspace == .assets {
        characterImportErrorMessage = message
      } else {
        presentModelImportError(message)
      }
      return
    }
    characterImportErrorMessage = nil
    pendingModelImportURLs = urls
  }

  @MainActor
  private func importModels(_ plan: ModelImportStagingPlan) async {
    let requests = plan.requests
    guard !requests.isEmpty else { return }
    let replacesSelectedPart = replacesSelectedPartOnNextImport
    replacesSelectedPartOnNextImport = false
    guard
      let targetCharacter = session.document.characters.first(where: {
        $0.id == plan.targetCharacterID
      })
    else {
      presentModelImportError("The selected destination character is no longer in this project.")
      return
    }
    if targetCharacter.id != session.document.activeCharacter?.id {
      await selectCharacter(targetCharacter)
      guard session.document.activeCharacter?.id == targetCharacter.id else {
        presentModelImportError("The destination character could not be opened for import.")
        return
      }
    }
    characterImportErrorMessage = nil
    for (index, request) in requests.enumerated() {
      characterImportProgress = CharacterImportProgress(
        completedFiles: index,
        totalFiles: requests.count,
        currentFilename: request.url.lastPathComponent
      )
      let succeeded = await importModel(
        from: request.url,
        sourceUnit: request.unit,
        replacingSelectedPart: replacesSelectedPart && index == 0
      )
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
    workspace.activeWorkspace = .assets
  }

  @MainActor
  @discardableResult
  private func importModel(
    from sourceURL: URL,
    sourceUnit: ModelImportUnit,
    replacingSelectedPart: Bool = false
  ) async -> Bool {
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
      if !replacingSelectedPart,
        let replacement = AssetBuilderImportMatching.automaticReplacement(
          sourceFilename: sourceURL.lastPathComponent,
          character: character,
          assets: updated.document.assets,
          parts: workspace.engineParts
        )
      {
        try ProjectLifecycle.store.replaceEmbeddedAsset(
          replacement.asset,
          from: sourceURL,
          in: projectURL
        )
        characterEditorMetadata.modelImports[replacement.modelReference] = ModelImportMetadata(
          unitName: sourceUnit.rawValue,
          unitScaleToMeters: sourceUnit.scaleToMeters
        )
        var versionedPartNames = Set<String>()
        for partName in replacement.partNames {
          recordAssetVersion(
            for: partName,
            replacesExisting: true,
            versionedPartNames: &versionedPartNames
          )
        }
        activeImportedModelReference = replacement.modelReference
        workspace.importedModelURL = projectURL.appendingPathComponent(replacement.relativePath)
        workspace.importedModelHierarchy = importedHierarchy
        workspace.retainProjectAssetAccess(projectURL)
        workspace.configurePartModelSources(
          characterDirectoryURL: projectURL.appendingPathComponent(
            character.directoryPath,
            isDirectory: true
          ),
          editorMetadata: characterEditorMetadata
        )
        workspace.selectParts(
          ids: Set(replacement.partNames.compactMap(workspace.partID(forEngineName:)))
        )
        updated.isDirty = true
        session = updated
        return true
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
        let partNamesBeforeImport = Set(workspace.engineParts.map(\.name))
        var versionedPartNames = Set<String>()
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
        let primaryPartName = try await workspace.authorImportedModel(
          modelReference: modelReference,
          suggestedPartName: sourceURL.deletingPathExtension().lastPathComponent,
          replacingSelectedPart: replacingSelectedPart
        )
        recordAssetVersion(
          for: primaryPartName,
          replacesExisting: partNamesBeforeImport.contains(primaryPartName),
          versionedPartNames: &versionedPartNames
        )
        let fileExtension = sourceURL.pathExtension.lowercased()
        let renderableNodes = importedHierarchy?.flattened.filter(\.hasRenderableGeometry) ?? []
        if !replacingSelectedPart,
          ["usd", "usda", "usdc", "usdz"].contains(fileExtension),
          renderableNodes.count > 1
        {
          for node in renderableNodes {
            let partName = try await workspace.authorImportedModel(
              modelReference: modelReference,
              modelNode: node.id.modelNodeReference,
              suggestedPartName: node.displayName
            )
            recordAssetVersion(
              for: partName,
              replacesExisting: partNamesBeforeImport.contains(partName),
              versionedPartNames: &versionedPartNames
            )
          }
        }
        activeImportedModelReference = modelReference
        workspace.importedModelURL = copiedURL
        workspace.importedModelHierarchy = importedHierarchy
        workspace.retainProjectAssetAccess(projectURL)
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

  private func recordAssetVersion(
    for partName: String,
    replacesExisting: Bool,
    versionedPartNames: inout Set<String>
  ) {
    guard versionedPartNames.insert(partName).inserted else { return }
    let current = max(characterEditorMetadata.partAssetVersions[partName] ?? 1, 1)
    characterEditorMetadata.partAssetVersions[partName] = replacesExisting ? current + 1 : current
  }

  @MainActor
  private func deleteParts(_ partIDs: Set<PartID>) async {
    guard !partIDs.isEmpty, let character = session.document.activeCharacter else { return }
    let locked = partIDs.filter(workspace.isComponentLocked)
    guard locked.isEmpty else {
      characterImportErrorMessage = "Unlock the selected parts before deleting them."
      return
    }
    let partNames = Set(partIDs.compactMap(workspace.enginePartName(for:)))
    guard !partNames.isEmpty else { return }
    let removedModelReferences = Set(
      workspace.engineParts.compactMap { part in
        partNames.contains(part.name) && !part.model.isEmpty ? part.model : nil
      }
    )
    do {
      try await workspace.deleteEngineParts(named: partNames)
      characterEditorMetadata.partAssetVersions = characterEditorMetadata.partAssetVersions.filter {
        !partNames.contains($0.key)
      }
      characterEditorMetadata.partAppearances = characterEditorMetadata.partAppearances.filter {
        !partNames.contains($0.key)
      }
      let remainingModelReferences = Set(workspace.engineParts.map(\.model).filter { !$0.isEmpty })
      let orphanedModelReferences = removedModelReferences.subtracting(remainingModelReferences)
      for reference in orphanedModelReferences {
        characterEditorMetadata.modelImports.removeValue(forKey: reference)
      }
      workspace.applyCharacterEditorMetadata(characterEditorMetadata)

      var updated = session
      let prefix = character.directoryPath + "/"
      let orphanedRelativePaths = Set(orphanedModelReferences.map { prefix + $0 })
      updated.document.assets.removeAll { asset in
        guard case .embedded(let path) = asset.storage else { return false }
        return orphanedRelativePaths.contains(path)
      }
      updated.isDirty = true
      session = updated
      let projectURL = try updated.resolvedProjectURL()
      workspace.retainProjectAssetAccess(projectURL)
      workspace.configurePartModelSources(
        characterDirectoryURL: projectURL.appendingPathComponent(
          character.directoryPath,
          isDirectory: true
        ),
        editorMetadata: characterEditorMetadata
      )
      guard await saveProject() else { return }
      let accessedProject = projectURL.startAccessingSecurityScopedResource()
      defer { if accessedProject { projectURL.stopAccessingSecurityScopedResource() } }
      for path in orphanedRelativePaths {
        let url = projectURL.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: url.path) {
          try FileManager.default.removeItem(at: url)
        }
      }
      showsCharacterLoadingStage = workspace.engineParts.isEmpty
      characterImportErrorMessage = nil
    } catch {
      characterImportErrorMessage = error.localizedDescription
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
      workspace.retainProjectAssetAccess(projectURL)
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
      workspace.retainProjectAssetAccess(projectURL)
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
