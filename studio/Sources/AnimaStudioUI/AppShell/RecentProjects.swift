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

  init(
    id: UUID = UUID(),
    displayName: String,
    lastOpenedAt: Date,
    revisionNumber: Int,
    milestoneName: String? = nil,
    thumbnailKind: RecentProjectThumbnailKind = .rig,
    thumbnailPath: String? = nil
  ) {
    self.id = id
    self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.lastOpenedAt = lastOpenedAt
    self.revisionNumber = max(revisionNumber, 1)
    self.milestoneName = milestoneName
    self.thumbnailKind = thumbnailKind
    self.thumbnailPath = thumbnailPath
  }

  var revisionLabel: String {
    "V\(revisionNumber)"
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
}

enum RecentProjectsPersistence {
  static let maximumCount = 12
  static let storageKey = "animaStudio.recentProjects.v1"

  static func load(from defaults: UserDefaults = .standard) -> [RecentProjectSummary] {
    guard let data = defaults.data(forKey: storageKey),
      let decoded = try? JSONDecoder().decode([RecentProjectSummary].self, from: data)
    else { return [] }
    return normalized(decoded)
  }

  static func recordOpened(
    _ project: RecentProjectSummary,
    in current: [RecentProjectSummary],
    defaults: UserDefaults = .standard
  ) -> [RecentProjectSummary] {
    let updated = normalized([project] + current.filter { $0.id != project.id })
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
