import XCTest

final class AnimaStudioAppUITests: XCTestCase {
  @MainActor
  func testLaunchesHomeAndOpensWorkspace() throws {
    let app = XCUIApplication()
    app.launch()

    let createProject = app.buttons["New Studio Project"]
    XCTAssertTrue(createProject.waitForExistence(timeout: 5))
    createProject.click()

    XCTAssertTrue(app.buttons["Animate"].waitForExistence(timeout: 5))
  }
}
