import XCTest

final class AnimaStudioAppUITests: XCTestCase {
  @MainActor
  func testLaunchesHomeAndOpensWorkspace() throws {
    let app = XCUIApplication()
    app.launchEnvironment["ANIMACORE_REPOSITORY_ROOT"] = repositoryRootPath
    app.launch()

    let createProject = app.buttons["New Studio Project"]
    XCTAssertTrue(createProject.waitForExistence(timeout: 5))
    createProject.click()

    XCTAssertTrue(app.buttons["Animate"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["AnimaCore 0.1.0"].waitForExistence(timeout: 5))
  }

  private var repositoryRootPath: String {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .path
  }
}
