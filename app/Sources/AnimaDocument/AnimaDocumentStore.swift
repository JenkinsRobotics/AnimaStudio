import AnimaModel
import Foundation

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

/// Filesystem owner for a plain-folder Anima Studio project.
///
/// The store never parses or authors `.anima` content. Callers obtain that
/// text from AnimaCore and pass it as `ProjectFileWrite` values so the engine
/// document and app manifest land in one atomic directory replacement.
public struct AnimaDocumentStore: Sendable {
  public static let manifestFilename = "project.json"
  public static let charactersDirectoryName = "characters"
  public static let scenesDirectoryName = "scenes"
  public static let assetsDirectoryName = "assets"
  public static let assetFolders = ProjectAssetFolder.allCases

  let bookmarkStyle: BookmarkStyle
  let now: @Sendable () -> Date

  public init(
    bookmarkStyle: BookmarkStyle = .securityScoped,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.bookmarkStyle = bookmarkStyle
    self.now = now
  }

  @discardableResult
  public func save(
    _ document: AnimaStudioDocument,
    to projectURL: URL,
    fileWrites: [ProjectFileWrite] = []
  ) throws -> AnimaStudioDocument {
    try write(
      document,
      sourceProjectURL: projectURL,
      destinationProjectURL: projectURL,
      fileWrites: fileWrites
    )
  }

  /// Copies an existing project to `destinationURL`, applies current dirty
  /// engine/editor documents, increments revision, and returns the retargeted
  /// document state. The source project is never modified.
  @discardableResult
  public func saveAs(
    _ document: AnimaStudioDocument,
    from sourceURL: URL,
    to destinationURL: URL,
    fileWrites: [ProjectFileWrite] = []
  ) throws -> AnimaStudioDocument {
    try write(
      document,
      sourceProjectURL: sourceURL,
      destinationProjectURL: destinationURL,
      fileWrites: fileWrites
    )
  }

  private func write(
    _ document: AnimaStudioDocument,
    sourceProjectURL: URL,
    destinationProjectURL: URL,
    fileWrites: [ProjectFileWrite]
  ) throws -> AnimaStudioDocument {
    var updated = document
    updated.metadata.revision += 1
    let saveDate = Self.wholeSecond(now())
    let createdDate = updated.metadata.createdDate ?? saveDate
    updated.metadata.createdDate = createdDate
    updated.metadata.modifiedDate = saveDate
    updated.characters.sort { $0.folderName < $1.folderName }
    updated.scenes.sort { $0.name < $1.name }
    updated.assets.sort { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }

    try Self.validate(document: updated)
    for fileWrite in fileWrites {
      try Self.validateProjectRelativePath(fileWrite.relativePath)
    }

    let manifest = ManifestV2(
      document: updated,
      createdDate: createdDate,
      modifiedDate: saveDate
    )
    let manifestData: Data
    do {
      manifestData = try ManifestCoding.encoder().encode(manifest)
    } catch {
      throw AnimaDocumentError.writeFailed(
        path: destinationProjectURL.path,
        detail: "Manifest encoding failed: \(error.localizedDescription)"
      )
    }

    let fileManager = FileManager.default
    let parent = destinationProjectURL.deletingLastPathComponent()
    try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
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
        path: destinationProjectURL.path,
        detail: error.localizedDescription
      )
    }
    defer { try? fileManager.removeItem(at: stagingRoot) }

    do {
      let staging = stagingRoot.appendingPathComponent(
        destinationProjectURL.lastPathComponent,
        isDirectory: true
      )
      if fileManager.fileExists(atPath: sourceProjectURL.path) {
        try fileManager.copyItem(at: sourceProjectURL, to: staging)
      } else {
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
      }
      try fileManager.createDirectory(
        at: staging.appendingPathComponent(Self.charactersDirectoryName, isDirectory: true),
        withIntermediateDirectories: true
      )
      try fileManager.createDirectory(
        at: staging.appendingPathComponent(Self.scenesDirectoryName, isDirectory: true),
        withIntermediateDirectories: true
      )
      try Self.ensureProjectDirectories(at: staging, fileManager: fileManager)
      for character in updated.characters {
        let directory = staging.appendingPathComponent(
          character.directoryPath,
          isDirectory: true
        )
        try fileManager.createDirectory(
          at: directory.appendingPathComponent("assets", isDirectory: true),
          withIntermediateDirectories: true
        )
      }
      for fileWrite in fileWrites {
        let fileURL = staging.appendingPathComponent(fileWrite.relativePath)
        try fileManager.createDirectory(
          at: fileURL.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        try fileWrite.data.write(to: fileURL)
      }
      try manifestData.write(
        to: staging.appendingPathComponent(Self.manifestFilename)
      )
      try Self.validateIndexedFiles(of: updated, in: staging)

      if fileManager.fileExists(atPath: destinationProjectURL.path) {
        _ = try fileManager.replaceItemAt(destinationProjectURL, withItemAt: staging)
      } else {
        try fileManager.moveItem(at: staging, to: destinationProjectURL)
      }
    } catch let error as AnimaDocumentError {
      throw error
    } catch {
      throw AnimaDocumentError.writeFailed(
        path: destinationProjectURL.path,
        detail: error.localizedDescription
      )
    }
    return updated
  }

  public func load(from projectURL: URL) throws -> AnimaStudioDocument {
    let fileManager = FileManager.default
    let manifestURL = projectURL.appendingPathComponent(Self.manifestFilename)
    guard fileManager.fileExists(atPath: manifestURL.path) else {
      throw AnimaDocumentError.packageNotFound(path: projectURL.path)
    }

    // Opening is also the migration point for the folder-only project
    // skeleton. Older format-v2 projects remain valid; missing typed asset
    // directories are backfilled without rewriting project.json.
    try Self.ensureProjectDirectories(at: projectURL, fileManager: fileManager)

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
    let probe: ManifestV2.VersionProbe
    do {
      probe = try decoder.decode(ManifestV2.VersionProbe.self, from: data)
    } catch {
      throw AnimaDocumentError.corruptManifest(
        path: manifestURL.path,
        detail: Self.describe(decodingError: error)
      )
    }
    guard ManifestV2.supportedVersions.contains(probe.formatVersion) else {
      throw AnimaDocumentError.unsupportedVersion(
        found: probe.formatVersion,
        supported: ManifestV2.supportedVersions
      )
    }

    let manifest: ManifestV2
    do {
      manifest = try decoder.decode(ManifestV2.self, from: data)
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
    try Self.validate(document: document)
    try Self.validateIndexedFiles(of: document, in: projectURL)
    for asset in document.assets {
      guard case .embedded(let relativePath) = asset.storage else { continue }
      guard fileManager.fileExists(atPath: projectURL.appendingPathComponent(relativePath).path)
      else {
        throw AnimaDocumentError.missingAsset(path: relativePath)
      }
    }
    return document
  }

  /// Copies an operator-owned source into the project's typed Pack-and-Go
  /// asset store. The source is never moved or modified.
  public func embedAsset(
    from sourceURL: URL,
    into projectURL: URL,
    document: AnimaStudioDocument,
    folder: ProjectAssetFolder,
    kind: String
  ) throws -> AnimaStudioDocument {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      throw AnimaDocumentError.missingAsset(path: sourceURL.path)
    }
    let requestedFilename = sourceURL.lastPathComponent
    try Self.validate(filename: requestedFilename)
    let filename = Self.availableAssetFilename(
      requestedFilename,
      folder: folder,
      document: document,
      projectURL: projectURL
    )
    let id = AssetID()
    let relativePath = "\(folder.relativeDirectoryPath)/\(filename)"
    let destination = projectURL.appendingPathComponent(relativePath)
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
        originalFilename: requestedFilename,
        kind: kind,
        storage: .embedded(packageRelativePath: relativePath)
      )
    )
    return updated
  }

  /// Replaces the bytes of an existing embedded asset without changing its
  /// stable ID or package-relative path. This is the document-layer primitive
  /// used by automatic part re-import/versioning.
  public func replaceEmbeddedAsset(
    _ asset: DocumentAssetReference,
    from sourceURL: URL,
    in projectURL: URL
  ) throws {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      throw AnimaDocumentError.missingAsset(path: sourceURL.path)
    }
    guard case .embedded(let relativePath) = asset.storage else {
      throw AnimaDocumentError.writeFailed(
        path: asset.originalFilename,
        detail: "Only project-embedded assets can be replaced automatically."
      )
    }
    try Self.validateProjectRelativePath(relativePath)
    let destinationURL = projectURL.appendingPathComponent(relativePath)
    if sourceURL.standardizedFileURL == destinationURL.standardizedFileURL { return }
    do {
      let replacement = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
      try fileManager.createDirectory(
        at: destinationURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try replacement.write(to: destinationURL, options: .atomic)
    } catch {
      throw AnimaDocumentError.writeFailed(
        path: destinationURL.path,
        detail: error.localizedDescription
      )
    }
  }

  private static func availableAssetFilename(
    _ requestedFilename: String,
    folder: ProjectAssetFolder,
    document: AnimaStudioDocument,
    projectURL: URL
  ) -> String {
    let requestedURL = URL(fileURLWithPath: requestedFilename)
    let stem = requestedURL.deletingPathExtension().lastPathComponent
    let pathExtension = requestedURL.pathExtension
    let prefix = "\(folder.relativeDirectoryPath)/"
    let occupied = Set(
      document.assets.compactMap { asset -> String? in
        guard case .embedded(let path) = asset.storage, path.hasPrefix(prefix) else { return nil }
        return String(path.dropFirst(prefix.count))
      }
    )
    func exists(_ filename: String) -> Bool {
      occupied.contains(filename)
        || FileManager.default.fileExists(
          atPath: projectURL.appendingPathComponent(prefix + filename).path
        )
    }
    guard exists(requestedFilename) else { return requestedFilename }
    var sequence = 2
    while true {
      let suffix = pathExtension.isEmpty ? "" : ".\(pathExtension)"
      let candidate = "\(stem)-\(sequence)\(suffix)"
      if !exists(candidate) { return candidate }
      sequence += 1
    }
  }

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
        storage: .linked(externalPath: externalURL.path, bookmarkData: bookmarkData)
      )
    )
    return updated
  }

  public func resolveAsset(
    _ asset: DocumentAssetReference,
    projectURL: URL
  ) throws -> AssetResolution {
    switch asset.storage {
    case .embedded(let relativePath):
      try Self.validateProjectRelativePath(relativePath)
      let url = projectURL.appendingPathComponent(relativePath)
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw AnimaDocumentError.missingAsset(path: relativePath)
      }
      return .resolved(url)
    case .linked(_, let bookmarkData):
      guard let bookmarkData else { return .needsRelink(.missingBookmark) }
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
        return .needsRelink(.unresolvableBookmark(detail: error.localizedDescription))
      }
      if isStale { return .needsRelink(.staleBookmark) }
      guard FileManager.default.fileExists(atPath: resolved.path) else {
        return .needsRelink(.fileMissing(path: resolved.path))
      }
      return .resolved(resolved)
    }
  }

  static func validate(document: AnimaStudioDocument) throws {
    try validate(assets: document.assets)
    var characterNames: Set<String> = []
    for character in document.characters {
      guard characterNames.insert(character.folderName).inserted else {
        throw AnimaDocumentError.duplicateCharacterName(name: character.folderName)
      }
      try validate(filename: character.folderName)
      try validate(filename: character.characterFilename)
      try validate(filename: character.editorFilename)
      try validateProjectRelativePath(character.characterPath)
      try validateProjectRelativePath(character.editorPath)
    }
    var sceneNames: Set<String> = []
    for scene in document.scenes {
      guard sceneNames.insert(scene.name).inserted else {
        throw AnimaDocumentError.duplicateSceneName(name: scene.name)
      }
      try validate(filename: scene.name)
      try validate(filename: scene.filename)
      try validateProjectRelativePath(scene.scenePath)
    }
  }

  static func validate(assets: [DocumentAssetReference]) throws {
    var seenIDs: Set<UUID> = []
    var seenEmbeddedPaths: Set<String> = []
    for asset in assets {
      guard seenIDs.insert(asset.id.rawValue).inserted else {
        throw AnimaDocumentError.duplicateAssetID(id: asset.id.rawValue)
      }
      try validate(filename: asset.originalFilename)
      if case .embedded(let relativePath) = asset.storage {
        guard seenEmbeddedPaths.insert(relativePath).inserted else {
          throw AnimaDocumentError.duplicateAssetName(name: relativePath)
        }
        try validateProjectRelativePath(relativePath)
        let parts = relativePath.split(separator: "/")
        let isLegacyCharacterAsset =
          parts.count >= 4 && parts[0] == "characters" && parts[2] == "assets"
        let isTypedProjectAsset =
          parts.count >= 3 && parts[0] == "assets"
          && ProjectAssetFolder(rawValue: String(parts[1])) != nil
        guard isLegacyCharacterAsset || isTypedProjectAsset else {
          throw AnimaDocumentError.pathTraversal(path: relativePath)
        }
      }
    }
  }

  static func validate(manifestAsset: ManifestV2.ManifestAsset, manifestPath: String) throws {
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

  static func validateIndexedFiles(of document: AnimaStudioDocument, in projectURL: URL) throws {
    for character in document.characters {
      let path = character.characterPath
      guard FileManager.default.fileExists(atPath: projectURL.appendingPathComponent(path).path)
      else { throw AnimaDocumentError.missingCanonicalDocument(path: path) }
    }
    for scene in document.scenes {
      let path = scene.scenePath
      guard FileManager.default.fileExists(atPath: projectURL.appendingPathComponent(path).path)
      else { throw AnimaDocumentError.missingCanonicalDocument(path: path) }
    }
  }

  static func validateProjectRelativePath(_ path: String) throws {
    guard !path.isEmpty, !path.hasPrefix("/") else {
      throw AnimaDocumentError.pathTraversal(path: path)
    }
    let components = path.split(separator: "/", omittingEmptySubsequences: false)
    guard
      !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
      components.first == "characters" || components.first == "scenes"
        || components.first == "assets"
    else {
      throw AnimaDocumentError.pathTraversal(path: path)
    }
  }

  /// Compatibility spelling retained for the existing security tests.
  static func validatePackageRelativePath(_ path: String) throws {
    try validateProjectRelativePath(path)
  }

  static func validate(filename: String) throws {
    guard
      !filename.isEmpty,
      filename != ".", filename != "..",
      !filename.contains("/"), !filename.contains("\0")
    else { throw AnimaDocumentError.pathTraversal(path: filename) }
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

  static func wholeSecond(_ date: Date) -> Date {
    Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
  }

  /// Creates the complete plain-folder skeleton and is safe to call for every
  /// create/open/save. This is intentionally independent of project.json's
  /// format version: adding a typed directory does not migrate engine data.
  public static func ensureProjectDirectories(
    at projectURL: URL,
    fileManager: FileManager = .default
  ) throws {
    do {
      for directory in [charactersDirectoryName, scenesDirectoryName, assetsDirectoryName] {
        try fileManager.createDirectory(
          at: projectURL.appendingPathComponent(directory, isDirectory: true),
          withIntermediateDirectories: true
        )
      }
      for folder in assetFolders {
        try fileManager.createDirectory(
          at: projectURL.appendingPathComponent(folder.relativeDirectoryPath, isDirectory: true),
          withIntermediateDirectories: true
        )
      }
    } catch {
      throw AnimaDocumentError.writeFailed(
        path: projectURL.path,
        detail: "Could not prepare project folders: \(error.localizedDescription)"
      )
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
