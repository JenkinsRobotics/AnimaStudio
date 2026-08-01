import Foundation
import XCTest

@testable import AnimaStudioUI

final class WorkspaceChromeTests: XCTestCase {
  func testWindowHeaderDoubleClickFollowsMacOSPreference() {
    XCTAssertEqual(StudioWindowDoubleClickAction.resolve(preference: nil), .zoom)
    XCTAssertEqual(StudioWindowDoubleClickAction.resolve(preference: "Maximize"), .zoom)
    XCTAssertEqual(StudioWindowDoubleClickAction.resolve(preference: "Minimize"), .minimize)
    XCTAssertEqual(StudioWindowDoubleClickAction.resolve(preference: "None"), .none)
  }

  func testCenteredWorkspaceNavigatorKeepsAReadableWidth() {
    XCTAssertGreaterThanOrEqual(WorkspaceSelectorMetrics.minimumWidth, 280)
    XCTAssertGreaterThanOrEqual(
      WorkspaceSelectorMetrics.idealWidth,
      WorkspaceSelectorMetrics.minimumWidth
    )
    XCTAssertGreaterThanOrEqual(
      WorkspaceSelectorMetrics.maximumWidth,
      WorkspaceSelectorMetrics.idealWidth
    )
    XCTAssertLessThan(WorkspaceSelectorMetrics.menuWidth, WorkspaceSelectorMetrics.minimumWidth)
    XCTAssertLessThanOrEqual(WorkspaceSelectorMetrics.maximumWidth, 560)
    XCTAssertGreaterThanOrEqual(WorkspaceSelectorMetrics.maximumWidth, 500)
  }

  func testStudioModesUseOperatorFacingNamesAndCycleInOrder() {
    XCTAssertEqual(StudioLayoutPreset.floating.title, "Floating")
    XCTAssertEqual(StudioLayoutPreset.docked.title, "Docked")
    XCTAssertEqual(StudioLayoutPreset.canvas.title, "Canvas")
    XCTAssertEqual(StudioLayoutPreset.floating.next, .docked)
    XCTAssertEqual(StudioLayoutPreset.docked.next, .canvas)
    XCTAssertEqual(StudioLayoutPreset.canvas.next, .floating)
  }

  func testDocumentBarUsesStableResponsiveDensities() {
    XCTAssertEqual(StudioDocumentBarDensity.resolve(width: 1_800), .expanded)
    XCTAssertEqual(StudioDocumentBarDensity.resolve(width: 1_320), .expanded)
    XCTAssertEqual(StudioDocumentBarDensity.resolve(width: 1_319), .compact)
    XCTAssertEqual(StudioDocumentBarDensity.resolve(width: 1_060), .compact)
    XCTAssertEqual(StudioDocumentBarDensity.resolve(width: 1_059), .minimal)

    XCTAssertEqual(
      StudioDocumentBarDensity.expanded.selectorWidth,
      WorkspaceSelectorMetrics.maximumWidth
    )
    XCTAssertEqual(
      StudioDocumentBarDensity.compact.selectorWidth,
      WorkspaceSelectorMetrics.idealWidth
    )
    XCTAssertEqual(
      StudioDocumentBarDensity.minimal.selectorWidth,
      WorkspaceSelectorMetrics.minimumWidth
    )
  }

  func testHeaderRegionsCollapseAtTheDemoBreakpointsIndependently() {
    XCTAssertEqual(
      StudioHeaderPresentation.resolve(width: 1_320),
      StudioHeaderPresentation(
        collapsesFileCommands: false,
        usesCompactTabs: false,
        usesCompactRuntimeControls: false
      )
    )
    XCTAssertEqual(
      StudioHeaderPresentation.resolve(width: 1_319),
      StudioHeaderPresentation(
        collapsesFileCommands: true,
        usesCompactTabs: false,
        usesCompactRuntimeControls: false
      )
    )
    XCTAssertTrue(StudioHeaderPresentation.resolve(width: 1_059).usesCompactTabs)
    XCTAssertFalse(
      StudioHeaderPresentation.resolve(width: 880).usesCompactRuntimeControls
    )
    XCTAssertTrue(
      StudioHeaderPresentation.resolve(width: 879).usesCompactRuntimeControls
    )
  }

  func testProjectIdentityNameWidthFollowsContentAndStaysBounded() {
    let shortNameWidth = StudioProjectIdentityMetrics.projectNameWidth(
      for: "Test",
      density: .expanded
    )
    let mediumNameWidth = StudioProjectIdentityMetrics.projectNameWidth(
      for: "Atlas Animatronic",
      density: .expanded
    )
    let longNameWidth = StudioProjectIdentityMetrics.projectNameWidth(
      for: String(repeating: "Character", count: 30),
      density: .expanded
    )

    XCTAssertLessThan(shortNameWidth, mediumNameWidth)
    XCTAssertLessThan(mediumNameWidth, longNameWidth)
    XCTAssertEqual(longNameWidth, 170)
  }

  func testWorkspaceWindowRequestRoundTripsItsPresentationIntent() throws {
    let id = UUID()
    let request = StudioWorkspaceWindowRequest(
      id: id,
      workspaceRawValue: StudioWorkspaceKind.animate.rawValue,
      projectDisplayName: "Atlas",
      targetTabWindowNumber: 42
    )

    let decoded = try JSONDecoder().decode(
      StudioWorkspaceWindowRequest.self,
      from: JSONEncoder().encode(request)
    )

    XCTAssertEqual(decoded, request)
    XCTAssertEqual(decoded.id, id)
    XCTAssertEqual(decoded.workspaceRawValue, "animate")
    XCTAssertEqual(decoded.projectDisplayName, "Atlas")
    XCTAssertEqual(decoded.targetTabWindowNumber, 42)
  }

  @MainActor
  func testClosingProjectKeepsOutgoingBindingSafeWithoutResurrectingSession() {
    let session = StudioProjectSession(
      document: ProjectLifecycle.makeEmptyDocument(name: "Atlas"),
      projectURL: URL(fileURLWithPath: "/tmp/Atlas", isDirectory: true)
    )
    let applicationState = AnimaStudioApplicationState()
    applicationState.projectSession = session
    let outgoingBinding = applicationState.presentationBinding(fallback: session)

    applicationState.projectSession = nil

    XCTAssertEqual(outgoingBinding.wrappedValue, session)
    var staleUpdate = session
    staleUpdate.isDirty = true
    outgoingBinding.wrappedValue = staleUpdate
    XCTAssertNil(applicationState.projectSession)
  }

  @MainActor
  func testWorkspaceWindowCatalogUsesTheActiveCharacterAuthoringSurface() {
    let workspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)

    workspace.characterType = .threeD
    XCTAssertEqual(
      workspace.availableWindowWorkspaces,
      [.assets, .rig, .animate, .show, .hardware, .nodes, .design]
    )

    workspace.characterType = .twoD
    XCTAssertEqual(workspace.availableWindowWorkspaces[1], .canvas2d)
    XCTAssertFalse(workspace.availableWindowWorkspaces.contains(.rig))

    workspace.characterType = .vr
    XCTAssertEqual(workspace.availableWindowWorkspaces[1], .vr)
    XCTAssertEqual(
      Set(workspace.availableWindowWorkspaces).count,
      workspace.availableWindowWorkspaces.count
    )
  }

  @MainActor
  func testLayoutPresetsConfigurePanelsAndRibbonTogether() {
    let workspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)

    workspace.applyLayoutPreset(.docked)
    XCTAssertEqual(workspace.navigatorPlacement, .docked)
    XCTAssertEqual(workspace.inspectorPlacement, .docked)
    XCTAssertEqual(workspace.ribbonPlacement, .docked)

    workspace.applyLayoutPreset(.floating)
    XCTAssertEqual(workspace.navigatorPlacement, .floating)
    XCTAssertEqual(workspace.inspectorPlacement, .floating)
    XCTAssertEqual(workspace.ribbonPlacement, .floating)

    workspace.applyLayoutPreset(.canvas)
    XCTAssertEqual(workspace.navigatorPlacement, .hidden)
    XCTAssertEqual(workspace.inspectorPlacement, .hidden)
    XCTAssertEqual(workspace.ribbonPlacement, .floating)
  }
}
