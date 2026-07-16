import AnimaCoreClient
import Foundation
import XCTest

@testable import AnimaStudioUI

final class RelationEditorPresentationTests: XCTestCase {
  func testRackPinionUsesMillimetersPerRevolutionAndNativeRatioConversion() throws {
    let type = try relationType(
      """
      {
        "kind":"rack_pinion",
        "label":"Rack and pinion",
        "driver_kind":"rotation",
        "driven_kind":"translation",
        "ratio_field":{"key":"distance_per_revolution","unit":"mm"},
        "reverse_supported":true
      }
      """
    )
    var draft = RelationDraft(type: type)
    draft.driverPath = "steering.rotation"
    draft.drivenPath = "rack.travel"
    draft.ratioFieldValue = 125.663_706

    XCTAssertEqual(RelationEditorPresentation(type: type).fieldTitle, "Distance per revolution")
    XCTAssertEqual(RelationEditorPresentation(type: type).fieldUnit, "mm")
    XCTAssertTrue(draft.canPrepareForAuthoring)
    XCTAssertEqual(try XCTUnwrap(draft.signedSemanticRatio), 0.02, accuracy: 0.000_000_1)

    draft.isReversed = true
    XCTAssertEqual(try XCTUnwrap(draft.signedSemanticRatio), -0.02, accuracy: 0.000_000_1)
  }

  func testGearKeepsUnitlessRatioAndRejectsSameDOFPair() throws {
    let type = try relationType(
      """
      {
        "kind":"gear",
        "label":"Gear",
        "driver_kind":"rotation",
        "driven_kind":"rotation",
        "ratio_field":{"key":"relation_ratio","unit":"ratio"},
        "reverse_supported":true
      }
      """
    )
    var draft = RelationDraft(type: type)
    draft.driverPath = "left.rotation"
    draft.drivenPath = "left.rotation"
    draft.ratioFieldValue = 2.5

    XCTAssertEqual(RelationEditorPresentation(type: type).fieldTitle, "Relation ratio")
    XCTAssertNil(RelationEditorPresentation(type: type).fieldUnit)
    XCTAssertFalse(draft.canPrepareForAuthoring)
    XCTAssertEqual(draft.signedSemanticRatio, 2.5)
  }

  private func relationType(_ json: String) throws -> AnimaCoreRelationTypeSummary {
    try JSONDecoder().decode(
      AnimaCoreRelationTypeSummary.self,
      from: Data(json.utf8)
    )
  }
}
