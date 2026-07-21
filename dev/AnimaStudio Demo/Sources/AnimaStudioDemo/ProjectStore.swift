// Project persistence — a JSON scene document holding the imported part sources
// plus the authored rig, clips, hardware channels, and theme.
//
// On import the operator chooses Copy (default) or Reference. Copy writes the
// file into `project/assets/` so the project is self-contained and portable
// (SolidWorks Pack-and-Go style); the stored path then points inside the
// project. Reference keeps the original path. Either way, parts are re-read from
// those paths on open — the tessellated geometry itself isn't serialised.
import AppKit
import Foundation
import GeomKit
import UniformTypeIdentifiers

struct ProjectFile: Codable, Equatable {
  var version = 1
  var name = "Untitled"
  var parts: [String] = []          // source file paths, re-imported on open
  var characters: [Character] = []  // assembly + rig, keyed by stable PartIDs
  var mates: [Mate] = []            // legacy single-character projects
  var clips: [Clip] = []
  var channels: [ServoChannel] = []
  var themeName = "Studio Blue"
}

@MainActor
enum ProjectStore {
  static var currentURL: URL?

  // MARK: - Snapshot / restore (pure enough to self-test)

  static func snapshot(name: String = "Untitled") -> ProjectFile {
    ProjectFile(
      name: name,
      parts: DemoModel.shared.parts.compactMap { $0.document.sourceURL?.path },
      characters: ProjectModel.shared.characters,
      mates: [],
      clips: AnimationModel.shared.clips,
      channels: HardwareModel.shared.channels,
      themeName: RenderState.shared.theme.name)
  }

  /// Restores everything except geometry (the caller re-imports parts).
  static func restoreState(from file: ProjectFile) {
    ProjectModel.shared.characters = file.characters
    ProjectModel.shared.activeCharacterID = file.characters.first?.id
    RigModel.shared.selectedMateID = file.characters.first?.mates.first?.id
    RigModel.shared.selectedParts = []
    AnimationModel.shared.pause()
    AnimationModel.shared.clips = file.clips.isEmpty ? [Clip(name: "Greeting")] : file.clips
    AnimationModel.shared.selectedClipID = AnimationModel.shared.clips.first?.id
    AnimationModel.shared.time = 0
    HardwareModel.shared.channels = file.channels
    HardwareModel.shared.selectedChannelID = file.channels.first?.id
    RenderState.shared.theme = .named(file.themeName)
  }

  static func encode(_ file: ProjectFile) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(file)
  }

  static func decode(_ data: Data) throws -> ProjectFile {
    try JSONDecoder().decode(ProjectFile.self, from: data)
  }

  // MARK: - Disk

  static func write(to url: URL, name: String) throws {
    try encode(snapshot(name: name)).write(to: url, options: .atomic)
    currentURL = url
  }

  static func read(from url: URL) throws -> ProjectFile {
    let file = try decode(try Data(contentsOf: url))
    currentURL = url
    return file
  }

  // MARK: - Panels

  static func save() {
    if StudioProject.shared.isOpen {
      autosave()
      DemoModel.shared.status = "Saved \(StudioProject.shared.name)"
      return
    }
    if let url = currentURL {
      try? write(to: url, name: url.deletingPathExtension().lastPathComponent)
      DemoModel.shared.status = "Saved \(url.lastPathComponent)"
      return
    }
    saveAs()
  }

  static func saveAs() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "Untitled.animastudio"
    panel.allowedContentTypes = [UTType(filenameExtension: "animastudio") ?? .json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try write(to: url, name: url.deletingPathExtension().lastPathComponent)
      DemoModel.shared.status = "Saved \(url.lastPathComponent)"
    } catch {
      DemoModel.shared.status = "Save failed — \(error.localizedDescription)"
    }
  }

  static func open() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [UTType(filenameExtension: "animastudio") ?? .json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let file = try read(from: url)
      restoreState(from: file)
      DemoModel.shared.reimport(paths: file.parts, projectName: file.name)
    } catch {
      DemoModel.shared.status = "Open failed — \(error.localizedDescription)"
    }
  }

  /// Reloads parts + state from the currently-open project's scene file. Call
  /// after `StudioProject.open(folder)` so a reopened project shows its parts.
  static func loadCurrentScene() {
    guard let url = StudioProject.shared.mainSceneURL,
      FileManager.default.fileExists(atPath: url.path)
    else {
      DemoModel.shared.reimport(paths: [], projectName: StudioProject.shared.name)
      return
    }
    do {
      let file = try read(from: url)
      restoreState(from: file)
      DemoModel.shared.reimport(paths: file.parts, projectName: StudioProject.shared.name)
    } catch {
      DemoModel.shared.status = "Open failed — \(error.localizedDescription)"
    }
  }

  /// Writes the open project's scene without prompting. Safe to call often.
  static func autosave() {
    guard let url = StudioProject.shared.mainSceneURL else { return }
    do {
      try encode(snapshot(name: StudioProject.shared.name)).write(to: url, options: .atomic)
      currentURL = url
    } catch {
      DemoModel.shared.status = "Autosave failed — \(error.localizedDescription)"
    }
  }

  static func newProject() {
    AnimationModel.shared.pause()
    DemoModel.shared.parts.removeAll()
    DemoModel.shared.selectedID = nil
    ProjectModel.shared.characters.removeAll()
    ProjectModel.shared.activeCharacterID = nil
    RigModel.shared.selectedParts = []
    RigModel.shared.selectedMateID = nil
    AnimationModel.shared.clips = [Clip(name: "Greeting", duration: 8)]
    AnimationModel.shared.selectedClipID = nil
    AnimationModel.shared.time = 0
    HardwareModel.shared.channels.removeAll()
    HardwareModel.shared.armed = false
    currentURL = nil
    DemoModel.shared.status = "New project — import a STEP file to begin"
  }
}
