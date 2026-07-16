import AnimaModel
import Foundation

/// How bookmark data is created and resolved for linked assets.
///
/// Production uses `.securityScoped` so links survive sandbox restarts.
/// The plain style exists as a documented test seam: swiftpm test runners are
/// not sandboxed, and security-scoped bookmark creation is unreliable there.
public struct BookmarkStyle: Sendable {
  public var creationOptions: URL.BookmarkCreationOptions
  public var resolutionOptions: URL.BookmarkResolutionOptions

  public init(
    creationOptions: URL.BookmarkCreationOptions,
    resolutionOptions: URL.BookmarkResolutionOptions
  ) {
    self.creationOptions = creationOptions
    self.resolutionOptions = resolutionOptions
  }

  public static let securityScoped = BookmarkStyle(
    creationOptions: [.withSecurityScope],
    resolutionOptions: [.withSecurityScope]
  )

  public static let plain = BookmarkStyle(creationOptions: [], resolutionOptions: [])
}

/// Reads and writes `.animastudio` project packages.
///
/// Package layout:
/// ```
/// MyRobot.animastudio/
///   project.json          versioned manifest (deterministic JSON)
///   Assets/               embedded asset payloads, "<uuid>-<filename>"
/// ```
///
/// Saves are atomic: the whole package is staged in a temporary directory and
/// swapped into place, so a crash mid-save never corrupts an existing package.
public struct AnimaDocumentStore: Sendable {
  static let manifestFilename = "project.json"
  static let assetsDirectoryName = "Assets"

  let bookmarkStyle: BookmarkStyle
  let now: @Sendable () -> Date

  /// - Parameters:
  ///   - bookmarkStyle: bookmark creation/resolution behavior for linked
  ///     assets. Defaults to security-scoped.
  ///   - now: clock used to stamp `modified_date` on save. Injectable so
  ///     tests can assert byte-identical output.
  public init(
    bookmarkStyle: BookmarkStyle = .securityScoped,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.bookmarkStyle = bookmarkStyle
    self.now = now
  }

  // MARK: - Save / load

  /// Atomically writes `document` to `packageURL`, bumping the revision and
  /// modified date. Returns the updated document (the caller's new in-memory
  /// state). A failed save leaves any existing package untouched.
  @discardableResult
  public func save(
    _ document: AnimaStudioDocument,
    to packageURL: URL
  ) throws -> AnimaStudioDocument {
    var updated = document
    updated.metadata.revision += 1
    // Whole seconds: ISO-8601 has no sub-second precision, and truncating
    // here keeps save → load round trips exactly equal.
    let saveDate = Date(
      timeIntervalSince1970: now().timeIntervalSince1970.rounded(.down)
    )
    updated.metadata.modifiedDate = saveDate
    // Canonical asset order (sorted by ID): the returned in-memory document
    // always equals what `load(from:)` will produce.
    updated.assets.sort { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }

    try Self.validate(assets: updated.assets)
    let manifest = ManifestV1(document: updated, modifiedDate: saveDate)
    let manifestData: Data
    do {
      manifestData = try ManifestCoding.encoder().encode(manifest)
    } catch {
      throw AnimaDocumentError.writeFailed(
        path: packageURL.path,
        detail: "Manifest encoding failed: \(error.localizedDescription)"
      )
    }

    let fileManager = FileManager.default
    let parent = packageURL.deletingLastPathComponent()
    let stagingRoot: URL
    do {
      stagingRoot = try fileManager.url(
        for: .itemReplacementDirectory,
        in: .userDomainMask,
        appropriateFor: parent,
        create: true
      )
    } catch {
      throw AnimaDocumentError.writeFailed(
        path: packageURL.path,
        detail: error.localizedDescription
      )
    }
    defer { try? fileManager.removeItem(at: stagingRoot) }

    do {
      let staging = stagingRoot.appendingPathComponent(
        packageURL.lastPathComponent,
        isDirectory: true
      )
      try fileManager.createDirectory(
        at: staging.appendingPathComponent(Self.assetsDirectoryName, isDirectory: true),
        withIntermediateDirectories: true
      )
      try manifestData.write(
        to: staging.appendingPathComponent(Self.manifestFilename)
      )

      // Carry embedded payloads from the existing package into the staged one.
      for asset in updated.assets {
        guard case .embedded(let relativePath) = asset.storage else { continue }
        try Self.validatePackageRelativePath(relativePath)
        let source = packageURL.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: source.path) else {
          throw AnimaDocumentError.missingAsset(path: relativePath)
        }
        try fileManager.copyItem(
          at: source,
          to: staging.appendingPathComponent(relativePath)
        )
      }

      if fileManager.fileExists(atPath: packageURL.path) {
        _ = try fileManager.replaceItemAt(packageURL, withItemAt: staging)
      } else {
        try fileManager.moveItem(at: staging, to: packageURL)
      }
    } catch let error as AnimaDocumentError {
      throw error
    } catch {
      throw AnimaDocumentError.writeFailed(
        path: packageURL.path,
        detail: error.localizedDescription
      )
    }
    return updated
  }

  /// Loads a package, validating version, manifest integrity, asset table
  /// consistency, and embedded payload presence.
  public func load(from packageURL: URL) throws -> AnimaStudioDocument {
    let fileManager = FileManager.default
    let manifestURL = packageURL.appendingPathComponent(Self.manifestFilename)
    guard fileManager.fileExists(atPath: manifestURL.path) else {
      throw AnimaDocumentError.packageNotFound(path: packageURL.path)
    }

    let data: Data
    do {
      data = try Data(contentsOf: manifestURL)
    } catch {
      throw AnimaDocumentError.corruptManifest(
        path: manifestURL.path,
        detail: error.localizedDescription
      )
    }

    let decoder = ManifestCoding.decoder()
    let probe: ManifestV1.VersionProbe
    do {
      probe = try decoder.decode(ManifestV1.VersionProbe.self, from: data)
    } catch {
      throw AnimaDocumentError.corruptManifest(
        path: manifestURL.path,
        detail: Self.describe(decodingError: error)
      )
    }
    guard ManifestV1.supportedVersions.contains(probe.formatVersion) else {
      throw AnimaDocumentError.unsupportedVersion(
        found: probe.formatVersion,
        supported: ManifestV1.supportedVersions
      )
    }

    let manifest: ManifestV1
    do {
      manifest = try decoder.decode(ManifestV1.self, from: data)
    } catch {
      throw AnimaDocumentError.corruptManifest(
        path: manifestURL.path,
        detail: Self.describe(decodingError: error)
      )
    }

    for asset in manifest.assets {
      try Self.validate(manifestAsset: asset, manifestPath: manifestURL.path)
    }
    let document = manifest.document()
    try Self.validate(assets: document.assets)
    for asset in document.assets {
      guard case .embedded(let relativePath) = asset.storage else { continue }
      let payload = packageURL.appendingPathComponent(relativePath)
      guard fileManager.fileExists(atPath: payload.path) else {
        throw AnimaDocumentError.missingAsset(path: relativePath)
      }
    }
    return document
  }

  // MARK: - Assets

  /// Copies the file at `sourceURL` into the package's `Assets/` directory
  /// and returns the document with the new reference appended. The manifest
  /// is not persisted until the next `save(_:to:)`.
  public func embedAsset(
    from sourceURL: URL,
    into packageURL: URL,
    document: AnimaStudioDocument,
    kind: String
  ) throws -> AnimaStudioDocument {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      throw AnimaDocumentError.missingAsset(path: sourceURL.path)
    }
    let filename = sourceURL.lastPathComponent
    try Self.validate(filename: filename)
    try Self.ensureUnique(filename: filename, id: nil, in: document.assets)

    let id = AssetID()
    let relativePath =
      "\(Self.assetsDirectoryName)/\(id.rawValue.uuidString)-\(filename)"
    let destination = packageURL.appendingPathComponent(relativePath)
    do {
      try fileManager.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try fileManager.copyItem(at: sourceURL, to: destination)
    } catch {
      throw AnimaDocumentError.writeFailed(
        path: destination.path,
        detail: error.localizedDescription
      )
    }

    var updated = document
    updated.assets.append(
      DocumentAssetReference(
        id: id,
        originalFilename: filename,
        kind: kind,
        storage: .embedded(packageRelativePath: relativePath)
      )
    )
    return updated
  }

  /// Records a link to an external file (SolidWorks-style reference part):
  /// the manifest keeps the absolute path plus bookmark data so the link
  /// survives sandbox restarts. The payload is not copied.
  public func linkAsset(
    at externalURL: URL,
    into document: AnimaStudioDocument,
    kind: String
  ) throws -> AnimaStudioDocument {
    guard FileManager.default.fileExists(atPath: externalURL.path) else {
      throw AnimaDocumentError.missingAsset(path: externalURL.path)
    }
    let filename = externalURL.lastPathComponent
    try Self.validate(filename: filename)
    try Self.ensureUnique(filename: filename, id: nil, in: document.assets)

    // A failed bookmark still records the absolute path; resolution then
    // reports .needsRelink(.missingBookmark) instead of losing the asset.
    let bookmarkData = try? externalURL.bookmarkData(
      options: bookmarkStyle.creationOptions,
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )

    var updated = document
    updated.assets.append(
      DocumentAssetReference(
        originalFilename: filename,
        kind: kind,
        storage: .linked(
          externalPath: externalURL.path,
          bookmarkData: bookmarkData
        )
      )
    )
    return updated
  }

  /// Resolves an asset reference to a readable file URL.
  ///
  /// Embedded assets throw typed errors on structural problems (traversal,
  /// missing payload). Linked assets never throw for a broken link — a stale,
  /// missing, or unresolvable bookmark is an expected user-fixable state and
  /// comes back as `.needsRelink` with the reason.
  public func resolveAsset(
    _ asset: DocumentAssetReference,
    packageURL: URL
  ) throws -> AssetResolution {
    let fileManager = FileManager.default
    switch asset.storage {
    case .embedded(let relativePath):
      try Self.validatePackageRelativePath(relativePath)
      let url = packageURL.appendingPathComponent(relativePath)
      guard fileManager.fileExists(atPath: url.path) else {
        throw AnimaDocumentError.missingAsset(path: relativePath)
      }
      return .resolved(url)

    case .linked(_, let bookmarkData):
      guard let bookmarkData else {
        return .needsRelink(.missingBookmark)
      }
      var isStale = false
      let resolved: URL
      do {
        resolved = try URL(
          resolvingBookmarkData: bookmarkData,
          options: bookmarkStyle.resolutionOptions,
          relativeTo: nil,
          bookmarkDataIsStale: &isStale
        )
      } catch {
        return .needsRelink(
          .unresolvableBookmark(detail: error.localizedDescription)
        )
      }
      if isStale {
        return .needsRelink(.staleBookmark)
      }
      guard fileManager.fileExists(atPath: resolved.path) else {
        return .needsRelink(.fileMissing(path: resolved.path))
      }
      return .resolved(resolved)
    }
  }

  // MARK: - Validation

  static func validate(assets: [DocumentAssetReference]) throws {
    var seenIDs: Set<UUID> = []
    var seenNames: Set<String> = []
    for asset in assets {
      guard seenIDs.insert(asset.id.rawValue).inserted else {
        throw AnimaDocumentError.duplicateAssetID(id: asset.id.rawValue)
      }
      guard seenNames.insert(asset.originalFilename).inserted else {
        throw AnimaDocumentError.duplicateAssetName(name: asset.originalFilename)
      }
      try validate(filename: asset.originalFilename)
      if case .embedded(let relativePath) = asset.storage {
        try validatePackageRelativePath(relativePath)
      }
    }
  }

  static func validate(
    manifestAsset: ManifestV1.ManifestAsset,
    manifestPath: String
  ) throws {
    switch manifestAsset.mode {
    case "embedded":
      guard let path = manifestAsset.packagePath, !path.isEmpty else {
        throw AnimaDocumentError.corruptManifest(
          path: manifestPath,
          detail: "Embedded asset \(manifestAsset.id.uuidString) has no package_path."
        )
      }
    case "linked":
      guard let path = manifestAsset.externalPath, !path.isEmpty else {
        throw AnimaDocumentError.corruptManifest(
          path: manifestPath,
          detail: "Linked asset \(manifestAsset.id.uuidString) has no external_path."
        )
      }
    default:
      throw AnimaDocumentError.corruptManifest(
        path: manifestPath,
        detail: "Unknown asset storage mode \"\(manifestAsset.mode)\"."
      )
    }
  }

  /// Rejects any manifest path that could escape the package. Called before
  /// the path ever touches the filesystem.
  static func validatePackageRelativePath(_ path: String) throws {
    guard !path.isEmpty, !path.hasPrefix("/") else {
      throw AnimaDocumentError.pathTraversal(path: path)
    }
    let components = path.split(separator: "/", omittingEmptySubsequences: false)
    guard
      !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
    else {
      throw AnimaDocumentError.pathTraversal(path: path)
    }
    guard components.count >= 2, components.first == "Assets" else {
      throw AnimaDocumentError.pathTraversal(path: path)
    }
  }

  /// Asset filenames must be a single, plain path component.
  static func validate(filename: String) throws {
    guard
      !filename.isEmpty,
      filename != ".", filename != "..",
      !filename.contains("/"), !filename.contains("\0")
    else {
      throw AnimaDocumentError.pathTraversal(path: filename)
    }
  }

  static func ensureUnique(
    filename: String,
    id: AssetID?,
    in assets: [DocumentAssetReference]
  ) throws {
    if let id, assets.contains(where: { $0.id == id }) {
      throw AnimaDocumentError.duplicateAssetID(id: id.rawValue)
    }
    if assets.contains(where: { $0.originalFilename == filename }) {
      throw AnimaDocumentError.duplicateAssetName(name: filename)
    }
  }

  static func describe(decodingError error: any Error) -> String {
    guard let decodingError = error as? DecodingError else {
      return error.localizedDescription
    }
    switch decodingError {
    case .dataCorrupted(let context):
      return "Data corrupted: \(context.debugDescription)"
    case .keyNotFound(let key, let context):
      return "Missing key \"\(key.stringValue)\": \(context.debugDescription)"
    case .typeMismatch(let type, let context):
      return "Type mismatch for \(type): \(context.debugDescription)"
    case .valueNotFound(let type, let context):
      return "Missing value for \(type): \(context.debugDescription)"
    @unknown default:
      return decodingError.localizedDescription
    }
  }
}
