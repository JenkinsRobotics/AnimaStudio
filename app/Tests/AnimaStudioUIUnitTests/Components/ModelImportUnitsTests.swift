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

  func testBatchRequestsOnlyAskForUnitsOnSTLAndOBJ() {
    let stl = ModelImportRequest(
      url: URL(fileURLWithPath: "/tmp/head.stl"),
      unit: .millimeters
    )
    let obj = ModelImportRequest(
      url: URL(fileURLWithPath: "/tmp/arm.obj"),
      unit: .centimeters
    )
    let usd = ModelImportRequest(
      url: URL(fileURLWithPath: "/tmp/robot.usdz"),
      unit: .meters
    )

    XCTAssertTrue(stl.isUnitless)
    XCTAssertTrue(obj.isUnitless)
    XCTAssertFalse(usd.isUnitless)
  }
}
