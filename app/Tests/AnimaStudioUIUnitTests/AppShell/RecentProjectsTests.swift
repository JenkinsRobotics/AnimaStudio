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

  func testRecordOpenedMovesExistingProjectToTheFrontWithoutDuplicatingIt() {
    let defaults = isolatedDefaults()
    let id = UUID()
    let earlier = RecentProjectSummary(
      id: id,
      displayName: "Robot",
      lastOpenedAt: Date(timeIntervalSince1970: 100),
      revisionNumber: 3
    )
    let other = RecentProjectSummary(
      displayName: "Stage",
      lastOpenedAt: Date(timeIntervalSince1970: 200),
      revisionNumber: 7,
      thumbnailKind: .show
    )
    let reopened = RecentProjectSummary(
      id: id,
      displayName: "Robot",
      lastOpenedAt: Date(timeIntervalSince1970: 300),
      revisionNumber: 4
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
    let project = RecentProjectSummary(
      displayName: "Walker",
      lastOpenedAt: Date(timeIntervalSince1970: 500),
      revisionNumber: 12,
      milestoneName: "Stable gait",
      thumbnailKind: .character,
      thumbnailPath: "/tmp/walker-preview.png",
      projectPath: "/tmp/Walker",
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
      RecentProjectSummary(
        displayName: "Project \(index)",
        lastOpenedAt: Date(timeIntervalSince1970: Double(index)),
        revisionNumber: index + 1
      )
    }

    RecentProjectsPersistence.save(projects, to: defaults)
    let loaded = RecentProjectsPersistence.load(from: defaults)

    XCTAssertEqual(loaded.count, RecentProjectsPersistence.maximumCount)
    XCTAssertEqual(loaded.first?.displayName, "Project 14")
    XCTAssertEqual(loaded.last?.displayName, "Project 3")
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
}
