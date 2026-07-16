import AnimaEvaluation
import AnimaModel
import XCTest

@testable import RealityKitViewport

final class SubObjectSelectionTests: XCTestCase {
  private let part = RigPartDefinition(displayName: "Box", primitiveKind: .box)

  private func candidate(_ id: String = "face-top") -> MateConnectorCandidate {
    MateConnectorInference.candidates(for: part).first { $0.id == id }!
  }

  // MARK: Tap outcome resolution

  func testFeatureTapSelectsTheFeatureInStandingMode() {
    let feature = candidate()

    let outcome = SubObjectSelection.outcome(
      forTapOn: .feature(feature),
      isPlacementActive: false
    )

    XCTAssertEqual(outcome, .selectFeature(feature))
  }

  func testFeatureTapDuringPlacementForwardsToThePlacementFlow() {
    let feature = candidate()

    let outcome = SubObjectSelection.outcome(
      forTapOn: .feature(feature),
      isPlacementActive: true
    )

    XCTAssertEqual(outcome, .forwardToPlacement(feature))
  }

  func testComponentTapIsPlainComponentSelection() {
    for isPlacementActive in [false, true] {
      let outcome = SubObjectSelection.outcome(
        forTapOn: .component(part.id),
        isPlacementActive: isPlacementActive
      )
      XCTAssertEqual(outcome, .selectComponent(part.id))
    }
  }

  func testEmptyTapClearsEverythingInStandingMode() {
    let outcome = SubObjectSelection.outcome(
      forTapOn: .empty,
      isPlacementActive: false
    )

    XCTAssertEqual(outcome, .clearAll)
  }

  func testEmptyTapDuringPlacementIsIgnored() {
    let outcome = SubObjectSelection.outcome(
      forTapOn: .empty,
      isPlacementActive: true
    )

    XCTAssertEqual(outcome, .ignore)
  }

  func testImportedNodeTapSelectsTheImportedNode() {
    let outcome = SubObjectSelection.outcome(
      forTapOn: .importedNode,
      isPlacementActive: false
    )

    XCTAssertEqual(outcome, .selectImportedNode)
  }

  func testPointerTargetsKeepOnlySemanticIdentity() {
    let feature = candidate()

    XCTAssertEqual(
      SubObjectSelection.pointerTarget(for: .feature(feature)),
      .feature(feature.partID)
    )
    XCTAssertEqual(
      SubObjectSelection.pointerTarget(for: .component(part.id)),
      .component(part.id)
    )
    XCTAssertEqual(SubObjectSelection.pointerTarget(for: .importedNode), .importedNode)
    XCTAssertEqual(SubObjectSelection.pointerTarget(for: .empty), .canvas)
  }

  func testObjectMenuRequiresSelectedComponentUnderPointer() {
    XCTAssertEqual(
      SubObjectSelection.contextMenuTarget(
        pointerTarget: .component(part.id),
        selectedPartID: part.id
      ),
      .selectedComponent(part.id)
    )
    XCTAssertEqual(
      SubObjectSelection.contextMenuTarget(
        pointerTarget: .feature(part.id),
        selectedPartID: part.id
      ),
      .selectedComponent(part.id)
    )

    let otherPart = RigPartDefinition(displayName: "Other", primitiveKind: .sphere)
    for pointerTarget in [
      ViewportPointerTarget.canvas,
      .importedNode,
      .component(otherPart.id),
    ] {
      XCTAssertEqual(
        SubObjectSelection.contextMenuTarget(
          pointerTarget: pointerTarget,
          selectedPartID: part.id
        ),
        .canvas
      )
    }
  }

  // MARK: Staged Escape

  func testEscapeClearsAStandingFeatureBeforeComponentSelection() {
    XCTAssertTrue(
      SubObjectSelection.shouldConsumeEscape(
        hasFeatureSelection: true,
        isPlacementActive: false,
        isTextInputActive: false
      )
    )
  }

  func testEscapePassesThroughWithoutAFeatureSelection() {
    XCTAssertFalse(
      SubObjectSelection.shouldConsumeEscape(
        hasFeatureSelection: false,
        isPlacementActive: false,
        isTextInputActive: false
      )
    )
  }

  func testEscapePassesThroughDuringMatePlacement() {
    XCTAssertFalse(
      SubObjectSelection.shouldConsumeEscape(
        hasFeatureSelection: true,
        isPlacementActive: true,
        isTextInputActive: false
      )
    )
  }

  func testEscapePassesThroughWhileEditingText() {
    XCTAssertFalse(
      SubObjectSelection.shouldConsumeEscape(
        hasFeatureSelection: true,
        isPlacementActive: false,
        isTextInputActive: true
      )
    )
  }

  // MARK: Focus coupling

  func testFeatureSurvivesOnlyWhileItsComponentStaysFocused() {
    let feature = candidate()
    let otherPartID = RigPartDefinition(displayName: "Other", primitiveKind: .sphere).id

    XCTAssertTrue(
      SubObjectSelection.featureSurvivesFocusChange(feature, focusedPartID: part.id)
    )
    XCTAssertFalse(
      SubObjectSelection.featureSurvivesFocusChange(feature, focusedPartID: otherPartID)
    )
    XCTAssertFalse(
      SubObjectSelection.featureSurvivesFocusChange(feature, focusedPartID: nil)
    )
    XCTAssertFalse(
      SubObjectSelection.featureSurvivesFocusChange(nil, focusedPartID: part.id)
    )
  }

  // MARK: Marker presentation

  func testStandingSelectionMarkersAreDistinguishableFromPlacementMarkers() {
    let placementIdle = MateConnectorMarkerStyle.placement.appearance(isSelected: false)
    let standingIdle = MateConnectorMarkerStyle.standingSelection.appearance(isSelected: false)
    let standingSelected = MateConnectorMarkerStyle.standingSelection.appearance(isSelected: true)

    XCTAssertNotEqual(placementIdle.tint, standingIdle.tint)
    XCTAssertNotNil(standingIdle.opacity, "idle preview markers stay quiet until hover")
    XCTAssertNil(standingSelected.opacity, "the committed feature reads at full strength")
    XCTAssertGreaterThan(standingSelected.radiusMeters, standingIdle.radiusMeters)
    XCTAssertFalse(standingIdle.showsAxisStem)
    XCTAssertTrue(standingSelected.showsAxisStem)
  }

  func testPlacementMarkerAppearanceIsUnchanged() {
    let idle = MateConnectorMarkerStyle.placement.appearance(isSelected: false)
    let selected = MateConnectorMarkerStyle.placement.appearance(isSelected: true)

    XCTAssertEqual(idle.tint, .systemOrange)
    XCTAssertEqual(idle.radiusMeters, 0.031)
    XCTAssertEqual(selected.tint, .systemPurple)
    XCTAssertEqual(selected.radiusMeters, 0.042)
    XCTAssertNil(idle.opacity)
    XCTAssertNil(selected.opacity)
  }

  func testFeatureKindsHaveOperatorFacingNames() {
    for kind in MateConnectorFeatureKind.allCases {
      XCTAssertFalse(kind.displayName.isEmpty)
    }
    XCTAssertEqual(MateConnectorFeatureKind.faceCenter.displayName, "Face Center")
    XCTAssertEqual(MateConnectorFeatureKind.edgeMidpoint.displayName, "Edge Midpoint")
  }
}
