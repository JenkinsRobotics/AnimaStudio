import XCTest

@testable import AnimaStudioUI

final class ModelImportUnitsTests: XCTestCase {
  func testSupportedModelImportContractIsExplicitAndClosed() {
    XCTAssertEqual(
      ModelImportFormatSupport.supportedFileExtensions,
      ["usd", "usda", "usdc", "usdz", "stl", "obj"]
    )
    for fileExtension in ModelImportFormatSupport.supportedFileExtensions {
      XCTAssertTrue(
        ModelImportFormatSupport.supports(
          URL(fileURLWithPath: "/tmp/model.\(fileExtension)")
        )
      )
    }
    for fileExtension in ["step", "stp", "reality", "urdf", "gltf", "glb"] {
      XCTAssertFalse(
        ModelImportFormatSupport.supports(
          URL(fileURLWithPath: "/tmp/model.\(fileExtension)")
        )
      )
    }
  }

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

  func testStagingDefaultsSTLToMillimetersAndOtherFormatsToMeters() {
    let stl = ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/head.stl"))
    let obj = ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/arm.obj"))
    let usd = ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/robot.usdz"))

    XCTAssertEqual(stl.unit, .millimeters)
    XCTAssertEqual(obj.unit, .meters)
    XCTAssertEqual(usd.unit, .meters)
  }

  func testStagingPlanAssignsTheWholeBatchToOneCharacter() {
    let requests = [
      ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/base.stl")),
      ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/head.usdz")),
    ]

    let plan = ModelImportStagingPlan(targetCharacterID: "atlas", requests: requests)

    XCTAssertEqual(plan.targetCharacterID, "atlas")
    XCTAssertEqual(plan.requests.map(\.url.lastPathComponent), ["base.stl", "head.usdz"])
  }

  func testStagingExplainsHowFilesBecomeRigidParts() {
    let stl = ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/base.stl"))
    let usd = ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/assembly.usd"))

    XCTAssertEqual(stl.partCreationDetail, "File becomes one rigid Part")
    XCTAssertEqual(usd.partCreationDetail, "Renderable nodes become rigid Parts")
  }
}
