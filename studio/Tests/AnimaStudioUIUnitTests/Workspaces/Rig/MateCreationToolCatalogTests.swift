import XCTest

@testable import AnimaStudioUI

final class MateCreationToolCatalogTests: XCTestCase {
  func testMateToolsAppearInTheAgreedRibbonOrder() {
    XCTAssertEqual(
      MateCreationToolKind.allCases.map(\.title),
      [
        "Fastened",
        "Parallel",
        "Slider",
        "Revolute",
        "Cylindrical",
        "Pin Slot",
        "Planar",
        "Ball",
      ]
    )
  }

  func testOnlyRevoluteIsMarkedImplementedUntilTypedMateBackendLands() {
    XCTAssertEqual(
      MateCreationToolKind.allCases.filter(\.isImplemented),
      [.revolute]
    )
  }

  func testEveryMateToolHasOperatorFacingPresentation() {
    for kind in MateCreationToolKind.allCases {
      XCTAssertFalse(kind.systemImage.isEmpty)
      XCTAssertFalse(kind.motionSummary.isEmpty)
    }
  }
}
