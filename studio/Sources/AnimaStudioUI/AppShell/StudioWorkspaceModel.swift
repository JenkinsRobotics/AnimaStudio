import AnimaCore
import Foundation
import Observation
import RealityKitViewport

enum NavigatorItem: Hashable {
  case project
  case asset(AssetID)
  case part(PartID)
  case structure
  case modelNode(ModelEntityPath)
  case joint(JointID)
  case animation(String)
}

@MainActor
@Observable
final class StudioWorkspaceModel {
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
  var selection: Set<NavigatorItem> = []
  var playheadSeconds = 0.0
  var isPlaying = false
  var loopsPreviewPlayback = true
  var timelineEditorMode: TimelineEditorMode = .dopeSheet
  var timelineDisplayFramesPerSecond = 30
  var timelineZoom = 1.0
  var showsPreviewGrid = true
  var cameraProjection: PreviewCameraProjection = .perspective
  var cameraViewpoint: PreviewCameraViewpoint = .home
  var cameraCommandRevision = 0
  var rigGuideVisibility = RigGuideVisibility()
  var showsCreationPalette = true
  var importedModelURL: URL?
  var importedModelHierarchy: ModelHierarchyNode?
  var isLoadingModelHierarchy = false
  var importErrorMessage: String?

  private let evaluator = AnimationEvaluator()

  init(
    project: AnimaProject = AnimaProject(
      name: "Untitled Character",
      rig: CharacterRig(joints: []),
      clips: []
    )
  ) {
    self.project = project
  }

  var activeClip: AnimationClip {
    project.clips.first ?? SampleContent.emptyClip
  }

  var evaluatedFrame: EvaluatedFrame {
    evaluator.evaluate(
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

  var canFrameSelection: Bool {
    switch primarySelection {
    case .modelNode, .part, .structure, .joint:
      true
    case .project, .asset, .animation, nil:
      false
    }
  }

  var isRigEmpty: Bool {
    project.rig.parts.isEmpty && project.rig.joints.isEmpty
  }

  var canCreateRevoluteJoint: Bool {
    let connectedChildren = Set(project.rig.joints.compactMap(\.childPartID))
    return project.rig.parts.contains { !connectedChildren.contains($0.id) }
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
      } ?? project.rig.parts.first { !connectedChildren.contains($0.id) }
    guard let child else { return }

    let parentID = project.rig.parts.first { $0.id != child.id }?.id
    var sequence = project.rig.joints.count + 1
    while project.rig.joints.contains(where: { $0.id.rawValue == "joint_\(sequence)" }) {
      sequence += 1
    }
    let joint = JointDefinition(
      id: JointID(rawValue: "joint_\(sequence)"),
      displayName: "Joint \(sequence)",
      axis: .y,
      minimumRadians: -.pi / 2,
      maximumRadians: .pi / 2,
      parentPartID: parentID,
      childPartID: child.id
    )
    project.rig.joints.append(joint)
    selection = [.joint(joint.id)]
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
    guard let index = project.rig.parts.firstIndex(where: { $0.id == id }) else { return }
    project.rig.parts[index].displayName = name
  }

  func setPartPosition(id: PartID, to positionMeters: RigVector3) {
    guard positionMeters.x.isFinite, positionMeters.y.isFinite, positionMeters.z.isFinite,
      let index = project.rig.parts.firstIndex(where: { $0.id == id })
    else { return }
    project.rig.parts[index].positionMeters = positionMeters
  }

  func setPartRotation(id: PartID, to rotationEulerRadians: RigVector3) {
    guard rotationEulerRadians.x.isFinite, rotationEulerRadians.y.isFinite,
      rotationEulerRadians.z.isFinite,
      let index = project.rig.parts.firstIndex(where: { $0.id == id })
    else { return }
    project.rig.parts[index].rotationEulerRadians = rotationEulerRadians
  }

  func renameJoint(id: JointID, to name: String) {
    guard let index = project.rig.joints.firstIndex(where: { $0.id == id }) else { return }
    project.rig.joints[index].displayName = name
  }

  func setJointAxis(id: JointID, to axis: JointAxis) {
    guard let index = project.rig.joints.firstIndex(where: { $0.id == id }) else { return }
    project.rig.joints[index].axis = axis
  }

  func setJointRange(id: JointID, minimumRadians: Double, maximumRadians: Double) {
    guard minimumRadians.isFinite, maximumRadians.isFinite,
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

  func setCameraViewpoint(_ viewpoint: PreviewCameraViewpoint) {
    cameraViewpoint = viewpoint
    cameraCommandRevision += 1
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

  private func updateActivePresentation(
    _ update: (inout WorkspacePresentation) -> Void
  ) {
    var presentation = activePresentation
    update(&presentation)
    workspacePresentations[activeWorkspace] = presentation
  }
}
