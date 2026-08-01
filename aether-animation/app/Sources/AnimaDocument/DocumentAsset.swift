import AnimaModel
import Foundation

/// Typed, project-owned asset destinations. These names are part of the
/// on-disk project layout and therefore stay stable across UI revisions.
public enum ProjectAssetFolder: String, CaseIterable, Codable, Sendable {
  case models
  case assemblies
  case audio
  case video
  case images
  case scripts
  case renders

  public var relativeDirectoryPath: String { "assets/\(rawValue)" }
}

/// The only two non-destructive import choices offered by Studio.
public enum AssetImportMode: String, CaseIterable, Codable, Sendable {
  case copyIntoProject
  case referenceInPlace
}

/// How an asset's payload is stored relative to the package —
/// the SolidWorks-assembly property: a project either carries a copy of a
/// reference file inside itself or links to an external file on disk.
public enum DocumentAssetStorage: Equatable, Sendable {
  /// The payload was copied into the package. The path is package-relative
  /// and normally lives under a typed `assets/<kind>/` directory. Legacy
  /// projects may still contain character-local embedded paths.
  case embedded(packageRelativePath: String)
  /// The payload lives outside the package. `externalPath` is the absolute
  /// path recorded at link time; `bookmarkData` is a macOS bookmark so the
  /// link survives moves and sandbox restarts. Either may go stale — resolve
  /// through `AnimaDocumentStore.resolveAsset(_:packageURL:)`.
  case linked(externalPath: String, bookmarkData: Data?)
}

/// One row of the document's asset table. Keyed by the same `AssetID` used by
/// `AnimaModel.ProjectAsset`, so the document layer stores *where the bytes
/// live* while the core project keeps owning what the asset *means*.
public struct DocumentAssetReference: Identifiable, Equatable, Sendable {
  public let id: AssetID
  /// The filename the asset had at import time (a single path component).
  public var originalFilename: String
  /// Free-form category string, e.g. "model3D", "audio", "image".
  public var kind: String
  public var storage: DocumentAssetStorage

  public init(
    id: AssetID = AssetID(),
    originalFilename: String,
    kind: String,
    storage: DocumentAssetStorage
  ) {
    self.id = id
    self.originalFilename = originalFilename
    self.kind = kind
    self.storage = storage
  }
}

/// Why a linked asset could not be resolved to a live file.
public enum AssetRelinkReason: Equatable, Sendable {
  /// The manifest carries no bookmark data for this link.
  case missingBookmark
  /// Bookmark data exists but the system reports it stale.
  case staleBookmark
  /// Bookmark data exists but cannot be resolved at all.
  case unresolvableBookmark(detail: String)
  /// Resolution produced a path, but no file exists there.
  case fileMissing(path: String)
}

/// Result of resolving an asset reference to a readable file.
public enum AssetResolution: Equatable, Sendable {
  case resolved(URL)
  /// The link is broken; the user must pick the file again.
  case needsRelink(AssetRelinkReason)
}
