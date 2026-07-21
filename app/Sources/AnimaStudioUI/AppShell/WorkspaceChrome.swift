import AppKit
import RealityKitViewport
import SwiftUI

enum StudioDocumentBarDensity: Equatable, Sendable {
  case expanded
  case compact
  case minimal

  static func resolve(width: CGFloat) -> Self {
    if width >= WorkspaceSelectorMetrics.compactWidth { return .expanded }
    if width >= 1_180 { return .compact }
    return .minimal
  }

  var selectorWidth: CGFloat {
    switch self {
    case .expanded: WorkspaceSelectorMetrics.maximumWidth
    case .compact: WorkspaceSelectorMetrics.idealWidth
    case .minimal: WorkspaceSelectorMetrics.minimumWidth
    }
  }
}

enum StudioProjectIdentityMetrics {
  static func projectNameWidth(
    for projectName: String,
    density: StudioDocumentBarDensity
  ) -> CGFloat {
    let displayName = projectName.isEmpty ? "Project name" : projectName
    let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
    let measuredWidth = (displayName as NSString).size(withAttributes: [.font: font]).width
    let maximumWidth: CGFloat =
      switch density {
      case .expanded: 170
      case .compact: 118
      case .minimal: 90
      }
    return min(max(ceil(measuredWidth) + 8, 30), maximumWidth)
  }
}

struct StudioDocumentBar: View {
  @Environment(\.openSettings) private var openSettings
  @Bindable var workspace: StudioWorkspaceModel
  @Binding var isUIDevWorkspace: Bool
  @Binding var showsWorkspaceGuide: Bool
  let isSaving: Bool
  let isDirty: Bool
  let newProject: () -> Void
  let openProject: () -> Void
  let saveProject: () -> Void
  let saveProjectAs: () -> Void
  let closeProject: () -> Void

  var body: some View {
    GeometryReader { proxy in
      let density = StudioDocumentBarDensity.resolve(width: proxy.size.width)
      let contentWidth = max(0, proxy.size.width - 28)
      let sideWidth = max(0, (contentWidth - density.selectorWidth - 24) / 2)
      ZStack {
        WorkspaceStageTabs(
          workspace: workspace,
          isUIDevWorkspace: $isUIDevWorkspace,
          compact: density != .expanded
        )
        .frame(width: density.selectorWidth)

        HStack(spacing: 0) {
          leadingControls(density: density)
            .frame(width: sideWidth, alignment: .leading)

          Spacer(minLength: 0)

          trailingControls(density: density)
            .frame(width: sideWidth, alignment: .trailing)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(StudioChromeIconButtonStyle())
      }
      .padding(.horizontal, 14)
    }
    .frame(height: StudioMetrics.documentBarHeight)
    .background(StudioPalette.documentChrome)
    .overlay(alignment: .bottom) {
      Rectangle().fill(StudioPalette.border).frame(height: 1)
    }
  }

  private func leadingControls(density: StudioDocumentBarDensity) -> some View {
    HStack(spacing: 7) {
      projectIdentity(density: density)

      Divider().frame(height: 18)

      switch density {
      case .expanded:
        settingsButton
        projectCommandMenu
        saveButton
        historyButtons
      case .compact:
        settingsButton
        projectCommandMenu
      case .minimal:
        compactApplicationMenu
      }
    }
  }

  private func trailingControls(density: StudioDocumentBarDensity) -> some View {
    HStack(spacing: 7) {
      engineStatus(compact: density == .minimal)
      playbackButton(showsLabel: density == .expanded)

      Divider().frame(height: 18)

      WorkspaceLayoutMenu(workspace: workspace)

      Button {
        showsWorkspaceGuide.toggle()
      } label: {
        Image(systemName: "questionmark.circle")
      }
      .foregroundStyle(showsWorkspaceGuide ? StudioPalette.accent : StudioPalette.muted)
      .help("Workspace walkthrough")
    }
    .fixedSize(horizontal: true, vertical: false)
  }

  private func projectIdentity(density: StudioDocumentBarDensity) -> some View {
    HStack(spacing: 8) {
      Button(action: closeProject) {
        Image(systemName: "house.fill")
      }
      .foregroundStyle(StudioPalette.hardware)
      .help("Return to Anima Studio home")
      .accessibilityLabel("Project Home")

      TextField("Project name", text: $workspace.project.name)
        .textFieldStyle(.plain)
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1)
        .frame(
          width: StudioProjectIdentityMetrics.projectNameWidth(
            for: workspace.project.name,
            density: density
          )
        )
        .layoutPriority(1)
        .accessibilityLabel("Project name")
      Text(isSaving ? "SAVING" : (isDirty ? "UNSAVED" : "SAVED"))
        .font(.system(size: 8.5, weight: .bold))
        .tracking(0.7)
        .foregroundStyle(isDirty ? StudioPalette.hardware : StudioPalette.semanticPart)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
          (isDirty ? StudioPalette.hardware : StudioPalette.semanticPart).opacity(0.12),
          in: Capsule()
        )
        .fixedSize(horizontal: true, vertical: false)
    }
    .fixedSize(horizontal: true, vertical: false)
  }

  private var settingsButton: some View {
    Button {
      openSettings()
    } label: {
      Image(systemName: "gearshape")
    }
    .help("Anima Studio Settings")
  }

  private var projectCommandMenu: some View {
    Menu {
      projectCommands
    } label: {
      Image(systemName: "doc")
    }
    .menuIndicator(.hidden)
    .help("Project file commands")
  }

  private var compactApplicationMenu: some View {
    Menu {
      Button("Settings…", systemImage: "gearshape") { openSettings() }
      Divider()
      projectCommands
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .menuIndicator(.hidden)
    .help("App and project commands")
  }

  @ViewBuilder private var projectCommands: some View {
    Button("New Project", systemImage: "doc.badge.plus", action: newProject)
    Button("Open Project…", systemImage: "folder", action: openProject)
    Divider()
    Button("Save", systemImage: "square.and.arrow.down", action: saveProject)
      .disabled(isSaving)
    Button("Save As…", systemImage: "doc.on.doc", action: saveProjectAs)
  }

  private var saveButton: some View {
    Button("Save", systemImage: "square.and.arrow.down", action: saveProject)
      .disabled(isSaving)
      .help("Save project through AnimaCore")
  }

  private var historyButtons: some View {
    Group {
      Button("Undo", systemImage: "arrow.uturn.backward") {}
        .disabled(true)
        .help("Undo history arrives with durable projects")
      Button("Redo", systemImage: "arrow.uturn.forward") {}
        .disabled(true)
        .help("Redo history arrives with durable projects")
    }
  }

  private func playbackButton(showsLabel: Bool) -> some View {
    Button {
      workspace.togglePlayback()
    } label: {
      HStack(spacing: 5) {
        Image(systemName: workspace.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 8, weight: .bold))
        if showsLabel {
          Text(workspace.isPlaying ? "Pause" : "Preview")
            .font(.system(size: 10.5, weight: .semibold))
        }
      }
      .foregroundStyle(workspace.isPlaying ? Color.white : StudioPalette.muted)
      .padding(.horizontal, showsLabel ? 10 : 8)
      .frame(height: 24)
      .background(
        workspace.isPlaying ? StudioPalette.accent : StudioPalette.panelInset,
        in: Capsule()
      )
      .overlay(
        Capsule().stroke(workspace.isPlaying ? StudioPalette.accent : StudioPalette.border))
    }
    .buttonStyle(.plain)
    .fixedSize()
    .help(workspace.isPlaying ? "Pause preview" : "Start preview")
  }

  private func engineStatus(compact: Bool) -> some View {
    HStack(spacing: 5) {
      Circle().fill(animaCoreStatusColor).frame(width: 7, height: 7)
      if compact {
        Image(systemName: "bolt.horizontal.fill")
          .font(.system(size: 9, weight: .semibold))
      } else {
        Text(workspace.animaCoreStatusLabel)
          .font(.system(size: 10.5, weight: .semibold))
          .lineLimit(1)
        Image(systemName: "chevron.down")
          .font(.system(size: 7, weight: .bold))
      }
    }
    .foregroundStyle(StudioPalette.muted)
    .padding(.horizontal, 9)
    .frame(height: 24)
    .background(StudioPalette.panelInset, in: Capsule())
    .overlay(Capsule().stroke(animaCoreStatusColor.opacity(0.38)))
    .fixedSize()
    .accessibilityLabel("AnimaCore status")
    .accessibilityValue(workspace.animaCoreStatusLabel)
    .help("AnimaCore status")
  }

  private var animaCoreStatusColor: Color {
    switch workspace.animaCoreState {
    case .ready, .loaded: StudioPalette.hardware
    case .connecting: StudioPalette.accent
    case .failed: Color.red
    case .unavailable: Color.secondary
    }
  }
}

struct WorkspaceLayoutMenu: View {
  @Bindable var workspace: StudioWorkspaceModel

  var body: some View {
    Menu {
      Section("Studio modes") {
        ForEach(StudioLayoutPreset.allCases) { preset in
          Button {
            workspace.applyLayoutPreset(preset)
          } label: {
            Label(
              preset.title,
              systemImage: workspace.detectedLayoutPreset == preset
                ? "checkmark" : preset.systemImage
            )
          }
        }
      }

      Divider()
      Button("Reset Studio Layout") {
        workspace.applyLayoutPreset(.studio)
      }
    } label: {
      Image(systemName: currentIcon)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Color.white)
        .frame(width: 28, height: 24)
        .background(currentColor, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
          RoundedRectangle(cornerRadius: 6)
            .stroke(currentColor.opacity(0.85), lineWidth: 1)
        }
    } primaryAction: {
      workspace.cycleLayoutPreset()
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .accessibilityLabel("Studio mode: \(currentTitle)")
    .help("Studio mode: \(currentTitle) · click to cycle")
  }

  private var currentIcon: String {
    workspace.detectedLayoutPreset?.systemImage ?? "square.grid.2x2"
  }

  private var currentTitle: String {
    workspace.detectedLayoutPreset?.title ?? "Custom"
  }

  private var currentColor: Color {
    switch workspace.detectedLayoutPreset {
    case .studio: StudioPalette.semanticPart
    case .docked: StudioPalette.joint
    case .canvas: StudioPalette.hardware
    case nil: StudioPalette.accent
    }
  }

}

/// Compact, in-window presentation of the same workspace tool catalog used by
/// the docked ribbon. It keeps the canvas full-bleed and reveals full tool
/// groups only when the operator asks for them.
struct WorkspaceFloatingToolBar: View {
  @Bindable var workspace: StudioWorkspaceModel
  @Binding var isUIDevWorkspace: Bool
  @Binding var uiDevSection: UIDevSection
  let importModel: () -> Void
  let importAnimaCharacter: () -> Void
  let toggleAgentPanel: () -> Void

  @State private var selectedGroupID: String?
  @State private var hoveredGroupID: String?

  var body: some View {
    HStack(spacing: 2) {
      ForEach(groups) { group in
        groupButton(group)
      }

      Rectangle()
        .fill(StudioPalette.border)
        .frame(width: 1, height: 28)
        .padding(.horizontal, 3)

      Menu {
        Button("Dock Tool Ribbon", systemImage: "rectangle.tophalf.inset.filled") {
          workspace.ribbonPlacement = .docked
        }
        Button("Float at Top", systemImage: "rectangle.tophalf.inset.filled") {
          workspace.floatingRibbonEdge = .top
        }
        Button("Float at Bottom", systemImage: "rectangle.bottomhalf.inset.filled") {
          workspace.floatingRibbonEdge = .bottom
        }
        Divider()
        Button("Hide Tool Ribbon", systemImage: "eye.slash") {
          workspace.ribbonPlacement = .hidden
        }
      } label: {
        Image(
          systemName: workspace.floatingRibbonEdge == .top
            ? "rectangle.tophalf.inset.filled" : "rectangle.bottomhalf.inset.filled"
        )
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(StudioPalette.muted)
        .frame(width: 28, height: 28)
        .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(StudioPalette.border))
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
      .help("Tool ribbon placement")
    }
    .padding(6)
    .background(.regularMaterial, in: Capsule())
    .overlay(Capsule().stroke(StudioPalette.border, lineWidth: 1))
    .shadow(
      color: .black.opacity(0.22),
      radius: 18,
      y: workspace.floatingRibbonEdge == .top ? 8 : -8
    )
  }

  private var groups: [WorkspaceFloatingGroup] {
    if isUIDevWorkspace {
      return [
        WorkspaceFloatingGroup(id: "ui-library", title: "Library", systemImage: "square.grid.3x3"),
        WorkspaceFloatingGroup(id: "ui-panels", title: "Panels", systemImage: "sidebar.right"),
        WorkspaceFloatingGroup(id: "ui-agent", title: "Agent", systemImage: "sparkles"),
      ]
    }
    if workspace.activeWorkspace == .rig {
      return [
        WorkspaceFloatingGroup(id: "rig-structure", title: "Structure", systemImage: "cube"),
        WorkspaceFloatingGroup(id: "rig-mates", title: "Mates", systemImage: "rotate.3d"),
        WorkspaceFloatingGroup(id: "rig-relations", title: "Relations", systemImage: "link"),
      ]
    }
    return WorkspaceRibbonCatalog.groups(for: workspace.activeWorkspace).map {
      WorkspaceFloatingGroup(
        id: $0.id,
        title: $0.title,
        systemImage: $0.systemImage,
        descriptor: $0
      )
    }
  }

  private func groupButton(_ group: WorkspaceFloatingGroup) -> some View {
    let isSelected = selectedGroupID == group.id
    let isHovered = hoveredGroupID == group.id
    return Button {
      selectedGroupID = isSelected ? nil : group.id
    } label: {
      Image(systemName: group.systemImage)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(isSelected ? Color.white : tint(for: group))
        .frame(width: 36, height: 36)
        .background(
          isSelected
            ? tint(for: group)
            : (isHovered ? tint(for: group).opacity(0.12) : Color.clear),
          in: RoundedRectangle(cornerRadius: 9)
        )
    }
    .buttonStyle(.plain)
    .onHover { hoveredGroupID = $0 ? group.id : nil }
    .popover(
      isPresented: Binding(
        get: { selectedGroupID == group.id },
        set: { if !$0 { selectedGroupID = nil } }
      ),
      arrowEdge: workspace.floatingRibbonEdge == .top ? .top : .bottom
    ) {
      groupPopover(group)
    }
    .help(group.title)
  }

  @ViewBuilder
  private func groupPopover(_ group: WorkspaceFloatingGroup) -> some View {
    if isUIDevWorkspace {
      VStack(alignment: .leading, spacing: 10) {
        StudioSectionHeader(
          title: group.title,
          detail: "UI Dev uses the same production component library.",
          systemImage: group.systemImage
        )
        Button("Open UI Kit") {
          uiDevSection = .templateMatrix
          selectedGroupID = nil
        }
        .buttonStyle(StudioButtonStyle(expandsHorizontally: false))
        if group.id == "ui-agent" {
          Button("Open Agent Panel", action: toggleAgentPanel)
            .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: false))
        }
      }
      .padding(12)
      .frame(width: 310)
    } else if workspace.activeWorkspace == .rig {
      CreationPaletteView(workspace: workspace)
        .frame(width: 1_000, height: StudioMetrics.rigCreationRibbonHeight)
    } else if let descriptor = group.descriptor {
      WorkspaceFloatingGroupPopover(
        workspace: workspace,
        group: descriptor,
        importModel: importModel,
        importAnimaCharacter: importAnimaCharacter
      )
    }
  }

  private func tint(for group: WorkspaceFloatingGroup) -> Color {
    guard let descriptor = group.descriptor else {
      if group.id.contains("mate") { return StudioPalette.joint }
      if group.id.contains("relation") { return StudioPalette.hardware }
      return StudioPalette.semanticPart
    }
    return switch descriptor.role {
    case .accent: StudioPalette.accent
    case .assets: StudioPalette.sourceModel
    case .components: StudioPalette.semanticPart
    case .mates: StudioPalette.joint
    case .hardware: StudioPalette.hardware
    case .planned: StudioPalette.muted
    }
  }
}

private struct WorkspaceFloatingGroup: Identifiable {
  let id: String
  let title: String
  let systemImage: String
  var descriptor: WorkspaceRibbonGroupDescriptor?
}

private struct WorkspaceFloatingGroupPopover: View {
  @Bindable var workspace: StudioWorkspaceModel
  let group: WorkspaceRibbonGroupDescriptor
  let importModel: () -> Void
  let importAnimaCharacter: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      StudioSectionHeader(
        title: group.title,
        detail: "\(group.tools.count) workspace tools",
        systemImage: group.systemImage
      )
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 7)], spacing: 7) {
        ForEach(group.tools) { tool in
          CreationToolButton(
            title: displayTitle(tool),
            systemImage: displayImage(tool),
            tint: tint,
            isEnabled: isEnabled(tool),
            isSelected: isSelected(tool),
            help: tool.help
          ) {
            perform(tool.action)
          }
        }
      }
    }
    .padding(12)
    .frame(width: min(CGFloat(group.tools.count) * 82 + 32, 430))
  }

  private var tint: Color {
    switch group.role {
    case .accent: StudioPalette.accent
    case .assets: StudioPalette.sourceModel
    case .components: StudioPalette.semanticPart
    case .mates: StudioPalette.joint
    case .hardware: StudioPalette.hardware
    case .planned: StudioPalette.muted
    }
  }

  private func displayTitle(_ tool: WorkspaceRibbonToolDescriptor) -> String {
    tool.action == .togglePlayback && workspace.isPlaying ? "Pause" : tool.title
  }

  private func displayImage(_ tool: WorkspaceRibbonToolDescriptor) -> String {
    tool.action == .togglePlayback && workspace.isPlaying ? "pause.fill" : tool.systemImage
  }

  private func isEnabled(_ tool: WorkspaceRibbonToolDescriptor) -> Bool {
    guard let action = tool.action else { return false }
    return switch action {
    case .importAnimaCharacter: workspace.animaCoreState != .connecting
    case .importModel: !workspace.isLoadingModelHierarchy
    case .frameSelection: workspace.canFrameSelection
    case .stopPlayback, .togglePlayback, .toggleLoop, .previousKeyframe, .nextKeyframe,
      .toggleGrid, .toggleBottomEditor:
      true
    }
  }

  private func isSelected(_ tool: WorkspaceRibbonToolDescriptor) -> Bool {
    switch tool.action {
    case .toggleLoop: workspace.loopsPreviewPlayback
    case .toggleGrid: workspace.showsPreviewGrid
    case .toggleBottomEditor: workspace.activePresentation.showsBottomEditor
    default: false
    }
  }

  private func perform(_ action: WorkspaceRibbonAction?) {
    guard let action else { return }
    switch action {
    case .importAnimaCharacter: importAnimaCharacter()
    case .importModel: importModel()
    case .stopPlayback: workspace.stopPlayback()
    case .togglePlayback: workspace.togglePlayback()
    case .toggleLoop: workspace.loopsPreviewPlayback.toggle()
    case .previousKeyframe: workspace.seekAdjacentKeyframe(forward: false)
    case .nextKeyframe: workspace.seekAdjacentKeyframe(forward: true)
    case .frameSelection: workspace.frameSelection()
    case .toggleGrid: workspace.showsPreviewGrid.toggle()
    case .toggleBottomEditor: workspace.toggleBottomEditor()
    }
  }
}

private struct UIDevRibbonTrailingControls: View {
  @Binding var selectedSection: UIDevSection

  var body: some View {
    VStack(spacing: 7) {
      Button("Overview", systemImage: "house") {
        selectedSection = .templateMatrix
      }
      .labelStyle(.iconOnly)
      .buttonStyle(StudioIconButtonStyle(isSelected: selectedSection == .templateMatrix))
      .help("Return to the all-surfaces template matrix")

      Button("Reset UI gallery", systemImage: "arrow.counterclockwise") {
        selectedSection = .templateMatrix
      }
      .labelStyle(.iconOnly)
      .buttonStyle(StudioIconButtonStyle())
      .help("Reset the UI Dev gallery to the template matrix")
    }
    .frame(width: 42)
  }
}

struct WorkspacePanelHeader: View {
  let title: String
  let systemImage: String
  var closeAction: (() -> Void)?

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: systemImage)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(StudioPalette.accent)
        .frame(width: 16)
      Text(title.uppercased())
        .font(.system(size: 10.5, weight: .semibold))
        .tracking(0.6)
      Spacer(minLength: 8)
      if let closeAction {
        Button(action: closeAction) {
          Image(systemName: "xmark")
            .font(.caption.bold())
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Clear selection")
      }
    }
    .foregroundStyle(Color.white.opacity(0.92))
    .padding(.horizontal, StudioMetrics.panelPadding)
    .frame(height: StudioMetrics.panelHeaderHeight)
    .background(StudioPalette.panelInset.opacity(0.52))
  }
}

struct StudioStatusBar: View {
  @Bindable var workspace: StudioWorkspaceModel
  let isUIDevWorkspace: Bool

  var body: some View {
    HStack(spacing: 12) {
      HStack(spacing: 5) {
        Image(systemName: "hexagon.fill")
          .foregroundStyle(StudioPalette.hardware)
        Text("Anima Studio")
          .fontWeight(.semibold)
      }
      Rectangle().fill(StudioPalette.border).frame(width: 1, height: 13)
      Label(activeTitle, systemImage: activeSystemImage)
      Text(workspace.animaCoreStatusLabel)
      Spacer()
      if let time = workspace.engineEvaluationTimeSeconds {
        Label(
          "\(time.formatted(.number.precision(.fractionLength(3)))) s",
          systemImage: "waveform.path.ecg"
        )
      }
      Text("Local macOS")
      Text("⌘1–7 Workspaces")
    }
    .font(.system(size: 9))
    .foregroundStyle(StudioPalette.muted.opacity(0.78))
    .padding(.horizontal, 12)
    .frame(height: 25)
    .background(StudioPalette.documentChrome)
    .overlay(alignment: .top) {
      Rectangle().fill(StudioPalette.border).frame(height: 1)
    }
  }

  private var activeTitle: String {
    isUIDevWorkspace ? UIDevWorkspaceDescriptor.title : workspace.activeWorkspace.descriptor.title
  }

  private var activeSystemImage: String {
    isUIDevWorkspace
      ? UIDevWorkspaceDescriptor.systemImage : workspace.activeWorkspace.descriptor.systemImage
  }
}

struct WorkspaceGuideCard: View {
  @Bindable var workspace: StudioWorkspaceModel
  @Binding var isUIDevWorkspace: Bool
  let dismiss: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: activeSystemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(StudioPalette.accent)
      VStack(alignment: .leading, spacing: 2) {
        Text("WORKSPACE WALKTHROUGH · \(activeIndex + 1) OF \(workspaceCount)")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(StudioPalette.accent)
        Text(activePurpose)
          .font(.system(size: 11))
          .lineLimit(1)
      }
      Divider().frame(height: 26)
      Button {
        select(offset: -1)
      } label: {
        Image(systemName: "chevron.left")
      }
      .buttonStyle(StudioChromeIconButtonStyle())
      Button("Next") {
        select(offset: 1)
      }
      .buttonStyle(StudioButtonStyle(expandsHorizontally: false))
      Button(action: dismiss) {
        Image(systemName: "xmark")
      }
      .buttonStyle(StudioChromeIconButtonStyle())
    }
    .padding(.horizontal, 13)
    .frame(height: 48)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(StudioPalette.accent.opacity(0.55), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.34), radius: 18, y: 8)
  }

  private var workspaceCount: Int { StudioWorkspaceKind.centeredNavigation.count + 1 }

  private var activeIndex: Int {
    guard !isUIDevWorkspace else { return workspaceCount - 1 }
    return StudioWorkspaceKind.centeredNavigation.firstIndex(of: workspace.activeWorkspace) ?? 0
  }

  private var activeSystemImage: String {
    isUIDevWorkspace
      ? UIDevWorkspaceDescriptor.systemImage : workspace.activeWorkspace.descriptor.systemImage
  }

  private var activePurpose: String {
    isUIDevWorkspace
      ? UIDevWorkspaceDescriptor.purpose : workspace.activeWorkspace.descriptor.purpose
  }

  private func select(offset: Int) {
    let next = (activeIndex + offset + workspaceCount) % workspaceCount
    if next == workspaceCount - 1 {
      isUIDevWorkspace = true
    } else {
      isUIDevWorkspace = false
      workspace.switchWorkspace(to: StudioWorkspaceKind.centeredNavigation[next])
    }
  }
}
