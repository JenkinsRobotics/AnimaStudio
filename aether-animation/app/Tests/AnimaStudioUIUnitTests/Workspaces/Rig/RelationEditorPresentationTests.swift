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
    draft.offsetFieldValue = 25

    XCTAssertEqual(RelationEditorPresentation(type: type).fieldTitle, "Distance per revolution")
    XCTAssertEqual(RelationEditorPresentation(type: type).fieldUnit, "mm")
    XCTAssertTrue(draft.canPrepareForAuthoring)
    XCTAssertEqual(try XCTUnwrap(draft.signedSemanticRatio), 0.02, accuracy: 0.000_000_1)
    XCTAssertEqual(try XCTUnwrap(draft.nativeOffset), 0.025, accuracy: 0.000_000_1)

    draft.isReversed = true
    XCTAssertEqual(try XCTUnwrap(draft.signedSemanticRatio), -0.02, accuracy: 0.000_000_1)

    let document = try draft.document(
      preserving: .object([
        "kind": .string("rack_pinion"),
        "driver": .string("old.rotation"),
        "driven": .string("old.travel"),
        "ratio": .number(1),
        "suppressed": .bool(true),
        "display": .object(["pinion_diameter_mm": .number(40)]),
        "future_field": .string("preserve"),
      ])
    )
    guard case .object(let object) = document else {
      XCTFail("Relation document must remain an object")
      return
    }
    XCTAssertEqual(object["driver"], .string("steering.rotation"))
    XCTAssertEqual(object["driven"], .string("rack.travel"))
    guard case .number(let ratio) = object["ratio"] else {
      XCTFail("Relation ratio must be numeric")
      return
    }
    XCTAssertEqual(ratio, -0.02, accuracy: 0.000_000_1)
    XCTAssertEqual(object["offset"], .number(0.025))
    XCTAssertEqual(object["suppressed"], .bool(true))
    XCTAssertEqual(object["future_field"], .string("preserve"))
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
    XCTAssertEqual(draft.validationError, .sameDegreeOfFreedom)
  }

  func testExistingRotationalRelationConvertsOffsetToDegrees() throws {
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
    let relation = try JSONDecoder().decode(
      AnimaCoreRelationSummary.self,
      from: Data(
        """
        {
          "kind":"gear",
          "driver":"left.rotation",
          "driven":"right.rotation",
          "ratio":-2,
          "offset":0.5235987755982988,
          "display":{}
        }
        """.utf8
      )
    )

    let draft = RelationDraft(relation: relation, type: type)

    XCTAssertEqual(draft.ratioFieldValue, 2)
    XCTAssertTrue(draft.isReversed)
    XCTAssertEqual(draft.offsetFieldValue, 30, accuracy: 0.000_001)
    XCTAssertEqual(try XCTUnwrap(draft.nativeOffset), .pi / 6, accuracy: 0.000_001)
  }

  private func relationType(_ json: String) throws -> AnimaCoreRelationTypeSummary {
    try JSONDecoder().decode(
      AnimaCoreRelationTypeSummary.self,
      from: Data(json.utf8)
    )
  }
}
