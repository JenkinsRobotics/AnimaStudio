import AnimaDocument
import Foundation
import XCTest

@testable import AnimaStudioUI

final class RecentProjectsTests: XCTestCase {
  func testSummaryNormalizesRevisionAndProvidesStableLabel() {
    let summary = RecentProjectSummary(
      displayName: "  Robot Head  ",
      lastOpenedAt: Date(timeIntervalSince1970: 100),
      revisionNumber: 0,
      milestoneName: "First motion",
      thumbnailKind: .character
    )

    XCTAssertEqual(summary.displayName, "Robot Head")
    XCTAssertEqual(summary.revisionNumber, 1)
    XCTAssertEqual(summary.revisionLabel, "V1")
    XCTAssertEqual(summary.milestoneName, "First motion")
  }

  func testRecordOpenedMovesExistingProjectToTheFrontWithoutDuplicatingIt() throws {
    let defaults = isolatedDefaults()
    let id = UUID()
    let robotURL = try temporaryProjectDirectory(named: "Robot")
    let stageURL = try temporaryProjectDirectory(named: "Stage")
    let earlier = RecentProjectSummary(
      id: id,
      displayName: "Robot",
      lastOpenedAt: Date(timeIntervalSince1970: 100),
      revisionNumber: 3,
      projectPath: robotURL.path
    )
    let other = RecentProjectSummary(
      displayName: "Stage",
      lastOpenedAt: Date(timeIntervalSince1970: 200),
      revisionNumber: 7,
      thumbnailKind: .show,
      projectPath: stageURL.path
    )
    let reopened = RecentProjectSummary(
      id: id,
      displayName: "Robot",
      lastOpenedAt: Date(timeIntervalSince1970: 300),
      revisionNumber: 4,
      projectPath: robotURL.path
    )

    let result = RecentProjectsPersistence.recordOpened(
      reopened,
      in: [other, earlier],
      defaults: defaults
    )

    XCTAssertEqual(result.map(\.id), [id, other.id])
    XCTAssertEqual(result.first?.revisionNumber, 4)
  }

  func testPersistenceRoundTripsMilestoneAndThumbnailMetadata() throws {
    let defaults = isolatedDefaults()
    let projectURL = try temporaryProjectDirectory(named: "Walker")
    let project = RecentProjectSummary(
      displayName: "Walker",
      lastOpenedAt: Date(timeIntervalSince1970: 500),
      revisionNumber: 12,
      milestoneName: "Stable gait",
      thumbnailKind: .character,
      thumbnailPath: "/tmp/walker-preview.png",
      projectPath: projectURL.path,
      bookmarkData: Data([1, 2, 3])
    )

    RecentProjectsPersistence.save([project], to: defaults)
    let loaded = try XCTUnwrap(RecentProjectsPersistence.load(from: defaults).first)

    XCTAssertEqual(loaded, project)
    XCTAssertTrue(loaded.canOpen)
  }

  func testProjectSessionProducesStableBookmarkBackedRecent() {
    let document = ProjectLifecycle.makeEmptyDocument(name: "Walker")
    let session = StudioProjectSession(
      document: document,
      projectURL: URL(fileURLWithPath: "/tmp/Walker", isDirectory: true),
      bookmarkData: Data([4, 5, 6])
    )
    let recent = RecentProjectSummary.project(
      session,
      openedAt: Date(timeIntervalSince1970: 900)
    )

    XCTAssertEqual(recent.id, document.projectID)
    XCTAssertEqual(recent.projectPath, "/tmp/Walker")
    XCTAssertEqual(recent.bookmarkData, Data([4, 5, 6]))
    XCTAssertTrue(recent.canOpen)
  }

  func testPersistenceKeepsOnlyTheTwelveMostRecentValidProjects() {
    let defaults = isolatedDefaults()
    let projects = (0..<15).map { index in
      let projectURL = try! temporaryProjectDirectory(named: "Project-\(index)")
      return RecentProjectSummary(
        displayName: "Project \(index)",
        lastOpenedAt: Date(timeIntervalSince1970: Double(index)),
        revisionNumber: index + 1,
        projectPath: projectURL.path
      )
    }

    RecentProjectsPersistence.save(projects, to: defaults)
    let loaded = RecentProjectsPersistence.load(from: defaults)

    XCTAssertEqual(loaded.count, RecentProjectsPersistence.maximumCount)
    XCTAssertEqual(loaded.first?.displayName, "Project 14")
    XCTAssertEqual(loaded.last?.displayName, "Project 3")
  }

  func testRemoveForgetsOnlyTheRecentEntryAndLeavesProjectFolderOnDisk() throws {
    let defaults = isolatedDefaults()
    let removedURL = try temporaryProjectDirectory(named: "Keep-On-Disk")
    let retainedURL = try temporaryProjectDirectory(named: "Retained")
    let removed = RecentProjectSummary(
      displayName: "Forget Me",
      lastOpenedAt: Date(timeIntervalSince1970: 200),
      revisionNumber: 2,
      projectPath: removedURL.path
    )
    let retained = RecentProjectSummary(
      displayName: "Keep Me",
      lastOpenedAt: Date(timeIntervalSince1970: 100),
      revisionNumber: 1,
      projectPath: retainedURL.path
    )
    RecentProjectsPersistence.save([removed, retained], to: defaults)

    let updated = RecentProjectsPersistence.remove(id: removed.id, from: defaults)

    XCTAssertEqual(updated.map(\.id), [retained.id])
    XCTAssertEqual(RecentProjectsPersistence.load(from: defaults).map(\.id), [retained.id])
    XCTAssertTrue(FileManager.default.fileExists(atPath: removedURL.path))
  }

  func testLoadPrunesMissingProjectsAndPersistsTheCleanedList() throws {
    let defaults = isolatedDefaults()
    let existingURL = try temporaryProjectDirectory(named: "Existing")
    let missingURL = existingURL.deletingLastPathComponent()
      .appendingPathComponent("Missing-\(UUID().uuidString)", isDirectory: true)
    let existing = RecentProjectSummary(
      displayName: "Existing",
      lastOpenedAt: Date(timeIntervalSince1970: 100),
      revisionNumber: 1,
      projectPath: existingURL.path
    )
    let missing = RecentProjectSummary(
      displayName: "Missing",
      lastOpenedAt: Date(timeIntervalSince1970: 200),
      revisionNumber: 1,
      projectPath: missingURL.path
    )
    RecentProjectsPersistence.save([missing, existing], to: defaults)

    XCTAssertEqual(RecentProjectsPersistence.load(from: defaults).map(\.id), [existing.id])

    let storedData = try XCTUnwrap(defaults.data(forKey: RecentProjectsPersistence.storageKey))
    let stored = try JSONDecoder().decode([RecentProjectSummary].self, from: storedData)
    XCTAssertEqual(stored.map(\.id), [existing.id])
  }

  private func isolatedDefaults() -> UserDefaults {
    let suiteName = "RecentProjectsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    addTeardownBlock {
      UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }
    return defaults
  }

  private func temporaryProjectDirectory(named name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("AnimaStudio-RecentProjectsTests-\(UUID().uuidString)")
      .appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
    return url
  }
}
