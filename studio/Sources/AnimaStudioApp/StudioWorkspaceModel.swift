import AnimaCore
import Foundation
import Observation

enum WorkspaceMode: String, CaseIterable, Identifiable {
  case build = "Build"
  case animate = "Animate"

  var id: Self { self }
}

enum NavigatorItem: Hashable {
  case project
  case asset(AssetID)
  case structure
  case joint(JointID)
  case animation(String)
}

@MainActor
@Observable
final class StudioWorkspaceModel {
  var mode: WorkspaceMode = .animate
  var project = AnimaProject(
    name: "Untitled Character",
    rig: SampleContent.rig,
    clips: [SampleContent.clip]
  )
  var selection: NavigatorItem? = .animation(SampleContent.clip.name)
  var playheadSeconds = 0.0
  var isPlaying = false
  var importedModelURL: URL?
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

  func importModel(from url: URL) {
    guard url.isFileURL else {
      importErrorMessage = "The selected model is not a local file."
      return
    }

    _ = url.startAccessingSecurityScopedResource()
    importedModelURL = url
    importErrorMessage = nil

    let asset = ProjectAsset(
      name: url.lastPathComponent,
      kind: .model3D,
      sourcePath: url.path
    )
    project.assets.removeAll { $0.sourcePath == asset.sourcePath }
    project.assets.append(asset)
    selection = .asset(asset.id)
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
