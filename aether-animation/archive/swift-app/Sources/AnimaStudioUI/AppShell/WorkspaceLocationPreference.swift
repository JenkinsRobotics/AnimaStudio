import AppKit
import Darwin
import Foundation

struct WorkspaceLocationPreference {
  static let folderName = "AnimaStudio"
  private static let legacyDefaultFolderName = "Anima Studio"

  let fileManager: FileManager
  let userDefaults: UserDefaults
  let documentsDirectory: () throws -> URL

  init(
    fileManager: FileManager = .default,
    userDefaults: UserDefaults = .standard,
    documentsDirectory: @escaping () throws -> URL = {
      WorkspaceLocationPreference.realUserDocumentsDirectory()
    }
  ) {
    self.fileManager = fileManager
    self.userDefaults = userDefaults
    self.documentsDirectory = documentsDirectory
  }

  var defaultWorkspaceRootURL: URL {
    documentsRootURL.appendingPathComponent(Self.folderName, isDirectory: true)
  }

  var workspaceRootURL: URL {
    if let bookmarkData = userDefaults.data(forKey: StudioPreferenceKey.workspaceRootBookmark) {
      var isStale = false
      if let bookmarkedURL = try? URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      ), !isStale, !isLegacyDefaultWorkspaceRoot(bookmarkedURL) {
        return bookmarkedURL.standardizedFileURL
      }
    }
    if let storedPath = userDefaults.string(forKey: StudioPreferenceKey.workspaceRootPath),
      !storedPath.isEmpty
    {
      let storedURL = URL(fileURLWithPath: storedPath, isDirectory: true)
      if !isLegacyDefaultWorkspaceRoot(storedURL) {
        return storedURL.standardizedFileURL
      }
    }
    return defaultWorkspaceRootURL.standardizedFileURL
  }

  /// Held for the whole app session (never stopped until replaced). The
  /// sandboxed app reads project meshes lazily during async rendering, long
  /// after any operation's own scoped access has stopped. Projects created
  /// under the workspace root have NO bookmark of their own, so their files
  /// are readable only through the root's security scope — without a lifetime
  /// hold the viewport shows placeholders instead of the imported geometry.
  @MainActor private static var retainedRootURL: URL?

  /// Resolve the bookmarked workspace root and hold its security-scoped access
  /// for the app session. Must access the URL returned directly from the
  /// bookmark (a `.standardizedFileURL` copy can drop the security scope).
  @MainActor @discardableResult
  func activatePersistentWorkspaceRootAccess() -> Bool {
    guard
      let bookmarkData = userDefaults.data(forKey: StudioPreferenceKey.workspaceRootBookmark)
    else { return Self.retainedRootURL != nil }
    var isStale = false
    guard
      let rootURL = try? URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
    else { return false }
    if let current = Self.retainedRootURL {
      if current == rootURL { return true }
      current.stopAccessingSecurityScopedResource()
    }
    Self.retainedRootURL = rootURL.startAccessingSecurityScopedResource() ? rootURL : nil
    return Self.retainedRootURL != nil
  }

  var usesDefaultWorkspaceRoot: Bool {
    workspaceRootURL.standardizedFileURL == defaultWorkspaceRootURL.standardizedFileURL
  }

  private var documentsRootURL: URL {
    (try? documentsDirectory())
      ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
        "Documents",
        isDirectory: true
      )
  }

  /// Returns the operator's real Documents directory, outside the app container.
  ///
  /// `FileManager.url(for: .documentDirectory, ...)` is container-relative in a
  /// sandboxed app. The user account record keeps the actual macOS home path,
  /// which the first-use folder grant authorizes this app to access.
  static func realUserDocumentsDirectory() -> URL {
    if let passwordEntry = getpwuid(getuid()),
      let homeDirectory = passwordEntry.pointee.pw_dir
    {
      return URL(fileURLWithPath: String(cString: homeDirectory), isDirectory: true)
        .appendingPathComponent("Documents", isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Documents", isDirectory: true)
  }

  private func isLegacyDefaultWorkspaceRoot(_ url: URL) -> Bool {
    let legacyRoot = documentsRootURL.appendingPathComponent(
      Self.legacyDefaultFolderName,
      isDirectory: true
    )
    return url.standardizedFileURL == legacyRoot.standardizedFileURL
  }

  @discardableResult
  func ensureWorkspaceRootExists() throws -> URL {
    let rootURL = workspaceRootURL
    let accessed = rootURL.startAccessingSecurityScopedResource()
    defer { if accessed { rootURL.stopAccessingSecurityScopedResource() } }
    try fileManager.createDirectory(
      at: rootURL,
      withIntermediateDirectories: true
    )
    return rootURL
  }

  /// Creates and returns the exact directory project panels should open in.
  ///
  /// Panel call sites use this instead of `existingPanelDirectory` so a missing
  /// first-run workspace is created rather than silently collapsing to its
  /// parent Documents folder.
  func preparedPanelDirectory() throws -> URL {
    try ensureWorkspaceRootExists()
  }

  @discardableResult
  func createWorkspaceRoot(in grantedParentURL: URL) throws -> URL {
    let rootURL =
      grantedParentURL.lastPathComponent == Self.folderName
      ? grantedParentURL
      : grantedParentURL.appendingPathComponent(Self.folderName, isDirectory: true)
    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    return rootURL
  }

  /// Requests the one-time sandbox grant needed to create the default root in
  /// the operator's real Documents folder, then bookmarks the created root.
  @MainActor
  func requestDefaultWorkspaceRootAccess() throws -> URL? {
    let panel = NSOpenPanel()
    panel.title = "Allow Anima Studio Project Access"
    panel.message =
      "Select your Documents folder. Anima Studio will create and use an AnimaStudio folder inside it."
    panel.prompt = "Allow Access"
    panel.directoryURL = Self.realUserDocumentsDirectory()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = false
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let grantedParentURL = panel.url else { return nil }

    let accessed = grantedParentURL.startAccessingSecurityScopedResource()
    defer { if accessed { grantedParentURL.stopAccessingSecurityScopedResource() } }
    let rootURL = try createWorkspaceRoot(in: grantedParentURL)
    guard let bookmarkData = Self.securityScopedBookmark(for: rootURL) else {
      throw CocoaError(.fileWriteNoPermission)
    }
    persistWorkspaceRoot(rootURL, bookmarkData: bookmarkData)

    var isStale = false
    return try URL(
      resolvingBookmarkData: bookmarkData,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )
  }

  func persistWorkspaceRoot(_ rootURL: URL, bookmarkData: Data? = nil) {
    let standardizedURL = rootURL.standardizedFileURL
    userDefaults.set(
      standardizedURL.path,
      forKey: StudioPreferenceKey.workspaceRootPath
    )
    let bookmark = bookmarkData ?? Self.securityScopedBookmark(for: standardizedURL)
    if let bookmark {
      userDefaults.set(bookmark, forKey: StudioPreferenceKey.workspaceRootBookmark)
    } else {
      userDefaults.removeObject(forKey: StudioPreferenceKey.workspaceRootBookmark)
    }
  }

  func restoreDefaultWorkspaceRoot() {
    userDefaults.removeObject(forKey: StudioPreferenceKey.workspaceRootPath)
    userDefaults.removeObject(forKey: StudioPreferenceKey.workspaceRootBookmark)
  }

  @MainActor
  func chooseWorkspaceRoot() -> URL? {
    let panel = NSOpenPanel()
    panel.title = "Choose Anima Studio Project Location"
    panel.message = "Projects created in the future will default to this folder."
    panel.prompt = "Use This Folder"
    panel.directoryURL = existingPanelDirectory
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let selectedURL = panel.url else { return nil }
    persistWorkspaceRoot(selectedURL)
    return selectedURL
  }

  var existingPanelDirectory: URL {
    var candidate = workspaceRootURL
    while !fileManager.fileExists(atPath: candidate.path),
      candidate.pathComponents.count > 1
    {
      candidate.deleteLastPathComponent()
    }
    return candidate
  }

  static func securityScopedBookmark(for url: URL) -> Data? {
    try? url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
  }
}
