import Foundation

/// App-only rendering metadata stored beside one canonical character file.
/// Mesh unit interpretation is deliberately absent from `.character.anima`;
/// the engine treats model references as opaque paths.
public struct CharacterEditorMetadata: Codable, Equatable, Sendable {
  public static let currentFormatVersion = "5"

  public var formatVersion: String
  public var modelImports: [String: ModelImportMetadata]
  /// Simple asset replacement counter keyed by engine part name. V1 is the
  /// initial import; each successful re-upload/replacement increments it.
  /// This is intentionally not a PDM or history system.
  public var partAssetVersions: [String: Int]
  public var partAppearances: [String: CharacterPartAppearanceMetadata]
  public var tree: CharacterTreeMetadata
  public var viewport: CharacterViewportMetadata

  public init(
    formatVersion: String = Self.currentFormatVersion,
    modelImports: [String: ModelImportMetadata] = [:],
    partAssetVersions: [String: Int] = [:],
    partAppearances: [String: CharacterPartAppearanceMetadata] = [:],
    tree: CharacterTreeMetadata = CharacterTreeMetadata(),
    viewport: CharacterViewportMetadata = CharacterViewportMetadata()
  ) {
    self.formatVersion = formatVersion
    self.modelImports = modelImports
    self.partAssetVersions = partAssetVersions
    self.partAppearances = partAppearances
    self.tree = tree
    self.viewport = viewport
  }

  enum CodingKeys: String, CodingKey {
    case formatVersion = "format_version"
    case modelImports = "model_imports"
    case partAssetVersions = "part_asset_versions"
    case partAppearances = "part_appearances"
    case tree
    case viewport
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    formatVersion = try container.decodeIfPresent(String.self, forKey: .formatVersion) ?? "1"
    modelImports =
      try container.decodeIfPresent([String: ModelImportMetadata].self, forKey: .modelImports)
      ?? [:]
    partAssetVersions =
      try container.decodeIfPresent([String: Int].self, forKey: .partAssetVersions)
      ?? [:]
    partAppearances =
      try container.decodeIfPresent(
        [String: CharacterPartAppearanceMetadata].self,
        forKey: .partAppearances
      ) ?? [:]
    tree =
      try container.decodeIfPresent(CharacterTreeMetadata.self, forKey: .tree)
      ?? CharacterTreeMetadata()
    viewport =
      try container.decodeIfPresent(CharacterViewportMetadata.self, forKey: .viewport)
      ?? CharacterViewportMetadata()
  }

  public static func decode(_ data: Data) throws -> Self {
    try JSONDecoder().decode(Self.self, from: data)
  }

  public func encodedData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(self)
    data.append(0x0A)
    return data
  }
}

public struct CharacterViewportColorMetadata: Codable, Equatable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double

  public init(red: Double, green: Double, blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }
}

public struct CharacterNamedViewMetadata: Codable, Equatable, Sendable {
  public var id: UUID
  public var name: String
  public var projection: String
  public var direction: [Double]
  public var rollRadians: Double
  public var target: [Double]
  public var distance: Double
  public var orthographicScale: Double

  public init(
    id: UUID = UUID(), name: String, projection: String, direction: [Double],
    rollRadians: Double, target: [Double], distance: Double, orthographicScale: Double
  ) {
    self.id = id
    self.name = name
    self.projection = projection
    self.direction = direction
    self.rollRadians = rollRadians
    self.target = target
    self.distance = distance
    self.orthographicScale = orthographicScale
  }

  enum CodingKeys: String, CodingKey {
    case id, name, projection, direction, target, distance
    case rollRadians = "roll_radians"
    case orthographicScale = "orthographic_scale"
  }
}

public struct CharacterViewportMetadata: Codable, Equatable, Sendable {
  public var backgroundMode: String
  public var appearancePreset: String
  public var primaryColor: CharacterViewportColorMetadata
  public var secondaryColor: CharacterViewportColorMetadata
  public var sectionEnabled: Bool
  public var sectionAxis: String
  public var sectionPositionMeters: Double
  public var namedViews: [CharacterNamedViewMetadata]

  public init(
    backgroundMode: String = "preset",
    appearancePreset: String = "midnight",
    primaryColor: CharacterViewportColorMetadata = .init(red: 0.035, green: 0.05, blue: 0.095),
    secondaryColor: CharacterViewportColorMetadata = .init(red: 0.12, green: 0.18, blue: 0.30),
    sectionEnabled: Bool = false,
    sectionAxis: String = "x",
    sectionPositionMeters: Double = 0,
    namedViews: [CharacterNamedViewMetadata] = []
  ) {
    self.backgroundMode = backgroundMode
    self.appearancePreset = appearancePreset
    self.primaryColor = primaryColor
    self.secondaryColor = secondaryColor
    self.sectionEnabled = sectionEnabled
    self.sectionAxis = sectionAxis
    self.sectionPositionMeters = sectionPositionMeters
    self.namedViews = namedViews
  }

  enum CodingKeys: String, CodingKey {
    case backgroundMode = "background_mode"
    case appearancePreset = "appearance_preset"
    case primaryColor = "primary_color"
    case secondaryColor = "secondary_color"
    case sectionEnabled = "section_enabled"
    case sectionAxis = "section_axis"
    case sectionPositionMeters = "section_position_m"
    case namedViews = "named_views"
  }
}

/// Per-part PBR/view override keyed by the engine part name. These values are
/// deliberately absent from `.character.anima`: they do not affect a solve.
public struct CharacterPartAppearanceMetadata: Codable, Equatable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double
  public var opacity: Double
  public var isVisible: Bool
  public var finish: String
  public var proxyFilletRadiusMeters: Double
  public var renderSettings: [String: String]

  public init(
    red: Double,
    green: Double,
    blue: Double,
    opacity: Double = 1,
    isVisible: Bool = true,
    finish: String = "satin",
    proxyFilletRadiusMeters: Double = 0,
    renderSettings: [String: String] = ["tessellation_quality": "automatic"]
  ) {
    self.red = red
    self.green = green
    self.blue = blue
    self.opacity = opacity
    self.isVisible = isVisible
    self.finish = finish
    self.proxyFilletRadiusMeters = proxyFilletRadiusMeters
    self.renderSettings = renderSettings
  }

  enum CodingKeys: String, CodingKey {
    case red
    case green
    case blue
    case opacity
    case isVisible = "visible"
    case finish
    case proxyFilletRadiusMeters = "proxy_fillet_radius_m"
    case renderSettings = "render_settings"
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    red = try container.decode(Double.self, forKey: .red)
    green = try container.decode(Double.self, forKey: .green)
    blue = try container.decode(Double.self, forKey: .blue)
    opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
    isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
    finish = try container.decodeIfPresent(String.self, forKey: .finish) ?? "satin"
    proxyFilletRadiusMeters =
      try container.decodeIfPresent(Double.self, forKey: .proxyFilletRadiusMeters) ?? 0
    renderSettings =
      try container.decodeIfPresent([String: String].self, forKey: .renderSettings)
      ?? ["tessellation_quality": "automatic"]
  }
}

public struct CharacterTreeMetadata: Codable, Equatable, Sendable {
  public var groups: [CharacterTreeGroupMetadata]
  public var lockedPartNames: [String]
  public var lockedMateIDs: [String]
  public var expandedNodeKeys: [String]
  public var partOrder: [String]
  public var mateOrder: [String]

  public init(
    groups: [CharacterTreeGroupMetadata] = [],
    lockedPartNames: [String] = [],
    lockedMateIDs: [String] = [],
    expandedNodeKeys: [String] = [],
    partOrder: [String] = [],
    mateOrder: [String] = []
  ) {
    self.groups = groups
    self.lockedPartNames = lockedPartNames
    self.lockedMateIDs = lockedMateIDs
    self.expandedNodeKeys = expandedNodeKeys
    self.partOrder = partOrder
    self.mateOrder = mateOrder
  }

  enum CodingKeys: String, CodingKey {
    case groups
    case lockedPartNames = "locked_parts"
    case lockedMateIDs = "locked_mates"
    case expandedNodeKeys = "expanded_nodes"
    case partOrder = "part_order"
    case mateOrder = "mate_order"
  }
}

public struct CharacterTreeGroupMetadata: Codable, Equatable, Sendable {
  public var id: UUID
  public var displayName: String
  public var partNames: [String]
  public var isLocked: Bool

  public init(
    id: UUID = UUID(),
    displayName: String,
    partNames: [String],
    isLocked: Bool = false
  ) {
    self.id = id
    self.displayName = displayName
    self.partNames = partNames
    self.isLocked = isLocked
  }

  enum CodingKeys: String, CodingKey {
    case id
    case displayName = "display_name"
    case partNames = "parts"
    case isLocked = "locked"
  }
}

public struct ModelImportMetadata: Codable, Equatable, Sendable {
  public var unitName: String
  public var unitScaleToMeters: Double

  public init(unitName: String, unitScaleToMeters: Double) {
    self.unitName = unitName
    self.unitScaleToMeters = unitScaleToMeters
  }
}
