import RealityKit
import XCTest

final class RealityKitModelLoadingTests: XCTestCase {
  @MainActor
  func testLoadsUSDHierarchyFromDisk() async throws {
    let modelURL = try XCTUnwrap(
      Bundle.module.url(
        forResource: "SimpleRobot",
        withExtension: "usda",
        subdirectory: "Fixtures"
      )
    )

    let model = try await Entity(contentsOf: modelURL)

    XCTAssertNotNil(model.findEntity(named: "Body"))
    XCTAssertNotNil(model.findEntity(named: "HeadYaw"))
    XCTAssertNotNil(model.findEntity(named: "Head"))
  }
}
