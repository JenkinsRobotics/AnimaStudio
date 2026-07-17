import AnimaCoreClient
import AnimaDocument
import AnimaEvaluation
import AnimaModel
import Foundation
import Observation
import RealityKitViewport

enum NavigatorItem: Hashable {
  case project
  case asset(AssetID)
  case part(PartID)
  case componentGroup(UUID)
  case structure
  case modelNode(ModelEntityPath)
  case joint(JointID)
  case relation(String)
  case animation(String)
}

enum ArmIKReachState: Equatable, Sendable {
  case idle
  case solving
  case reached(iterations: Int)
  case unreachable(positionErrorMeters: Double, orientationErrorRadians: Double)
  case failed(String)
}

@MainActor
@Observable
final class StudioWorkspaceModel {
  enum AnimaCoreState: Equatable, Sendable {
    case unavailable
    case connecting
    case ready(engineVersion: String)
    case loaded(characterName: String, engineVersion: String)
    case failed
  }

  var activeWorkspace: StudioWorkspaceKind
  var workspacePresentations = Dictionary(
    uniqueKeysWithValues: StudioWorkspaceKind.allCases.map {
      ($0, $0.descriptor.defaultPresentation)
    }
  )
  var project = AnimaProject(
    name: "Untitled Character",
    rig: CharacterRig(joints: []),
    clips: []
  )
  var selection: Set<NavigatorItem> = [] {
    didSet {
      revealInspectorForInspectableSelection()
      requestNavigatorRevealForPrimarySelection()
    }
  }
  var playheadSeconds = 0.0
  var isPlaying = false
  var loopsPreviewPlayback = true
  var timelineEditorMode: TimelineEditorMode = .dopeSheet
  var timelineDisplayFramesPerSecond = 30
  var timelineZoom = 1.0
  var showsPreviewGrid = true
  var cameraProjection: PreviewCameraProjection = .perspective
  var cameraViewpoint: PreviewCameraViewpoint = .home
  var cameraState = PreviewCameraState()
  var cameraCommandRevision = 0
  var previousCameraState: PreviewCameraState?
  var previousCameraProjection: PreviewCameraProjection?
  var namedCameraViews: [PreviewNamedView] = []
  var viewportBackground = ViewportBackgroundSettings()
  var viewportSectionPlane = ViewportSectionPlane()
  var rigGuideVisibility = RigGuideVisibility()
  var showsCreationPalette = true
  var importedModelURL: URL?
  var importedModelHierarchy: ModelHierarchyNode?
  var isLoadingModelHierarchy = false
  var importErrorMessage: String?
  var animaCoreErrorMessage: String?
  var animaCoreState: AnimaCoreState = .unavailable
  var engineEvaluationTimeSeconds: Double?
  var engineResolvedPartPoses: [PartID: EngineResolvedPartPose] = [:]
  var enginePartModelSources: [PartID: PartModelSource] = [:]
  var engineParts: [AnimaCorePartSummary] = []
  var engineMateTypes: [AnimaCoreMateTypeSummary] = []
  var engineMates: [AnimaCoreJointSummary] = []
  var engineRelationTypes: [AnimaCoreRelationTypeSummary] = []
  var engineRelations: [AnimaCoreRelationSummary] = []
  var engineKinematicChain: AnimaCoreKinematicChainSummary?
  var armJointValues: [String: Double] = [:]
  var armToolPose: EngineResolvedPartPose?
  var armIKTargetPose: EngineResolvedPartPose?
  var armIKReachState: ArmIKReachState = .idle
  var relationDraft: RelationDraft?
  var componentGroups: [NavigatorComponentGroup] = []
  var lockedComponentIDs: Set<PartID> = []
  var lockedMateIDs: Set<JointID> = []
  var componentAppearances: [PartID: PreviewPartAppearance] = [:]
  var navigatorExpandedNodeKeys: Set<String> = []
  var navigatorRevealItem: NavigatorItem?
  var navigatorRevealRevision = 0
  var documentEditRevision = 0
  var isolatedComponentID: PartID?
  var transparentComponentIDs: Set<PartID> = []
  var componentInspectorTab = ComponentInspectorTab.properties
  var matePlacement: MatePlacementSession?
  private var storedSelectedFeature: MateConnectorCandidate?
  @ObservationIgnored private let animaCoreClient: (any AnimaCoreServing)?
  @ObservationIgnored private var animaCoreHandle: String?
  @ObservationIgnored private var engineRigDocument: AnimaCoreJSONValue?
  @ObservationIgnored private var engineRigIdentity: AnimaCoreRigIdentity?
  @ObservationIgnored private var animaCoreEngineVersion: String?
  @ObservationIgnored private var engineEvaluation: AnimaCoreEvaluation?
  @ObservationIgnored private var enginePartIDsByName: [String: PartID] = [:]
  @ObservationIgnored private var engineClipName: String?
  @ObservationIgnored private var engineFrameRequestRevision = 0
  @ObservationIgnored private var armRequestRevision = 0
  @ObservationIgnored private var manualCameraHistoryOrigin:
    (state: PreviewCameraState, projection: PreviewCameraProjection)?
  @ObservationIgnored private var manualCameraHistoryTask: Task<Void, Never>?

  private let evaluator = AnimationEvaluator()

  init(
    project: AnimaProject = AnimaProject(
      name: "Untitled Character",
      rig: CharacterRig(joints: []),
      clips: []
    ),
    startupWorkspace: StudioWorkspaceKind = .assets,
    animaCoreClient: (any AnimaCoreServing)? = nil,
    resolvesDefaultAnimaCoreClient: Bool = true
  ) {
    self.project = project
    self.activeWorkspace = startupWorkspace
    self.animaCoreClient =
      animaCoreClient
      ?? (resolvesDefaultAnimaCoreClient ? (try? AnimaCoreClient()) : nil)
  }

  var activeClip: AnimationClip {
    project.clips.first ?? SampleContent.emptyClip
  }

  var evaluatedFrame: EvaluatedFrame {
    if let engineEvaluation, let engineEvaluationTimeSeconds {
      return EvaluatedFrame(
        timeSeconds: engineEvaluationTimeSeconds,
        jointAnglesRadians: Dictionary(
          uniqueKeysWithValues: engineEvaluation.degreesOfFreedom.map { path, value in
            (JointID(rawValue: path), value)
          }
        )
      )
    }
    return evaluator.evaluate(
      clip: activeClip,
      rig: project.rig,
      atSeconds: playheadSeconds
    )
  }

  var primarySelection: NavigatorItem? {
    selection.count == 1 ? selection.first : nil
  }

  var selectionCount: Int {
    selection.count
  }

  var selectedComponentIDs: [PartID] {
    project.rig.parts.compactMap { part in
      selection.contains(.part(part.id)) ? part.id : nil
    }
  }

  var selectedUnlockedComponentIDs: [PartID] {
    selectedComponentIDs.filter { !isComponentLocked($0) }
  }

  var activePresentation: WorkspacePresentation {
    workspacePresentations[activeWorkspace] ?? activeWorkspace.descriptor.defaultPresentation
  }

  var selectedModelPath: ModelEntityPath? {
    guard case .modelNode(let path) = primarySelection else { return nil }
    return path
  }

  var selectedPartID: PartID? {
    guard case .part(let id) = primarySelection else { return nil }
    return id
  }

  var selectedEngineMate: AnimaCoreJointSummary? {
    guard case .joint(let selectedID) = primarySelection else { return nil }
    return engineMates.first { $0.selectionKey == selectedID.rawValue }
  }

  var selectedEngineRelation: AnimaCoreRelationSummary? {
    guard case .relation(let selectedID) = primarySelection else { return nil }
    return engineRelations.first { $0.id == selectedID }
  }

  func engineMateType(for mate: AnimaCoreJointSummary) -> AnimaCoreMateTypeSummary? {
    engineMateTypes.first { $0.type == mate.type }
  }

  func engineRelationType(
    for relation: AnimaCoreRelationSummary
  ) -> AnimaCoreRelationTypeSummary? {
    engineRelationTypes.first { $0.kind == relation.kind }
  }

  var viewportHighlightedPartIDs: Set<PartID> {
    var highlighted = Set(selectedComponentIDs)
    guard let relation = selectedEngineRelation else { return highlighted }
    for path in [relation.driver, relation.driven] {
      guard let mateName = Self.mateName(fromDOFPath: path),
        let mate = engineMates.first(where: { $0.name == mateName }),
        let childPart = mate.childPart,
        let partID = enginePartIDsByName[childPart]
      else { continue }
      highlighted.insert(partID)
    }
    return highlighted
  }

  /// The standing sub-object (face/edge/corner/axis/origin) selection made
  /// in the viewport. Valid only while its owning component remains the
  /// focused component and no mate placement is running, so it can never
  /// dangle after navigator or placement interactions.
  var selectedFeature: MateConnectorCandidate? {
    guard matePlacement == nil,
      let feature = storedSelectedFeature,
      selectedPartID == feature.partID
    else { return nil }
    return feature
  }

  var canFrameSelection: Bool {
    switch primarySelection {
    case .modelNode, .part, .structure, .joint:
      true
    case .project, .asset, .componentGroup, .relation, .animation, nil:
      false
    }
  }

  var isRigEmpty: Bool {
    project.rig.parts.isEmpty && project.rig.joints.isEmpty && engineMates.isEmpty
  }

  var animaCoreStatusLabel: String {
    switch animaCoreState {
    case .unavailable: "Engine unavailable"
    case .connecting: "Connecting to engine…"
    case .ready(let version): "AnimaCore \(version)"
    case .loaded(let characterName, _): "Engine · \(characterName)"
    case .failed: "Engine error"
    }
  }

  var isAnimaCoreReady: Bool {
    switch animaCoreState {
    case .ready, .loaded: true
    case .unavailable, .connecting, .failed: false
    }
  }

  var hasSerializableCharacter: Bool {
    engineRigDocument != nil
  }

  var currentCharacterReference: ProjectCharacterReference? {
    guard let identity = engineRigIdentity else { return nil }
    let folderName = Self.safeProjectComponent(identity.name)
    return ProjectCharacterReference(
      folderName: folderName,
      displayName: identity.displayName
    )
  }

  func serializedCharacterText() async throws -> String {
    guard let animaCoreClient, let engineRigDocument else {
      throw ProjectLifecycleError.noCharacterLoaded
    }
    return try await animaCoreClient.serializeCharacter(rig: engineRigDocument).text
  }

  func serializedEmptyCharacterText(name: String, displayName: String) async throws -> String {
    guard let animaCoreClient else { throw AnimaCoreClientError.helperNotFound }
    let document = AnimaCoreRigDocumentEditor.emptyCharacter(
      name: name,
      displayName: displayName
    )
    return try await animaCoreClient.serializeCharacter(rig: document).text
  }

  func loadSerializedCharacter(text: String) async throws {
    try await loadAnimaCharacter(text: text)
  }

  func connectToAnimaCore() async {
    guard let animaCoreClient else {
      animaCoreState = .unavailable
      return
    }
    guard !isAnimaCoreReady else { return }
    animaCoreState = .connecting
    do {
      let hello = try await animaCoreClient.start()
      let mateCatalog = try await animaCoreClient.mateTypes()
      let relationCatalog = try await animaCoreClient.relationTypes()
      animaCoreEngineVersion = hello.engineVersion
      engineMateTypes = mateCatalog.mateTypes
      engineRelationTypes = relationCatalog.relationTypes
      animaCoreState = .ready(engineVersion: hello.engineVersion)
    } catch {
      animaCoreState = .failed
      animaCoreErrorMessage = error.localizedDescription
    }
  }

  func importAnimaCharacter(from url: URL) async {
    guard animaCoreClient != nil else {
      animaCoreState = .unavailable
      animaCoreErrorMessage = AnimaCoreClientError.helperNotFound.localizedDescription
      return
    }
    guard url.isFileURL else {
      animaCoreErrorMessage = "The selected character is not a local file."
      return
    }

    let accessedSecurityScope = url.startAccessingSecurityScopedResource()
    defer {
      if accessedSecurityScope {
        url.stopAccessingSecurityScopedResource()
      }
    }

    animaCoreState = .connecting
    animaCoreErrorMessage = nil
    do {
      let text = try String(contentsOf: url, encoding: .utf8)
      try await loadAnimaCharacter(text: text)
    } catch {
      animaCoreState = .failed
      animaCoreErrorMessage = error.localizedDescription
    }
  }

  private func loadAnimaCharacter(text: String) async throws {
    guard let animaCoreClient else {
      throw AnimaCoreClientError.helperNotFound
    }
    var pendingHandle: String?
    do {
      let hello = try await animaCoreClient.start()
      let mateCatalog = try await animaCoreClient.mateTypes()
      let relationCatalog = try await animaCoreClient.relationTypes()
      let loaded = try await animaCoreClient.loadCharacter(text: text)
      pendingHandle = loaded.handle
      let clip = loaded.rig.clips.first
      let evaluationTimeSeconds = min(clip?.durationSeconds ?? 0, 1)
      let evaluation = try await animaCoreClient.evaluate(
        handle: loaded.handle,
        clip: clip?.name,
        timeSeconds: evaluationTimeSeconds
      )
      let resolvedPose = try await animaCoreClient.resolvePose(
        handle: loaded.handle,
        clip: clip?.name,
        timeSeconds: evaluationTimeSeconds
      )
      let armJointValues = Self.armJointValues(
        chain: loaded.rig.kinematicChain,
        evaluation: evaluation
      )
      let armForwardResult: AnimaCoreForwardKinematicsResult? =
        if loaded.rig.kinematicChain != nil {
          try await animaCoreClient.forwardKinematics(
            handle: loaded.handle,
            jointValues: armJointValues
          )
        } else {
          nil
        }
      let preview = Self.previewProject(for: loaded.rig)

      if let previousHandle = animaCoreHandle {
        try? await animaCoreClient.release(handle: previousHandle)
      }
      animaCoreHandle = loaded.handle
      engineRigDocument = loaded.rigDocument
      engineRigIdentity = loaded.rig.identity
      pendingHandle = nil
      animaCoreEngineVersion = hello.engineVersion
      engineMateTypes = mateCatalog.mateTypes
      engineParts = loaded.rig.parts
      engineMates = loaded.rig.joints
      engineRelationTypes = relationCatalog.relationTypes
      engineRelations = loaded.rig.relations
      engineKinematicChain = loaded.rig.kinematicChain
      self.armJointValues = armJointValues
      engineEvaluation = evaluation
      engineEvaluationTimeSeconds = evaluationTimeSeconds
      enginePartIDsByName = preview.partIDsByEngineName
      engineClipName = clip?.name
      engineResolvedPartPoses = Self.previewPoses(
        from: resolvedPose,
        partIDsByEngineName: preview.partIDsByEngineName
      )
      if let chain = loaded.rig.kinematicChain, let armForwardResult {
        applyArmForwardResult(armForwardResult, chain: chain)
      } else {
        armToolPose = nil
        armIKTargetPose = nil
      }
      armIKReachState = .idle
      project = preview.project
      playheadSeconds = evaluationTimeSeconds
      isPlaying = false
      selection.removeAll()
      componentGroups.removeAll()
      lockedComponentIDs.removeAll()
      lockedMateIDs.removeAll()
      relationDraft = nil
      componentAppearances.removeAll()
      enginePartModelSources.removeAll()
      importedModelURL = nil
      importedModelHierarchy = nil
      cameraViewpoint = .home
      cameraCommandRevision += 1
      animaCoreState = .loaded(
        characterName: loaded.rig.identity.displayName,
        engineVersion: hello.engineVersion
      )
    } catch {
      if let pendingHandle {
        try? await animaCoreClient.release(handle: pendingHandle)
      }
      throw error
    }
  }

  /// Adds or assigns one renderer asset in the full-fidelity engine DTO, then
  /// asks AnimaCore to serialize, validate, and reload the result. Swift never
  /// writes `.anima` text or accepts an unvalidated part edit.
  @discardableResult
  func authorImportedModel(
    modelReference: String,
    modelNode: String? = nil,
    suggestedPartName: String,
    replacingSelectedPart: Bool = false
  ) async throws -> String {
    guard let animaCoreClient, let engineRigDocument else {
      throw ProjectLifecycleError.noCharacterLoaded
    }
    let selectedEnginePartName = selectedPartID.flatMap { selectedPartID in
      enginePartIDsByName.first(where: { $0.value == selectedPartID })?.key
    }.flatMap { selectedName in
      engineParts.first(where: { part in
        guard part.name == selectedName else { return false }
        if replacingSelectedPart { return true }
        if part.model.isEmpty { return true }
        return modelNode != nil && part.model == modelReference && part.modelNode == nil
      })?.name
    }
    let edited: AnimaCoreJSONValue
    let partName: String
    if let selectedEnginePartName {
      edited = try AnimaCoreRigDocumentEditor.assigningModel(
        modelReference,
        modelNode: modelNode,
        toPartNamed: selectedEnginePartName,
        in: engineRigDocument
      )
      partName = selectedEnginePartName
    } else {
      let addition = try AnimaCoreRigDocumentEditor.addingPart(
        suggestedName: suggestedPartName,
        model: modelReference,
        modelNode: modelNode,
        to: engineRigDocument
      )
      edited = addition.document
      partName = addition.partName
    }
    let text = try await animaCoreClient.serializeCharacter(rig: edited).text
    try await loadAnimaCharacter(text: text)
    if let partID = enginePartIDsByName[partName] {
      selection = [.part(partID)]
    }
    return partName
  }

  func configurePartModelSources(
    characterDirectoryURL: URL,
    editorMetadata: CharacterEditorMetadata
  ) {
    enginePartModelSources = Dictionary(
      uniqueKeysWithValues: engineParts.compactMap { part in
        guard !part.model.isEmpty, let partID = enginePartIDsByName[part.name] else { return nil }
        let metadata = editorMetadata.modelImports[part.model]
        return (
          partID,
          PartModelSource(
            partID: partID,
            fileURL: characterDirectoryURL.appendingPathComponent(part.model),
            modelNode: part.modelNode,
            unitScaleToMeters: metadata?.unitScaleToMeters ?? 1
          )
        )
      }
    )
  }

  func enginePart(for id: PartID) -> AnimaCorePartSummary? {
    guard let name = enginePartName(for: id) else { return nil }
    return engineParts.first { $0.name == name }
  }

  func enginePartName(for id: PartID) -> String? {
    enginePartIDsByName.first { $0.value == id }?.key
  }

  func partID(forEngineName name: String) -> PartID? {
    enginePartIDsByName[name]
  }

  func requestNavigatorReveal(_ item: NavigatorItem) {
    navigatorRevealItem = item
    navigatorRevealRevision += 1
  }

  func setNavigatorExpandedNodeKeys(_ keys: Set<String>) {
    guard keys != navigatorExpandedNodeKeys else { return }
    navigatorExpandedNodeKeys = keys
    documentEditRevision += 1
  }

  func applyCharacterEditorMetadata(_ metadata: CharacterEditorMetadata) {
    let orderedNames = metadata.tree.partOrder
    if !orderedNames.isEmpty {
      let rank = Dictionary(uniqueKeysWithValues: orderedNames.enumerated().map { ($1, $0) })
      project.rig.parts.sort {
        let lhsName = enginePartName(for: $0.id) ?? $0.displayName
        let rhsName = enginePartName(for: $1.id) ?? $1.displayName
        return (rank[lhsName] ?? Int.max) < (rank[rhsName] ?? Int.max)
      }
    }

    let mateRank = Dictionary(
      uniqueKeysWithValues: metadata.tree.mateOrder.enumerated().map { ($1, $0) }
    )
    if !mateRank.isEmpty {
      engineMates.sort {
        (mateRank[$0.selectionKey] ?? Int.max) < (mateRank[$1.selectionKey] ?? Int.max)
      }
    }

    lockedComponentIDs = Set(
      metadata.tree.lockedPartNames.compactMap { enginePartIDsByName[$0] }
    )
    lockedMateIDs = Set(metadata.tree.lockedMateIDs.map(JointID.init(rawValue:)))
    componentGroups = metadata.tree.groups.map { group in
      NavigatorComponentGroup(
        id: group.id,
        displayName: group.displayName,
        componentIDs: group.partNames.compactMap { enginePartIDsByName[$0] },
        isLocked: group.isLocked
      )
    }.filter { !$0.componentIDs.isEmpty }
    navigatorExpandedNodeKeys = Set(metadata.tree.expandedNodeKeys)
    componentAppearances = Dictionary(
      uniqueKeysWithValues: metadata.partAppearances.compactMap { name, value in
        guard let partID = enginePartIDsByName[name] else { return nil }
        return (
          partID,
          PreviewPartAppearance(
            red: value.red,
            green: value.green,
            blue: value.blue,
            opacity: value.opacity,
            isVisible: value.isVisible,
            finish: ViewportMaterialFinish(rawValue: value.finish) ?? .satin,
            proxyFilletRadiusMeters: value.proxyFilletRadiusMeters
          )
        )
      }
    )
    let viewport = metadata.viewport
    viewportBackground = ViewportBackgroundSettings(
      mode: ViewportBackgroundMode(rawValue: viewport.backgroundMode) ?? .preset,
      preset: PreviewAppearance(rawValue: viewport.appearancePreset) ?? .midnight,
      primary: ViewportColor(
        red: viewport.primaryColor.red,
        green: viewport.primaryColor.green,
        blue: viewport.primaryColor.blue
      ),
      secondary: ViewportColor(
        red: viewport.secondaryColor.red,
        green: viewport.secondaryColor.green,
        blue: viewport.secondaryColor.blue
      )
    )
    viewportSectionPlane = ViewportSectionPlane(
      isEnabled: viewport.sectionEnabled,
      axis: ViewportSectionAxis(rawValue: viewport.sectionAxis) ?? .x,
      positionMeters: viewport.sectionPositionMeters
    )
    namedCameraViews = viewport.namedViews.compactMap(Self.namedView(from:))
  }

  func characterEditorMetadata(applyingTo metadata: CharacterEditorMetadata)
    -> CharacterEditorMetadata
  {
    var updated = metadata
    updated.formatVersion = CharacterEditorMetadata.currentFormatVersion
    updated.partAppearances = Dictionary(
      uniqueKeysWithValues: componentAppearances.compactMap { partID, appearance in
        guard let name = enginePartName(for: partID) else { return nil }
        return (
          name,
          CharacterPartAppearanceMetadata(
            red: appearance.red,
            green: appearance.green,
            blue: appearance.blue,
            opacity: appearance.opacity,
            isVisible: appearance.isVisible,
            finish: appearance.finish.rawValue,
            proxyFilletRadiusMeters: appearance.proxyFilletRadiusMeters
          )
        )
      }
    )
    updated.tree = CharacterTreeMetadata(
      groups: componentGroups.map { group in
        CharacterTreeGroupMetadata(
          id: group.id,
          displayName: group.displayName,
          partNames: group.componentIDs.compactMap(enginePartName(for:)),
          isLocked: group.isLocked
        )
      },
      lockedPartNames: lockedComponentIDs.compactMap(enginePartName(for:)).sorted(),
      lockedMateIDs: lockedMateIDs.map(\.rawValue).sorted(),
      expandedNodeKeys: navigatorExpandedNodeKeys.sorted(),
      partOrder: project.rig.parts.compactMap { enginePartName(for: $0.id) },
      mateOrder: engineMates.map(\.selectionKey)
    )
    updated.viewport = CharacterViewportMetadata(
      backgroundMode: viewportBackground.mode.rawValue,
      appearancePreset: viewportBackground.preset.rawValue,
      primaryColor: .init(
        red: viewportBackground.primary.red,
        green: viewportBackground.primary.green,
        blue: viewportBackground.primary.blue
      ),
      secondaryColor: .init(
        red: viewportBackground.secondary.red,
        green: viewportBackground.secondary.green,
        blue: viewportBackground.secondary.blue
      ),
      sectionEnabled: viewportSectionPlane.isEnabled,
      sectionAxis: viewportSectionPlane.axis.rawValue,
      sectionPositionMeters: viewportSectionPlane.positionMeters,
      namedViews: namedCameraViews.map(Self.namedViewMetadata(from:))
    )
    return updated
  }

  private static func namedView(from value: CharacterNamedViewMetadata) -> PreviewNamedView? {
    guard value.direction.count == 3, value.target.count == 3 else { return nil }
    return PreviewNamedView(
      id: value.id,
      name: value.name,
      state: PreviewCameraState(
        orientation: PreviewCameraOrientation(
          direction: PreviewCameraDirection(
            x: Float(value.direction[0]), y: Float(value.direction[1]),
            z: Float(value.direction[2])
          ),
          rollRadians: Float(value.rollRadians)
        ),
        target: PreviewCameraPoint(
          x: Float(value.target[0]), y: Float(value.target[1]), z: Float(value.target[2])
        ),
        distance: Float(value.distance),
        orthographicScale: Float(value.orthographicScale)
      ),
      projection: PreviewCameraProjection(rawValue: value.projection) ?? .perspective
    )
  }

  private static func namedViewMetadata(from value: PreviewNamedView) -> CharacterNamedViewMetadata
  {
    CharacterNamedViewMetadata(
      id: value.id,
      name: value.name,
      projection: value.projection.rawValue,
      direction: [
        Double(value.state.orientation.direction.x),
        Double(value.state.orientation.direction.y),
        Double(value.state.orientation.direction.z),
      ],
      rollRadians: Double(value.state.orientation.rollRadians),
      target: [
        Double(value.state.target.x), Double(value.state.target.y), Double(value.state.target.z),
      ],
      distance: Double(value.state.distance),
      orthographicScale: Double(value.state.orthographicScale)
    )
  }

  func shutdownAnimaCore() async {
    guard let animaCoreClient else { return }
    if let animaCoreHandle {
      try? await animaCoreClient.release(handle: animaCoreHandle)
    }
    await animaCoreClient.shutdown()
    self.animaCoreHandle = nil
    engineRigDocument = nil
    engineRigIdentity = nil
    animaCoreEngineVersion = nil
    engineEvaluation = nil
    engineEvaluationTimeSeconds = nil
    engineResolvedPartPoses.removeAll()
    enginePartModelSources.removeAll()
    engineParts.removeAll()
    enginePartIDsByName.removeAll()
    engineClipName = nil
    engineFrameRequestRevision += 1
    engineMateTypes.removeAll()
    engineMates.removeAll()
    engineRelationTypes.removeAll()
    engineRelations.removeAll()
    engineKinematicChain = nil
    armJointValues.removeAll()
    armToolPose = nil
    armIKTargetPose = nil
    armIKReachState = .idle
    armRequestRevision += 1
    relationDraft = nil
    animaCoreState = .unavailable
  }

  private static func safeProjectComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let scalars = value.lowercased().unicodeScalars.map { scalar in
      allowed.contains(scalar) ? Character(String(scalar)) : "-"
    }
    let collapsed = String(scalars)
      .split(separator: "-", omittingEmptySubsequences: true)
      .joined(separator: "-")
    return collapsed.isEmpty ? "character" : collapsed
  }

  func beginRelationDraft(_ type: AnimaCoreRelationTypeSummary) {
    relationDraft = RelationDraft(type: type)
  }

  func dismissRelationDraft() {
    relationDraft = nil
  }

  func relationDOFOptions(kind: AnimaCoreDOFKind) -> [RelationDOFOption] {
    engineMates.flatMap { mate in
      mate.degreesOfFreedom.compactMap { degreeOfFreedom in
        guard degreeOfFreedom.kind == kind else { return nil }
        return RelationDOFOption(
          path: degreeOfFreedom.path,
          mateName: mate.name,
          mateTrackingID: mate.id,
          kind: degreeOfFreedom.kind
        )
      }
    }
  }

  /// Refreshes both the inspector/output frame and the renderer transform from
  /// one canonical AnimaCore playhead evaluation. Superseded requests may
  /// finish in the actor queue but never overwrite a newer playhead state.
  func refreshAnimaCoreFrameAtPlayhead() async {
    guard let animaCoreClient, let handle = animaCoreHandle else { return }
    engineFrameRequestRevision += 1
    let revision = engineFrameRequestRevision
    let requestedTimeSeconds = playheadSeconds
    do {
      let evaluation = try await animaCoreClient.evaluate(
        handle: handle,
        clip: engineClipName,
        timeSeconds: requestedTimeSeconds
      )
      let resolvedPose = try await animaCoreClient.resolvePose(
        handle: handle,
        clip: engineClipName,
        timeSeconds: requestedTimeSeconds
      )
      let updatedArmJointValues = Self.armJointValues(
        chain: engineKinematicChain,
        evaluation: evaluation
      )
      let armForwardResult: AnimaCoreForwardKinematicsResult? =
        if engineKinematicChain != nil {
          try await animaCoreClient.forwardKinematics(
            handle: handle,
            jointValues: updatedArmJointValues
          )
        } else {
          nil
        }
      guard revision == engineFrameRequestRevision,
        handle == animaCoreHandle,
        abs(requestedTimeSeconds - playheadSeconds) < 0.000_001
      else { return }
      engineEvaluation = evaluation
      engineEvaluationTimeSeconds = requestedTimeSeconds
      engineResolvedPartPoses = Self.previewPoses(
        from: resolvedPose,
        partIDsByEngineName: enginePartIDsByName
      )
      armJointValues = updatedArmJointValues
      if let chain = engineKinematicChain, let armForwardResult {
        applyArmForwardResult(armForwardResult, chain: chain)
      }
    } catch is CancellationError {
      return
    } catch {
      guard revision == engineFrameRequestRevision else { return }
      animaCoreErrorMessage = error.localizedDescription
    }
  }

  /// Jogs one DH joint through AnimaCore FK. The app keeps only the current
  /// authoring pose; all chain math and limit enforcement remains canonical in
  /// the engine.
  func jogArmJoint(named name: String, to value: Double) async {
    guard let animaCoreClient, let handle = animaCoreHandle,
      let chain = engineKinematicChain,
      chain.joints.contains(where: { $0.name == name })
    else { return }

    var requestedValues = armJointValues
    requestedValues[name] = value
    armRequestRevision += 1
    let revision = armRequestRevision
    do {
      let result = try await animaCoreClient.forwardKinematics(
        handle: handle,
        jointValues: requestedValues
      )
      guard revision == armRequestRevision, handle == animaCoreHandle else { return }
      armJointValues = requestedValues
      applyArmForwardResult(result, chain: chain)
      armIKTargetPose = armToolPose
      armIKReachState = .idle
    } catch is CancellationError {
      return
    } catch {
      guard revision == armRequestRevision else { return }
      armIKReachState = .failed(error.localizedDescription)
    }
  }

  /// Sends a character-space tool target to AnimaCore's IK solver. An
  /// unreachable request remains visible as the target pose while the last
  /// valid arm pose stays rendered.
  func solveArmIK(target: EngineResolvedPartPose) async {
    guard let animaCoreClient, let handle = animaCoreHandle,
      let chain = engineKinematicChain
    else { return }

    armIKTargetPose = target
    armIKReachState = .solving
    armRequestRevision += 1
    let revision = armRequestRevision
    do {
      let result = try await animaCoreClient.solveInverseKinematics(
        handle: handle,
        targetPose: AnimaCoreTransformPose(
          position: [
            Double(target.positionMeters.x),
            Double(target.positionMeters.y),
            Double(target.positionMeters.z),
          ],
          orientation: [
            Double(target.orientationImaginaryReal.x),
            Double(target.orientationImaginaryReal.y),
            Double(target.orientationImaginaryReal.z),
            Double(target.orientationImaginaryReal.w),
          ]
        ),
        seed: armJointValues
      )
      guard revision == armRequestRevision, handle == animaCoreHandle else { return }
      guard result.reached else {
        armIKReachState = .unreachable(
          positionErrorMeters: result.positionErrorMeters,
          orientationErrorRadians: result.orientationErrorRadians
        )
        return
      }

      let forward = try await animaCoreClient.forwardKinematics(
        handle: handle,
        jointValues: result.jointValues
      )
      guard revision == armRequestRevision, handle == animaCoreHandle else { return }
      armJointValues = result.jointValues
      applyArmForwardResult(forward, chain: chain)
      armIKTargetPose = armToolPose
      armIKReachState = .reached(iterations: result.iterations)
    } catch is CancellationError {
      return
    } catch {
      guard revision == armRequestRevision else { return }
      armIKReachState = .failed(error.localizedDescription)
    }
  }

  private func applyArmForwardResult(
    _ result: AnimaCoreForwardKinematicsResult,
    chain: AnimaCoreKinematicChainSummary
  ) {
    for (joint, frame) in zip(chain.joints, result.linkFrames) {
      guard let partName = joint.part, let partID = enginePartIDsByName[partName],
        let pose = Self.previewPose(frame)
      else { continue }
      engineResolvedPartPoses[partID] = pose
    }
    if let toolPart = chain.toolPart, let partID = enginePartIDsByName[toolPart],
      let pose = Self.previewPose(result.toolPose)
    {
      engineResolvedPartPoses[partID] = pose
    }
    armToolPose = Self.previewPose(result.toolPose)
    if armIKTargetPose == nil {
      armIKTargetPose = armToolPose
    }
  }

  private static func armJointValues(
    chain: AnimaCoreKinematicChainSummary?,
    evaluation: AnimaCoreEvaluation
  ) -> [String: Double] {
    guard let chain else { return [:] }
    return Dictionary(
      uniqueKeysWithValues: chain.joints.map { joint in
        (joint.name, evaluation.degreesOfFreedom[joint.degreeOfFreedomPath] ?? joint.neutral)
      }
    )
  }

  private static func previewPose(_ pose: AnimaCoreTransformPose) -> EngineResolvedPartPose? {
    EngineResolvedPartPose(
      positionMeters: pose.position,
      orientationImaginaryReal: pose.orientation
    )
  }

  var canCreateRevoluteJoint: Bool {
    let connectedChildren = Set(project.rig.joints.compactMap(\.childPartID))
    let eligibleChildren = project.rig.parts.filter {
      !connectedChildren.contains($0.id) && !isComponentLocked($0.id)
    }
    return eligibleChildren.contains { child in
      project.rig.parts.contains { parent in
        parent.id != child.id
          && !isComponentLocked(parent.id)
          && !wouldCreateMateCycle(childID: child.id, parentID: parent.id)
      }
    }
  }

  var mateCandidatePartIDs: Set<PartID> {
    guard let matePlacement else { return [] }
    if let source = matePlacement.sourceCandidate {
      return Set(
        project.rig.parts.compactMap { part in
          part.id != source.partID
            && !isComponentLocked(part.id)
            && !wouldCreateMateCycle(childID: source.partID, parentID: part.id)
            ? part.id : nil
        }
      )
    }

    let connectedChildren = Set(project.rig.joints.compactMap(\.childPartID))
    let eligible = project.rig.parts.filter {
      !connectedChildren.contains($0.id) && !isComponentLocked($0.id)
    }
    if let preferredPartID = matePlacement.preferredPartID,
      eligible.contains(where: { $0.id == preferredPartID })
    {
      return [preferredPartID]
    }
    return Set(eligible.map(\.id))
  }

  func importModel(from url: URL, unitScaleToMeters: Double = 1) async {
    guard url.isFileURL else {
      importErrorMessage = "The selected model is not a local file."
      return
    }

    let accessedSecurityScope = url.startAccessingSecurityScopedResource()
    defer {
      if accessedSecurityScope {
        url.stopAccessingSecurityScopedResource()
      }
    }
    isLoadingModelHierarchy = true
    importErrorMessage = nil
    defer { isLoadingModelHierarchy = false }

    let hierarchy: ModelHierarchyNode
    do {
      hierarchy = try await RealityKitModelHierarchy.load(
        contentsOf: url,
        unitScaleToMeters: unitScaleToMeters
      )
    } catch {
      importErrorMessage = "\(url.lastPathComponent): \(error.localizedDescription)"
      return
    }

    let asset = ProjectAsset(
      name: url.lastPathComponent,
      kind: .model3D,
      sourcePath: url.path
    )
    project.assets.removeAll { $0.sourcePath == asset.sourcePath }
    project.assets.append(asset)
    importedModelURL = url
    importedModelHierarchy = hierarchy
    selection = [.modelNode(hierarchy.id)]
  }

  func clearSelection() {
    storedSelectedFeature = nil
    selection.removeAll()
  }

  func showCreationTools() {
    showsCreationPalette = true
  }

  func addPart(kind: RigPrimitiveKind) {
    let sequence = project.rig.parts.count + 1
    let part = RigPartDefinition(
      displayName: "\(kind.displayName) \(sequence)",
      primitiveKind: kind
    )
    project.rig.parts.append(part)
    selection = [.part(part.id)]
  }

  func createRevoluteJoint() {
    let connectedChildren = Set(project.rig.joints.compactMap(\.childPartID))
    let selectedPartID: PartID? = {
      guard case .part(let partID) = primarySelection else { return nil }
      return partID
    }()
    let child =
      project.rig.parts.first {
        $0.id == selectedPartID && !connectedChildren.contains($0.id)
          && !isComponentLocked($0.id)
      }
      ?? project.rig.parts.first {
        !connectedChildren.contains($0.id) && !isComponentLocked($0.id)
      }
    guard let child else { return }

    let parentID = project.rig.parts.first {
      $0.id != child.id && !isComponentLocked($0.id)
    }?.id
    var sequence = project.rig.joints.count + 1
    while project.rig.joints.contains(where: { $0.id.rawValue == "joint_\(sequence)" }) {
      sequence += 1
    }
    let joint = JointDefinition(
      id: JointID(rawValue: "joint_\(sequence)"),
      displayName: "Revolute Mate \(sequence)",
      axis: .y,
      minimumRadians: -.pi / 2,
      maximumRadians: .pi / 2,
      parentPartID: parentID,
      childPartID: child.id
    )
    project.rig.joints.append(joint)
    selection = [.joint(joint.id)]
  }

  func beginRevoluteMatePlacement() {
    guard canCreateRevoluteJoint else { return }
    let connectedChildren = Set(project.rig.joints.compactMap(\.childPartID))
    let preferredPartID = selectedPartID.flatMap { partID in
      !connectedChildren.contains(partID) && !isComponentLocked(partID) ? partID : nil
    }
    storedSelectedFeature = nil
    matePlacement = MatePlacementSession(preferredPartID: preferredPartID)
    isPlaying = false
    showsCreationPalette = false
  }

  func cancelMatePlacement() {
    matePlacement = nil
  }

  /// Handles feature-pick events from the standing viewport interaction.
  /// During mate placement, feature picks forward to the placement flow
  /// unchanged and empty clicks are ignored, so placement keeps its
  /// existing two-click semantics. Feature selection is allowed on locked
  /// components: locks guard edits, and inspecting a feature edits nothing.
  func selectMateConnector(_ event: ViewportPickEvent) {
    switch event {
    case .feature(let candidate):
      if matePlacement != nil {
        selectMateConnector(candidate)
        return
      }
      guard project.rig.parts.contains(where: { $0.id == candidate.partID }) else { return }
      storedSelectedFeature = candidate
      selection = [.part(candidate.partID)]
    case .clearFeature:
      storedSelectedFeature = nil
    case .clearAll:
      guard matePlacement == nil else { return }
      clearSelection()
    }
  }

  func selectMateConnector(_ candidate: MateConnectorCandidate) {
    guard var placement = matePlacement,
      !isComponentLocked(candidate.partID)
    else { return }

    if placement.sourceCandidate == nil {
      guard mateCandidatePartIDs.contains(candidate.partID) else { return }
      placement.sourceCandidate = candidate
      matePlacement = placement
      selection = [.part(candidate.partID)]
      return
    }

    guard let source = placement.sourceCandidate,
      source.partID != candidate.partID,
      mateCandidatePartIDs.contains(candidate.partID),
      let parent = project.rig.parts.first(where: { $0.id == candidate.partID })
    else { return }

    var sequence = project.rig.joints.count + 1
    while project.rig.joints.contains(where: { $0.id.rawValue == "joint_\(sequence)" }) {
      sequence += 1
    }
    let joint = JointDefinition(
      id: JointID(rawValue: "joint_\(sequence)"),
      displayName: "Revolute Mate \(sequence)",
      axis: .z,
      minimumRadians: -.pi / 2,
      maximumRadians: .pi / 2,
      parentPartID: parent.id,
      childPartID: source.partID,
      parentConnector: candidate.connector,
      childConnector: source.connector
    )
    project.rig.joints.append(joint)
    matePlacement = nil
    selection = [.joint(joint.id)]
  }

  private func wouldCreateMateCycle(childID: PartID, parentID: PartID) -> Bool {
    var currentID: PartID? = parentID
    var visited: Set<PartID> = []
    while let current = currentID, visited.insert(current).inserted {
      if current == childID { return true }
      currentID = project.rig.joints.first { $0.childPartID == current }?.parentPartID
    }
    return false
  }

  func switchWorkspace(to workspace: StudioWorkspaceKind) {
    guard activeWorkspace != workspace else { return }
    if workspace != .animate {
      isPlaying = false
    }
    activeWorkspace = workspace
  }

  func toggleNavigator() {
    updateActivePresentation { $0.showsNavigator.toggle() }
  }

  func toggleInspector() {
    updateActivePresentation { $0.showsInspector.toggle() }
  }

  func toggleBottomEditor() {
    guard activeWorkspace == .animate || activeWorkspace == .show else { return }
    updateActivePresentation { $0.showsBottomEditor.toggle() }
  }

  func resetActivePresentation() {
    workspacePresentations[activeWorkspace] = activeWorkspace.descriptor.defaultPresentation
  }

  func toggleRigConnectors() {
    rigGuideVisibility.showsConnectors.toggle()
  }

  func toggleRigDOFHandles() {
    rigGuideVisibility.showsDOFHandles.toggle()
  }

  func toggleRigReferencePlanes() {
    rigGuideVisibility.showsReferencePlanes.toggle()
  }

  func toggleRigLimits() {
    rigGuideVisibility.showsLimits.toggle()
  }

  func selectModelNode(at path: ModelEntityPath, extendingSelection: Bool) {
    let item = NavigatorItem.modelNode(path)
    if extendingSelection {
      if selection.contains(item) {
        selection.remove(item)
      } else {
        selection.insert(item)
      }
    } else {
      selection = [item]
    }
  }

  func selectPart(id: PartID, extendingSelection: Bool) {
    // Plain component selection (viewport geometry click away from any
    // feature marker) always drops the standing feature selection.
    storedSelectedFeature = nil
    let item = NavigatorItem.part(id)
    if extendingSelection {
      if selection.contains(item) {
        selection.remove(item)
      } else {
        selection.insert(item)
      }
    } else {
      selection = [item]
    }
  }

  func selectParts(ids: Set<PartID>) {
    storedSelectedFeature = nil
    selection = Set(ids.map(NavigatorItem.part))
  }

  func renameAsset(id: AssetID, to name: String) {
    guard let index = project.assets.firstIndex(where: { $0.id == id }) else { return }
    project.assets[index].name = name
  }

  func renamePart(id: PartID, to name: String) {
    guard !isComponentLocked(id) else { return }
    guard let index = project.rig.parts.firstIndex(where: { $0.id == id }) else { return }
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return }
    project.rig.parts[index].displayName = trimmedName
  }

  func setPartPosition(id: PartID, to positionMeters: RigVector3) {
    guard !isComponentLocked(id), isPartRestTransformEditable(id),
      positionMeters.x.isFinite, positionMeters.y.isFinite, positionMeters.z.isFinite,
      let index = project.rig.parts.firstIndex(where: { $0.id == id })
    else { return }
    project.rig.parts[index].positionMeters = positionMeters
    updateEnginePartTransform(id: id)
  }

  func setPartRotation(id: PartID, to rotationEulerRadians: RigVector3) {
    guard !isComponentLocked(id), isPartRestTransformEditable(id),
      rotationEulerRadians.x.isFinite, rotationEulerRadians.y.isFinite,
      rotationEulerRadians.z.isFinite,
      let index = project.rig.parts.firstIndex(where: { $0.id == id })
    else { return }
    project.rig.parts[index].rotationEulerRadians = rotationEulerRadians
    updateEnginePartTransform(id: id)
  }

  func isPartRestTransformEditable(_ id: PartID) -> Bool {
    guard let part = enginePart(for: id) else { return true }
    if part.isGrounded { return true }
    return !engineMates.contains { !$0.isSuppressed && $0.childPart == part.name }
  }

  func componentAppearance(for id: PartID) -> PreviewPartAppearance? {
    guard let part = project.rig.parts.first(where: { $0.id == id }) else { return nil }
    return componentAppearances[id] ?? .defaultAppearance(for: part.primitiveKind)
  }

  func setComponentAppearance(id: PartID, to appearance: PreviewPartAppearance) {
    guard !isComponentLocked(id), project.rig.parts.contains(where: { $0.id == id }) else {
      return
    }
    componentAppearances[id] = PreviewPartAppearance(
      red: appearance.red,
      green: appearance.green,
      blue: appearance.blue,
      opacity: appearance.opacity,
      isVisible: appearance.isVisible,
      finish: appearance.finish,
      proxyFilletRadiusMeters: appearance.proxyFilletRadiusMeters
    )
    documentEditRevision += 1
  }

  func setComponentProxyFilletRadius(id: PartID, meters: Double) {
    guard !isComponentLocked(id),
      let part = project.rig.parts.first(where: { $0.id == id }),
      part.primitiveKind == .box
    else { return }
    var appearance = componentAppearance(for: id) ?? .defaultAppearance(for: .box)
    appearance.proxyFilletRadiusMeters = min(
      max(meters, 0), PreviewPartAppearance.maximumProxyFilletRadiusMeters
    )
    componentAppearances[id] = appearance
    documentEditRevision += 1
  }

  func resetComponentAppearance(id: PartID) {
    guard !isComponentLocked(id) else { return }
    componentAppearances.removeValue(forKey: id)
    documentEditRevision += 1
  }

  func togglePartSuppressed(_ id: PartID) async {
    guard let part = enginePart(for: id), let document = engineRigDocument else { return }
    do {
      engineRigDocument = try AnimaCoreRigDocumentEditor.settingPartState(
        named: part.name,
        suppressed: !part.isSuppressed,
        in: document
      )
      documentEditRevision += 1
      try await reloadEditedEngineRig()
    } catch {
      animaCoreErrorMessage = error.localizedDescription
    }
  }

  func togglePartGrounded(_ id: PartID) async {
    guard let part = enginePart(for: id), let document = engineRigDocument else { return }
    do {
      engineRigDocument = try AnimaCoreRigDocumentEditor.settingPartState(
        named: part.name,
        grounded: !part.isGrounded,
        in: document
      )
      documentEditRevision += 1
      try await reloadEditedEngineRig()
    } catch {
      animaCoreErrorMessage = error.localizedDescription
    }
  }

  func toggleMateSuppressed(_ mate: AnimaCoreJointSummary) async {
    guard let document = engineRigDocument else { return }
    do {
      engineRigDocument = try AnimaCoreRigDocumentEditor.settingJointSuppressed(
        named: mate.name,
        suppressed: !mate.isSuppressed,
        in: document
      )
      documentEditRevision += 1
      try await reloadEditedEngineRig()
    } catch {
      animaCoreErrorMessage = error.localizedDescription
    }
  }

  func toggleRelationSuppressed(_ relation: AnimaCoreRelationSummary) async {
    guard let document = engineRigDocument else { return }
    do {
      engineRigDocument = try AnimaCoreRigDocumentEditor.settingRelationSuppressed(
        kind: relation.kind,
        driver: relation.driver,
        driven: relation.driven,
        suppressed: !relation.isSuppressed,
        in: document
      )
      documentEditRevision += 1
      try await reloadEditedEngineRig()
    } catch {
      animaCoreErrorMessage = error.localizedDescription
    }
  }

  func renameJoint(id: JointID, to name: String) {
    guard !isMateLocked(id) else { return }
    guard let index = project.rig.joints.firstIndex(where: { $0.id == id }) else { return }
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return }
    project.rig.joints[index].displayName = trimmedName
  }

  func setJointAxis(id: JointID, to axis: JointAxis) {
    guard !isMateLocked(id) else { return }
    guard let index = project.rig.joints.firstIndex(where: { $0.id == id }) else { return }
    project.rig.joints[index].axis = axis
  }

  func setJointRange(id: JointID, minimumRadians: Double, maximumRadians: Double) {
    guard !isMateLocked(id),
      minimumRadians.isFinite, maximumRadians.isFinite,
      minimumRadians <= maximumRadians,
      let index = project.rig.joints.firstIndex(where: { $0.id == id })
    else { return }
    project.rig.joints[index].minimumRadians = minimumRadians
    project.rig.joints[index].maximumRadians = maximumRadians
    project.rig.joints[index].neutralRadians = min(
      max(project.rig.joints[index].neutralRadians, minimumRadians),
      maximumRadians
    )
  }

  @discardableResult
  func createComponentGroup(named name: String? = nil) -> UUID {
    let selectedIDs = selectedUnlockedComponentIDs
    for componentID in selectedIDs {
      removeComponentFromGroups(componentID)
    }

    let sequence = componentGroups.count + 1
    let group = NavigatorComponentGroup(
      displayName: name ?? "Group \(sequence)",
      componentIDs: selectedIDs
    )
    componentGroups.append(group)
    selection = [.componentGroup(group.id)]
    documentEditRevision += 1
    return group.id
  }

  func renameComponentGroup(id: UUID, to name: String) {
    guard let index = componentGroups.firstIndex(where: { $0.id == id }),
      !componentGroups[index].isLocked
    else { return }
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return }
    componentGroups[index].displayName = trimmedName
    documentEditRevision += 1
  }

  func dissolveComponentGroup(id: UUID) {
    guard let index = componentGroups.firstIndex(where: { $0.id == id }),
      !componentGroups[index].isLocked
    else { return }
    componentGroups.remove(at: index)
    selection.remove(.componentGroup(id))
    documentEditRevision += 1
  }

  func moveComponent(_ id: PartID, direction: NavigatorMoveDirection) {
    guard !isComponentLocked(id) else { return }
    if let groupIndex = componentGroups.firstIndex(where: { $0.componentIDs.contains(id) }) {
      guard !componentGroups[groupIndex].isLocked else { return }
      componentGroups[groupIndex].componentIDs = NavigatorOrdering.moved(
        componentGroups[groupIndex].componentIDs,
        value: id,
        direction: direction
      )
      documentEditRevision += 1
      return
    }

    let rootIDs = project.rig.parts.compactMap { part in
      componentGroup(containing: part.id) == nil ? part.id : nil
    }
    guard let siblingIndex = rootIDs.firstIndex(of: id) else { return }
    let destinationSiblingIndex =
      switch direction {
      case .up: siblingIndex - 1
      case .down: siblingIndex + 1
      }
    guard rootIDs.indices.contains(destinationSiblingIndex) else { return }
    let destinationID = rootIDs[destinationSiblingIndex]
    guard
      let sourceIndex = project.rig.parts.firstIndex(where: { $0.id == id }),
      let destinationIndex = project.rig.parts.firstIndex(where: { $0.id == destinationID })
    else { return }
    project.rig.parts.swapAt(sourceIndex, destinationIndex)
    documentEditRevision += 1
  }

  func moveComponentGroup(_ id: UUID, direction: NavigatorMoveDirection) {
    guard let group = componentGroups.first(where: { $0.id == id }), !group.isLocked else { return }
    componentGroups = NavigatorOrdering.moved(componentGroups, value: group, direction: direction)
    documentEditRevision += 1
  }

  @discardableResult
  func moveComponentGroup(_ id: UUID, before destinationID: UUID) -> Bool {
    moveComponentGroup(id, relativeTo: destinationID, placement: .before)
  }

  @discardableResult
  func moveComponentGroup(
    _ id: UUID,
    relativeTo destinationID: UUID,
    placement: NavigatorRelativePlacement
  ) -> Bool {
    guard
      let group = componentGroups.first(where: { $0.id == id }),
      let destination = componentGroups.first(where: { $0.id == destinationID }),
      !group.isLocked, !destination.isLocked
    else { return false }
    let reordered = NavigatorOrdering.moving(
      componentGroups,
      value: group,
      relativeTo: destination,
      placement: placement
    )
    guard reordered != componentGroups else { return false }
    componentGroups = reordered
    documentEditRevision += 1
    return true
  }

  func moveMate(_ id: JointID, direction: NavigatorMoveDirection) {
    guard !isMateLocked(id),
      let mate = project.rig.joints.first(where: { $0.id == id })
    else { return }
    project.rig.joints = NavigatorOrdering.moved(
      project.rig.joints,
      value: mate,
      direction: direction
    )
    documentEditRevision += 1
  }

  @discardableResult
  func moveMate(_ id: JointID, before destinationID: JointID) -> Bool {
    moveMate(id, relativeTo: destinationID, placement: .before)
  }

  @discardableResult
  func moveMate(
    _ id: JointID,
    relativeTo destinationID: JointID,
    placement: NavigatorRelativePlacement
  ) -> Bool {
    guard !isMateLocked(id), !isMateLocked(destinationID),
      let mate = project.rig.joints.first(where: { $0.id == id }),
      let destination = project.rig.joints.first(where: { $0.id == destinationID })
    else { return false }
    let reordered = NavigatorOrdering.moving(
      project.rig.joints,
      value: mate,
      relativeTo: destination,
      placement: placement
    )
    guard reordered != project.rig.joints else { return false }
    project.rig.joints = reordered
    documentEditRevision += 1
    return true
  }

  @discardableResult
  func moveComponent(_ id: PartID, before destinationID: PartID) -> Bool {
    moveComponent(id, relativeTo: destinationID, placement: .before)
  }

  @discardableResult
  func moveComponent(
    _ id: PartID,
    relativeTo destinationID: PartID,
    placement: NavigatorRelativePlacement
  ) -> Bool {
    guard id != destinationID,
      !isComponentLocked(id), !isComponentLocked(destinationID),
      project.rig.parts.contains(where: { $0.id == id }),
      project.rig.parts.contains(where: { $0.id == destinationID })
    else { return false }

    let originalGroups = componentGroups
    let originalPartIDs = project.rig.parts.map(\.id)

    if let destinationGroup = componentGroup(containing: destinationID),
      let destinationIndex = componentGroups.firstIndex(where: { $0.id == destinationGroup.id })
    {
      removeComponentFromGroups(id)
      componentGroups[destinationIndex].componentIDs.append(id)
      componentGroups[destinationIndex].componentIDs = NavigatorOrdering.moving(
        componentGroups[destinationIndex].componentIDs,
        value: id,
        relativeTo: destinationID,
        placement: placement
      )
      let changed = componentGroups != originalGroups
      if changed { documentEditRevision += 1 }
      return changed
    }

    removeComponentFromGroups(id)
    guard let sourceIndex = project.rig.parts.firstIndex(where: { $0.id == id }) else {
      return false
    }
    let component = project.rig.parts[sourceIndex]
    project.rig.parts.remove(at: sourceIndex)
    guard let destinationIndex = project.rig.parts.firstIndex(where: { $0.id == destinationID })
    else {
      project.rig.parts.insert(component, at: sourceIndex)
      return false
    }
    let insertionIndex = placement == .before ? destinationIndex : destinationIndex + 1
    project.rig.parts.insert(component, at: insertionIndex)
    let changed =
      componentGroups != originalGroups || project.rig.parts.map(\.id) != originalPartIDs
    if changed { documentEditRevision += 1 }
    return changed
  }

  @discardableResult
  func groupComponents(draggedID: PartID, onto destinationID: PartID) -> UUID? {
    guard draggedID != destinationID,
      !isComponentLocked(draggedID), !isComponentLocked(destinationID)
    else { return nil }

    let draggedIDs = componentIDsForDrag(startingWith: draggedID)
    guard !draggedIDs.isEmpty else { return nil }

    if let destinationGroup = componentGroup(containing: destinationID),
      let destinationIndex = componentGroups.firstIndex(where: { $0.id == destinationGroup.id }),
      !destinationGroup.isLocked
    {
      let originalGroups = componentGroups
      for componentID in draggedIDs
      where !componentGroups[destinationIndex].componentIDs.contains(componentID) {
        removeComponentFromGroups(componentID)
        componentGroups[destinationIndex].componentIDs.append(componentID)
      }
      guard componentGroups != originalGroups else { return nil }
      selection = [.componentGroup(destinationGroup.id)]
      documentEditRevision += 1
      return destinationGroup.id
    }

    let memberSet = Set(draggedIDs + [destinationID])
    let memberIDs = project.rig.parts.compactMap { memberSet.contains($0.id) ? $0.id : nil }
    guard memberIDs.count >= 2 else { return nil }
    for componentID in memberIDs {
      removeComponentFromGroups(componentID)
    }

    let group = NavigatorComponentGroup(
      displayName: "Group \(componentGroups.count + 1)",
      componentIDs: memberIDs
    )
    componentGroups.append(group)
    selection = [.componentGroup(group.id)]
    documentEditRevision += 1
    return group.id
  }

  @discardableResult
  func moveComponent(_ id: PartID, toGroup groupID: UUID?) -> Bool {
    guard !isComponentLocked(id) else { return false }
    if let sourceGroup = componentGroup(containing: id), sourceGroup.isLocked { return false }
    if let groupID {
      guard let destinationIndex = componentGroups.firstIndex(where: { $0.id == groupID }),
        !componentGroups[destinationIndex].isLocked
      else { return false }
      guard !componentGroups[destinationIndex].componentIDs.contains(id) else { return false }
      removeComponentFromGroups(id)
      componentGroups[destinationIndex].componentIDs.append(id)
    } else {
      guard componentGroup(containing: id) != nil else { return false }
      removeComponentFromGroups(id)
    }
    documentEditRevision += 1
    return true
  }

  @discardableResult
  func moveDraggedComponents(startingWith id: PartID, toGroup groupID: UUID?) -> Bool {
    var didMove = false
    for componentID in componentIDsForDrag(startingWith: id) {
      didMove = moveComponent(componentID, toGroup: groupID) || didMove
    }
    return didMove
  }

  func toggleComponentLock(_ id: PartID) {
    if lockedComponentIDs.contains(id) {
      lockedComponentIDs.remove(id)
    } else {
      lockedComponentIDs.insert(id)
    }
    documentEditRevision += 1
  }

  func toggleMateLock(_ id: JointID) {
    if lockedMateIDs.contains(id) {
      lockedMateIDs.remove(id)
    } else {
      lockedMateIDs.insert(id)
    }
    documentEditRevision += 1
  }

  func toggleComponentGroupLock(_ id: UUID) {
    guard let index = componentGroups.firstIndex(where: { $0.id == id }) else { return }
    componentGroups[index].isLocked.toggle()
    documentEditRevision += 1
  }

  func isComponentLocked(_ id: PartID) -> Bool {
    lockedComponentIDs.contains(id) || componentGroup(containing: id)?.isLocked == true
  }

  func isComponentIndividuallyLocked(_ id: PartID) -> Bool {
    lockedComponentIDs.contains(id)
  }

  func isComponentLockedByGroup(_ id: PartID) -> Bool {
    componentGroup(containing: id)?.isLocked == true
  }

  func isMateLocked(_ id: JointID) -> Bool {
    lockedMateIDs.contains(id)
  }

  func componentGroup(containing id: PartID) -> NavigatorComponentGroup? {
    componentGroups.first { $0.componentIDs.contains(id) }
  }

  private func removeComponentFromGroups(_ id: PartID) {
    for index in componentGroups.indices {
      componentGroups[index].componentIDs.removeAll { $0 == id }
    }
  }

  private func componentIDsForDrag(startingWith id: PartID) -> [PartID] {
    guard !isComponentLocked(id) else { return [] }
    guard selection.contains(.part(id)) else { return [id] }
    return selectedUnlockedComponentIDs.contains(id) ? selectedUnlockedComponentIDs : [id]
  }

  func setCameraViewpoint(_ viewpoint: PreviewCameraViewpoint) {
    rememberCurrentCamera()
    if viewpoint != .custom {
      cameraState.orientation = PreviewCameraOrientation(
        direction: cameraState.orientation.direction
      )
    }
    cameraViewpoint = viewpoint
    cameraCommandRevision += 1
  }

  func setCameraDirection(_ direction: PreviewCameraDirection) {
    rememberCurrentCamera()
    cameraState.orientation = PreviewCameraOrientation(direction: direction)
    cameraViewpoint = .custom
    cameraCommandRevision += 1
  }

  func nudgeCamera(horizontalRadians: Float = 0, verticalRadians: Float = 0) {
    rememberCurrentCamera()
    cameraState.orientation.direction = cameraState.orientation.direction.nudged(
      horizontalRadians: horizontalRadians,
      verticalRadians: verticalRadians
    )
    cameraViewpoint = .custom
    cameraCommandRevision += 1
  }

  func rollCamera(by radians: Float) {
    rememberCurrentCamera()
    cameraState.orientation = cameraState.orientation.rolled(by: radians)
    cameraViewpoint = .custom
    cameraCommandRevision += 1
  }

  func reportCameraState(_ state: PreviewCameraState) {
    guard state != cameraState else { return }
    if manualCameraHistoryOrigin == nil {
      manualCameraHistoryOrigin = (cameraState, cameraProjection)
    }
    cameraState = state
    cameraViewpoint = .custom
    manualCameraHistoryTask?.cancel()
    manualCameraHistoryTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled, let self, let origin = self.manualCameraHistoryOrigin else { return }
      self.previousCameraState = origin.state
      self.previousCameraProjection = origin.projection
      self.manualCameraHistoryOrigin = nil
    }
  }

  func frameSelection() {
    guard canFrameSelection else { return }
    setCameraViewpoint(.selection)
  }

  func setViewportBackground(_ settings: ViewportBackgroundSettings) {
    guard settings != viewportBackground else { return }
    viewportBackground = settings
    documentEditRevision += 1
  }

  func setViewportSectionPlane(_ section: ViewportSectionPlane) {
    guard section != viewportSectionPlane else { return }
    viewportSectionPlane = section
    documentEditRevision += 1
  }

  func saveNamedCameraView(name: String) {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }
    namedCameraViews.append(
      PreviewNamedView(
        name: name,
        state: cameraState,
        projection: cameraProjection
      )
    )
    documentEditRevision += 1
  }

  func restoreNamedCameraView(id: UUID) {
    guard let view = namedCameraViews.first(where: { $0.id == id }) else { return }
    rememberCurrentCamera()
    cameraState = view.state
    cameraProjection = view.projection
    cameraViewpoint = .custom
    cameraCommandRevision += 1
  }

  func deleteNamedCameraView(id: UUID) {
    let oldCount = namedCameraViews.count
    namedCameraViews.removeAll { $0.id == id }
    if namedCameraViews.count != oldCount { documentEditRevision += 1 }
  }

  func restorePreviousCameraView() {
    guard let previousCameraState else { return }
    let currentState = cameraState
    let currentProjection = cameraProjection
    cameraState = previousCameraState
    cameraProjection = previousCameraProjection ?? cameraProjection
    self.previousCameraState = currentState
    previousCameraProjection = currentProjection
    cameraViewpoint = .custom
    cameraCommandRevision += 1
  }

  private func rememberCurrentCamera() {
    manualCameraHistoryTask?.cancel()
    if let origin = manualCameraHistoryOrigin {
      previousCameraState = origin.state
      previousCameraProjection = origin.projection
      manualCameraHistoryOrigin = nil
    } else {
      previousCameraState = cameraState
      previousCameraProjection = cameraProjection
    }
  }

  func togglePlayback() {
    if playheadSeconds >= activeClip.durationSeconds {
      playheadSeconds = 0
    }
    isPlaying.toggle()
  }

  func stopPlayback() {
    isPlaying = false
    playheadSeconds = 0
  }

  func seekTimeline(to seconds: Double) {
    isPlaying = false
    playheadSeconds = min(max(seconds, 0), activeClip.durationSeconds)
  }

  func stepTimeline(byFrames frameDelta: Int) {
    let framesPerSecond = max(timelineDisplayFramesPerSecond, 1)
    seekTimeline(
      to: playheadSeconds + Double(frameDelta) / Double(framesPerSecond)
    )
  }

  func seekAdjacentKeyframe(forward: Bool) {
    let times = Set(
      activeClip.jointTracks.flatMap { track in
        track.keyframes.map(\.timeSeconds)
      }
    ).sorted()
    let epsilon = 1e-9
    let destination: Double
    if forward {
      destination = times.first { $0 > playheadSeconds + epsilon } ?? activeClip.durationSeconds
    } else {
      destination = times.last { $0 < playheadSeconds - epsilon } ?? 0
    }
    seekTimeline(to: destination)
  }

  func advancePlayback(by seconds: Double) {
    guard isPlaying else { return }
    let nextTime = playheadSeconds + seconds
    if nextTime >= activeClip.durationSeconds {
      if loopsPreviewPlayback {
        playheadSeconds =
          activeClip.durationSeconds > 0
          ? nextTime.truncatingRemainder(dividingBy: activeClip.durationSeconds)
          : 0
      } else {
        playheadSeconds = activeClip.durationSeconds
        isPlaying = false
      }
    } else {
      playheadSeconds = nextTime
    }
  }

  private struct EnginePreviewProject {
    let project: AnimaProject
    let partIDsByEngineName: [String: PartID]
  }

  /// Creates renderer-only proxy geometry for every engine part. The engine
  /// name-to-ID projection is session-local; all transforms come from
  /// `resolve_pose`, never from a Swift reconstruction of the mate graph.
  private static func previewProject(for summary: AnimaCoreRigSummary) -> EnginePreviewProject {
    let parts = summary.parts.enumerated().map { index, part in
      RigPartDefinition(
        displayName: part.name,
        primitiveKind: index.isMultiple(of: 2) ? .cylinder : .box,
        positionMeters: Self.rigVector(part.positionMeters),
        rotationEulerRadians: Self.rigVector(part.rotationEulerRadians)
      )
    }
    let partIDsByEngineName = Dictionary(
      uniqueKeysWithValues: zip(summary.parts, parts).map { ($0.name, $1.id) }
    )
    let clips = summary.clips.map { clip in
      AnimationClip(
        name: clip.name,
        durationSeconds: clip.durationSeconds,
        jointTracks: []
      )
    }
    return EnginePreviewProject(
      project: AnimaProject(
        name: summary.identity.displayName,
        rig: CharacterRig(parts: parts, joints: []),
        clips: clips
      ),
      partIDsByEngineName: partIDsByEngineName
    )
  }

  private static func previewPoses(
    from resolvedPose: AnimaCoreResolvedPose,
    partIDsByEngineName: [String: PartID]
  ) -> [PartID: EngineResolvedPartPose] {
    Dictionary(
      uniqueKeysWithValues: resolvedPose.parts.compactMap { name, pose in
        guard let partID = partIDsByEngineName[name],
          let previewPose = EngineResolvedPartPose(
            positionMeters: pose.position,
            orientationImaginaryReal: pose.orientation
          )
        else { return nil }
        return (partID, previewPose)
      }
    )
  }

  private static func mateName(fromDOFPath path: String) -> String? {
    path.split(separator: ".", maxSplits: 1).first.map(String.init)
  }

  private static func rigVector(_ values: [Double]) -> RigVector3 {
    guard values.count == 3 else { return RigVector3() }
    return RigVector3(x: values[0], y: values[1], z: values[2])
  }

  private func updateEnginePartTransform(id: PartID) {
    guard let document = engineRigDocument,
      let name = enginePartName(for: id),
      let part = project.rig.parts.first(where: { $0.id == id })
    else { return }
    do {
      engineRigDocument = try AnimaCoreRigDocumentEditor.settingPartTransform(
        named: name,
        positionMeters: [part.positionMeters.x, part.positionMeters.y, part.positionMeters.z],
        rotationEulerRadians: [
          part.rotationEulerRadians.x,
          part.rotationEulerRadians.y,
          part.rotationEulerRadians.z,
        ],
        in: document
      )
      // The retained engine handle still contains the pre-edit pose. Falling
      // back to this character-space rest transform keeps direct manipulation
      // responsive; Save validates/serializes the edited DTO through AnimaCore.
      engineResolvedPartPoses.removeValue(forKey: id)
      documentEditRevision += 1
    } catch {
      animaCoreErrorMessage = error.localizedDescription
    }
  }

  private func reloadEditedEngineRig() async throws {
    guard let animaCoreClient, let engineRigDocument else {
      throw ProjectLifecycleError.noCharacterLoaded
    }
    let metadata = characterEditorMetadata(applyingTo: CharacterEditorMetadata())
    let projectName = project.name
    let selectedPartName = selectedPartID.flatMap(enginePartName(for:))
    let selectedMateKey = selectedEngineMate?.selectionKey
    let selectedRelationID = selectedEngineRelation?.id
    let sourcesByName = Dictionary(
      uniqueKeysWithValues: enginePartModelSources.compactMap { partID, source in
        enginePartName(for: partID).map { ($0, source) }
      }
    )

    let text = try await animaCoreClient.serializeCharacter(rig: engineRigDocument).text
    try await loadAnimaCharacter(text: text)
    project.name = projectName
    applyCharacterEditorMetadata(metadata)
    enginePartModelSources = Dictionary(
      uniqueKeysWithValues: sourcesByName.compactMap { name, source in
        guard let partID = enginePartIDsByName[name] else { return nil }
        return (
          partID,
          PartModelSource(
            partID: partID,
            fileURL: source.fileURL,
            modelNode: source.modelNode,
            unitScaleToMeters: source.unitScaleToMeters
          )
        )
      }
    )
    if let selectedPartName, let partID = enginePartIDsByName[selectedPartName] {
      selection = [.part(partID)]
    } else if let selectedMateKey {
      selection = [.joint(JointID(rawValue: selectedMateKey))]
    } else if let selectedRelationID {
      selection = [.relation(selectedRelationID)]
    }
  }

  private func updateActivePresentation(
    _ update: (inout WorkspacePresentation) -> Void
  ) {
    var presentation = activePresentation
    update(&presentation)
    workspacePresentations[activeWorkspace] = presentation
  }

  private func revealInspectorForInspectableSelection() {
    let hasInspectableSelection = selection.contains { item in
      switch item {
      case .asset, .part, .componentGroup, .modelNode, .joint, .relation, .animation:
        true
      case .project, .structure:
        false
      }
    }
    guard hasInspectableSelection, !activePresentation.showsInspector else { return }
    updateActivePresentation { $0.showsInspector = true }
  }

  private func requestNavigatorRevealForPrimarySelection() {
    guard let primarySelection else { return }
    switch primarySelection {
    case .part, .joint, .relation:
      requestNavigatorReveal(primarySelection)
    case .project, .asset, .componentGroup, .structure, .modelNode, .animation:
      break
    }
  }
}
