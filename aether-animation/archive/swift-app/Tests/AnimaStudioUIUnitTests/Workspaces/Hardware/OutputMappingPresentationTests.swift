import AnimaCoreClient
import Foundation
import XCTest

@testable import AnimaStudioUI

final class OutputMappingPresentationTests: XCTestCase {
  func testCatalogIncludesBoundedDOFsAndParametersButExcludesUnlimitedDOFs() throws {
    let mates = try JSONDecoder().decode(
      [AnimaCoreJointSummary].self,
      from: Data(
        """
        [
          {
            "id":"Revolute 1",
            "name":"head_pan",
            "type":"revolute",
            "category":"kinematic",
            "parent_part":"base",
            "child_part":"head",
            "dofs":[
              {
                "path":"head_pan.rotation",
                "kind":"rotation",
                "unit":"radians",
                "axis":"z",
                "min":-1.5707963267948966,
                "max":1.5707963267948966,
                "neutral":0
              }
            ],
            "suppressed":false
          },
          {
            "id":"Revolute 2",
            "name":"free_wheel",
            "type":"revolute",
            "category":"kinematic",
            "parent_part":"base",
            "child_part":"wheel",
            "dofs":[
              {
                "path":"free_wheel.rotation",
                "kind":"rotation",
                "unit":"radians",
                "axis":"z",
                "neutral":0
              }
            ],
            "suppressed":false
          }
        ]
        """.utf8
      )
    )
    let parameters = try JSONDecoder().decode(
      [AnimaCoreParameterSummary].self,
      from: Data(
        """
        [{"name":"brightness","neutral":0.5,"description":"LED brightness"}]
        """.utf8
      )
    )

    let catalog = HardwareOutputTargetOption.catalog(
      mates: mates,
      chain: nil,
      parameters: parameters
    )

    XCTAssertEqual(Set(catalog.map(\.path)), Set(["head_pan.rotation", "brightness"]))
    let rotation = try XCTUnwrap(catalog.first { $0.path == "head_pan.rotation" })
    XCTAssertEqual(rotation.kind, .rotation)
    XCTAssertEqual(rotation.suggestedValueAtZero, -90, accuracy: 0.000_001)
    XCTAssertEqual(rotation.suggestedValueAtOne, 90, accuracy: 0.000_001)
  }

  func testDraftConvertsDegreesToRadiansAndSupportsDescendingRanges() throws {
    let target = HardwareOutputTargetOption(
      path: "head_pan.rotation",
      label: "Head Pan",
      kind: .rotation,
      suggestedValueAtZero: -90,
      suggestedValueAtOne: 90
    )
    var draft = HardwareOutputMappingDraft(target: target, channel: 4)
    draft.reverse()

    let values = try draft.validatedNativeValues(
      targets: [target],
      existingMappings: [],
      originalChannel: nil
    )

    XCTAssertEqual(values.valueAtZero, Double.pi / 2, accuracy: 0.000_000_1)
    XCTAssertEqual(values.valueAtOne, -Double.pi / 2, accuracy: 0.000_000_1)
  }

  func testDraftRejectsDuplicateChannelExceptItsOwnOriginalChannel() throws {
    let target = HardwareOutputTargetOption(
      path: "jaw.rotation",
      label: "Jaw",
      kind: .rotation,
      suggestedValueAtZero: -20,
      suggestedValueAtOne: 20
    )
    let draft = HardwareOutputMappingDraft(target: target, channel: 2)
    let existing = [
      AnimaCoreOutputSummary(
        targetPath: "head.rotation",
        channel: 2,
        valueAtZero: -1,
        valueAtOne: 1
      )
    ]

    XCTAssertThrowsError(
      try draft.validatedNativeValues(
        targets: [target],
        existingMappings: existing,
        originalChannel: nil
      )
    ) { error in
      XCTAssertEqual(
        error as? HardwareOutputMappingValidationError,
        .duplicateChannel(2)
      )
    }
    XCTAssertNoThrow(
      try draft.validatedNativeValues(
        targets: [target],
        existingMappings: existing,
        originalChannel: 2
      )
    )
  }
}
