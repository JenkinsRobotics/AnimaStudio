import Foundation

/// The provenance of a Character copy indexed by a Project.
///
/// Projects always contain a complete Character directory. A library-backed
/// Character is therefore a pinned snapshot, never a fragile live link.
public enum ProjectCharacterSourceKind: String, Codable, Equatable, Sendable {
  case projectLocal = "project_local"
  case librarySnapshot = "library_snapshot"
}

/// App-owned metadata for one reusable Character package.
/// Canonical rig and animation meaning remains in the adjacent
/// `.character.anima` document authored by AnimaCore.
public struct CharacterLibraryEntry: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var displayName: String
  public var folderName: String
  public var characterFilename: String
  public var editorFilename: String
  public var revision: Int
  public var modifiedDate: Date

  public init(
    id: UUID,
    displayName: String,
    folderName: String,
    characterFilename: String,
    editorFilename: String,
    revision: Int,
    modifiedDate: Date
  ) {
    self.id = id
    self.displayName = displayName
    self.folderName = folderName
    self.characterFilename = characterFilename
    self.editorFilename = editorFilename
    self.revision = revision
    self.modifiedDate = modifiedDate
  }

  public var directoryName: String { id.uuidString.lowercased() }
}

public struct CharacterLibraryPublication: Equatable, Sendable {
  public var entry: CharacterLibraryEntry
  public var projectReference: ProjectCharacterReference

  public init(entry: CharacterLibraryEntry, projectReference: ProjectCharacterReference) {
    self.entry = entry
    self.projectReference = projectReference
  }
}

public enum CharacterLibraryError: Error, Equatable, Sendable {
  case missingCharacterDirectory(String)
  case missingLibraryEntry(UUID)
  case invalidEntry(String)
  case fileOperation(String)
}

extension CharacterLibraryError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .missingCharacterDirectory(let path):
      "The Character directory could not be found at \(path)."
    case .missingLibraryEntry(let id):
      "Character Library entry \(id.uuidString) could not be found."
    case .invalidEntry(let detail):
      "The Character Library entry is invalid: \(detail)"
    case .fileOperation(let detail):
      "The Character Library operation failed: \(detail)"
    }
  }
}

/// Filesystem owner for reusable Character packages.
///
/// Library packages live outside Projects. Publishing copies a Project's
/// complete Character directory into the library. Installing copies it back
/// into a Project, producing a stable snapshot with source ID and revision.
public struct CharacterLibraryStore: Sendable {
  public static let directoryName = "Character Library"
  public static let metadataFilename = "character-library.json"

  private let now: @Sendable () -> Date

  public init(now: @escaping @Sendable () -> Date = Date.init) {
    self.now = now
  }

  public func list(in libraryRootURL: URL) throws -> [CharacterLibraryEntry] {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: libraryRootURL.path) else { return [] }
    do {
      let directories = try fileManager.contentsOfDirectory(
        at: libraryRootURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
      return try directories.compactMap { directory in
        guard
          (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        else { return nil }
        let metadataURL = directory.appendingPathComponent(Self.metadataFilename)
        guard fileManager.fileExists(atPath: metadataURL.path) else { return nil }
        return try Self.decoder().decode(
          CharacterLibraryEntry.self,
          from: Data(contentsOf: metadataURL)
        )
      }
      .sorted {
        $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
      }
    } catch let error as CharacterLibraryError {
      throw error
    } catch {
      throw CharacterLibraryError.fileOperation(error.localizedDescription)
    }
  }

  /// Publishes or updates the reusable source for a project Character.
  /// The returned reference records the library identity/revision while still
  /// pointing at the unchanged, self-contained project directory.
  public func publish(
    _ character: ProjectCharacterReference,
    from projectURL: URL,
    to libraryRootURL: URL
  ) throws -> CharacterLibraryPublication {
    let fileManager = FileManager.default
    let sourceURL = projectURL.appendingPathComponent(character.directoryPath, isDirectory: true)
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      throw CharacterLibraryError.missingCharacterDirectory(sourceURL.path)
    }

    let id = character.libraryCharacterID ?? UUID()
    let destinationURL = libraryRootURL.appendingPathComponent(
      id.uuidString.lowercased(),
      isDirectory: true
    )
    let priorRevision =
      try existingEntry(at: destinationURL)?.revision
      ?? character.libraryRevision
      ?? 0
    let entry = CharacterLibraryEntry(
      id: id,
      displayName: character.displayName,
      folderName: character.folderName,
      characterFilename: character.characterFilename,
      editorFilename: character.editorFilename,
      revision: priorRevision + 1,
      modifiedDate: now()
    )

    do {
      try fileManager.createDirectory(at: libraryRootURL, withIntermediateDirectories: true)
      let stagingURL = libraryRootURL.appendingPathComponent(
        ".\(id.uuidString)-staging-\(UUID().uuidString)",
        isDirectory: true
      )
      defer { try? fileManager.removeItem(at: stagingURL) }
      try fileManager.copyItem(at: sourceURL, to: stagingURL)
      let metadata = try Self.encoder().encode(entry)
      try metadata.write(to: stagingURL.appendingPathComponent(Self.metadataFilename))
      if fileManager.fileExists(atPath: destinationURL.path) {
        _ = try fileManager.replaceItemAt(destinationURL, withItemAt: stagingURL)
      } else {
        try fileManager.moveItem(at: stagingURL, to: destinationURL)
      }
    } catch {
      throw CharacterLibraryError.fileOperation(error.localizedDescription)
    }

    var projectReference = character
    projectReference.sourceKind = .librarySnapshot
    projectReference.libraryCharacterID = id
    projectReference.libraryRevision = entry.revision
    return CharacterLibraryPublication(entry: entry, projectReference: projectReference)
  }

  /// Copies a library Character into a Project as a pinned, portable snapshot.
  public func install(
    _ entry: CharacterLibraryEntry,
    from libraryRootURL: URL,
    into projectURL: URL,
    existingCharacters: [ProjectCharacterReference]
  ) throws -> ProjectCharacterReference {
    let fileManager = FileManager.default
    let sourceURL = libraryRootURL.appendingPathComponent(entry.directoryName, isDirectory: true)
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      throw CharacterLibraryError.missingLibraryEntry(entry.id)
    }
    let reference = try availableReference(for: entry, existingCharacters: existingCharacters)
    let destinationURL = projectURL.appendingPathComponent(
      reference.directoryPath, isDirectory: true)
    do {
      try fileManager.createDirectory(
        at: destinationURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try fileManager.copyItem(at: sourceURL, to: destinationURL)
      try? fileManager.removeItem(
        at: destinationURL.appendingPathComponent(Self.metadataFilename)
      )
    } catch {
      throw CharacterLibraryError.fileOperation(error.localizedDescription)
    }
    return reference
  }

  private func existingEntry(at directoryURL: URL) throws -> CharacterLibraryEntry? {
    let metadataURL = directoryURL.appendingPathComponent(Self.metadataFilename)
    guard FileManager.default.fileExists(atPath: metadataURL.path) else { return nil }
    do {
      return try Self.decoder().decode(
        CharacterLibraryEntry.self,
        from: Data(contentsOf: metadataURL)
      )
    } catch {
      throw CharacterLibraryError.invalidEntry(error.localizedDescription)
    }
  }

  private func availableReference(
    for entry: CharacterLibraryEntry,
    existingCharacters: [ProjectCharacterReference]
  ) throws -> ProjectCharacterReference {
    var attempt = 0
    while attempt < 10_000 {
      let suffix = attempt == 0 ? "" : (attempt == 1 ? " Copy" : " Copy \(attempt)")
      let displayName = entry.displayName + suffix
      do {
        var reference = try ProjectCharacterNaming.reference(
          for: displayName,
          existingCharacters: existingCharacters
        )
        reference.characterFilename = entry.characterFilename
        reference.editorFilename = entry.editorFilename
        reference.sourceKind = .librarySnapshot
        reference.libraryCharacterID = entry.id
        reference.libraryRevision = entry.revision
        return reference
      } catch ProjectCharacterNameError.duplicate {
        attempt += 1
      }
    }
    throw CharacterLibraryError.invalidEntry("No unique project name could be generated.")
  }

  private static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return encoder
  }

  private static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
