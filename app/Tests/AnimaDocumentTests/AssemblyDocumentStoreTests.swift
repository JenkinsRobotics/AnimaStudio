import XCTest

@testable import AnimaDocument

final class AssemblyDocumentStoreTests: XCTestCase {
  private var root: URL!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("AssemblyDocumentTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: root)
  }

  func testAssemblySavesListsAndReloadsFromTypedFolder() throws {
    let document = AnimaAssemblyDocument(
      id: UUID(uuidString: "A5000000-0000-4000-8000-000000000001")!,
      name: "Head Pan",
      nodes: [
        AssemblyNodeReference(
          name: "Head",
          kind: .part,
          partName: "head",
          modelReference: "assets/head.step",
          modelNode: "Head"
        )
      ]
    )
    let store = AssemblyDocumentStore()

    let url = try store.save(document, in: root)
    let loaded = try store.load(from: url)
    let listed = try store.list(in: root)

    XCTAssertEqual(url.pathExtension, "animasm")
    XCTAssertTrue(url.path.contains("/assets/assemblies/"))
    XCTAssertEqual(loaded, document)
    XCTAssertEqual(listed.map(\.id), [document.id])
    XCTAssertEqual(listed.map(\.name), ["Head Pan"])
    XCTAssertEqual(listed.map(\.nodeCount), [1])
    XCTAssertEqual(listed.first?.url.standardizedFileURL.path, url.standardizedFileURL.path)
  }

  func testLegacyDemoAssemblyMigratesToCurrentFormat() throws {
    let legacy = Data(
      """
      {
        "version": 1,
        "name": "Legacy Arm",
        "nodes": [
          {"name":"Shoulder","isFolder":false,"children":[]}
        ]
      }
      """.utf8
    )

    let migrated = try AnimaAssemblyDocument.decode(legacy)

    XCTAssertEqual(migrated.formatVersion, "1")
    XCTAssertEqual(migrated.name, "Legacy Arm")
    XCTAssertEqual(migrated.nodes.first?.partName, "Shoulder")
  }

  func testUnsupportedAssemblyVersionIsRejected() throws {
    let unsupported = Data(
      """
      {"format_version":"99","id":"A5000000-0000-4000-8000-000000000001","name":"Future","nodes":[]}
      """.utf8
    )

    XCTAssertThrowsError(try AnimaAssemblyDocument.decode(unsupported)) { error in
      guard case AnimaDocumentError.unsupportedVersion(let found, _) = error else {
        return XCTFail("Expected unsupportedVersion, got \(error)")
      }
      XCTAssertEqual(found, "99")
    }
  }
}
