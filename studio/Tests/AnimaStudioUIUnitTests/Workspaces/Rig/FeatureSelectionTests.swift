import AnimaCore
import RealityKitViewport
import XCTest

@testable import AnimaStudioUI

/// Workspace-model semantics for standing sub-object (feature) selection:
/// viewport pick events, deselection, staged clearing, lock interaction,
/// and non-interference with the mate-placement flow.
@MainActor
final class FeatureSelectionTests: XCTestCase {
  private func candidate(
    for part: RigPartDefinition,
    id: String = "face-top"
  ) throws -> MateConnectorCandidate {
    try XCTUnwrap(MateConnectorInference.candidates(for: part).first { $0.id == id })
  }

  func testFeaturePickSelectsFeatureAndOwningComponent() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let part = model.project.rig.parts[0]
    let feature = try candidate(for: part)

    model.selectMateConnector(ViewportPickEvent.feature(feature))

    XCTAssertEqual(model.selectedFeature, feature)
    XCTAssertEqual(model.selection, [.part(part.id)])
    XCTAssertEqual(model.selectedPartID, part.id)
  }

  func testPickingAnotherFeatureReplacesTheSelection() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let part = model.project.rig.parts[0]
    let first = try candidate(for: part, id: "face-top")
    let second = try candidate(for: part, id: "corner-ppp")

    model.selectMateConnector(ViewportPickEvent.feature(first))
    model.selectMateConnector(ViewportPickEvent.feature(second))

    XCTAssertEqual(model.selectedFeature, second)
    XCTAssertEqual(model.selection, [.part(part.id)])
  }

  func testClearFeatureKeepsTheComponentSelected() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let part = model.project.rig.parts[0]
    model.selectMateConnector(ViewportPickEvent.feature(try candidate(for: part)))

    model.selectMateConnector(ViewportPickEvent.clearFeature)

    XCTAssertNil(model.selectedFeature)
    XCTAssertEqual(model.selection, [.part(part.id)])
  }

  func testEmptyClickClearsFeatureAndComponents() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let part = model.project.rig.parts[0]
    model.selectMateConnector(ViewportPickEvent.feature(try candidate(for: part)))

    model.selectMateConnector(ViewportPickEvent.clearAll)

    XCTAssertNil(model.selectedFeature)
    XCTAssertTrue(model.selection.isEmpty)
  }

  func testComponentGeometryClickClearsTheFeature() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let part = model.project.rig.parts[0]
    model.selectMateConnector(ViewportPickEvent.feature(try candidate(for: part)))

    model.selectPart(id: part.id, extendingSelection: false)

    XCTAssertNil(model.selectedFeature)
    XCTAssertEqual(model.selection, [.part(part.id)])
  }

  func testNavigatorSelectionOfAnotherComponentInvalidatesTheFeature() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let first = model.project.rig.parts[0]
    model.addPart(kind: .sphere)
    let second = model.project.rig.parts[1]
    model.selectMateConnector(ViewportPickEvent.feature(try candidate(for: first)))

    // The navigator writes the selection set directly.
    model.selection = [.part(second.id)]

    XCTAssertNil(model.selectedFeature)
  }

  func testClearSelectionClearsTheFeatureToo() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    model.selectMateConnector(
      ViewportPickEvent.feature(try candidate(for: model.project.rig.parts[0])))

    model.clearSelection()

    XCTAssertNil(model.selectedFeature)
    XCTAssertTrue(model.selection.isEmpty)
  }

  func testFeatureSelectionOnLockedComponentIsInspectOnly() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let part = model.project.rig.parts[0]
    model.toggleComponentLock(part.id)

    model.selectMateConnector(ViewportPickEvent.feature(try candidate(for: part)))

    XCTAssertEqual(model.selectedFeature?.partID, part.id)
    XCTAssertEqual(model.selection, [.part(part.id)])

    // Lock semantics still guard every edit path.
    model.setPartPosition(id: part.id, to: RigVector3(x: 1, y: 2, z: 3))
    XCTAssertEqual(model.project.rig.parts[0].positionMeters, RigVector3())
  }

  func testUnknownPartFeaturePickIsRejected() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let foreignPart = RigPartDefinition(displayName: "Ghost", primitiveKind: .box)
    let feature = try candidate(for: foreignPart)

    model.selectMateConnector(ViewportPickEvent.feature(feature))

    XCTAssertNil(model.selectedFeature)
    XCTAssertNotEqual(model.selection, [.part(foreignPart.id)])
  }

  func testBeginningMatePlacementSuppressesTheStandingFeature() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    model.addPart(kind: .box)
    let part = model.project.rig.parts[0]
    model.selectMateConnector(ViewportPickEvent.feature(try candidate(for: part)))

    model.beginRevoluteMatePlacement()
    XCTAssertNil(model.selectedFeature)

    model.cancelMatePlacement()
    XCTAssertNil(model.selectedFeature, "a cancelled placement does not resurrect the feature")
  }

  func testFeaturePickDuringPlacementDrivesThePlacementFlowUnchanged() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    let base = model.project.rig.parts[0]
    model.setPartPosition(id: base.id, to: RigVector3(x: 1, y: 0, z: 0))
    model.addPart(kind: .box)
    let moving = model.project.rig.parts[1]

    model.beginRevoluteMatePlacement()
    let source = try candidate(for: moving, id: "face-left")
    model.selectMateConnector(ViewportPickEvent.feature(source))

    XCTAssertEqual(model.matePlacement?.sourceCandidate, source)
    XCTAssertNil(model.selectedFeature)

    let target = try candidate(for: base, id: "face-right")
    model.selectMateConnector(ViewportPickEvent.feature(target))

    XCTAssertNil(model.matePlacement)
    XCTAssertEqual(model.project.rig.joints.count, 1)
    XCTAssertNil(model.selectedFeature)
  }

  func testEmptyClickDuringPlacementPreservesThePlacementSession() throws {
    let model = StudioWorkspaceModel()
    model.addPart(kind: .box)
    model.addPart(kind: .box)
    let moving = model.project.rig.parts[1]

    model.beginRevoluteMatePlacement()
    let source = try candidate(for: moving, id: "face-left")
    model.selectMateConnector(ViewportPickEvent.feature(source))

    model.selectMateConnector(ViewportPickEvent.clearAll)

    XCTAssertNotNil(model.matePlacement)
    XCTAssertEqual(model.matePlacement?.sourceCandidate, source)
  }
}
