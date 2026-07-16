import AnimaModel
import Foundation

/// Document-level metadata persisted in the manifest alongside the project.
public struct DocumentMetadata: Equatable, Sendable {
  /// Save counter, starting at 0 for a never-saved document. Each successful
  /// save increments it; the recents gallery renders it as a "V12"-style badge.
  public var revision: Int
  /// Optional user-named milestone (e.g. "First servo test").
  public var milestoneName: String?
  /// Wall-clock time of the last successful save, whole seconds (ISO-8601 in
  /// the manifest). `nil` until first save.
  public var modifiedDate: Date?

  public init(revision: Int = 0, milestoneName: String? = nil, modifiedDate: Date? = nil) {
    self.revision = revision
    self.milestoneName = milestoneName
    self.modifiedDate = modifiedDate
  }
}

/// The in-memory value of one `.animastudio` package: the AnimaModel project,
/// the document metadata, and the asset storage table.
public struct AnimaStudioDocument: Equatable, Sendable {
  public var project: AnimaProject
  public var metadata: DocumentMetadata
  /// Storage table for reference files, keyed by the same `AssetID` space as
  /// `project.assets`. Order is not meaningful; encoding sorts by ID.
  public var assets: [DocumentAssetReference]

  public init(
    project: AnimaProject,
    metadata: DocumentMetadata = DocumentMetadata(),
    assets: [DocumentAssetReference] = []
  ) {
    self.project = project
    self.metadata = metadata
    self.assets = assets
  }

  /// The name shown in window titles and the recents gallery.
  /// Projection of `project.name` — the core project owns this truth.
  public var displayName: String { project.name }
}
