import AnimaDocument
import XCTest

@testable import AnimaStudioUI

final class ModelImportUnitsTests: XCTestCase {
  func testSupportedModelImportContractIsExplicitAndClosed() {
    XCTAssertEqual(
      ModelImportFormatSupport.supportedFileExtensions,
      ["step", "stp", "usd", "usda", "usdc", "usdz", "stl", "obj"]
    )
    for fileExtension in ModelImportFormatSupport.supportedFileExtensions {
      XCTAssertTrue(
        ModelImportFormatSupport.supports(
          URL(fileURLWithPath: "/tmp/model.\(fileExtension)")
        )
      )
    }
    for fileExtension in ["reality", "urdf", "gltf", "glb"] {
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
    XCTAssertEqual(ModelImportUnit.inches.scaleToMeters, 0.0254)
    XCTAssertEqual(ModelImportUnit.meters.scaleToMeters, 1)
  }

  func testEveryUnitHasReadableUniquePresentation() {
    XCTAssertEqual(Set(ModelImportUnit.allCases.map(\.label)).count, 4)
    XCTAssertTrue(ModelImportUnit.millimeters.label.contains("mm"))
    XCTAssertTrue(ModelImportUnit.inches.label.contains("in"))
  }

  func testCADFilesOfferMillimetersCentimetersAndInchesButNotMeters() {
    let step = ModelImportRequest(url: URL(fileURLWithPath: "/tmp/gear.step"), unit: .millimeters)
    XCTAssertTrue(step.isCAD)
    XCTAssertTrue(step.allowsUnitSelection)
    XCTAssertEqual(step.availableUnits, [.millimeters, .centimeters, .inches])
    XCTAssertFalse(step.availableUnits.contains(.meters))
  }

  func testDetectsSTEPLengthUnitFromHeaderDeclaration() throws {
    func detect(_ body: String) throws -> ModelImportUnit? {
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("anima-unit-\(UUID().uuidString).step")
      try body.write(to: url, atomically: true, encoding: .utf8)
      defer { try? FileManager.default.removeItem(at: url) }
      return ModelImportUnit.detectedSTEPUnit(at: url)
    }
    XCTAssertEqual(try detect("#11 = ( LENGTH_UNIT() SI_UNIT(.MILLI.,.METRE.) );"), .millimeters)
    XCTAssertEqual(try detect("#11 = ( LENGTH_UNIT() SI_UNIT(.CENTI.,.METRE.) );"), .centimeters)
    XCTAssertEqual(try detect("#11 = ( LENGTH_UNIT() SI_UNIT($,.METRE.) );"), .meters)
    // Inch files declare .MILLI. .METRE. as the conversion base — inch wins.
    XCTAssertEqual(
      try detect("#9 = ( CONVERSION_BASED_UNIT('INCH',#10) LENGTH_UNIT() );\n"
        + "#11 = SI_UNIT(.MILLI.,.METRE.);"),
      .inches
    )
  }

  func testStagingAutoSelectsInchesForInchSTEPAndMillimetersWhenUnreadable() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("anima-inch-\(UUID().uuidString).step")
    try "( CONVERSION_BASED_UNIT('INCH',#10) LENGTH_UNIT() )".write(
      to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }

    XCTAssertEqual(ModelImportRequest.staged(url: url).unit, .inches)
    // A path with no readable file falls back to millimeters, never meters.
    XCTAssertEqual(
      ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/missing.step")).unit, .millimeters)
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

  func testStagingUsesPreferredUnitForUnitlessModelsAndMetersForEmbeddedUnits() {
    let suiteName = "ModelImportUnitsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(
      ModelImportUnit.centimeters.rawValue,
      forKey: StudioPreferenceKey.projectDefaultImportUnit
    )

    let stl = ModelImportRequest.staged(
      url: URL(fileURLWithPath: "/tmp/head.stl"), defaults: defaults)
    let obj = ModelImportRequest.staged(
      url: URL(fileURLWithPath: "/tmp/arm.obj"), defaults: defaults)
    let usd = ModelImportRequest.staged(
      url: URL(fileURLWithPath: "/tmp/robot.usdz"), defaults: defaults)

    XCTAssertEqual(stl.unit, .centimeters)
    XCTAssertEqual(obj.unit, .centimeters)
    XCTAssertEqual(usd.unit, .meters)
  }

  func testStagingPlanAssignsTheWholeBatchToOneCharacter() {
    let requests = [
      ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/base.stl")),
      ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/head.usdz")),
    ]

    let plan = ModelImportStagingPlan(
      targetCharacterID: "atlas",
      requests: requests,
      importMode: .copyIntoProject
    )

    XCTAssertEqual(plan.targetCharacterID, "atlas")
    XCTAssertEqual(plan.requests.map(\.url.lastPathComponent), ["base.stl", "head.usdz"])
    XCTAssertEqual(plan.importMode, .copyIntoProject)
  }

  func testImportStorageOffersOnlyNonDestructiveChoices() {
    XCTAssertEqual(
      AssetImportMode.allCases,
      [.copyIntoProject, .referenceInPlace]
    )
  }

  func testStagingExplainsHowFilesBecomeRigidParts() {
    let stl = ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/base.stl"))
    let usd = ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/assembly.usd"))
    let step = ModelImportRequest.staged(url: URL(fileURLWithPath: "/tmp/assembly.step"))

    XCTAssertEqual(stl.partCreationDetail, "File becomes one rigid Part")
    XCTAssertEqual(usd.partCreationDetail, "Renderable nodes become rigid Parts")
    XCTAssertEqual(step.partCreationDetail, "Open CASCADE assembly nodes become rigid Parts")
  }
}
