import AnimaCore
import Foundation
import Observation
import RealityKitViewport

enum NavigatorItem: Hashable {
  case project
  case asset(AssetID)
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
    rig: SampleContent.rig,
    clips: [SampleContent.clip]
  )
  var selection: Set<NavigatorItem> = [.structure]
  var playheadSeconds = 0.0
  var isPlaying = false
  var showsPreviewGrid = true
  var cameraProjection: PreviewCameraProjection = .perspective
  var cameraViewpoint: PreviewCameraViewpoint = .home
  var cameraCommandRevision = 0
  var rigGuideVisibility = RigGuideVisibility()
  var importedModelURL: URL?
  var importedModelHierarchy: ModelHierarchyNode?
  var isLoadingModelHierarchy = false
  var importErrorMessage: String?

  private let evaluator = AnimationEvaluator()

  var activeClip: AnimationClip {
    project.clips.first ?? SampleContent.clip
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

  var canFrameSelection: Bool {
    switch primarySelection {
    case .modelNode, .structure, .joint:
      true
    case .project, .asset, .animation, nil:
      false
    }
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

  func renameAsset(id: AssetID, to name: String) {
    guard let index = project.assets.firstIndex(where: { $0.id == id }) else { return }
    project.assets[index].name = name
  }

  func renameJoint(id: JointID, to name: String) {
    guard let index = project.rig.joints.firstIndex(where: { $0.id == id }) else { return }
    project.rig.joints[index].displayName = name
  }

  func setJointAxis(id: JointID, to axis: JointAxis) {
    guard let index = project.rig.joints.firstIndex(where: { $0.id == id }) else { return }
    project.rig.joints[index].axis = axis
  }

  func setCameraViewpoint(_ viewpoint: PreviewCameraViewpoint) {
    cameraViewpoint = viewpoint
    cameraCommandRevision += 1
  }

  func frameSelection() {
    guard canFrameSelection else { return }
    setCameraViewpoint(selectedModelPath == nil ? .home : .selection)
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

  func advancePlayback(by seconds: Double) {
    guard isPlaying else { return }
    let nextTime = playheadSeconds + seconds
    if nextTime >= activeClip.durationSeconds {
      playheadSeconds = 0
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
