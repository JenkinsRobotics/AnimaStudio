import AnimaDocument
import AnimaModel
import AppKit
import Foundation

enum ProjectLifecycleError: LocalizedError, Equatable {
  case noCharacterLoaded
  case recentProjectUnavailable

  var errorDescription: String? {
    switch self {
    case .noCharacterLoaded:
      "No AnimaCore character is loaded to save."
    case .recentProjectUnavailable:
      "This recent project folder is no longer available. Locate it with Open Project."
    }
  }
}

struct StudioProjectSession: Equatable {
  var document: AnimaStudioDocument
  var projectURL: URL
  var bookmarkData: Data?
  var isDirty: Bool

  init(
    document: AnimaStudioDocument,
    projectURL: URL,
    bookmarkData: Data? = nil,
    isDirty: Bool = false
  ) {
    self.document = document
    self.projectURL = projectURL
    self.bookmarkData = bookmarkData
    self.isDirty = isDirty
  }

  func resolvedProjectURL() throws -> URL {
    guard let bookmarkData else { return projectURL }
    var stale = false
    if let resolved = try? URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    ), !stale {
      return resolved
    }
    guard FileManager.default.fileExists(atPath: projectURL.path) else {
      throw ProjectLifecycleError.recentProjectUnavailable
    }
    return projectURL
  }
}

enum ProjectLifecycle {
  static let store = AnimaDocumentStore()

  static func makeEmptyDocument(name: String) -> AnimaStudioDocument {
    AnimaStudioDocument(
      project: AnimaProject(
        name: name,
        rig: CharacterRig(parts: [], joints: []),
        clips: []
      )
    )
  }

  static func defaultProjectsDirectory() -> URL {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documents.appendingPathComponent("Anima Studio", isDirectory: true)
  }

  @MainActor
  static func chooseNewProjectURL(suggestedName: String = "Untitled Project") -> URL? {
    let panel = NSSavePanel()
    panel.title = "Create Anima Studio Project"
    panel.message = "Choose a name and location for the project folder."
    panel.prompt = "Create Project"
    panel.nameFieldStringValue = suggestedName
    panel.directoryURL = defaultProjectsDirectory()
    panel.canCreateDirectories = true
    panel.isExtensionHidden = true
    return panel.runModal() == .OK ? panel.url : nil
  }

  @MainActor
  static func chooseProjectToOpen() -> URL? {
    let panel = NSOpenPanel()
    panel.title = "Open Anima Studio Project"
    panel.message = "Choose a project folder containing project.json."
    panel.prompt = "Open Project"
    panel.directoryURL = defaultProjectsDirectory()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    return panel.runModal() == .OK ? panel.url : nil
  }

  @MainActor
  static func chooseSaveAsURL(currentName: String) -> URL? {
    let panel = NSSavePanel()
    panel.title = "Save Anima Studio Project As"
    panel.message = "Choose a new project folder name and location."
    panel.prompt = "Save As"
    panel.nameFieldStringValue = currentName
    panel.directoryURL = defaultProjectsDirectory()
    panel.canCreateDirectories = true
    panel.isExtensionHidden = true
    return panel.runModal() == .OK ? panel.url : nil
  }

  static func createProject(at url: URL) throws -> StudioProjectSession {
    let accessed = url.startAccessingSecurityScopedResource()
    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
    var document = makeEmptyDocument(name: url.lastPathComponent)
    document = try store.save(document, to: url)
    return StudioProjectSession(
      document: document,
      projectURL: url,
      bookmarkData: bookmark(for: url)
    )
  }

  static func openProject(at url: URL) throws -> StudioProjectSession {
    let accessed = url.startAccessingSecurityScopedResource()
    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
    return StudioProjectSession(
      document: try store.load(from: url),
      projectURL: url,
      bookmarkData: bookmark(for: url)
    )
  }

  static func openRecent(_ recent: RecentProjectSummary) throws -> StudioProjectSession {
    let url: URL
    if let bookmarkData = recent.bookmarkData {
      var stale = false
      url = try URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &stale
      )
      if stale { throw ProjectLifecycleError.recentProjectUnavailable }
    } else if let path = recent.projectPath {
      url = URL(fileURLWithPath: path, isDirectory: true)
    } else {
      throw ProjectLifecycleError.recentProjectUnavailable
    }
    return try openProject(at: url)
  }

  static func bookmark(for url: URL) -> Data? {
    try? url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
  }
}
