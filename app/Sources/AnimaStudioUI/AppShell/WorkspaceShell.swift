import AnimaModel
import Observation
import SwiftUI

// MARK: - Shared shell state

struct StudioWorkspaceOverlayInsets: Equatable, Sendable {
  var top: CGFloat = 0
  var leading: CGFloat = 0
  var trailing: CGFloat = 0
}

private struct StudioWorkspaceOverlayInsetsKey: EnvironmentKey {
  static let defaultValue = StudioWorkspaceOverlayInsets()
}

extension EnvironmentValues {
  var studioWorkspaceOverlayInsets: StudioWorkspaceOverlayInsets {
    get { self[StudioWorkspaceOverlayInsetsKey.self] }
    set { self[StudioWorkspaceOverlayInsetsKey.self] = newValue }
  }
}

enum StudioToolDensity: String, CaseIterable, Identifiable, Sendable {
  case compact = "Compact"
  case standard = "Standard"
  case expanded = "Expanded"

  var id: Self { self }

  static func resolved(preference: Self, docked: Bool) -> Self {
    docked ? .expanded : preference
  }

  var systemImage: String {
    switch self {
    case .compact: "square.grid.3x3"
    case .standard: "rectangle.grid.1x2"
    case .expanded: "square.grid.2x2"
    }
  }
}

enum StudioSidebarSizing {
  static let railWidth: CGFloat = 44
  static let workspacePanelWidth: CGFloat = StudioMetrics.navigatorWidth
  static let viewPanelWidth: CGFloat = StudioMetrics.inspectorWidth

  static func dockedWidth(side: StudioSidebarSide, panelsAreOpen: Bool) -> CGFloat {
    railWidth
      + (panelsAreOpen
        ? (side == .leading ? workspacePanelWidth : viewPanelWidth) + 1
        : 0)
  }
}

enum StudioSidebarSide: String, Sendable {
  case leading
  case trailing
}

@MainActor
@Observable
final class StudioToolSettings {
  static let shared = StudioToolSettings()

  var density = StudioToolDensity.standard
  var activeCategoryByWorkspace: [StudioWorkspaceKind: String] = [:]

  func activeCategory(for workspace: StudioWorkspaceKind, fallback: String) -> String {
    activeCategoryByWorkspace[workspace] ?? fallback
  }

  func setActiveCategory(_ category: String, for workspace: StudioWorkspaceKind) {
    activeCategoryByWorkspace[workspace] = category
  }
}

enum StudioToolBehavior: Sendable {
  case arm(command: String)
  case command(WorkspaceRibbonAction)
  case unavailable
}

struct StudioToolDescriptor: Identifiable, Sendable {
  let id: String
  let title: String
  let systemImage: String
  let help: String
  let behavior: StudioToolBehavior
}

struct StudioToolGroup: Identifiable, Sendable {
  let id: String
  let title: String
  let tools: [StudioToolDescriptor]
}

struct StudioToolCategory: Identifiable, Sendable {
  let id: String
  let title: String
  let groups: [StudioToolGroup]
}

@MainActor
@Observable
final class StudioToolState {
  static let shared = StudioToolState()

  var armedTool: StudioToolDescriptor?
  var staysArmed = false

  var isArmed: Bool { armedTool != nil }

  var prompt: String {
    guard let armedTool else { return "" }
    return "\(armedTool.title) — click in the workspace to apply. Esc to cancel."
  }

  func arm(_ tool: StudioToolDescriptor) {
    guard case .arm = tool.behavior else { return }
    StudioViewSidebarState.shared.navigationMode = .select
    armedTool = tool
  }

  func committed() {
    if !staysArmed { armedTool = nil }
  }

  func disarm() {
    armedTool = nil
  }
}

enum StudioViewSidebarTab: String, CaseIterable, Identifiable, Sendable {
  case view = "View"
  case environment = "Environment"
  case appearance = "Appearance"
  case inspector = "Inspector"

  var id: Self { self }

  var systemImage: String {
    switch self {
    case .view: "cube"
    case .environment: "sun.max"
    case .appearance: "paintpalette"
    case .inspector: "slider.horizontal.3"
    }
  }
}

enum StudioCameraNavigationMode: String, CaseIterable, Identifiable, Sendable {
  case select = "Select"
  case pan = "Pan"
  case orbit = "Orbit"
  case measure = "Measure"

  var id: Self { self }

  var systemImage: String {
    switch self {
    case .select: "cursorarrow"
    case .pan: "hand.raised"
    case .orbit: "arrow.triangle.2.circlepath"
    case .measure: "ruler"
    }
  }
}

enum StudioViewportDisplayMode: String, CaseIterable, Identifiable, Sendable {
  case wireframe = "Wireframe"
  case hiddenLine = "Hidden line"
  case shaded = "Shaded"

  var id: Self { self }

  var systemImage: String {
    switch self {
    case .wireframe: "cube.transparent"
    case .hiddenLine: "cube"
    case .shaded: "cube.fill"
    }
  }
}

@MainActor
@Observable
final class StudioViewSidebarState {
  static let shared = StudioViewSidebarState()

  var selectedTab = StudioViewSidebarTab.view
  var isOpen = true
  var navigationMode = StudioCameraNavigationMode.select
  var displayMode = StudioViewportDisplayMode.shaded
  var viewPreset = "Standard"
  var showsHiddenEdges = true
  var showsGrid = true
  var showsOrigin = true
  var showsGroundShadow = true
  var lightingIntensity = 1.0
  var appearanceTheme = "Studio Blue"
  var showsEdges = true
  var keepsImportedColors = true
  var opacity = 1.0

  func select(_ tab: StudioViewSidebarTab) {
    let result = StudioSidebarInteraction.select(tab, current: selectedTab, isOpen: isOpen)
    selectedTab = result.selection
    isOpen = result.isOpen
    StudioToolState.shared.disarm()
  }

  func selectNavigation(_ mode: StudioCameraNavigationMode) {
    navigationMode = mode
    StudioToolState.shared.disarm()
  }
}

// MARK: - Catalog adapters

struct StudioWorkspaceSidebarTab: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let systemImage: String
}

enum StudioSidebarInteraction {
  static func select<T: Equatable>(
    _ tab: T,
    current: T,
    isOpen: Bool
  ) -> (selection: T, isOpen: Bool) {
    tab == current ? (current, !isOpen) : (tab, true)
  }
}

enum StudioWorkspaceSidebarCatalog {
  static func tabs(for workspace: StudioWorkspaceKind) -> [StudioWorkspaceSidebarTab] {
    switch workspace {
    case .assets:
      [
        tab("Characters", "person.2"), tab("Collections", "square.stack.3d.up"),
        tab("Library", "books.vertical"),
      ]
    case .rig:
      [
        tab("Components", "cube"), tab("Mates", "link"),
        tab("Relations", "arrow.triangle.branch"),
      ]
    case .animate:
      [
        tab("Tracks", "list.bullet.rectangle"), tab("Components", "cube"),
        tab("Clips", "film.stack"),
      ]
    case .show:
      [
        tab("Scenes", "sparkles.rectangle.stack"), tab("Cues", "bolt.circle"),
        tab("Media", "play.rectangle"),
      ]
    case .nodes:
      [tab("Library", "square.grid.3x3"), tab("Graph", "point.3.connected.trianglepath.dotted")]
    case .hardware:
      [
        tab("Devices", "cable.connector"), tab("Outputs", "slider.horizontal.3"),
        tab("Safety", "exclamationmark.shield"),
      ]
    }
  }

  static func defaultSelection(for workspace: StudioWorkspaceKind) -> String {
    tabs(for: workspace).first?.id ?? "Workspace"
  }

  private static func tab(_ title: String, _ systemImage: String) -> StudioWorkspaceSidebarTab {
    StudioWorkspaceSidebarTab(id: title, title: title, systemImage: systemImage)
  }
}

enum StudioWorkspaceToolCatalog {
  static func groups(for workspace: StudioWorkspaceKind) -> [StudioToolGroup] {
    WorkspaceRibbonCatalog.groups(for: workspace).map { group in
      StudioToolGroup(
        id: group.id,
        title: group.title,
        tools: group.tools.map { tool in
          StudioToolDescriptor(
            id: "\(workspace.rawValue).\(group.id).\(tool.id)",
            title: tool.title,
            systemImage: tool.systemImage,
            help: tool.help,
            behavior: tool.action.map(StudioToolBehavior.command) ?? .unavailable
          )
        }
      )
    }
  }

  @MainActor
  static func rigCategories(workspace: StudioWorkspaceModel) -> [StudioToolCategory] {
    let canCreateRevoluteJoint = workspace.canCreateRevoluteJoint
    let partTools = RigPrimitiveKind.creatableCases.map { kind in
      StudioToolDescriptor(
        id: "rig.part.\(kind.rawValue)",
        title: kind.displayName,
        systemImage: kind.systemImage,
        help: "Add a \(kind.displayName.lowercased()) to the semantic rig.",
        behavior: .arm(command: "rig.part.\(kind.rawValue)")
      )
    }
    let mateTools = MateCreationToolKind.allCases.map { kind in
      StudioToolDescriptor(
        id: "rig.mate.\(kind.id)",
        title: kind.title,
        systemImage: kind.systemImage,
        help: kind.motionSummary,
        behavior: kind == .revolute && canCreateRevoluteJoint
          ? .arm(command: "rig.mate.revolute") : .unavailable
      )
    }
    let relationTools = workspace.engineRelationTypes.map { relation in
      StudioToolDescriptor(
        id: "rig.relation.\(relation.kind.rawValue)",
        title: relation.label,
        systemImage: relation.kind.systemImage,
        help: "Create an engine-backed \(relation.label.lowercased()) relation.",
        behavior: .arm(command: "rig.relation.\(relation.kind.rawValue)")
      )
    }
    return [
      StudioToolCategory(
        id: "Build", title: "Build",
        groups: [StudioToolGroup(id: "Structures", title: "Create", tools: partTools)]
      ),
      StudioToolCategory(
        id: "Mates", title: "Mates",
        groups: [StudioToolGroup(id: "Mates", title: "Connect", tools: mateTools)]
      ),
      StudioToolCategory(
        id: "Relations", title: "Relations",
        groups: [StudioToolGroup(id: "Relations", title: "Couple", tools: relationTools)]
      ),
      StudioToolCategory(
        id: "Inspect", title: "Inspect",
        groups: [
          StudioToolGroup(
            id: "Inspect", title: "Inspect",
            tools: [
              StudioToolDescriptor(
                id: "rig.frame", title: "Frame", systemImage: "viewfinder",
                help: "Frame the current selection.", behavior: .command(.frameSelection)),
              StudioToolDescriptor(
                id: "rig.grid", title: "Grid", systemImage: "grid",
                help: "Show or hide the workspace grid.", behavior: .command(.toggleGrid)),
            ]
          )
        ]
      ),
    ]
  }
}

// MARK: - Shared chrome and rails

struct SidebarChrome: ViewModifier {
  let docked: Bool
  var cornerRadius: CGFloat = 12

  @ViewBuilder
  func body(content: Content) -> some View {
    if docked {
      content.background(StudioPalette.panel)
    } else {
      content
        .background(
          .regularMaterial,
          in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(StudioPalette.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 16, y: 7)
    }
  }
}

extension View {
  func sidebarChrome(docked: Bool, cornerRadius: CGFloat = 12) -> some View {
    modifier(SidebarChrome(docked: docked, cornerRadius: cornerRadius))
  }
}

private struct StudioSidebarRail: View {
  let tabs: [StudioWorkspaceSidebarTab]
  @Binding var selection: String
  @Binding var isOpen: Bool
  let docked: Bool

  var body: some View {
    VStack(spacing: 3) {
      ForEach(tabs) { tab in
        let active = selection == tab.id && isOpen
        Button {
          withAnimation(.easeOut(duration: 0.18)) {
            let result = StudioSidebarInteraction.select(
              tab.id,
              current: selection,
              isOpen: isOpen
            )
            selection = result.selection
            isOpen = result.isOpen
          }
        } label: {
          Image(systemName: tab.systemImage)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(active ? Color.white : StudioPalette.muted)
            .frame(width: 34, height: 34)
            .background(
              active ? StudioPalette.accent : Color.clear,
              in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .help(tab.title)
      }
    }
    .padding(5)
    .frame(maxHeight: docked ? .infinity : nil, alignment: docked ? .top : .center)
    .sidebarChrome(docked: docked)
  }
}

private struct StudioViewRail: View {
  let docked: Bool
  private var state: StudioViewSidebarState { .shared }

  var body: some View {
    VStack(spacing: 3) {
      ForEach(StudioViewSidebarTab.allCases) { tab in
        let active = state.selectedTab == tab && state.isOpen
        Button {
          state.select(tab)
        } label: {
          Image(systemName: tab.systemImage)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(active ? Color.white : StudioPalette.muted)
            .frame(width: 34, height: 34)
            .background(
              active ? StudioPalette.accent : Color.clear,
              in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
      }
    }
    .padding(5)
    .frame(maxHeight: docked ? .infinity : nil, alignment: docked ? .top : .center)
    .sidebarChrome(docked: docked)
  }
}

// MARK: - Tool sidebar

struct StudioToolSidebar: View {
  let workspaceKind: StudioWorkspaceKind
  var groups: [StudioToolGroup]
  var categories: [StudioToolCategory]
  let docked: Bool
  let performCommand: (WorkspaceRibbonAction) -> Void

  private var settings: StudioToolSettings { .shared }
  private var state: StudioToolState { .shared }

  private var density: StudioToolDensity {
    StudioToolDensity.resolved(preference: settings.density, docked: docked)
  }
  private var activeCategory: StudioToolCategory? {
    guard let first = categories.first else { return nil }
    let selected = settings.activeCategory(for: workspaceKind, fallback: first.id)
    return categories.first { $0.id == selected } ?? first
  }
  private var activeGroups: [StudioToolGroup] { activeCategory?.groups ?? groups }

  var body: some View {
    VStack(spacing: 0) {
      if density == .expanded, !categories.isEmpty {
        categoryStrip
      }
      toolRow
    }
    .padding(.horizontal, 7)
    .padding(.vertical, 5)
    .sidebarChrome(docked: docked, cornerRadius: 14)
    .frame(maxWidth: docked ? .infinity : nil, alignment: .leading)
  }

  private var categoryStrip: some View {
    HStack(spacing: 2) {
      ForEach(categories) { category in
        let active = activeCategory?.id == category.id
        Button {
          settings.setActiveCategory(category.id, for: workspaceKind)
        } label: {
          Text(category.title.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(active ? StudioPalette.accent : StudioPalette.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
              active ? StudioPalette.accent.opacity(0.14) : Color.clear,
              in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
      }
      Spacer(minLength: 8)
    }
    .padding(.bottom, 2)
  }

  private var toolRow: some View {
    HStack(alignment: .top, spacing: density == .expanded ? 13 : 2) {
      ForEach(activeGroups) { group in
        if density == .expanded {
          VStack(spacing: 1) {
            HStack(spacing: 2) { ForEach(group.tools) { toolButton($0) } }
            Text(group.title.uppercased())
              .font(.system(size: 8.5, weight: .semibold))
              .tracking(0.7)
              .foregroundStyle(StudioPalette.muted)
          }
        } else {
          ForEach(group.tools) { toolButton($0) }
        }
      }
      densityMenu
    }
  }

  private func toolButton(_ tool: StudioToolDescriptor) -> some View {
    let active = state.armedTool?.id == tool.id
    let compact = density == .compact
    let enabled: Bool = {
      if case .unavailable = tool.behavior { return false }
      return true
    }()
    return Button {
      activate(tool)
    } label: {
      VStack(spacing: 3) {
        Image(systemName: tool.systemImage)
          .font(.system(size: compact ? 14 : 16, weight: .medium))
        if !compact {
          Text(tool.title).font(.system(size: 9.5, weight: .medium)).lineLimit(1)
        }
      }
      .foregroundStyle(active ? Color.white : StudioPalette.muted)
      .frame(width: compact ? 34 : 56, height: compact ? 34 : 48)
      .background(
        active ? StudioPalette.accent : Color.clear,
        in: RoundedRectangle(cornerRadius: 8)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.32)
    .help(tool.help)
  }

  private var densityMenu: some View {
    Menu {
      Section("Tool density") {
        ForEach(StudioToolDensity.allCases) { density in
          Button {
            settings.density = density
          } label: {
            Label(
              density.rawValue,
              systemImage: settings.density == density ? "checkmark" : density.systemImage
            )
          }
        }
      }
    } label: {
      Image(systemName: "ellipsis")
        .frame(width: 30, height: density == .compact ? 34 : 48)
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .help("Tool sidebar density")
  }

  private func activate(_ tool: StudioToolDescriptor) {
    switch tool.behavior {
    case .arm:
      state.arm(tool)
    case .command(let action):
      state.disarm()
      performCommand(action)
    case .unavailable:
      break
    }
  }
}

struct StudioToolPromptBar: View {
  private var state: StudioToolState { .shared }

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: state.armedTool?.systemImage ?? "cursorarrow")
        .foregroundStyle(Color.white)
        .frame(width: 22, height: 22)
        .background(StudioPalette.accent, in: RoundedRectangle(cornerRadius: 6))
      Text(state.prompt).font(.system(size: 11.5, weight: .medium))
      Toggle("Repeat", isOn: Binding(get: { state.staysArmed }, set: { state.staysArmed = $0 }))
        .toggleStyle(.checkbox)
        .controlSize(.small)
      Button {
        state.disarm()
      } label: {
        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 7)
    .background(.regularMaterial, in: Capsule())
    .overlay(Capsule().stroke(StudioPalette.accent.opacity(0.55)))
    .shadow(color: .black.opacity(0.22), radius: 12, y: 4)
  }
}

// MARK: - Sidebars and scaffold

private struct StudioWorkspaceSidebar<Content: View>: View {
  let tabs: [StudioWorkspaceSidebarTab]
  @Binding var selection: String
  @Binding var isOpen: Bool
  let docked: Bool
  @ViewBuilder let content: (String) -> Content

  var body: some View {
    HStack(alignment: .center, spacing: docked ? 0 : 9) {
      StudioSidebarRail(
        tabs: tabs,
        selection: $selection,
        isOpen: $isOpen,
        docked: docked
      )
      if isOpen {
        if docked { Divider().overlay(StudioPalette.border) }
        content(selection)
          .frame(width: StudioMetrics.navigatorWidth)
          .frame(maxHeight: docked ? .infinity : nil)
          .environment(\.studioPanelSurfaceMode, docked ? .docked : .floating)
          .transition(.move(edge: .leading).combined(with: .opacity))
      }
    }
  }
}

private struct StudioViewSidebar<Content: View>: View {
  let docked: Bool
  @ViewBuilder let content: (StudioViewSidebarTab) -> Content
  private var state: StudioViewSidebarState { .shared }

  var body: some View {
    HStack(alignment: .center, spacing: docked ? 0 : 9) {
      if state.isOpen {
        content(state.selectedTab)
          .frame(width: StudioMetrics.inspectorWidth)
          .frame(maxHeight: docked ? .infinity : nil)
          .environment(\.studioPanelSurfaceMode, docked ? .docked : .floating)
          .transition(.move(edge: .trailing).combined(with: .opacity))
        if docked { Divider().overlay(StudioPalette.border) }
      }
      StudioViewRail(docked: docked)
    }
  }
}

private enum StudioShellEdge: Hashable {
  case top
  case leading
  case trailing
}

struct StudioWorkspaceScaffold<Center: View, Left: View, Right: View>: View {
  let workspaceKind: StudioWorkspaceKind
  var toolGroups: [StudioToolGroup]
  var toolCategories: [StudioToolCategory]
  let leftTabs: [StudioWorkspaceSidebarTab]
  @Binding var leftSelection: String
  @Binding var leftOpen: Bool
  let performCommand: (WorkspaceRibbonAction) -> Void
  @ViewBuilder let center: Center
  @ViewBuilder let left: (String) -> Left
  @ViewBuilder let right: (StudioViewSidebarTab) -> Right

  private var layout: StudioLayoutState { .shared }
  private var tools: StudioToolState { .shared }
  @State private var hoveredZones: Set<StudioShellEdge> = []
  @State private var hoveredSidebars: Set<StudioShellEdge> = []
  @State private var revealedEdges: Set<StudioShellEdge> = []
  @State private var hideTasks: [StudioShellEdge: Task<Void, Never>] = [:]

  private var isDocked: Bool { layout.detectedPreset == .docked }
  private var isCanvas: Bool { layout.detectedPreset == .canvas }

  var body: some View {
    Group {
      if isDocked { dockedBody } else { floatingBody }
    }
    .animation(.spring(response: 0.28, dampingFraction: 0.88), value: layout.detectedPreset)
  }

  private var dockedBody: some View {
    HStack(spacing: 0) {
      workspaceSidebar(docked: true)
      Divider().overlay(StudioPalette.border)
      VStack(spacing: 0) {
        toolSidebar(docked: true)
        Divider().overlay(StudioPalette.border)
        center
      }
      Divider().overlay(StudioPalette.border)
      viewSidebar(docked: true)
    }
  }

  private var floatingBody: some View {
    center
      .environment(\.studioWorkspaceOverlayInsets, centerOverlayInsets)
      .animation(.spring(response: 0.24, dampingFraction: 0.9), value: centerOverlayInsets)
      .overlay(alignment: .top) {
        reveal(edge: .top) { toolSidebar(docked: false).padding(.top, 12) }
      }
      .overlay(alignment: .top) {
        if tools.isArmed {
          StudioToolPromptBar().padding(.top, 78)
        }
      }
      .overlay(alignment: .leading) {
        reveal(edge: .leading) {
          workspaceSidebar(docked: false)
            .padding(.leading, 12)
            .frame(maxHeight: .infinity, alignment: .center)
        }
      }
      .overlay(alignment: .trailing) {
        reveal(edge: .trailing) {
          viewSidebar(docked: false)
            .padding(.trailing, 12)
            .frame(maxHeight: .infinity, alignment: .center)
        }
      }
  }

  private var centerOverlayInsets: StudioWorkspaceOverlayInsets {
    if isCanvas {
      return StudioWorkspaceOverlayInsets(
        top: revealedEdges.contains(.top) ? StudioMetrics.rigCreationRibbonHeight + 24 : 0,
        leading: revealedEdges.contains(.leading) ? StudioMetrics.navigatorWidth + 76 : 0,
        trailing: revealedEdges.contains(.trailing) ? StudioMetrics.inspectorWidth + 76 : 0
      )
    }
    return StudioWorkspaceOverlayInsets(
      top: StudioMetrics.rigCreationRibbonHeight + 24,
      leading: leftOpen ? StudioMetrics.navigatorWidth + 76 : 58,
      trailing: StudioViewSidebarState.shared.isOpen ? StudioMetrics.inspectorWidth + 76 : 58
    )
  }

  private func toolSidebar(docked: Bool) -> some View {
    StudioToolSidebar(
      workspaceKind: workspaceKind,
      groups: toolGroups,
      categories: toolCategories,
      docked: docked,
      performCommand: performCommand
    )
  }

  private func workspaceSidebar(docked: Bool) -> some View {
    StudioWorkspaceSidebar(
      tabs: leftTabs,
      selection: $leftSelection,
      isOpen: $leftOpen,
      docked: docked,
      content: left
    )
  }

  private func viewSidebar(docked: Bool) -> some View {
    StudioViewSidebar(docked: docked, content: right)
  }

  @ViewBuilder
  private func reveal<Content: View>(
    edge: StudioShellEdge,
    @ViewBuilder content: () -> Content
  ) -> some View {
    if !isCanvas {
      content()
    } else {
      ZStack(alignment: alignment(for: edge)) {
        hotZone(for: edge)
        if isRevealed(edge) {
          content()
            .onHover { updateSidebarHover($0, edge: edge) }
            .transition(.move(edge: transitionEdge(for: edge)).combined(with: .opacity))
        } else {
          edgeHandle(for: edge)
        }
      }
    }
  }

  private func hotZone(for edge: StudioShellEdge) -> some View {
    Color.clear
      .frame(
        width: edge == .top ? nil : 16,
        height: edge == .top ? 16 : nil
      )
      .frame(
        maxWidth: edge == .top ? .infinity : nil,
        maxHeight: edge == .top ? nil : .infinity
      )
      .contentShape(Rectangle())
      .onHover { updateZoneHover($0, edge: edge) }
  }

  private func edgeHandle(for edge: StudioShellEdge) -> some View {
    Capsule()
      .fill(StudioPalette.muted.opacity(0.42))
      .frame(width: edge == .top ? 34 : 4, height: edge == .top ? 4 : 34)
      .padding(edgePadding(for: edge), 5)
      .allowsHitTesting(false)
  }

  private func isRevealed(_ edge: StudioShellEdge) -> Bool {
    revealedEdges.contains(edge)
  }

  private func updateZoneHover(_ hovering: Bool, edge: StudioShellEdge) {
    updateHover(hovering, edge: edge, set: &hoveredZones)
  }

  private func updateSidebarHover(_ hovering: Bool, edge: StudioShellEdge) {
    updateHover(hovering, edge: edge, set: &hoveredSidebars)
  }

  private func updateHover(
    _ hovering: Bool,
    edge: StudioShellEdge,
    set: inout Set<StudioShellEdge>
  ) {
    if hovering {
      hideTasks[edge]?.cancel()
      set.insert(edge)
      revealedEdges.insert(edge)
    } else {
      set.remove(edge)
      hideTasks[edge]?.cancel()
      hideTasks[edge] = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled,
          !hoveredZones.contains(edge),
          !hoveredSidebars.contains(edge)
        else { return }
        revealedEdges.remove(edge)
      }
    }
  }

  private func alignment(for edge: StudioShellEdge) -> Alignment {
    switch edge {
    case .top: .top
    case .leading: .leading
    case .trailing: .trailing
    }
  }

  private func transitionEdge(for edge: StudioShellEdge) -> Edge {
    switch edge {
    case .top: .top
    case .leading: .leading
    case .trailing: .trailing
    }
  }

  private func edgePadding(for edge: StudioShellEdge) -> Edge.Set {
    switch edge {
    case .top: .top
    case .leading: .leading
    case .trailing: .trailing
    }
  }
}

// MARK: - Presentation cards used by the right sidebar

struct StudioViewSidebarPanel<Inspector: View>: View {
  let tab: StudioViewSidebarTab
  @ViewBuilder let inspector: Inspector
  @Environment(\.studioPanelSurfaceMode) private var surfaceMode
  private var state: StudioViewSidebarState { .shared }

  var body: some View {
    if tab == .inspector {
      inspector
    } else {
      VStack(alignment: .leading, spacing: 0) {
        WorkspacePanelHeader(title: tab.rawValue, systemImage: tab.systemImage)
        VStack(alignment: .leading, spacing: 11) {
          switch tab {
          case .view: viewControls
          case .environment: environmentControls
          case .appearance: appearanceControls
          case .inspector: EmptyView()
          }
        }
        .padding(12)
        if surfaceMode == .docked { Spacer(minLength: 0) }
      }
      .studioPanelSurface()
    }
  }

  private var viewControls: some View {
    Group {
      Picker("View", selection: Binding(get: { state.viewPreset }, set: { state.viewPreset = $0 }))
      {
        ForEach(["Standard", "Isometric", "Front", "Top", "Right"], id: \.self) { Text($0) }
      }
      .controlSize(.small)

      Text("DISPLAY").studioSidebarCaption()
      HStack(spacing: 5) {
        ForEach(StudioViewportDisplayMode.allCases) { mode in
          Button {
            state.displayMode = mode
          } label: {
            Image(systemName: mode.systemImage)
              .frame(width: 34, height: 30)
              .background(
                state.displayMode == mode ? StudioPalette.accent : StudioPalette.panelInset,
                in: RoundedRectangle(cornerRadius: 7)
              )
          }
          .buttonStyle(.plain)
          .help(mode.rawValue)
        }
      }
      Toggle(
        "Show hidden edges",
        isOn: Binding(get: { state.showsHiddenEdges }, set: { state.showsHiddenEdges = $0 })
      )
      .controlSize(.small)

      Divider()
      Text("CAMERA NAVIGATION").studioSidebarCaption()
      HStack(spacing: 4) {
        ForEach(StudioCameraNavigationMode.allCases) { mode in
          Button {
            state.selectNavigation(mode)
          } label: {
            Image(systemName: mode.systemImage)
              .frame(width: 32, height: 28)
              .background(
                state.navigationMode == mode ? StudioPalette.accent : StudioPalette.panelInset,
                in: RoundedRectangle(cornerRadius: 7)
              )
          }
          .buttonStyle(.plain)
          .help("\(mode.rawValue) camera")
        }
      }
    }
  }

  private var environmentControls: some View {
    Group {
      Text("SCENE").studioSidebarCaption()
      Toggle("Grid", isOn: Binding(get: { state.showsGrid }, set: { state.showsGrid = $0 }))
      Toggle("Origin", isOn: Binding(get: { state.showsOrigin }, set: { state.showsOrigin = $0 }))
      Toggle(
        "Ground shadow",
        isOn: Binding(get: { state.showsGroundShadow }, set: { state.showsGroundShadow = $0 })
      )
      Text("KEY LIGHT").studioSidebarCaption()
      Slider(
        value: Binding(
          get: { state.lightingIntensity }, set: { state.lightingIntensity = $0 }
        ),
        in: 0...2
      )
    }
    .controlSize(.small)
  }

  private var appearanceControls: some View {
    Group {
      Picker(
        "Theme",
        selection: Binding(get: { state.appearanceTheme }, set: { state.appearanceTheme = $0 })
      ) {
        ForEach(["Studio Blue", "Graphite", "Blueprint", "High Contrast"], id: \.self) {
          Text($0)
        }
      }
      .controlSize(.small)
      Toggle("Show edges", isOn: Binding(get: { state.showsEdges }, set: { state.showsEdges = $0 }))
      Toggle(
        "Keep imported colors",
        isOn: Binding(get: { state.keepsImportedColors }, set: { state.keepsImportedColors = $0 })
      )
      Text("OPACITY").studioSidebarCaption()
      Slider(value: Binding(get: { state.opacity }, set: { state.opacity = $0 }), in: 0.2...1)
    }
    .controlSize(.small)
  }
}

extension View {
  fileprivate func studioSidebarCaption() -> some View {
    font(.system(size: 9.5, weight: .semibold))
      .tracking(0.6)
      .foregroundStyle(StudioPalette.muted)
  }
}
