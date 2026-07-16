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
  @State private var isImportingAnimaCharacter = false
  @State private var isUIDevWorkspace = false
  @State private var uiDevSection = UIDevSection.templateMatrix
  @State private var showsUIDevAgentPanel = false
  @State private var viewportPointerTarget = ViewportPointerTarget.canvas
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
  @AppStorage("viewportOrbitSpeed") private var viewportOrbitSpeedRawValue =
    PreviewNavigationSpeed.standard.rawValue
  @AppStorage("viewportPanSpeed") private var viewportPanSpeedRawValue =
    PreviewNavigationSpeed.standard.rawValue
  @AppStorage("viewportZoomSpeed") private var viewportZoomSpeedRawValue =
    PreviewNavigationSpeed.reduced.rawValue
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
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          Task { @MainActor in
            await workspace.importModel(from: url)
            copyImportedModelIntoActiveCharacter(from: url)
          }
        }
      case .failure(let error):
        workspace.importErrorMessage = error.localizedDescription
      }
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
        get: { workspace.importErrorMessage != nil },
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
        rig: workspace.project.rig,
        engineResolvedPartPoses: workspace.engineResolvedPartPoses,
        modelURL: workspace.importedModelURL,
        showsGrid: workspace.showsPreviewGrid,
        projection: workspace.cameraProjection,
        viewpoint: workspace.cameraViewpoint,
        cameraCommandRevision: workspace.cameraCommandRevision,
        cameraState: workspace.cameraState,
        navigationProfile: viewportNavigationProfile,
        customNavigationMapping: viewportCustomNavigationMapping,
        navigationSensitivity: viewportNavigationSensitivity,
        focusedModelPath: workspace.selectedModelPath,
        focusedPartID: workspace.selectedPartID,
        highlightedPartIDs: workspace.viewportHighlightedPartIDs,
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
        },
        onPointerTargetChange: { target in
          viewportPointerTarget = target
        }
      )
      .frame(minWidth: 520, minHeight: 420)
      .componentViewportContextMenu(
        workspace: workspace,
        pointerTarget: viewportPointerTarget
      )

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
        orbitSpeed: viewportOrbitSpeedBinding,
        panSpeed: viewportPanSpeedBinding,
        zoomSpeed: viewportZoomSpeedBinding
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
      panDrag: viewportCustomPanDrag
    )
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

  private static let animaCharacterContentTypes: [UTType] = [
    UTType(filenameExtension: "anima") ?? .data
  ]

  @MainActor
  private func loadIndexedCharacterIfNeeded() async {
    guard !didLoadIndexedCharacter, let character = session.document.activeCharacter else {
      return
    }
    didLoadIndexedCharacter = true
    do {
      let projectURL = try session.resolvedProjectURL()
      let accessed = projectURL.startAccessingSecurityScopedResource()
      defer { if accessed { projectURL.stopAccessingSecurityScopedResource() } }
      await workspace.importAnimaCharacter(
        from: projectURL.appendingPathComponent(character.characterPath)
      )
      workspace.project.name = session.document.displayName
      registerLoadedCharacter(markDirty: false)
    } catch {
      lifecycleErrorMessage = error.localizedDescription
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
  private func saveProject() async {
    guard !isSavingProject else { return }
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
    } catch {
      lifecycleErrorMessage = error.localizedDescription
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
    let editorText = "{\n  \"format_version\" : \"1\"\n}\n"
    return [
      ProjectFileWrite(relativePath: character.characterPath, text: canonicalText),
      ProjectFileWrite(relativePath: character.editorPath, text: editorText),
    ]
  }

  @MainActor
  private func copyImportedModelIntoActiveCharacter(from sourceURL: URL) {
    guard workspace.importErrorMessage == nil,
      let character = session.document.activeCharacter
    else { return }
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
        workspace.importedModelURL = projectURL.appendingPathComponent(relativePath)
      }
      updated.isDirty = true
      session = updated
    } catch {
      workspace.importErrorMessage = error.localizedDescription
    }
  }
}
