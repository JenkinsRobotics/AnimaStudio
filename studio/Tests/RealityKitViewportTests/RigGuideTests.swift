import XCTest

@testable import RealityKitViewport

@MainActor
final class RigGuideTests: XCTestCase {
  func testDefaultVisibilityEmphasizesConnectorDOFAndLimits() {
    let visibility = RigGuideVisibility()

    XCTAssertTrue(visibility.showsConnectors)
    XCTAssertTrue(visibility.showsDOFHandles)
    XCTAssertFalse(visibility.showsReferencePlanes)
    XCTAssertTrue(visibility.showsLimits)
  }

  func testHiddenVisibilityDisablesEveryGuideLayer() {
    let visibility = RigGuideVisibility.hidden

    XCTAssertFalse(visibility.showsConnectors)
    XCTAssertFalse(visibility.showsDOFHandles)
    XCTAssertFalse(visibility.showsReferencePlanes)
    XCTAssertFalse(visibility.showsLimits)
  }

  func testRevoluteGuideHasNamedToggleLayers() {
    let guide = RigGuideFactory.makeRevoluteGuide()

    XCTAssertEqual(guide.name, RigGuideFactory.rootName)
    XCTAssertNotNil(guide.findEntity(named: RigGuideFactory.connectorName))
    XCTAssertNotNil(guide.findEntity(named: RigGuideFactory.dofName))
    XCTAssertNotNil(guide.findEntity(named: RigGuideFactory.planeName))
    XCTAssertNotNil(guide.findEntity(named: RigGuideFactory.limitsName))
  }
}
