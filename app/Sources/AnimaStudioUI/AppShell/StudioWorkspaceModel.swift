import AnimaCoreClient
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
  case animation(String)
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

  var activeWorkspace: StudioWorkspaceKind = .rig
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
  var rigGuideVisibility = RigGuideVisibility()
  var showsCreationPalette = true
  var importedModelURL: URL?
  var importedModelHierarchy: ModelHierarchyNode?
  var isLoadingModelHierarchy = false
  var importErrorMessage: String?
  var animaCoreErrorMessage: String?
  var animaCoreState: AnimaCoreState = .unavailable
  var engineEvaluationTimeSeconds: Double?
  var engineMateTypes: [AnimaCoreMateTypeSummary] = []
  var engineMates: [AnimaCoreJointSummary] = []
  var componentGroups: [NavigatorComponentGroup] = []
  var lockedComponentIDs: Set<PartID> = []
  var lockedMateIDs: Set<JointID> = []
  var componentAppearances: [PartID: PreviewPartAppearance] = [:]
  var isolatedComponentID: PartID?
  var transparentComponentIDs: Set<PartID> = []
  var componentInspectorTab = ComponentInspectorTab.properties
  var matePlacement: MatePlacementSession?
  private var storedSelectedFeature: MateConnectorCandidate?
  @ObservationIgnored private let animaCoreClient: (any AnimaCoreServing)?
  @ObservationIgnored private var animaCoreHandle: String?
  @ObservationIgnored private var animaCoreEngineVersion: String?
  @ObservationIgnored private var engineEvaluation: AnimaCoreEvaluation?

  private let evaluator = AnimationEvaluator()

  init(
    project: AnimaProject = AnimaProject(
      name: "Untitled Character",
      rig: CharacterRig(joints: []),
      clips: []
    ),
    animaCoreClient: (any AnimaCoreServing)? = nil,
    resolvesDefaultAnimaCoreClient: Bool = true
  ) {
    self.project = project
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

  func engineMateType(for mate: AnimaCoreJointSummary) -> AnimaCoreMateTypeSummary? {
    engineMateTypes.first { $0.type == mate.type }
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
    case .project, .asset, .componentGroup, .animation, nil:
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
      animaCoreEngineVersion = hello.engineVersion
      engineMateTypes = mateCatalog.mateTypes
      animaCoreState = .ready(engineVersion: hello.engineVersion)
    } catch {
      animaCoreState = .failed
      animaCoreErrorMessage = error.localizedDescription
    }
  }

  func importAnimaCharacter(from url: URL) async {
    guard let animaCoreClient else {
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
    var pendingHandle: String?
    do {
      let text = try String(contentsOf: url, encoding: .utf8)
      let hello = try await animaCoreClient.start()
      let mateCatalog = try await animaCoreClient.mateTypes()
      let loaded = try await animaCoreClient.loadCharacter(text: text)
      pendingHandle = loaded.handle
      let clip = loaded.rig.clips.first
      let evaluationTimeSeconds = min(clip?.durationSeconds ?? 0, 1)
      let evaluation = try await animaCoreClient.evaluate(
        handle: loaded.handle,
        clip: clip?.name,
        timeSeconds: evaluationTimeSeconds
      )

      if let previousHandle = animaCoreHandle {
        try? await animaCoreClient.release(handle: previousHandle)
      }
      animaCoreHandle = loaded.handle
      pendingHandle = nil
      animaCoreEngineVersion = hello.engineVersion
      engineMateTypes = mateCatalog.mateTypes
      engineMates = loaded.rig.joints
      engineEvaluation = evaluation
      engineEvaluationTimeSeconds = evaluationTimeSeconds
      project = Self.previewProject(for: loaded.rig)
      playheadSeconds = evaluationTimeSeconds
      isPlaying = false
      selection.removeAll()
      componentGroups.removeAll()
      lockedComponentIDs.removeAll()
      lockedMateIDs.removeAll()
      componentAppearances.removeAll()
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
      animaCoreState = .failed
      animaCoreErrorMessage = error.localizedDescription
    }
  }

  func shutdownAnimaCore() async {
    guard let animaCoreClient else { return }
    if let animaCoreHandle {
      try? await animaCoreClient.release(handle: animaCoreHandle)
    }
    await animaCoreClient.shutdown()
    self.animaCoreHandle = nil
    animaCoreEngineVersion = nil
    engineEvaluation = nil
    engineEvaluationTimeSeconds = nil
    engineMateTypes.removeAll()
    engineMates.removeAll()
    animaCoreState = .unavailable
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

  func importModel(from url: URL) async {
    guard url.isFileURL else {
      importErrorMessage = "The selected model is not a local file."
      return
    }

    _ = url.startAccessingSecurityScopedResource()
    isLoadingModelHierarchy = true
    importErrorMessage = nil
    defer { isLoadingModelHierarchy = false }

    let hierarchy: ModelHierarchyNode
    do {
      hierarchy = try await RealityKitModelHierarchy.load(contentsOf: url)
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
      let childIndex = project.rig.parts.firstIndex(where: { $0.id == source.partID }),
      let parent = project.rig.parts.first(where: { $0.id == candidate.partID })
    else { return }

    let snappedTransform = MateConnectorMath.snappedChildTransform(
      childPart: project.rig.parts[childIndex],
      childConnector: source.connector,
      parentPart: parent,
      parentConnector: candidate.connector
    )
    project.rig.parts[childIndex].positionMeters = snappedTransform.positionMeters
    project.rig.parts[childIndex].rotationEulerRadians = snappedTransform.rotationEulerRadians

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
    guard !isComponentLocked(id),
      positionMeters.x.isFinite, positionMeters.y.isFinite, positionMeters.z.isFinite,
      let index = project.rig.parts.firstIndex(where: { $0.id == id })
    else { return }
    project.rig.parts[index].positionMeters = positionMeters
  }

  func setPartRotation(id: PartID, to rotationEulerRadians: RigVector3) {
    guard !isComponentLocked(id),
      rotationEulerRadians.x.isFinite, rotationEulerRadians.y.isFinite,
      rotationEulerRadians.z.isFinite,
      let index = project.rig.parts.firstIndex(where: { $0.id == id })
    else { return }
    project.rig.parts[index].rotationEulerRadians = rotationEulerRadians
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
      isVisible: appearance.isVisible
    )
  }

  func resetComponentAppearance(id: PartID) {
    guard !isComponentLocked(id) else { return }
    componentAppearances.removeValue(forKey: id)
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
    return group.id
  }

  func renameComponentGroup(id: UUID, to name: String) {
    guard let index = componentGroups.firstIndex(where: { $0.id == id }),
      !componentGroups[index].isLocked
    else { return }
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return }
    componentGroups[index].displayName = trimmedName
  }

  func dissolveComponentGroup(id: UUID) {
    guard let index = componentGroups.firstIndex(where: { $0.id == id }),
      !componentGroups[index].isLocked
    else { return }
    componentGroups.remove(at: index)
    selection.remove(.componentGroup(id))
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
  }

  func moveComponentGroup(_ id: UUID, direction: NavigatorMoveDirection) {
    guard let group = componentGroups.first(where: { $0.id == id }), !group.isLocked else { return }
    componentGroups = NavigatorOrdering.moved(componentGroups, value: group, direction: direction)
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
      return componentGroups != originalGroups
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
    return componentGroups != originalGroups || project.rig.parts.map(\.id) != originalPartIDs
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
  }

  func toggleMateLock(_ id: JointID) {
    if lockedMateIDs.contains(id) {
      lockedMateIDs.remove(id)
    } else {
      lockedMateIDs.insert(id)
    }
  }

  func toggleComponentGroupLock(_ id: UUID) {
    guard let index = componentGroups.firstIndex(where: { $0.id == id }) else { return }
    componentGroups[index].isLocked.toggle()
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
    cameraViewpoint = viewpoint
    cameraCommandRevision += 1
  }

  func setCameraDirection(_ direction: PreviewCameraDirection) {
    cameraState.orientation.direction = direction
    cameraViewpoint = .custom
    cameraCommandRevision += 1
  }

  func nudgeCamera(horizontalRadians: Float = 0, verticalRadians: Float = 0) {
    setCameraDirection(
      cameraState.orientation.direction.nudged(
        horizontalRadians: horizontalRadians,
        verticalRadians: verticalRadians
      )
    )
  }

  func reportCameraState(_ state: PreviewCameraState) {
    guard state != cameraState else { return }
    cameraState = state
    cameraViewpoint = .custom
  }

  func frameSelection() {
    guard canFrameSelection else { return }
    setCameraViewpoint(.selection)
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

  /// BR1 presentation adapter: each rotational engine DOF gets a separate
  /// proxy so RealityKit can visibly consume the exact value returned by the
  /// bridge. It deliberately does not infer a mechanism hierarchy or axis.
  /// Canonical per-part transforms arrive with the planned `resolve_pose`
  /// bridge verb, at which point this diagnostic projection is removed.
  private static func previewProject(for summary: AnimaCoreRigSummary) -> AnimaProject {
    let rotationalDegreesOfFreedom = summary.joints.flatMap { joint in
      joint.degreesOfFreedom
        .filter { $0.kind == .rotation }
        .map { (joint, $0) }
    }
    let spacingMeters = 0.42
    let centerOffset = Double(max(rotationalDegreesOfFreedom.count - 1, 0)) / 2
    let parts = rotationalDegreesOfFreedom.enumerated().map { index, pair in
      RigPartDefinition(
        displayName: pair.1.path,
        primitiveKind: index.isMultiple(of: 2) ? .cylinder : .box,
        positionMeters: RigVector3(
          x: (Double(index) - centerOffset) * spacingMeters,
          y: 0.35,
          z: 0
        )
      )
    }
    let joints = zip(rotationalDegreesOfFreedom, parts).map { pair, part in
      let degreeOfFreedom = pair.1
      let minimumRadians = degreeOfFreedom.minimum ?? degreeOfFreedom.neutral - 2 * .pi
      let maximumRadians = degreeOfFreedom.maximum ?? degreeOfFreedom.neutral + 2 * .pi
      return JointDefinition(
        id: JointID(rawValue: degreeOfFreedom.path),
        displayName: pair.0.name,
        axis: .z,
        minimumRadians: minimumRadians,
        maximumRadians: maximumRadians,
        neutralRadians: degreeOfFreedom.neutral,
        childPartID: part.id
      )
    }
    let clips = summary.clips.map { clip in
      AnimationClip(
        name: clip.name,
        durationSeconds: clip.durationSeconds,
        jointTracks: []
      )
    }
    return AnimaProject(
      name: summary.identity.displayName,
      rig: CharacterRig(parts: parts, joints: joints),
      clips: clips
    )
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
      case .asset, .part, .componentGroup, .modelNode, .joint, .animation:
        true
      case .project, .structure:
        false
      }
    }
    guard hasInspectableSelection, !activePresentation.showsInspector else { return }
    updateActivePresentation { $0.showsInspector = true }
  }
}
