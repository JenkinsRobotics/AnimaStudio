import AnimaCore
import Foundation
import Observation
import RealityKitViewport

enum WorkspaceMode: String, CaseIterable, Identifiable {
  case build = "Build"
  case animate = "Animate"
  case importAssets = "Import"
  case hardware = "Hardware"

  var id: Self { self }
}

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
  var mode: WorkspaceMode = .build
  var project = AnimaProject(
    name: "Untitled Character",
    rig: SampleContent.rig,
    clips: [SampleContent.clip]
  )
  var selection: NavigatorItem? = .animation(SampleContent.clip.name)
  var playheadSeconds = 0.0
  var isPlaying = false
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
    selection = .modelNode(hierarchy.id)
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
}
