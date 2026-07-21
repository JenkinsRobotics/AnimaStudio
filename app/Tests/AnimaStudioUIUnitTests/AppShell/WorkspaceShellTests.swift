import XCTest

@testable import AnimaStudioUI

@MainActor
final class WorkspaceShellTests: XCTestCase {
  func testStructuredCentersCanConsumeTemporaryOverlayInsets() {
    let hidden = StudioWorkspaceOverlayInsets()
    let revealed = StudioWorkspaceOverlayInsets(top: 92, leading: 320, trailing: 350)

    XCTAssertEqual(hidden, StudioWorkspaceOverlayInsets())
    XCTAssertGreaterThan(revealed.top, hidden.top)
    XCTAssertGreaterThan(revealed.leading, hidden.leading)
    XCTAssertGreaterThan(revealed.trailing, hidden.trailing)
  }

  private func resetShellState() {
    StudioLayoutState.shared.apply(.studio)
    StudioToolState.shared.disarm()
    StudioToolState.shared.staysArmed = false
    StudioToolSettings.shared.density = .standard
    StudioToolSettings.shared.activeCategoryByWorkspace.removeAll()
    StudioViewSidebarState.shared.selectedTab = .view
    StudioViewSidebarState.shared.isOpen = false
    StudioViewSidebarState.shared.navigationMode = .select
    StudioLayoutState.shared.panelsOnOuterEdge = false
  }

  func testLayoutModeIsGlobalAndCyclesAcrossAllThreePresets() {
    defer { resetShellState() }
    let firstWorkspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)
    let secondWorkspace = StudioWorkspaceModel(
      startupWorkspace: .rig,
      resolvesDefaultAnimaCoreClient: false
    )

    firstWorkspace.applyLayoutPreset(.docked)
    XCTAssertEqual(secondWorkspace.detectedLayoutPreset, .docked)

    secondWorkspace.cycleLayoutPreset()
    XCTAssertEqual(firstWorkspace.detectedLayoutPreset, .canvas)
    firstWorkspace.cycleLayoutPreset()
    XCTAssertEqual(secondWorkspace.detectedLayoutPreset, .studio)
  }

  func testBothRailsUseSwitchOpenAndActiveCollapseRule() {
    defer { resetShellState() }
    let switched = StudioSidebarInteraction.select("Mates", current: "Components", isOpen: false)
    XCTAssertEqual(switched.selection, "Mates")
    XCTAssertTrue(switched.isOpen)

    let collapsed = StudioSidebarInteraction.select("Mates", current: "Mates", isOpen: true)
    XCTAssertEqual(collapsed.selection, "Mates")
    XCTAssertFalse(collapsed.isOpen)

    let reopened = StudioSidebarInteraction.select("Mates", current: "Mates", isOpen: false)
    XCTAssertTrue(reopened.isOpen)
  }

  func testWorkspaceSidebarStateSurvivesWorkspaceAndLayoutChanges() {
    defer { resetShellState() }
    let workspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)
    workspace.activeWorkspaceSidebarSelection = "Collections"
    workspace.isActiveWorkspaceSidebarOpen = false
    workspace.applyLayoutPreset(.canvas)
    workspace.switchWorkspace(to: .rig)
    workspace.activeWorkspaceSidebarSelection = "Mates"
    workspace.switchWorkspace(to: .assets)

    XCTAssertEqual(workspace.activeWorkspaceSidebarSelection, "Collections")
    XCTAssertFalse(workspace.isActiveWorkspaceSidebarOpen)
  }

  func testPanelStacksStartUnselectedAndAllowMultipleOpenPanels() {
    let panels = StudioPanelStackState(
      order: ["A", "B", "C"],
      defaults: [],
      side: .leading
    )

    XCTAssertFalse(panels.isOpen)
    XCTAssertNil(panels.focusedID)

    panels.toggle("A")
    panels.toggle("C")
    XCTAssertEqual(panels.stacked, ["A", "C"])
    XCTAssertEqual(panels.focusedID, "C")

    panels.toggle("A")
    XCTAssertEqual(panels.stacked, ["C"])
  }

  func testProductionSidebarsDefaultToNoSelectedPanel() {
    StudioViewSidebarState.shared.panels.closeAll()
    defer { resetShellState() }
    let workspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)

    XCTAssertFalse(workspace.activeWorkspaceSidebarPanels.isOpen)
    XCTAssertFalse(StudioViewSidebarState.shared.panels.isOpen)
  }

  func testPanelReorderIndexAndOrderAreDeterministic() {
    let panels = StudioPanelStackState(
      order: ["A", "B", "C"],
      defaults: ["A", "B", "C"],
      side: .leading
    )
    let index = StudioPanelStackState.reorderIndex(
      locationY: 250,
      excluding: "A",
      stacked: panels.stacked,
      cardMidpoints: ["B": 100, "C": 200]
    )

    XCTAssertEqual(index, 2)
    panels.reorderStacked("A", to: index)
    XCTAssertEqual(panels.stacked, ["B", "C", "A"])
  }

  func testPanelTearOffClampAndReturnToEdge() {
    let panels = StudioPanelStackState(
      order: ["View", "Inspector"],
      defaults: ["View", "Inspector"],
      side: .trailing
    )
    panels.detach("View", offset: CGSize(width: -240, height: 60))
    XCTAssertEqual(panels.stacked, ["Inspector"])
    XCTAssertEqual(panels.floating, ["View"])

    let clamped = StudioFloatingPanelGeometry.clamp(
      CGSize(width: -10_000, height: 10_000),
      side: .trailing,
      canvasSize: CGSize(width: 1_200, height: 800),
      panelWidth: 280
    )
    XCTAssertGreaterThanOrEqual(clamped.width, -784)
    XCTAssertLessThanOrEqual(clamped.height, 580)
    XCTAssertTrue(panels.nearHomeEdge(CGSize(width: -40, height: 0)))

    panels.restack("View")
    XCTAssertEqual(panels.stacked, ["View", "Inspector"])
    XCTAssertTrue(panels.floating.isEmpty)
  }

  func testOuterEdgeSettingFlipsRailWithoutRemovingPanelMargin() {
    XCTAssertTrue(
      StudioSidebarArrangement.railPrecedesStack(
        side: .leading,
        panelsOnOuterEdge: false
      )
    )
    XCTAssertFalse(
      StudioSidebarArrangement.railPrecedesStack(
        side: .leading,
        panelsOnOuterEdge: true
      )
    )
    XCTAssertFalse(
      StudioSidebarArrangement.railPrecedesStack(
        side: .trailing,
        panelsOnOuterEdge: false
      )
    )
    XCTAssertTrue(
      StudioSidebarArrangement.railPrecedesStack(
        side: .trailing,
        panelsOnOuterEdge: true
      )
    )

    let suiteName = "WorkspaceShellTests.outerEdge"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let first = StudioLayoutState(defaults: defaults)
    first.panelsOnOuterEdge = true
    XCTAssertTrue(StudioLayoutState(defaults: defaults).panelsOnOuterEdge)
  }

  func testDockedForcesExpandedToolsWithoutLosingFloatingPreference() {
    defer { resetShellState() }
    StudioToolSettings.shared.density = .compact

    XCTAssertEqual(
      StudioToolDensity.resolved(preference: StudioToolSettings.shared.density, docked: true),
      .expanded
    )
    XCTAssertEqual(
      StudioToolDensity.resolved(preference: StudioToolSettings.shared.density, docked: false),
      .compact
    )
  }

  func testDockedSidebarsUseFixedPanelWidthsAroundTheCenterColumn() {
    XCTAssertEqual(
      StudioSidebarSizing.dockedWidth(side: .leading, panelsAreOpen: true),
      StudioSidebarSizing.railWidth + StudioSidebarSizing.workspacePanelWidth + 1
    )
    XCTAssertEqual(
      StudioSidebarSizing.dockedWidth(side: .trailing, panelsAreOpen: true),
      StudioSidebarSizing.railWidth + StudioSidebarSizing.viewPanelWidth + 1
    )
    XCTAssertEqual(
      StudioSidebarSizing.dockedWidth(side: .leading, panelsAreOpen: false),
      StudioSidebarSizing.railWidth
    )
  }

  func testToolAndCameraModesAreMutuallyExclusive() {
    defer { resetShellState() }
    let tool = StudioToolDescriptor(
      id: "test.tool",
      title: "Place Part",
      systemImage: "cube",
      help: "Test tool",
      behavior: .arm(command: "test")
    )
    StudioViewSidebarState.shared.navigationMode = .orbit

    StudioToolState.shared.arm(tool)
    XCTAssertEqual(StudioViewSidebarState.shared.navigationMode, .select)
    XCTAssertTrue(StudioToolState.shared.isArmed)

    StudioViewSidebarState.shared.selectNavigation(.pan)
    XCTAssertEqual(StudioViewSidebarState.shared.navigationMode, .pan)
    XCTAssertFalse(StudioToolState.shared.isArmed)
  }

  func testToolCommitHonorsRepeatMode() {
    defer { resetShellState() }
    let tool = StudioToolDescriptor(
      id: "test.tool",
      title: "Place Part",
      systemImage: "cube",
      help: "Test tool",
      behavior: .arm(command: "test")
    )
    StudioToolState.shared.arm(tool)
    StudioToolState.shared.staysArmed = true
    StudioToolState.shared.committed()
    XCTAssertTrue(StudioToolState.shared.isArmed)

    StudioToolState.shared.staysArmed = false
    StudioToolState.shared.committed()
    XCTAssertFalse(StudioToolState.shared.isArmed)
  }
}
