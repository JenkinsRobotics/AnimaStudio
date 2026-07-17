import Foundation
import XCTest

@testable import AnimaStudioUI

final class WorkspaceLocationPreferenceTests: XCTestCase {
  private var suiteName: String!
  private var userDefaults: UserDefaults!
  private var temporaryRoot: URL!

  override func setUpWithError() throws {
    suiteName = "WorkspaceLocationPreferenceTests.\(UUID().uuidString)"
    userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    userDefaults.removePersistentDomain(forName: suiteName)
    temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("AnimaWorkspaceLocation-\(UUID().uuidString)", isDirectory: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: temporaryRoot)
    userDefaults.removePersistentDomain(forName: suiteName)
    userDefaults = nil
    suiteName = nil
    temporaryRoot = nil
  }

  func testDefaultRootIsAnimaStudioInsideDocuments() throws {
    let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
    let preference = makePreference(documentsURL: documentsURL)

    XCTAssertEqual(
      preference.workspaceRootURL,
      documentsURL.appendingPathComponent("AnimaStudio", isDirectory: true)
    )
  }

  func testProductionDocumentsResolverDoesNotUseAnAppContainer() {
    let documentsURL = WorkspaceLocationPreference.realUserDocumentsDirectory()

    XCTAssertEqual(documentsURL.lastPathComponent, "Documents")
    XCTAssertFalse(documentsURL.path.contains("/Library/Containers/"))
  }

  func testPreparedPanelDirectoryCreatesAndReturnsExactWorkspaceRoot() throws {
    let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
    let preference = makePreference(documentsURL: documentsURL)

    let panelDirectory = try preference.preparedPanelDirectory()

    XCTAssertEqual(
      panelDirectory,
      documentsURL.appendingPathComponent("AnimaStudio", isDirectory: true)
    )
    XCTAssertTrue(FileManager.default.fileExists(atPath: panelDirectory.path))
  }

  func testGrantedDocumentsParentCreatesTheNamedWorkspaceRoot() throws {
    let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
    let preference = makePreference(documentsURL: documentsURL)

    let rootURL = try preference.createWorkspaceRoot(in: documentsURL)

    XCTAssertEqual(
      rootURL,
      documentsURL.appendingPathComponent("AnimaStudio", isDirectory: true)
    )
    XCTAssertTrue(FileManager.default.fileExists(atPath: rootURL.path))
  }

  func testGrantingExistingWorkspaceRootDoesNotNestAnotherFolder() throws {
    let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
    let existingRoot = documentsURL.appendingPathComponent("AnimaStudio", isDirectory: true)
    let preference = makePreference(documentsURL: documentsURL)

    let rootURL = try preference.createWorkspaceRoot(in: existingRoot)

    XCTAssertEqual(rootURL, existingRoot)
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: existingRoot.appendingPathComponent("AnimaStudio").path
      )
    )
  }

  func testEnsureRootCreatesDefaultFolderLazily() throws {
    let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
    let preference = makePreference(documentsURL: documentsURL)

    let rootURL = try preference.ensureWorkspaceRootExists()

    var isDirectory: ObjCBool = false
    XCTAssertTrue(FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory))
    XCTAssertTrue(isDirectory.boolValue)
  }

  func testCustomRootPersistsAndRestoreReturnsToDefault() throws {
    let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
    let customURL = temporaryRoot.appendingPathComponent("Robot Projects", isDirectory: true)
    let preference = makePreference(documentsURL: documentsURL)

    preference.persistWorkspaceRoot(customURL, bookmarkData: Data())
    XCTAssertEqual(preference.workspaceRootURL, customURL.standardizedFileURL)

    preference.restoreDefaultWorkspaceRoot()
    XCTAssertEqual(
      preference.workspaceRootURL,
      documentsURL.appendingPathComponent("AnimaStudio", isDirectory: true).standardizedFileURL
    )
  }

  func testLegacySpacedDefaultMigratesToNoSpaceDefault() throws {
    let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
    let legacyURL = documentsURL.appendingPathComponent("Anima Studio", isDirectory: true)
    let preference = makePreference(documentsURL: documentsURL)
    userDefaults.set(legacyURL.path, forKey: StudioPreferenceKey.workspaceRootPath)

    XCTAssertEqual(
      preference.workspaceRootURL,
      documentsURL.appendingPathComponent("AnimaStudio", isDirectory: true).standardizedFileURL
    )
  }

  private func makePreference(documentsURL: URL) -> WorkspaceLocationPreference {
    WorkspaceLocationPreference(
      fileManager: .default,
      userDefaults: userDefaults,
      documentsDirectory: { documentsURL }
    )
  }
}
