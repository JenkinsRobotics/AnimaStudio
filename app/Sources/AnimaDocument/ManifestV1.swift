import AnimaModel
import Foundation

/// Version-1 on-disk shape of `project.json`. Snake-case keys are explicit on
/// the manifest's own types; the nested AnimaModel project keeps its native
/// camel-case Codable keys so core coding stays untouched.
struct ManifestV1: Codable {
  static let formatVersion = "1"
  /// Versions this build can decode. Extend when a migration lands.
  static let supportedVersions = ["1"]

  var formatVersion: String
  var displayName: String
  var revision: Int
  var milestoneName: String?
  var modifiedDate: Date
  var project: AnimaProject
  var assets: [ManifestAsset]

  enum CodingKeys: String, CodingKey {
    case formatVersion = "format_version"
    case displayName = "display_name"
    case revision
    case milestoneName = "milestone_name"
    case modifiedDate = "modified_date"
    case project
    case assets
  }

  struct ManifestAsset: Codable {
    var id: UUID
    var originalFilename: String
    var kind: String
    /// "embedded" or "linked".
    var mode: String
    /// Package-relative payload path (embedded mode only).
    var packagePath: String?
    /// Absolute external path recorded at link time (linked mode only).
    var externalPath: String?
    /// macOS bookmark data, base64 in JSON (linked mode only).
    var bookmark: Data?

    enum CodingKeys: String, CodingKey {
      case id
      case originalFilename = "original_filename"
      case kind
      case mode
      case packagePath = "package_path"
      case externalPath = "external_path"
      case bookmark
    }
  }

  /// Minimal probe decoded before the full manifest so an unsupported version
  /// is reported as `unsupportedVersion`, not as a decoding failure.
  struct VersionProbe: Codable {
    var formatVersion: String

    enum CodingKeys: String, CodingKey {
      case formatVersion = "format_version"
    }
  }
}

enum ManifestCoding {
  /// Deterministic encoder: sorted keys + pretty printing means byte-identical
  /// manifests for identical documents.
  static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

extension ManifestV1 {
  init(document: AnimaStudioDocument, modifiedDate: Date) {
    self.formatVersion = Self.formatVersion
    self.displayName = document.project.name
    self.revision = document.metadata.revision
    self.milestoneName = document.metadata.milestoneName
    self.modifiedDate = modifiedDate
    self.project = document.project
    // Stable asset ordering: sorted by identifier.
    self.assets =
      document.assets
      .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
      .map(ManifestAsset.init(reference:))
  }

  func document() -> AnimaStudioDocument {
    AnimaStudioDocument(
      project: project,
      metadata: DocumentMetadata(
        revision: revision,
        milestoneName: milestoneName,
        modifiedDate: modifiedDate
      ),
      assets: assets.map { $0.reference() }
    )
  }
}

extension ManifestV1.ManifestAsset {
  init(reference: DocumentAssetReference) {
    self.id = reference.id.rawValue
    self.originalFilename = reference.originalFilename
    self.kind = reference.kind
    switch reference.storage {
    case .embedded(let packageRelativePath):
      self.mode = "embedded"
      self.packagePath = packageRelativePath
      self.externalPath = nil
      self.bookmark = nil
    case .linked(let externalPath, let bookmarkData):
      self.mode = "linked"
      self.packagePath = nil
      self.externalPath = externalPath
      self.bookmark = bookmarkData
    }
  }

  func reference() -> DocumentAssetReference {
    let storage: DocumentAssetStorage
    if mode == "linked" {
      storage = .linked(externalPath: externalPath ?? "", bookmarkData: bookmark)
    } else {
      storage = .embedded(packageRelativePath: packagePath ?? "")
    }
    return DocumentAssetReference(
      id: AssetID(rawValue: id),
      originalFilename: originalFilename,
      kind: kind,
      storage: storage
    )
  }
}
