import XCTest

final class AnimaStudioAppUITests: XCTestCase {
  @MainActor
  func testCommandCommaOpensStandardSettingsWindow() {
    let app = XCUIApplication()
    app.launch()

    app.typeKey(",", modifierFlags: .command)

    XCTAssertTrue(app.staticTexts["Project Workspace"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Navigation"].exists)
    XCTAssertTrue(app.buttons["Appearance"].exists)
  }

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

  @MainActor
  func testDraggingAComponentOntoAnotherCreatesAnExpandedGroup() {
    let app = XCUIApplication()
    app.launchEnvironment["ANIMACORE_REPOSITORY_ROOT"] = repositoryRootPath
    app.launch()

    let createProject = app.buttons["New Studio Project"]
    XCTAssertTrue(createProject.waitForExistence(timeout: 5))
    createProject.click()
    XCTAssertTrue(app.buttons["Animate"].waitForExistence(timeout: 5))

    app.typeKey("2", modifierFlags: .command)
    let boxTool = app.buttons["Box"]
    XCTAssertTrue(boxTool.waitForExistence(timeout: 5))
    boxTool.click()
    boxTool.click()

    let first = app.staticTexts["Box 1"]
    let second = app.staticTexts["Box 2"]
    XCTAssertTrue(first.waitForExistence(timeout: 5))
    XCTAssertTrue(second.waitForExistence(timeout: 5))

    first.press(forDuration: 0.7, thenDragTo: second)

    XCTAssertTrue(app.staticTexts["Group 1"].waitForExistence(timeout: 5))
    XCTAssertTrue(first.exists)
    XCTAssertTrue(second.exists)
  }

  private var repositoryRootPath: String {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .path
  }
}
