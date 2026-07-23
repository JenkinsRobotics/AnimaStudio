import CodexUICore
import CoreGraphics
import Testing

@Test func catalogCoversTheCompleteAuthoringWalkthrough() {
  #expect(
    UIWorkspace.allCases.map(\.name) == [
      "Assets", "Rig", "Animate", "Show", "Hardware", "Nodes", "UI Kit",
    ])
  #expect(UIWorkspace.allCases.allSatisfy { !$0.ribbonGroups.isEmpty })
  #expect(
    UIWorkspace.allCases.allSatisfy { workspace in
      workspace.ribbonGroups.allSatisfy { !$0.tools.isEmpty }
    })
}

@Test func centeredWorkspaceTabsCoverStagesAndUtilities() {
  #expect(
    UIWorkspace.authoringPipeline == [.assets, .rig, .animate, .show, .hardware]
  )
  #expect(UIWorkspace.utilityWorkspaces == [.nodes, .uiKit])
  #expect(UIWorkspace.centeredNavigation == UIWorkspace.allCases)
  #expect(
    Set(UIWorkspace.authoringPipeline + UIWorkspace.utilityWorkspaces) == Set(UIWorkspace.allCases))
}

@Test func workspaceTabLabelsAdaptAndRemainUserConfigurable() {
  #expect(WorkspaceTabLabelMode.automatic.showsLabel(isSelected: false, compact: false))
  #expect(WorkspaceTabLabelMode.automatic.showsLabel(isSelected: true, compact: true))
  #expect(!WorkspaceTabLabelMode.automatic.showsLabel(isSelected: false, compact: true))
  #expect(WorkspaceTabLabelMode.all.showsLabel(isSelected: false, compact: true))
  #expect(WorkspaceTabLabelMode.selectedOnly.showsLabel(isSelected: true, compact: false))
  #expect(!WorkspaceTabLabelMode.selectedOnly.showsLabel(isSelected: false, compact: false))
  #expect(!WorkspaceTabLabelMode.iconsOnly.showsLabel(isSelected: true, compact: false))
}

@Test func headerDensityMatchesTheAnimaStudioDemoContract() {
  #expect(WorkspaceHeaderMetrics.height == 54)
  #expect(WorkspaceHeaderMetrics.controlWidth == 28)
  #expect(WorkspaceHeaderMetrics.controlHeight == 24)
  #expect(WorkspaceHeaderMetrics.stageChipHeight == 30)
  #expect(WorkspaceHeaderMetrics.compactStageChipHeight == 28)
  #expect(WorkspaceHeaderMetrics.capsuleInset == 4)
}

@Test func ribbonToolsHaveStableUniqueNamesWithinAWorkspace() {
  for workspace in UIWorkspace.allCases {
    let ids = workspace.ribbonGroups.flatMap(\.tools).map(\.id)
    #expect(ids.count == Set(ids).count)
  }
}

@Test func tourWrapsInBothDirectionsAndCanJump() {
  var tour = WorkspaceTour()
  tour.retreat()
  #expect(tour.workspace == .uiKit)
  tour.advance()
  #expect(tour.workspace == .assets)
  tour.select(.hardware)
  #expect(tour.workspace == .hardware)
  #expect(tour.progressLabel == "5 of 7")
}

@Test func layoutPresetsDescribeTheSharedDockingContract() {
  #expect(WorkspaceLayoutPreset.studio.label == "Floating")
  #expect(WorkspaceLayoutPreset.classic.label == "Docked")
  #expect(WorkspaceLayoutPreset.canvas.label == "Canvas")
  #expect(WorkspaceLayoutPreset.studio.leftPanel == .floating)
  #expect(WorkspaceLayoutPreset.studio.rightPanel == .floating)
  #expect(WorkspaceLayoutPreset.studio.ribbon == .floating)

  #expect(WorkspaceLayoutPreset.classic.leftPanel == .docked)
  #expect(WorkspaceLayoutPreset.classic.rightPanel == .docked)
  #expect(WorkspaceLayoutPreset.classic.ribbon == .docked)

  #expect(WorkspaceLayoutPreset.canvas.leftPanel == .hidden)
  #expect(WorkspaceLayoutPreset.canvas.rightPanel == .hidden)
  #expect(WorkspaceLayoutPreset.canvas.ribbon == .floating)
  #expect(WorkspaceLayoutPreset.studio.next == .classic)
  #expect(WorkspaceLayoutPreset.classic.next == .canvas)
  #expect(WorkspaceLayoutPreset.canvas.next == .studio)
}

@Test func structuredContentCanResolveFloatingPanelObstructions() {
  let floating = PanelObstructionInsets(
    leftPlacement: .floating,
    rightPlacement: .floating,
    ribbonPlacement: .floating,
    leftPanelWidth: 250,
    rightPanelWidth: 300
  )
  #expect(floating.leading == 268)
  #expect(floating.trailing == 318)
  #expect(floating.top == 74)
  #expect(floating.bottom == 0)

  let bottomRibbon = PanelObstructionInsets(
    leftPlacement: .hidden,
    rightPlacement: .hidden,
    ribbonPlacement: .floating,
    floatingRibbonEdge: .bottom,
    leftPanelWidth: 250,
    rightPanelWidth: 300
  )
  #expect(bottomRibbon.top == 0)
  #expect(bottomRibbon.bottom == 74)

  let dockedOrHidden = PanelObstructionInsets(
    leftPlacement: .docked,
    rightPlacement: .hidden,
    ribbonPlacement: .docked,
    leftPanelWidth: 250,
    rightPanelWidth: 300
  )
  #expect(dockedOrHidden.leading == 0)
  #expect(dockedOrHidden.trailing == 0)
  #expect(dockedOrHidden.top == 0)
  #expect(dockedOrHidden.bottom == 0)
}

@Test func floatingPanelSizingLeavesCanvasVisibleButUsesSmallWindows() {
  #expect(FloatingPanelSizing.spatialPreviewMinimumContentHeight == 220)
  #expect(FloatingPanelSizing.height(availableHeight: 1_000) == 720)
  #expect(FloatingPanelSizing.height(availableHeight: 500) == 380)
  #expect(FloatingPanelSizing.height(availableHeight: 300) == 276)
}

@Test func floatingWidgetTranslationStaysInsideTheWorkspace() {
  let frame = CGRect(x: 700, y: 100, width: 280, height: 300)
  let workspace = CGSize(width: 1_000, height: 700)

  let lowerRight = FloatingWidgetPlacement.constrainedTranslation(
    startingFrame: frame,
    translation: CGSize(width: 200, height: 500),
    workspaceSize: workspace
  )
  #expect(lowerRight == CGSize(width: 12, height: 292))

  let upperLeft = FloatingWidgetPlacement.constrainedTranslation(
    startingFrame: frame,
    translation: CGSize(width: -1_000, height: -1_000),
    workspaceSize: workspace
  )
  #expect(upperLeft == CGSize(width: -692, height: -92))
}

@Test func uiKitCatalogTracksEveryReusableAssetWithoutDuplicates() {
  let ids = UIKitAssetCatalog.all.map(\.id)
  #expect(ids.count == Set(ids).count)
  #expect(ids.count == 21)
  #expect(UIKitAssetCatalog.all.allSatisfy { !$0.section.isEmpty && !$0.specimen.isEmpty })
  #expect(ids.contains("WorkspaceStageTabs"))
  #expect(ids.contains("AdaptiveRibbon"))
  #expect(ids.contains("DockingWorkspace"))
  #expect(ids.contains("TimelinePrototype"))
  #expect(ids.contains("ViewportPerformanceHUD"))
  #expect(ids.contains("PrototypeNodeCard"))
  #expect(ids.contains("PrototypeNodeLibrary"))
  #expect(ids.contains("PrototypeNodeInspector"))
  #expect(ids.contains("PrototypeNodePortRow"))
  #expect(ids.contains("PrototypeNodeCanvas"))
}

@Test func canvasHoverRevealOnlyAppliesToHiddenCanvasPanels() {
  #expect(CanvasPanelRevealPolicy.isEnabled(layoutPreset: .canvas, panelPlacement: .hidden))
  #expect(!CanvasPanelRevealPolicy.isEnabled(layoutPreset: .studio, panelPlacement: .hidden))
  #expect(!CanvasPanelRevealPolicy.isEnabled(layoutPreset: .canvas, panelPlacement: .floating))
}
