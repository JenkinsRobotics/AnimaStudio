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
  static var workspaceLocation: WorkspaceLocationPreference {
    WorkspaceLocationPreference()
  }

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
    workspaceLocation.workspaceRootURL
  }

  @discardableResult
  static func ensureDefaultProjectsDirectory() throws -> URL {
    try workspaceLocation.ensureWorkspaceRootExists()
  }

  @MainActor
  static func chooseNewProjectURL(suggestedName: String = "Untitled Project") -> URL? {
    guard let rootURL = prepareWorkspaceRootForPanel() else { return nil }
    let accessed = rootURL.startAccessingSecurityScopedResource()
    defer { if accessed { rootURL.stopAccessingSecurityScopedResource() } }
    let panel = NSSavePanel()
    panel.title = "Create Anima Studio Project"
    panel.message = "Choose a name and location for the project folder."
    panel.prompt = "Create Project"
    panel.nameFieldStringValue = suggestedName
    panel.directoryURL = rootURL
    panel.canCreateDirectories = true
    panel.isExtensionHidden = true
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    if url.deletingLastPathComponent().standardizedFileURL == rootURL.standardizedFileURL {
      workspaceLocation.persistWorkspaceRoot(rootURL)
    }
    return url
  }

  @MainActor
  static func chooseProjectToOpen() -> URL? {
    guard let rootURL = prepareWorkspaceRootForPanel() else { return nil }
    let accessed = rootURL.startAccessingSecurityScopedResource()
    defer { if accessed { rootURL.stopAccessingSecurityScopedResource() } }
    let panel = NSOpenPanel()
    panel.title = "Open Anima Studio Project"
    panel.message = "Choose a project folder containing project.json."
    panel.prompt = "Open Project"
    panel.directoryURL = rootURL
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    if url.deletingLastPathComponent().standardizedFileURL == rootURL.standardizedFileURL {
      workspaceLocation.persistWorkspaceRoot(rootURL)
    }
    return url
  }

  @MainActor
  static func chooseSaveAsURL(currentName: String) -> URL? {
    guard let rootURL = prepareWorkspaceRootForPanel() else { return nil }
    let accessed = rootURL.startAccessingSecurityScopedResource()
    defer { if accessed { rootURL.stopAccessingSecurityScopedResource() } }
    let panel = NSSavePanel()
    panel.title = "Save Anima Studio Project As"
    panel.message = "Choose a new project folder name and location."
    panel.prompt = "Save As"
    panel.nameFieldStringValue = currentName
    panel.directoryURL = rootURL
    panel.canCreateDirectories = true
    panel.isExtensionHidden = true
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    if url.deletingLastPathComponent().standardizedFileURL == rootURL.standardizedFileURL {
      workspaceLocation.persistWorkspaceRoot(rootURL)
    }
    return url
  }

  @MainActor
  private static func prepareWorkspaceRootForPanel() -> URL? {
    do {
      return try workspaceLocation.preparedPanelDirectory()
    } catch {
      if workspaceLocation.usesDefaultWorkspaceRoot {
        do {
          return try workspaceLocation.requestDefaultWorkspaceRootAccess()
        } catch {
          return showWorkspacePreparationError(error)
        }
      }
      return showWorkspacePreparationError(error)
    }
  }

  @MainActor
  private static func showWorkspacePreparationError(_ error: Error) -> URL? {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "Anima Studio Could Not Prepare the Project Folder"
    alert.informativeText =
      "The default project location could not be created. Choose another location in Settings → Workspace, then try again.\n\n\(error.localizedDescription)"
    alert.addButton(withTitle: "OK")
    alert.runModal()
    return nil
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
    guard let url = recent.resolvedProjectURL() else {
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
