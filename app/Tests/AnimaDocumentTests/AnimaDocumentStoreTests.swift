import AnimaModel
import XCTest

@testable import AnimaDocument

final class AnimaDocumentStoreTests: XCTestCase {
  private var workDirectory: URL!
  private let fixedDate = Date(timeIntervalSince1970: 1_784_400_000)
  private let projectID = UUID(uuidString: "D0C00000-0000-4000-8000-000000000001")!
  private var store: AnimaDocumentStore!

  override func setUpWithError() throws {
    workDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("AnimaDocumentTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
    let date = fixedDate
    store = AnimaDocumentStore(bookmarkStyle: .plain, now: { date })
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: workDirectory)
  }

  private func projectURL(_ name: String = "TestRobot") -> URL {
    workDirectory.appendingPathComponent(name, isDirectory: true)
  }

  private func document(
    name: String = "Test Robot",
    characters: [ProjectCharacterReference] = []
  ) -> AnimaStudioDocument {
    AnimaStudioDocument(
      projectID: projectID,
      project: AnimaProject(
        name: name,
        rig: CharacterRig(parts: [], joints: []),
        clips: []
      ),
      metadata: DocumentMetadata(milestoneName: "First motion"),
      characters: characters,
      editorState: ProjectEditorState(
        activeCharacterFolderName: characters.first?.folderName,
        activeWorkspaceID: "assets"
      )
    )
  }

  private var character: ProjectCharacterReference {
    ProjectCharacterReference(folderName: "jp01", displayName: "JP-01")
  }

  private func canonicalWrite(_ reference: ProjectCharacterReference? = nil) -> ProjectFileWrite {
    let reference = reference ?? character
    return ProjectFileWrite(
      relativePath: reference.characterPath,
      text: "format: anima-character/0.1\nidentity:\n  name: jp01\n"
    )
  }

  private func manifestURL(_ project: URL) -> URL {
    project.appendingPathComponent("project.json")
  }

  func testNewProjectCreatesPlainFolderLayoutAndRevisionOne() throws {
    let url = projectURL()
    let saved = try store.save(document(), to: url)

    XCTAssertEqual(saved.metadata.revision, 1)
    XCTAssertEqual(saved.metadata.createdDate, fixedDate)
    XCTAssertEqual(saved.metadata.modifiedDate, fixedDate)
    XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL(url).path))
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: url.appendingPathComponent("characters").path
      )
    )
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathComponent("scenes").path))
    XCTAssertFalse(url.pathExtension == "animastudio")
  }

  func testCharacterIndexAndCanonicalEngineFileRoundTrip() throws {
    let url = projectURL()
    let original = document(characters: [character])
    let saved = try store.save(original, to: url, fileWrites: [canonicalWrite()])
    let loaded = try store.load(from: url)

    XCTAssertEqual(loaded.projectID, projectID)
    XCTAssertEqual(loaded.displayName, "Test Robot")
    XCTAssertEqual(loaded.characters, [character])
    XCTAssertEqual(loaded.editorState.activeCharacterFolderName, "jp01")
    XCTAssertEqual(loaded.metadata, saved.metadata)
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: url.appendingPathComponent(character.characterPath).path
      )
    )
  }

  func testManifestDoesNotPersistSwiftRigOrClips() throws {
    let url = projectURL()
    try store.save(document(characters: [character]), to: url, fileWrites: [canonicalWrite()])
    let manifest = try String(contentsOf: manifestURL(url), encoding: .utf8)

    XCTAssertFalse(manifest.contains("\"rig\""))
    XCTAssertFalse(manifest.contains("\"clips\""))
    XCTAssertTrue(manifest.contains("\"character_file\""))
    XCTAssertTrue(manifest.contains("\"format_version\" : \"2\""))
  }

  func testSaveIncrementsRevisionWithoutChangingCreationDate() throws {
    let url = projectURL()
    let first = try store.save(document(), to: url)
    let second = try store.save(first, to: url)

    XCTAssertEqual(second.metadata.revision, 2)
    XCTAssertEqual(second.metadata.createdDate, first.metadata.createdDate)
    XCTAssertEqual(try store.load(from: url).metadata.revision, 2)
  }

  func testSaveAsCopiesCanonicalFilesAndRetargetsNameFromCaller() throws {
    let source = projectURL("Source")
    let destination = projectURL("Copy")
    let saved = try store.save(
      document(characters: [character]),
      to: source,
      fileWrites: [canonicalWrite()]
    )
    var renamed = saved
    renamed.project.name = "Copy"
    let copied = try store.saveAs(renamed, from: source, to: destination)

    XCTAssertEqual(copied.displayName, "Copy")
    XCTAssertEqual(copied.metadata.revision, 2)
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: destination.appendingPathComponent(character.characterPath).path
      )
    )
    XCTAssertEqual(try store.load(from: source).displayName, "Test Robot")
  }

  func testDeterministicManifestForIdenticalDocuments() throws {
    let one = projectURL("One")
    let two = projectURL("Two")
    try store.save(document(), to: one)
    try store.save(document(), to: two)
    XCTAssertEqual(
      try Data(contentsOf: manifestURL(one)),
      try Data(contentsOf: manifestURL(two))
    )
  }

  func testMissingIndexedCanonicalFileIsRejectedWithoutReplacingProject() throws {
    let url = projectURL()
    let good = try store.save(document(), to: url)
    let goodManifest = try Data(contentsOf: manifestURL(url))
    var broken = good
    broken.characters = [character]

    XCTAssertThrowsError(try store.save(broken, to: url)) { error in
      guard case AnimaDocumentError.missingCanonicalDocument = error else {
        return XCTFail("Expected missingCanonicalDocument, got \(error)")
      }
    }
    XCTAssertEqual(try Data(contentsOf: manifestURL(url)), goodManifest)
  }

  func testCorruptAndUnsupportedManifestsProduceTypedErrors() throws {
    let corrupt = projectURL("Corrupt")
    try FileManager.default.createDirectory(at: corrupt, withIntermediateDirectories: true)
    try Data("{not json".utf8).write(to: manifestURL(corrupt))
    XCTAssertThrowsError(try store.load(from: corrupt)) { error in
      guard case AnimaDocumentError.corruptManifest = error else {
        return XCTFail("Expected corruptManifest, got \(error)")
      }
    }

    let unsupported = projectURL("Unsupported")
    try store.save(document(), to: unsupported)
    let manifest = try String(contentsOf: manifestURL(unsupported), encoding: .utf8)
    try Data(manifest.replacingOccurrences(of: "\"2\"", with: "\"99\"").utf8)
      .write(to: manifestURL(unsupported))
    XCTAssertThrowsError(try store.load(from: unsupported)) { error in
      guard case AnimaDocumentError.unsupportedVersion(let found, _) = error else {
        return XCTFail("Expected unsupportedVersion, got \(error)")
      }
      XCTAssertEqual(found, "99")
    }
  }

  func testProjectRelativePathTraversalIsRejected() {
    for path in ["../../etc/passwd", "/etc/passwd", "characters/jp01/../project.json"] {
      XCTAssertThrowsError(try AnimaDocumentStore.validateProjectRelativePath(path))
    }
    XCTAssertNoThrow(
      try AnimaDocumentStore.validateProjectRelativePath(
        "characters/jp01/assets/head.usdz"
      )
    )
  }

  func testDuplicateCharacterAndSceneNamesAreRejected() {
    var duplicateCharacters = document(characters: [character, character])
    XCTAssertThrowsError(try store.save(duplicateCharacters, to: projectURL())) { error in
      guard case AnimaDocumentError.duplicateCharacterName = error else {
        return XCTFail("Expected duplicateCharacterName, got \(error)")
      }
    }
    duplicateCharacters.characters = []
    duplicateCharacters.scenes = [
      ProjectSceneReference(name: "show", displayName: "Show"),
      ProjectSceneReference(name: "show", displayName: "Show 2"),
    ]
    XCTAssertThrowsError(try store.save(duplicateCharacters, to: projectURL())) { error in
      guard case AnimaDocumentError.duplicateSceneName = error else {
        return XCTFail("Expected duplicateSceneName, got \(error)")
      }
    }
  }

  func testEmbeddedAssetLivesInsideActiveCharacterAssetsFolder() throws {
    let url = projectURL()
    var saved = try store.save(
      document(characters: [character]),
      to: url,
      fileWrites: [canonicalWrite()]
    )
    let source = workDirectory.appendingPathComponent("head.usdz")
    try Data("mesh".utf8).write(to: source)
    saved = try store.embedAsset(
      from: source,
      into: url,
      document: saved,
      characterFolderName: "jp01",
      kind: "model3D"
    )
    saved = try store.save(saved, to: url)
    let asset = try XCTUnwrap(saved.assets.first)
    guard case .embedded(let path) = asset.storage else {
      return XCTFail("Expected embedded asset")
    }
    XCTAssertTrue(path.hasPrefix("characters/jp01/assets/"))
    guard case .resolved(let resolved) = try store.resolveAsset(asset, projectURL: url) else {
      return XCTFail("Expected resolved asset")
    }
    XCTAssertEqual(try String(contentsOf: resolved, encoding: .utf8), "mesh")
  }

  func testLinkedAssetBookmarkRoundTrips() throws {
    let url = projectURL()
    let external = workDirectory.appendingPathComponent("voice.wav")
    try Data("audio".utf8).write(to: external)
    var value = try store.linkAsset(
      at: external,
      into: document(),
      kind: "audio"
    )
    value = try store.save(value, to: url)
    let loaded = try store.load(from: url)
    XCTAssertEqual(loaded.assets, value.assets)
    guard case .resolved = try store.resolveAsset(loaded.assets[0], projectURL: url) else {
      return XCTFail("Expected linked asset to resolve")
    }
  }

  func testMissingProjectThrowsPackageNotFound() {
    XCTAssertThrowsError(try store.load(from: projectURL("Missing"))) { error in
      guard case AnimaDocumentError.packageNotFound = error else {
        return XCTFail("Expected packageNotFound, got \(error)")
      }
    }
  }
}
