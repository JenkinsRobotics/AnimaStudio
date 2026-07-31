// A project is a FOLDER, not a file — the container that holds reusable
// characters, the scenes that reference them, and imported assets:
//
//   MyProject/
//     project.json
//     characters/   rex.animachar        ← reusable rigs
//     scenes/       lobby.animascene     ← reference characters
//     assets/       wheel.step
//
// Characters live independently of any one scene, matching the engine's
// `.character.anima` / `.scene.anima` split.
import AppKit
import Foundation

/// Matches the AnimaStudio app's `project.json` (format_version 2) so projects
/// created by either app open in the other.
struct ProjectMeta: Codable, Equatable {
  var formatVersion = "2"
  var projectID = UUID().uuidString
  var displayName: String
  var revision = 1
  var createdDate = Date()
  var modifiedDate = Date()
  var assets: [String] = []
  var characters: [String] = []
  var scenes: [String] = []

  /// Convenience for call sites that just want a title.
  var name: String { displayName }

  enum CodingKeys: String, CodingKey {
    case formatVersion = "format_version"
    case projectID = "project_id"
    case displayName = "display_name"
    case revision
    case createdDate = "created_date"
    case modifiedDate = "modified_date"
    case assets, characters, scenes
  }

  init(name: String) { displayName = name }

  /// Tolerant decode: unknown/missing fields fall back rather than failing, so a
  /// project written by a newer app version still opens.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    formatVersion = (try? c.decode(String.self, forKey: .formatVersion)) ?? "2"
    projectID = (try? c.decode(String.self, forKey: .projectID)) ?? UUID().uuidString
    displayName = (try? c.decode(String.self, forKey: .displayName)) ?? "Untitled Project"
    revision = (try? c.decode(Int.self, forKey: .revision)) ?? 1
    createdDate = (try? c.decode(Date.self, forKey: .createdDate)) ?? Date()
    modifiedDate = (try? c.decode(Date.self, forKey: .modifiedDate)) ?? Date()
    assets = (try? c.decode([String].self, forKey: .assets)) ?? []
    characters = (try? c.decode([String].self, forKey: .characters)) ?? []
    scenes = (try? c.decode([String].self, forKey: .scenes)) ?? []
  }
}

struct RecentProject: Codable, Identifiable, Equatable {
  var id: String { path }
  var path: String
  var name: String
  var openedAt: Date
  var url: URL { URL(fileURLWithPath: path) }
  var exists: Bool { FileManager.default.fileExists(atPath: path) }
}

@MainActor @Observable final class StudioProject {
  static let shared = StudioProject()

  /// Matches the core app: projects live in ~/Documents/AnimaStudio.
  static let folderName = "AnimaStudio"

  /// The operator's real Documents directory (container-independent).
  static func realUserDocumentsDirectory() -> URL {
    URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
      .appendingPathComponent("Documents", isDirectory: true)
  }

  static var defaultRoot: URL {
    realUserDocumentsDirectory().appendingPathComponent(folderName, isDirectory: true)
  }

  /// A unique folder under the default root, e.g. "Untitled Project 2".
  static func uniqueDefaultURL(named base: String = "Untitled Project") -> URL {
    let root = defaultRoot
    var candidate = root.appendingPathComponent(base, isDirectory: true)
    var counter = 2
    while FileManager.default.fileExists(atPath: candidate.path) {
      candidate = root.appendingPathComponent("\(base) \(counter)", isDirectory: true)
      counter += 1
    }
    return candidate
  }

  /// Creates a project in the default location without prompting.
  @discardableResult
  func createInDefaultLocation(named base: String = "Untitled Project") throws -> URL {
    let url = Self.uniqueDefaultURL(named: base)
    try create(at: url, name: url.lastPathComponent)
    return url
  }

  /// The scene document this project autosaves into.
  var mainSceneURL: URL? { scenesURL?.appendingPathComponent("main.animascene") }

  private(set) var url: URL?
  private(set) var name = "Untitled"
  var isOpen: Bool { url != nil }

  var charactersURL: URL? { url?.appendingPathComponent("characters", isDirectory: true) }
  var scenesURL: URL? { url?.appendingPathComponent("scenes", isDirectory: true) }
  var assetsURL: URL? { url?.appendingPathComponent("assets", isDirectory: true) }

  /// Typed asset subfolders, so imports land where they belong (models/,
  /// assemblies/, audio/, …) instead of one flat pile.
  static let assetSubfolders = ["models", "assemblies", "audio", "video", "images", "scripts", "renders"]
  func assetFolder(_ kind: String) -> URL? {
    assetsURL?.appendingPathComponent(kind, isDirectory: true)
  }
  var modelsURL: URL? { assetFolder("models") }
  var assembliesURL: URL? { assetFolder("assemblies") }

  /// Makes sure the asset subfolders exist (older projects may predate them).
  func ensureAssetFolders() {
    guard let assetsURL else { return }
    for kind in Self.assetSubfolders {
      try? FileManager.default.createDirectory(
        at: assetsURL.appendingPathComponent(kind, isDirectory: true),
        withIntermediateDirectories: true)
    }
  }

  // MARK: - Lifecycle

  /// Creates the folder skeleton and its `project.json`.
  @discardableResult
  static func createSkeleton(at url: URL, name: String) throws -> ProjectMeta {
    let fm = FileManager.default
    try fm.createDirectory(at: url, withIntermediateDirectories: true)
    for child in ["characters", "scenes", "assets"] {
      try fm.createDirectory(
        at: url.appendingPathComponent(child, isDirectory: true),
        withIntermediateDirectories: true)
    }
    // Typed subfolders under assets/.
    for kind in assetSubfolders {
      try fm.createDirectory(
        at: url.appendingPathComponent("assets", isDirectory: true)
          .appendingPathComponent(kind, isDirectory: true),
        withIntermediateDirectories: true)
    }
    var meta = ProjectMeta(name: name)
    meta.modifiedDate = Date()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(meta).write(to: url.appendingPathComponent("project.json"), options: .atomic)
    return meta
  }

  static func readMeta(at url: URL) throws -> ProjectMeta {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(
      ProjectMeta.self, from: Data(contentsOf: url.appendingPathComponent("project.json")))
  }

  static func isProjectFolder(_ url: URL) -> Bool {
    let fm = FileManager.default
    if fm.fileExists(atPath: url.appendingPathComponent("project.json").path) { return true }
    // Tolerate an AnimaStudio project that only has the folder shape.
    return fm.fileExists(atPath: url.appendingPathComponent("characters").path)
      && fm.fileExists(atPath: url.appendingPathComponent("scenes").path)
  }

  func create(at url: URL, name: String) throws {
    _ = try Self.createSkeleton(at: url, name: name)
    adopt(url: url, name: name)
  }

  func open(_ url: URL) throws {
    let name = (try? Self.readMeta(at: url).name) ?? url.lastPathComponent
    adopt(url: url, name: name)
  }

  private func adopt(url: URL, name: String) {
    self.url = url
    self.name = name
    ensureAssetFolders()   // backfill typed subfolders for older projects
    DemoModel.shared.projectName = name
    RecentProjects.add(url, name: name)
  }

  func close() {
    url = nil
    name = "Untitled"
  }

  /// Documents of a given extension inside a project subfolder.
  func documents(in folder: URL?, ext: String) -> [URL] {
    guard let folder,
      let items = try? FileManager.default.contentsOfDirectory(
        at: folder, includingPropertiesForKeys: nil)
    else { return [] }
    return items.filter { $0.pathExtension == ext }.sorted { $0.lastPathComponent < $1.lastPathComponent }
  }
}

enum RecentProjects {
  private static let key = "AnimaStudioDemo.recentProjects"
  private static let limit = 8

  static func list() -> [RecentProject] {
    guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return (try? decoder.decode([RecentProject].self, from: data)) ?? []
  }

  static func add(_ url: URL, name: String) {
    var entries = list().filter { $0.path != url.path }        // de-dupe, most recent first
    entries.insert(RecentProject(path: url.path, name: name, openedAt: Date()), at: 0)
    save(Array(entries.prefix(limit)))
    UserDefaults.standard.synchronize()   // flush now — the app may be killed abruptly
  }

  static func remove(_ path: String) { save(list().filter { $0.path != path }) }
  static func clear() { UserDefaults.standard.removeObject(forKey: key) }

  /// Every project folder actually on disk under the default root, newest first.
  /// The source of truth is the filesystem — a project exists because its folder
  /// exists, not because UserDefaults happened to flush.
  @MainActor static func onDisk() -> [RecentProject] {
    let fm = FileManager.default
    guard let items = try? fm.contentsOfDirectory(
      at: StudioProject.defaultRoot,
      includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey])
    else { return [] }
    return items
      .filter { StudioProject.isProjectFolder($0) }
      .map { url in
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
          .contentModificationDate ?? Date.distantPast
        let name = (try? StudioProject.readMeta(at: url).name) ?? url.lastPathComponent
        return RecentProject(path: url.path, name: name, openedAt: modified)
      }
  }

  /// What Home shows: UserDefaults recents (for open-order/time) unioned with
  /// everything currently on disk, de-duped by path, newest first.
  @MainActor static func merged() -> [RecentProject] {
    var byPath: [String: RecentProject] = [:]
    for entry in onDisk() { byPath[entry.path] = entry }
    for entry in list() where byPath[entry.path] == nil { byPath[entry.path] = entry }
    return byPath.values.sorted { $0.openedAt > $1.openedAt }
  }

  private static func save(_ entries: [RecentProject]) {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    if let data = try? encoder.encode(entries) {
      UserDefaults.standard.set(data, forKey: key)
    }
  }
}

/// What the operator is starting from — routes to the right workspace.
enum StartArchetype: String, CaseIterable, Identifiable {
  case hardwareCharacter, digitalCharacter, showControl

  var id: String { rawValue }
  var title: String {
    switch self {
    case .hardwareCharacter: return "Hardware Character"
    case .digitalCharacter: return "Digital Character"
    case .showControl: return "Show Control"
    }
  }
  var detail: String {
    switch self {
    case .hardwareCharacter: return "Rigid components, mates, servos, and motion"
    case .digitalCharacter: return "3D avatars, faces, and expressions"
    case .showControl: return "Audio, screens, LEDs, and events"
    }
  }
  var icon: String {
    switch self {
    case .hardwareCharacter: return "figure.stand"
    case .digitalCharacter: return "person.crop.square"
    case .showControl: return "light.max"
    }
  }
  /// Where the app lands after creating the project.
  var workspace: Workspace {
    switch self {
    case .hardwareCharacter: return .character
    case .digitalCharacter: return .character
    case .showControl: return .show
    }
  }
  /// Honest about what's actually wired (mirrors the real app's roadmap note).
  var isPreview: Bool { self == .digitalCharacter }
}
