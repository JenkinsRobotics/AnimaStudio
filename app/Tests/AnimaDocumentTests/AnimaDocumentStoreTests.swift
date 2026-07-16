import AnimaModel
import XCTest

@testable import AnimaDocument

final class AnimaDocumentStoreTests: XCTestCase {
  private var workDirectory: URL!

  /// Fixed clock so save output is reproducible byte-for-byte.
  private let fixedDate = Date(timeIntervalSince1970: 1_784_400_000)
  private var store: AnimaDocumentStore!

  override func setUpWithError() throws {
    workDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("AnimaDocumentTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: workDirectory,
      withIntermediateDirectories: true
    )
    // Plain bookmarks: the swiftpm test runner is not sandboxed, where
    // security-scoped bookmark creation is unreliable. Documented seam in
    // BookmarkStyle; production defaults to .securityScoped.
    let date = fixedDate
    store = AnimaDocumentStore(bookmarkStyle: .plain, now: { date })
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: workDirectory)
  }

  // MARK: - Fixtures

  private func fixedUUID(_ suffix: String) -> UUID {
    UUID(uuidString: "D0C00000-0000-4000-8000-\(suffix)")!
  }

  private func sampleProject(name: String = "Test Robot") -> AnimaProject {
    let base = RigPartDefinition(
      id: PartID(rawValue: fixedUUID("00000000000A")),
      displayName: "Base",
      primitiveKind: .box
    )
    let head = RigPartDefinition(
      id: PartID(rawValue: fixedUUID("00000000000B")),
      displayName: "Head",
      primitiveKind: .sphere,
      positionMeters: RigVector3(x: 0, y: 0.4, z: 0)
    )
    let neck = JointDefinition(
      id: "neck",
      displayName: "Neck",
      axis: .y,
      minimumRadians: -1.0,
      maximumRadians: 1.0,
      parentPartID: base.id,
      childPartID: head.id,
      parentConnector: MateConnectorDefinition(
        originMeters: RigVector3(x: 0, y: 0.2, z: 0)
      ),
      childConnector: MateConnectorDefinition()
    )
    let clip = AnimationClip(
      name: "Nod",
      durationSeconds: 2,
      jointTracks: [
        JointTrack(
          jointID: "neck",
          keyframes: [
            ScalarKeyframe(timeSeconds: 0, value: 0, interpolation: .hold),
            ScalarKeyframe(timeSeconds: 1.5, value: 0.75, interpolation: .linear),
          ]
        )
      ]
    )
    return AnimaProject(
      name: name,
      rig: CharacterRig(parts: [base, head], joints: [neck]),
      clips: [clip]
    )
  }

  private func packageURL(_ name: String = "TestRobot") -> URL {
    workDirectory.appendingPathComponent("\(name).animastudio", isDirectory: true)
  }

  private func manifestURL(of package: URL) -> URL {
    package.appendingPathComponent("project.json")
  }

  @discardableResult
  private func writeTempFile(
    named name: String,
    contents: String = "payload-bytes"
  ) throws -> URL {
    let url = workDirectory.appendingPathComponent(name)
    try contents.data(using: .utf8)!.write(to: url)
    return url
  }

  private func rewriteManifest(
    of package: URL,
    replacing target: String,
    with replacement: String
  ) throws {
    let url = manifestURL(of: package)
    let text = try String(contentsOf: url, encoding: .utf8)
    XCTAssertTrue(text.contains(target), "Fixture drift: \(target) not in manifest")
    try text.replacingOccurrences(of: target, with: replacement)
      .data(using: .utf8)!.write(to: url)
  }

  // MARK: - Save / load round trip

  func testSaveThenLoadRoundTripsProjectMetadataAndAssets() throws {
    let url = packageURL()
    var document = AnimaStudioDocument(
      project: sampleProject(),
      metadata: DocumentMetadata(milestoneName: "First head nod")
    )
    document = try store.save(document, to: url)

    let payload = try writeTempFile(named: "head.usdz", contents: "usdz-bytes")
    document = try store.embedAsset(
      from: payload,
      into: url,
      document: document,
      kind: "model3D"
    )
    let external = try writeTempFile(named: "voice.wav", contents: "wav-bytes")
    document = try store.linkAsset(at: external, into: document, kind: "audio")
    document = try store.save(document, to: url)

    let loaded = try store.load(from: url)
    XCTAssertEqual(loaded, document)
    XCTAssertEqual(loaded.project, document.project)
    XCTAssertEqual(loaded.displayName, "Test Robot")
    XCTAssertEqual(loaded.metadata.revision, 2)
    XCTAssertEqual(loaded.metadata.milestoneName, "First head nod")
    XCTAssertEqual(loaded.metadata.modifiedDate, fixedDate)
    XCTAssertEqual(loaded.assets.count, 2)
  }

  func testSaveCreatesManifestAndAssetsDirectory() throws {
    let url = packageURL()
    try store.save(AnimaStudioDocument(project: sampleProject()), to: url)
    XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL(of: url).path))
    var isDirectory: ObjCBool = false
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: url.appendingPathComponent("Assets").path,
        isDirectory: &isDirectory
      )
    )
    XCTAssertTrue(isDirectory.boolValue)
  }

  // MARK: - Deterministic encoding

  func testSaveIsByteIdenticalForIdenticalInput() throws {
    // Two assets supplied in opposite orders; fixed IDs, fixed bookmark data.
    let assetA = DocumentAssetReference(
      id: AssetID(rawValue: fixedUUID("0000000000A1")),
      originalFilename: "a.usdz",
      kind: "model3D",
      storage: .linked(externalPath: "/tmp/a.usdz", bookmarkData: Data([1, 2, 3]))
    )
    let assetB = DocumentAssetReference(
      id: AssetID(rawValue: fixedUUID("0000000000B2")),
      originalFilename: "b.wav",
      kind: "audio",
      storage: .linked(externalPath: "/tmp/b.wav", bookmarkData: nil)
    )
    let first = AnimaStudioDocument(project: sampleProject(), assets: [assetA, assetB])
    let second = AnimaStudioDocument(project: sampleProject(), assets: [assetB, assetA])

    let urlOne = packageURL("One")
    let urlTwo = packageURL("Two")
    try store.save(first, to: urlOne)
    try store.save(second, to: urlTwo)

    let bytesOne = try Data(contentsOf: manifestURL(of: urlOne))
    let bytesTwo = try Data(contentsOf: manifestURL(of: urlTwo))
    XCTAssertEqual(bytesOne, bytesTwo, "Identical input must encode byte-identically")
    XCTAssertFalse(bytesOne.isEmpty)
  }

  func testResaveOfUnchangedDocumentDiffersOnlyInRevision() throws {
    let url = packageURL()
    let saved = try store.save(AnimaStudioDocument(project: sampleProject()), to: url)
    let firstBytes = try Data(contentsOf: manifestURL(of: url))
    try store.save(saved, to: url)
    let secondBytes = try Data(contentsOf: manifestURL(of: url))

    let firstText = String(decoding: firstBytes, as: UTF8.self)
    let secondText = String(decoding: secondBytes, as: UTF8.self)
    XCTAssertEqual(
      firstText.replacingOccurrences(of: "\"revision\" : 1", with: "\"revision\" : 2"),
      secondText,
      "With a fixed clock, a re-save changes exactly the revision field"
    )
  }

  // MARK: - Revision + metadata

  func testRevisionIncrementsPerSave() throws {
    let url = packageURL()
    var document = AnimaStudioDocument(project: sampleProject())
    XCTAssertEqual(document.metadata.revision, 0)
    document = try store.save(document, to: url)
    XCTAssertEqual(document.metadata.revision, 1)
    document = try store.save(document, to: url)
    XCTAssertEqual(document.metadata.revision, 2)
    XCTAssertEqual(try store.load(from: url).metadata.revision, 2)
  }

  // MARK: - Typed load failures

  func testLoadMissingPackageThrowsPackageNotFound() {
    XCTAssertThrowsError(try store.load(from: packageURL("Nowhere"))) { error in
      guard case AnimaDocumentError.packageNotFound = error else {
        return XCTFail("Expected packageNotFound, got \(error)")
      }
    }
  }

  func testCorruptJSONThrowsCorruptManifest() throws {
    let url = packageURL()
    try store.save(AnimaStudioDocument(project: sampleProject()), to: url)
    try Data("{ not json".utf8).write(to: manifestURL(of: url))
    XCTAssertThrowsError(try store.load(from: url)) { error in
      guard case AnimaDocumentError.corruptManifest = error else {
        return XCTFail("Expected corruptManifest, got \(error)")
      }
    }
  }

  func testMissingRequiredKeyThrowsCorruptManifest() throws {
    let url = packageURL()
    try store.save(AnimaStudioDocument(project: sampleProject()), to: url)
    try rewriteManifest(of: url, replacing: "\"project\"", with: "\"not_project\"")
    XCTAssertThrowsError(try store.load(from: url)) { error in
      guard case AnimaDocumentError.corruptManifest(_, let detail) = error else {
        return XCTFail("Expected corruptManifest, got \(error)")
      }
      XCTAssertTrue(detail.contains("project"), "Detail should name the missing key")
    }
  }

  func testUnsupportedFormatVersionThrowsTypedError() throws {
    let url = packageURL()
    try store.save(AnimaStudioDocument(project: sampleProject()), to: url)
    try rewriteManifest(
      of: url,
      replacing: "\"format_version\" : \"1\"",
      with: "\"format_version\" : \"99\""
    )
    XCTAssertThrowsError(try store.load(from: url)) { error in
      guard case AnimaDocumentError.unsupportedVersion(let found, let supported) = error
      else {
        return XCTFail("Expected unsupportedVersion, got \(error)")
      }
      XCTAssertEqual(found, "99")
      XCTAssertEqual(supported, ["1"])
    }
  }

  // MARK: - Path traversal

  func testTraversalPackagePathInManifestIsRejected() throws {
    let url = packageURL()
    var document = AnimaStudioDocument(project: sampleProject())
    document = try store.save(document, to: url)
    let payload = try writeTempFile(named: "part.usdz")
    document = try store.embedAsset(
      from: payload,
      into: url,
      document: document,
      kind: "model3D"
    )
    document = try store.save(document, to: url)
    guard case .embedded(let relativePath) = document.assets[0].storage else {
      return XCTFail("Expected embedded storage")
    }
    for hostile in ["../../etc/passwd", "/etc/passwd", "Assets/../project.json"] {
      try rewriteManifest(of: url, replacing: relativePath, with: hostile)
      XCTAssertThrowsError(try store.load(from: url), "path: \(hostile)") { error in
        guard case AnimaDocumentError.pathTraversal(let path) = error else {
          return XCTFail("Expected pathTraversal for \(hostile), got \(error)")
        }
        XCTAssertEqual(path, hostile)
      }
      try rewriteManifest(of: url, replacing: hostile, with: relativePath)
    }
  }

  func testTraversalPathIsRejectedBeforeTouchingTheFilesystem() {
    // Validation is pure: no package needs to exist for rejection.
    XCTAssertThrowsError(
      try AnimaDocumentStore.validatePackageRelativePath("../../etc")
    )
    XCTAssertThrowsError(
      try AnimaDocumentStore.validatePackageRelativePath("NotAssets/file.usdz")
    )
    XCTAssertNoThrow(
      try AnimaDocumentStore.validatePackageRelativePath("Assets/x.usdz")
    )
  }

  func testSaveRejectsTraversalInAssetTable() {
    let hostile = DocumentAssetReference(
      originalFilename: "x.usdz",
      kind: "model3D",
      storage: .embedded(packageRelativePath: "../../escape.usdz")
    )
    let document = AnimaStudioDocument(project: sampleProject(), assets: [hostile])
    XCTAssertThrowsError(try store.save(document, to: packageURL())) { error in
      guard case AnimaDocumentError.pathTraversal = error else {
        return XCTFail("Expected pathTraversal, got \(error)")
      }
    }
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: packageURL().path),
      "A rejected save must not create the package"
    )
  }

  // MARK: - Duplicate assets

  func testDuplicateAssetNamesRejectedAtEmbedTime() throws {
    let url = packageURL()
    var document = AnimaStudioDocument(project: sampleProject())
    document = try store.save(document, to: url)
    let payload = try writeTempFile(named: "part.usdz")
    document = try store.embedAsset(
      from: payload,
      into: url,
      document: document,
      kind: "model3D"
    )
    XCTAssertThrowsError(
      try store.embedAsset(from: payload, into: url, document: document, kind: "model3D")
    ) { error in
      guard case AnimaDocumentError.duplicateAssetName(let name) = error else {
        return XCTFail("Expected duplicateAssetName, got \(error)")
      }
      XCTAssertEqual(name, "part.usdz")
    }
  }

  func testDuplicateAssetNamesRejectedAtSaveTime() {
    let assets = [
      DocumentAssetReference(
        originalFilename: "same.wav",
        kind: "audio",
        storage: .linked(externalPath: "/tmp/one/same.wav", bookmarkData: nil)
      ),
      DocumentAssetReference(
        originalFilename: "same.wav",
        kind: "audio",
        storage: .linked(externalPath: "/tmp/two/same.wav", bookmarkData: nil)
      ),
    ]
    let document = AnimaStudioDocument(project: sampleProject(), assets: assets)
    XCTAssertThrowsError(try store.save(document, to: packageURL())) { error in
      guard case AnimaDocumentError.duplicateAssetName = error else {
        return XCTFail("Expected duplicateAssetName, got \(error)")
      }
    }
  }

  func testDuplicateAssetIDsRejected() {
    let sharedID = AssetID(rawValue: fixedUUID("00000000DEAD"))
    let assets = [
      DocumentAssetReference(
        id: sharedID,
        originalFilename: "one.wav",
        kind: "audio",
        storage: .linked(externalPath: "/tmp/one.wav", bookmarkData: nil)
      ),
      DocumentAssetReference(
        id: sharedID,
        originalFilename: "two.wav",
        kind: "audio",
        storage: .linked(externalPath: "/tmp/two.wav", bookmarkData: nil)
      ),
    ]
    let document = AnimaStudioDocument(project: sampleProject(), assets: assets)
    XCTAssertThrowsError(try store.save(document, to: packageURL())) { error in
      guard case AnimaDocumentError.duplicateAssetID(let id) = error else {
        return XCTFail("Expected duplicateAssetID, got \(error)")
      }
      XCTAssertEqual(id, sharedID.rawValue)
    }
  }

  // MARK: - Embedded assets

  func testEmbedAssetCopiesPayloadAndResolves() throws {
    let url = packageURL()
    var document = AnimaStudioDocument(project: sampleProject())
    document = try store.save(document, to: url)
    let payload = try writeTempFile(named: "servo-horn.usdz", contents: "horn-bytes")
    document = try store.embedAsset(
      from: payload,
      into: url,
      document: document,
      kind: "model3D"
    )

    let asset = try XCTUnwrap(document.assets.first)
    XCTAssertEqual(asset.originalFilename, "servo-horn.usdz")
    XCTAssertEqual(asset.kind, "model3D")
    guard case .resolved(let resolved) = try store.resolveAsset(asset, packageURL: url)
    else {
      return XCTFail("Embedded asset should resolve")
    }
    XCTAssertEqual(
      try String(contentsOf: resolved, encoding: .utf8),
      "horn-bytes",
      "Payload must be copied into the package"
    )
    XCTAssertTrue(resolved.path.hasPrefix(url.path), "Payload lives inside the package")
  }

  func testMissingEmbeddedPayloadThrowsMissingAssetOnLoad() throws {
    let url = packageURL()
    var document = AnimaStudioDocument(project: sampleProject())
    document = try store.save(document, to: url)
    let payload = try writeTempFile(named: "part.usdz")
    document = try store.embedAsset(
      from: payload,
      into: url,
      document: document,
      kind: "model3D"
    )
    document = try store.save(document, to: url)

    guard case .embedded(let relativePath) = document.assets[0].storage else {
      return XCTFail("Expected embedded storage")
    }
    try FileManager.default.removeItem(at: url.appendingPathComponent(relativePath))
    XCTAssertThrowsError(try store.load(from: url)) { error in
      guard case AnimaDocumentError.missingAsset(let path) = error else {
        return XCTFail("Expected missingAsset, got \(error)")
      }
      XCTAssertEqual(path, relativePath)
    }
  }

  func testEmbedNonexistentSourceThrowsMissingAsset() throws {
    let url = packageURL()
    let document = try store.save(AnimaStudioDocument(project: sampleProject()), to: url)
    XCTAssertThrowsError(
      try store.embedAsset(
        from: workDirectory.appendingPathComponent("ghost.usdz"),
        into: url,
        document: document,
        kind: "model3D"
      )
    ) { error in
      guard case AnimaDocumentError.missingAsset = error else {
        return XCTFail("Expected missingAsset, got \(error)")
      }
    }
  }

  // MARK: - Linked assets

  func testLinkedAssetResolvesWhileFileExists() throws {
    let external = try writeTempFile(named: "reference.usdz", contents: "ref-bytes")
    var document = AnimaStudioDocument(project: sampleProject())
    document = try store.linkAsset(at: external, into: document, kind: "model3D")

    let asset = try XCTUnwrap(document.assets.first)
    guard case .linked(let externalPath, let bookmarkData) = asset.storage else {
      return XCTFail("Expected linked storage")
    }
    XCTAssertEqual(externalPath, external.path)
    XCTAssertNotNil(bookmarkData, "Link should carry bookmark data")

    guard
      case .resolved(let resolved) = try store.resolveAsset(asset, packageURL: packageURL())
    else {
      return XCTFail("Linked asset should resolve while the file exists")
    }
    XCTAssertEqual(
      resolved.standardizedFileURL.path,
      external.standardizedFileURL.path
    )
  }

  func testLinkedAssetRoundTripsThroughManifest() throws {
    let url = packageURL()
    let external = try writeTempFile(named: "reference.usdz")
    var document = AnimaStudioDocument(project: sampleProject())
    document = try store.linkAsset(at: external, into: document, kind: "model3D")
    document = try store.save(document, to: url)

    let loaded = try store.load(from: url)
    XCTAssertEqual(loaded.assets, document.assets)
    guard
      case .resolved = try store.resolveAsset(loaded.assets[0], packageURL: url)
    else {
      return XCTFail("Reloaded link should still resolve")
    }
  }

  func testDeletedLinkedFileReportsNeedsRelink() throws {
    let external = try writeTempFile(named: "will-vanish.usdz")
    var document = AnimaStudioDocument(project: sampleProject())
    document = try store.linkAsset(at: external, into: document, kind: "model3D")
    try FileManager.default.removeItem(at: external)

    let resolution = try store.resolveAsset(
      document.assets[0],
      packageURL: packageURL()
    )
    guard case .needsRelink(let reason) = resolution else {
      return XCTFail("Deleted target must report needsRelink, got \(resolution)")
    }
    switch reason {
    case .unresolvableBookmark, .fileMissing, .staleBookmark:
      break  // any broken-link reason is acceptable for a deleted file
    case .missingBookmark:
      XCTFail("Bookmark data existed; reason should describe the broken target")
    }
  }

  func testMissingBookmarkReportsNeedsRelink() throws {
    let asset = DocumentAssetReference(
      originalFilename: "no-bookmark.usdz",
      kind: "model3D",
      storage: .linked(externalPath: "/tmp/no-bookmark.usdz", bookmarkData: nil)
    )
    let resolution = try store.resolveAsset(asset, packageURL: packageURL())
    XCTAssertEqual(resolution, .needsRelink(.missingBookmark))
  }

  func testLinkNonexistentFileThrowsMissingAsset() {
    let document = AnimaStudioDocument(project: sampleProject())
    XCTAssertThrowsError(
      try store.linkAsset(
        at: workDirectory.appendingPathComponent("ghost.usdz"),
        into: document,
        kind: "model3D"
      )
    ) { error in
      guard case AnimaDocumentError.missingAsset = error else {
        return XCTFail("Expected missingAsset, got \(error)")
      }
    }
  }

  // MARK: - Atomic save

  func testFailedSaveLeavesExistingPackageUntouched() throws {
    let url = packageURL()
    let saved = try store.save(AnimaStudioDocument(project: sampleProject()), to: url)
    let goodBytes = try Data(contentsOf: manifestURL(of: url))

    // A document referencing an embedded payload that does not exist on disk
    // fails during staging — after the manifest is written to the temp dir.
    var broken = saved
    broken.assets.append(
      DocumentAssetReference(
        originalFilename: "phantom.usdz",
        kind: "model3D",
        storage: .embedded(
          packageRelativePath: "Assets/\(fixedUUID("00000000BEEF").uuidString)-phantom.usdz"
        )
      )
    )
    XCTAssertThrowsError(try store.save(broken, to: url)) { error in
      guard case AnimaDocumentError.missingAsset = error else {
        return XCTFail("Expected missingAsset, got \(error)")
      }
    }

    XCTAssertEqual(
      try Data(contentsOf: manifestURL(of: url)),
      goodBytes,
      "A failed save must leave the previous package byte-identical"
    )
    let siblings = try FileManager.default.contentsOfDirectory(atPath: workDirectory.path)
    XCTAssertFalse(
      siblings.contains { $0.contains("A Document Being Saved") },
      "No staging leftovers may remain next to the package: \(siblings)"
    )
  }

  func testSuccessfulSaveLeavesNoStagingLeftovers() throws {
    let url = packageURL()
    try store.save(AnimaStudioDocument(project: sampleProject()), to: url)
    let siblings = try FileManager.default.contentsOfDirectory(atPath: workDirectory.path)
    XCTAssertEqual(siblings, ["TestRobot.animastudio"])
    let packageContents = try FileManager.default.contentsOfDirectory(atPath: url.path)
    XCTAssertEqual(packageContents.sorted(), ["Assets", "project.json"])
  }
}
