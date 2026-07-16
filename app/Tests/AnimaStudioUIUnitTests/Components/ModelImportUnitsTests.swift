import XCTest

@testable import AnimaStudioUI

final class ModelImportUnitsTests: XCTestCase {
  func testUnitlessModelScalesAreExplicitSIConversions() {
    XCTAssertEqual(ModelImportUnit.millimeters.scaleToMeters, 0.001)
    XCTAssertEqual(ModelImportUnit.centimeters.scaleToMeters, 0.01)
    XCTAssertEqual(ModelImportUnit.meters.scaleToMeters, 1)
  }

  func testEveryUnitHasReadableUniquePresentation() {
    XCTAssertEqual(Set(ModelImportUnit.allCases.map(\.label)).count, 3)
    XCTAssertTrue(ModelImportUnit.millimeters.label.contains("mm"))
  }
}
