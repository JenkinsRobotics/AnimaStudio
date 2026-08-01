import Foundation
import XCTest

@testable import AnimaDocument

final class CharacterLibraryStoreTests: XCTestCase {
  private let fixedDate = Date(timeIntervalSince1970: 1_721_234_567)

  func testPublishAndInstallCreatesPinnedProjectSnapshot() throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceProject = root.appendingPathComponent("Source", isDirectory: true)
    let destinationProject = root.appendingPathComponent("Destination", isDirectory: true)
    let library = root.appendingPathComponent("Character Library", isDirectory: true)
    let reference = ProjectCharacterReference(folderName: "atlas", displayName: "Atlas")
    let sourceCharacter = sourceProject.appendingPathComponent(
      reference.directoryPath,
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: sourceCharacter.appendingPathComponent("assets", isDirectory: true),
      withIntermediateDirectories: true
    )
    try Data("rig: atlas".utf8).write(
      to: sourceProject.appendingPathComponent(reference.characterPath)
    )
    try Data("{}".utf8).write(to: sourceProject.appendingPathComponent(reference.editorPath))
    try Data([0x01, 0x02]).write(
      to: sourceCharacter.appendingPathComponent("assets/head.usdz")
    )

    let date = fixedDate
    let store = CharacterLibraryStore(now: { date })
    let publication = try store.publish(reference, from: sourceProject, to: library)

    XCTAssertEqual(publication.entry.revision, 1)
    XCTAssertEqual(publication.projectReference.sourceKind, .librarySnapshot)
    XCTAssertEqual(publication.projectReference.libraryCharacterID, publication.entry.id)
    XCTAssertEqual(publication.projectReference.libraryRevision, 1)
    XCTAssertEqual(try store.list(in: library), [publication.entry])

    let installed = try store.install(
      publication.entry,
      from: library,
      into: destinationProject,
      existingCharacters: []
    )
    XCTAssertEqual(installed.sourceKind, .librarySnapshot)
    XCTAssertEqual(installed.libraryCharacterID, publication.entry.id)
    XCTAssertEqual(installed.libraryRevision, 1)
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: destinationProject.appendingPathComponent(installed.characterPath).path
      )
    )
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath:
          destinationProject
          .appendingPathComponent(installed.assetsDirectoryPath)
          .appendingPathComponent("head.usdz").path
      )
    )
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath:
          destinationProject
          .appendingPathComponent(installed.directoryPath)
          .appendingPathComponent(CharacterLibraryStore.metadataFilename).path
      )
    )
  }

  func testRepublishKeepsIdentityAndIncrementsRevision() throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let project = root.appendingPathComponent("Project", isDirectory: true)
    let library = root.appendingPathComponent("Library", isDirectory: true)
    let reference = ProjectCharacterReference(folderName: "atlas", displayName: "Atlas")
    let characterDirectory = project.appendingPathComponent(reference.directoryPath)
    try FileManager.default.createDirectory(
      at: characterDirectory.appendingPathComponent("assets"),
      withIntermediateDirectories: true
    )
    try Data("first".utf8).write(to: project.appendingPathComponent(reference.characterPath))
    try Data("{}".utf8).write(to: project.appendingPathComponent(reference.editorPath))
    let date = fixedDate
    let store = CharacterLibraryStore(now: { date })

    let first = try store.publish(reference, from: project, to: library)
    try Data("second".utf8).write(to: project.appendingPathComponent(reference.characterPath))
    let second = try store.publish(first.projectReference, from: project, to: library)

    XCTAssertEqual(second.entry.id, first.entry.id)
    XCTAssertEqual(second.entry.revision, 2)
    XCTAssertEqual(second.projectReference.libraryRevision, 2)
    XCTAssertEqual(try store.list(in: library).count, 1)
  }

  func testInstallUsesIndependentNameWhenProjectAlreadyHasCharacter() throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceProject = root.appendingPathComponent("Source")
    let targetProject = root.appendingPathComponent("Target")
    let library = root.appendingPathComponent("Library")
    let reference = ProjectCharacterReference(folderName: "atlas", displayName: "Atlas")
    try FileManager.default.createDirectory(
      at: sourceProject.appendingPathComponent(reference.assetsDirectoryPath),
      withIntermediateDirectories: true
    )
    try Data("rig".utf8).write(to: sourceProject.appendingPathComponent(reference.characterPath))
    try Data("{}".utf8).write(to: sourceProject.appendingPathComponent(reference.editorPath))
    let date = fixedDate
    let store = CharacterLibraryStore(now: { date })
    let published = try store.publish(reference, from: sourceProject, to: library)

    let installed = try store.install(
      published.entry,
      from: library,
      into: targetProject,
      existingCharacters: [reference]
    )

    XCTAssertEqual(installed.displayName, "Atlas Copy")
    XCTAssertEqual(installed.folderName, "atlas-copy")
    XCTAssertEqual(installed.characterFilename, reference.characterFilename)
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      "CharacterLibraryStoreTests-\(UUID().uuidString)",
      isDirectory: true
    )
  }
}
