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
      XCTAssertFalse(kind.dofSummary.isEmpty)
    }
  }

  func testDofSummariesMatchTheOnshapeMateDefinitions() {
    XCTAssertEqual(MateCreationToolKind.fastened.dofSummary, "0 — fully bonded")
    XCTAssertEqual(
      MateCreationToolKind.parallel.dofSummary, "3 translational + 1 rotational")
    XCTAssertEqual(MateCreationToolKind.slider.dofSummary, "1 translational")
    XCTAssertEqual(MateCreationToolKind.revolute.dofSummary, "1 rotational")
    XCTAssertEqual(
      MateCreationToolKind.cylindrical.dofSummary,
      "1 rotational + 1 translational")
    XCTAssertEqual(
      MateCreationToolKind.pinSlot.dofSummary, "1 rotational + 1 translational")
    XCTAssertEqual(
      MateCreationToolKind.planar.dofSummary, "2 translational + 1 rotational")
    XCTAssertEqual(MateCreationToolKind.ball.dofSummary, "3 rotational")
  }
}
