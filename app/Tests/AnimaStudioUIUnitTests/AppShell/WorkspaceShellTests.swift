import XCTest

@testable import AnimaStudioUI

@MainActor
final class WorkspaceShellTests: XCTestCase {
  func testToolPresentationPreferencesPersist() {
    let suiteName = "WorkspaceShellTests.ToolSettings.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = StudioToolSettings(defaults: defaults)
    settings.density = .expanded
    settings.chromeShape = .square

    let restored = StudioToolSettings(defaults: defaults)
    XCTAssertEqual(restored.density, .expanded)
    XCTAssertEqual(restored.chromeShape, .square)
  }

  func testViewOriginPreferenceDefaultsVisibleAndPersists() {
    let suiteName = "WorkspaceShellTests.ViewSidebar.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let state = StudioViewSidebarState(defaults: defaults)
    XCTAssertTrue(state.showsOrigin)
    state.showsOrigin = false
    XCTAssertFalse(StudioViewSidebarState(defaults: defaults).showsOrigin)
  }

  func testStructuredCentersCanConsumeTemporaryOverlayInsets() {
    let hidden = StudioWorkspaceOverlayInsets()
    let revealed = StudioWorkspaceOverlayInsets(
      top: 92,
      leading: 320,
      bottom: 76,
      trailing: 350
    )

    XCTAssertEqual(hidden, StudioWorkspaceOverlayInsets())
    XCTAssertGreaterThan(revealed.top, hidden.top)
    XCTAssertGreaterThan(revealed.leading, hidden.leading)
    XCTAssertGreaterThan(revealed.bottom, hidden.bottom)
    XCTAssertGreaterThan(revealed.trailing, hidden.trailing)
  }

  func testCenterViewCatalogMatchesTheFiveProductionWorkspaces() {
    XCTAssertEqual(StudioCenterViewCatalog.modes(for: .assets), [.threeD, .gallery, .table])
    XCTAssertEqual(StudioCenterViewCatalog.modes(for: .rig), [.threeD, .table, .exploded])
    XCTAssertEqual(
      StudioCenterViewCatalog.modes(for: .animate),
      [.threeD, .dopeSheet, .curves]
    )
    XCTAssertEqual(StudioCenterViewCatalog.modes(for: .show), [.nodeGraph, .table, .threeD])
    XCTAssertEqual(
      StudioCenterViewCatalog.modes(for: .hardware),
      [.servoTimeline, .table, .threeD]
    )
    XCTAssertTrue(StudioCenterViewCatalog.modes(for: .nodes).isEmpty)
    XCTAssertTrue(StudioCenterViewCatalog.modes(for: .design).isEmpty)
  }

  func testVisibleZoneTracksAllFourChromeEdges() {
    let floating = StudioVisibleZoneLayout.insets(
      preset: .floating,
      toolInset: 98,
      hasCenterSwitcher: true,
      leftStackOpen: true,
      rightStackOpen: false
    )

    XCTAssertEqual(floating.top, 98)
    XCTAssertEqual(
      floating.leading,
      StudioSidebarSizing.workspacePanelWidth + StudioVisibleZoneLayout.openStackInset
    )
    XCTAssertEqual(floating.trailing, StudioVisibleZoneLayout.sideRailInset)
    XCTAssertEqual(floating.bottom, StudioVisibleZoneLayout.bottomSwitcherInset)

    let docked = StudioVisibleZoneLayout.insets(
      preset: .docked,
      toolInset: 98,
      hasCenterSwitcher: true,
      leftStackOpen: true,
      rightStackOpen: true
    )
    XCTAssertEqual(docked.leading, StudioVisibleZoneLayout.dockedInset)
    XCTAssertEqual(docked.trailing, StudioVisibleZoneLayout.dockedInset)
  }

  func testCanvasZoneOnlyReservesRevealedEdges() {
    let hidden = StudioVisibleZoneLayout.insets(
      preset: .canvas,
      toolInset: 88,
      hasCenterSwitcher: true,
      leftStackOpen: true,
      rightStackOpen: true,
      revealedTop: false,
      revealedLeading: false,
      revealedTrailing: false
    )
    XCTAssertEqual(hidden.top, 0)
    XCTAssertEqual(hidden.leading, 0)
    XCTAssertEqual(hidden.trailing, 0)
    XCTAssertEqual(hidden.bottom, StudioVisibleZoneLayout.bottomSwitcherInset)
  }

  func testTornOffPanelFootprintPushesTheSafeContentBoundary() {
    let insets = StudioVisibleZoneLayout.insets(
      preset: .floating,
      toolInset: 88,
      hasCenterSwitcher: true,
      leftStackOpen: false,
      rightStackOpen: false,
      canvasWidth: 1_200,
      floatingPanels: [
        StudioFloatingPanelFootprint(side: .leading, minimumX: 220, maximumX: 452),
        StudioFloatingPanelFootprint(side: .trailing, minimumX: 870, maximumX: 1_070),
      ]
    )
    XCTAssertEqual(insets.leading, 452 + StudioVisibleZoneLayout.floatingPanelGap)
    XCTAssertEqual(insets.trailing, 1_200 - 870 + StudioVisibleZoneLayout.floatingPanelGap)
  }

  private func resetShellState() {
    StudioLayoutState.shared.apply(.floating)
    StudioToolState.shared.disarm()
    StudioToolState.shared.staysArmed = false
    StudioToolState.shared.actionHandler = nil
    StudioToolSettings.shared.density = StudioToolSettings.defaultDensity
    StudioToolSettings.shared.activeCategoryByWorkspace.removeAll()
    StudioToolSettings.shared.openCompactGroupByWorkspace.removeAll()
    StudioViewSidebarState.shared.selectedTab = .view
    StudioViewSidebarState.shared.isOpen = false
    StudioViewSidebarState.shared.navigationMode = .select
    StudioLayoutState.shared.panelsOnOuterEdge = false
    StudioLayoutState.shared.showsLayoutZones = false
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
    XCTAssertEqual(secondWorkspace.detectedLayoutPreset, .floating)
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

  func testAssetsSidebarExposesProjectCharacterAssetWorkflows() {
    XCTAssertEqual(
      StudioWorkspaceSidebarCatalog.tabs(for: .assets).map(\.title),
      [
        "Characters", "Parts", "Source Assets", "Renders", "Assemblies",
        "Scripts", "Animations",
      ]
    )
    XCTAssertFalse(
      StudioWorkspaceSidebarCatalog.tabs(for: .assets).contains { $0.title == "Library" }
    )
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

  func testRigToolsCarryTypedPayloadsInsteadOfParsingCommandStrings() {
    let workspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)
    let categories = StudioWorkspaceToolCatalog.rigCategories(workspace: workspace)
    let box = categories.flatMap(\.groups).flatMap(\.tools).first { $0.title == "Box" }

    guard case .arm(.addPart(.box)) = box?.behavior else {
      return XCTFail("Expected Box to carry a typed add-part payload")
    }
  }

  func testExpandedRibbonUsesOneRowUntilTheCatalogIsActuallyLarge() {
    XCTAssertFalse(
      StudioToolCategoryPresentation.usesTabs(
        groups: StudioWorkspaceToolCatalog.groups(for: .assets),
        categories: StudioWorkspaceToolCatalog.categories(for: .assets)
      )
    )
    XCTAssertTrue(
      StudioToolCategoryPresentation.usesTabs(
        groups: StudioWorkspaceToolCatalog.groups(for: .show),
        categories: StudioWorkspaceToolCatalog.categories(for: .show)
      )
    )
    XCTAssertTrue(
      StudioToolCategoryPresentation.usesTabs(
        groups: StudioWorkspaceToolCatalog.groups(for: .animate),
        categories: StudioWorkspaceToolCatalog.categories(for: .animate)
      )
    )
    XCTAssertTrue(
      StudioToolCategoryPresentation.usesTabs(
        groups: StudioWorkspaceToolCatalog.groups(for: .nodes),
        categories: StudioWorkspaceToolCatalog.categories(for: .nodes)
      )
    )
  }

  func testStandardIsTheDefaultFloatingToolDensity() {
    XCTAssertEqual(StudioToolSettings.defaultDensity, .standard)
    XCTAssertFalse(StudioToolDensity.expanded.usesVisualCategoryPalette)
    XCTAssertFalse(StudioToolDensity.standard.usesVisualCategoryPalette)
    XCTAssertTrue(StudioToolDensity.compact.usesVisualCategoryPalette)
    XCTAssertFalse(StudioToolBarSizing.fillsAvailableWidth(.expanded))
    XCTAssertFalse(StudioToolBarSizing.fillsAvailableWidth(.standard))
    XCTAssertFalse(StudioToolBarSizing.fillsAvailableWidth(.compact))
    XCTAssertGreaterThan(
      StudioToolBarSizing.height(for: .expanded),
      StudioToolBarSizing.height(for: .standard)
    )
    XCTAssertGreaterThan(
      StudioToolBarSizing.height(for: .standard),
      StudioToolBarSizing.height(for: .compact)
    )
  }

  func testCharacterStandardToolbarShowsPrimaryToolsAndMovesTheRestToOverflow() {
    let groups = StudioWorkspaceToolCatalog.groups(for: .assets)
    let primaryByGroup = Dictionary(
      uniqueKeysWithValues: groups.map { group in
        (group.title, StudioStandardToolPresentation.primaryTools(in: group).map(\.title))
      }
    )

    XCTAssertEqual(primaryByGroup["Import"], ["Character", "3D Model"])
    XCTAssertEqual(primaryByGroup["Manage"], ["Replace", "Reveal"])
    XCTAssertEqual(primaryByGroup["Prepare"], ["Units", "Validate"])
    XCTAssertEqual(groups.first { $0.title == "Import" }?.categoryIcon, "square.and.arrow.down")
    XCTAssertEqual(
      groups.first { $0.title == "Import" }?.overflowTools.first?.title,
      "Audio"
    )
  }

  func testCompactCategoryPaletteKeepsOneOpenGroupPerWorkspace() {
    defer { resetShellState() }
    let settings = StudioToolSettings.shared

    settings.toggleCompactGroup("Import", for: .assets)
    XCTAssertTrue(settings.isCompactGroupOpen("Import", for: .assets))
    XCTAssertFalse(settings.isCompactGroupOpen("Manage", for: .assets))

    settings.toggleCompactGroup("Manage", for: .assets)
    XCTAssertFalse(settings.isCompactGroupOpen("Import", for: .assets))
    XCTAssertTrue(settings.isCompactGroupOpen("Manage", for: .assets))

    settings.closeCompactGroup(for: .assets)
    XCTAssertFalse(settings.isCompactGroupOpen("Manage", for: .assets))
  }

  func testViewportDisplayProjectionUsesThePersistedRenderStyleAsTruth() {
    XCTAssertEqual(StudioViewportDisplayMode.resolve(renderStyle: .wireframe), .wireframe)
    XCTAssertEqual(StudioViewportDisplayMode.resolve(renderStyle: .shadedWithEdges), .hiddenLine)
    XCTAssertEqual(StudioViewportDisplayMode.shaded.renderStyle, .shaded)
  }

  func testRibbonActionsShareOneDispatcher() {
    let workspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)
    let initial = workspace.showsPreviewGrid
    WorkspaceRibbonActionDispatcher.perform(
      .toggleGrid,
      workspace: workspace,
      importModel: {},
      importAnimaCharacter: {}
    )
    XCTAssertEqual(workspace.showsPreviewGrid, !initial)
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

  func testFloatingPanelMotionMirrorsSidesAndKeepsRailAboveStack() {
    XCTAssertEqual(StudioSidebarMotion.revealEdge(for: .leading), .leading)
    XCTAssertEqual(StudioSidebarMotion.revealEdge(for: .trailing), .trailing)
    XCTAssertGreaterThan(StudioSidebarMotion.railLayer, StudioSidebarMotion.stackLayer)
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
    XCTAssertEqual(StudioSidebarSizing.workspacePanelWidth, 232)
    XCTAssertEqual(StudioSidebarSizing.viewPanelWidth, 200)
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
      behavior: .arm(.addPart(.box))
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
      behavior: .arm(.addPart(.box))
    )
    StudioToolState.shared.arm(tool)
    StudioToolState.shared.staysArmed = true
    StudioToolState.shared.committed()
    XCTAssertTrue(StudioToolState.shared.isArmed)

    StudioToolState.shared.staysArmed = false
    StudioToolState.shared.committed()
    XCTAssertFalse(StudioToolState.shared.isArmed)
  }

  func testImmediateToolUsesTheOnAppearHandlerAndNeverArms() {
    defer {
      StudioToolState.shared.actionHandler = nil
      resetShellState()
    }
    var performed: WorkspaceRibbonAction?
    StudioToolState.shared.actionHandler = { tool in
      guard case .command(let action) = tool.behavior else { return false }
      performed = action
      return true
    }
    let tool = StudioToolDescriptor(
      id: "test.import",
      title: "Import",
      systemImage: "square.and.arrow.down",
      help: "Import immediately",
      behavior: .command(.importModel)
    )

    StudioToolState.shared.activate(tool)

    XCTAssertEqual(performed?.rawValue, WorkspaceRibbonAction.importModel.rawValue)
    XCTAssertFalse(StudioToolState.shared.isArmed)
  }
}
