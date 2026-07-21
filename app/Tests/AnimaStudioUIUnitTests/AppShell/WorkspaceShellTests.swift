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
    StudioViewSidebarState.shared.isOpen = true
    StudioViewSidebarState.shared.navigationMode = .select
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
