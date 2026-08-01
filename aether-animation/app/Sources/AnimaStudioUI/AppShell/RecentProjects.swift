import AnimaDocument
import Foundation

enum RecentProjectThumbnailKind: String, Codable, CaseIterable, Sendable {
  case rig
  case character
  case show

  var systemImage: String {
    switch self {
    case .rig: "cube.transparent"
    case .character: "figure.wave"
    case .show: "lightbulb.led.wide"
    }
  }
}

struct RecentProjectSummary: Codable, Equatable, Identifiable, Sendable {
  let id: UUID
  var displayName: String
  var lastOpenedAt: Date
  var revisionNumber: Int
  var milestoneName: String?
  var thumbnailKind: RecentProjectThumbnailKind
  var thumbnailPath: String?
  var projectPath: String?
  var bookmarkData: Data?

  init(
    id: UUID = UUID(),
    displayName: String,
    lastOpenedAt: Date,
    revisionNumber: Int,
    milestoneName: String? = nil,
    thumbnailKind: RecentProjectThumbnailKind = .rig,
    thumbnailPath: String? = nil,
    projectPath: String? = nil,
    bookmarkData: Data? = nil
  ) {
    self.id = id
    self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.lastOpenedAt = lastOpenedAt
    self.revisionNumber = max(revisionNumber, 1)
    self.milestoneName = milestoneName
    self.thumbnailKind = thumbnailKind
    self.thumbnailPath = thumbnailPath
    self.projectPath = projectPath
    self.bookmarkData = bookmarkData
  }

  var revisionLabel: String {
    "V\(revisionNumber)"
  }

  var canOpen: Bool {
    projectPath != nil || bookmarkData != nil
  }

  func resolvedProjectURL(fileManager: FileManager = .default) -> URL? {
    if let bookmarkData {
      var isStale = false
      if let bookmarkedURL = try? URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      ), !isStale, Self.isExistingDirectory(bookmarkedURL, fileManager: fileManager) {
        return bookmarkedURL
      }
    }

    guard let projectPath else { return nil }
    let pathURL = URL(fileURLWithPath: projectPath, isDirectory: true)
    return Self.isExistingDirectory(pathURL, fileManager: fileManager) ? pathURL : nil
  }

  static func project(_ session: StudioProjectSession, openedAt: Date = Date()) -> Self {
    Self(
      id: session.document.projectID,
      displayName: session.document.displayName,
      lastOpenedAt: openedAt,
      revisionNumber: session.document.metadata.revision,
      milestoneName: session.document.metadata.milestoneName,
      thumbnailKind: .rig,
      projectPath: session.projectURL.path,
      bookmarkData: session.bookmarkData
    )
  }

  static func scratch(lastOpenedAt: Date = Date()) -> Self {
    Self(
      id: UUID(uuidString: "A11A0000-0000-4000-8000-000000000001")!,
      displayName: "Untitled Character",
      lastOpenedAt: lastOpenedAt,
      revisionNumber: 1,
      thumbnailKind: .rig
    )
  }

  private static func isExistingDirectory(_ url: URL, fileManager: FileManager) -> Bool {
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        url.stopAccessingSecurityScopedResource()
      }
    }

    var isDirectory: ObjCBool = false
    return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
      && isDirectory.boolValue
  }
}

enum RecentProjectsPersistence {
  static let maximumCount = 12
  static let storageKey = "animaStudio.recentProjects.v2"
  static let legacyStorageKey = "animaStudio.recentProjects.v1"

  static func load(from defaults: UserDefaults = .standard) -> [RecentProjectSummary] {
    guard let data = defaults.data(forKey: storageKey) ?? defaults.data(forKey: legacyStorageKey),
      let decoded = try? JSONDecoder().decode([RecentProjectSummary].self, from: data)
    else { return [] }

    let normalizedProjects = normalized(decoded)
    let resolvableProjects = normalizedProjects.filter { $0.resolvedProjectURL() != nil }
    if resolvableProjects != normalizedProjects {
      save(resolvableProjects, to: defaults)
    }
    return resolvableProjects
  }

  static func recordOpened(
    _ project: RecentProjectSummary,
    in current: [RecentProjectSummary],
    defaults: UserDefaults = .standard
  ) -> [RecentProjectSummary] {
    let updated = normalized([project] + current.filter { $0.id != project.id })
      .filter { $0.resolvedProjectURL() != nil }
    save(updated, to: defaults)
    return updated
  }

  @discardableResult
  static func remove(
    id: RecentProjectSummary.ID,
    from defaults: UserDefaults = .standard
  ) -> [RecentProjectSummary] {
    let updated = load(from: defaults).filter { $0.id != id }
    save(updated, to: defaults)
    return updated
  }

  static func save(
    _ projects: [RecentProjectSummary],
    to defaults: UserDefaults = .standard
  ) {
    guard let data = try? JSONEncoder().encode(normalized(projects)) else { return }
    defaults.set(data, forKey: storageKey)
  }

  /// Reconciles the explicit recent-project store with projects that are
  /// physically present in the selected Studio workspace root. A project can
  /// therefore return to Home after the preferences store is reset without
  /// requiring a second Open operation.
  static func mergedWithDiscoveredProjects(
    _ stored: [RecentProjectSummary],
    in workspaceRootURL: URL,
    fileManager: FileManager = .default,
    documentStore: AnimaDocumentStore = AnimaDocumentStore()
  ) -> [RecentProjectSummary] {
    let accessed = workspaceRootURL.startAccessingSecurityScopedResource()
    defer { if accessed { workspaceRootURL.stopAccessingSecurityScopedResource() } }

    let properties: Set<URLResourceKey> = [
      .isDirectoryKey, .contentModificationDateKey,
    ]
    let children =
      (try? fileManager.contentsOfDirectory(
        at: workspaceRootURL,
        includingPropertiesForKeys: Array(properties),
        options: [.skipsHiddenFiles]
      )) ?? []
    let discovered = children.compactMap { projectURL -> RecentProjectSummary? in
      let values = try? projectURL.resourceValues(forKeys: properties)
      guard values?.isDirectory == true,
        fileManager.fileExists(
          atPath: projectURL.appendingPathComponent(AnimaDocumentStore.manifestFilename).path
        ),
        let document = try? documentStore.load(from: projectURL)
      else { return nil }

      return RecentProjectSummary(
        id: document.projectID,
        displayName: document.displayName,
        lastOpenedAt: document.metadata.modifiedDate
          ?? values?.contentModificationDate
          ?? .distantPast,
        revisionNumber: document.metadata.revision,
        milestoneName: document.metadata.milestoneName,
        thumbnailKind: document.scenes.isEmpty ? .character : .show,
        projectPath: projectURL.path,
        bookmarkData: ProjectLifecycle.bookmark(for: projectURL)
      )
    }

    return normalized(stored + discovered)
      .filter { $0.resolvedProjectURL(fileManager: fileManager) != nil }
  }

  private static func normalized(_ projects: [RecentProjectSummary]) -> [RecentProjectSummary] {
    var seen: Set<UUID> = []
    return
      projects
      .sorted { $0.lastOpenedAt > $1.lastOpenedAt }
      .filter { seen.insert($0.id).inserted && !$0.displayName.isEmpty }
      .prefix(maximumCount)
      .map(\.self)
  }
}
