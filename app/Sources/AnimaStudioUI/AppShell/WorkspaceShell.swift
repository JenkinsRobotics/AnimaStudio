import AnimaModel
import Observation
import RealityKitViewport
import SwiftUI

// MARK: - Shared shell state

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

  var usesGroupedMenus: Bool { self != .expanded }
  var usesVisualCategoryPalette: Bool { self == .compact }
}

enum StudioToolBarSizing {
  static func height(for density: StudioToolDensity) -> CGFloat {
    switch density {
    case .compact: StudioMetrics.compactRibbonHeight
    case .standard: 64
    case .expanded: StudioMetrics.rigCreationRibbonHeight
    }
  }

  static func fillsAvailableWidth(_ density: StudioToolDensity) -> Bool {
    false
  }
}

enum StudioStandardToolPresentation {
  static func primaryTools(in group: StudioToolGroup) -> [StudioToolDescriptor] {
    group.primaryTools
  }
}

enum StudioSidebarSizing {
  static let railWidth: CGFloat = 44
  /// Match the accepted demo shell. These are intentionally fixed so a
  /// docked browser or inspector cannot greedily consume the center canvas.
  static let workspacePanelWidth: CGFloat = 232
  static let viewPanelWidth: CGFloat = 200

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
  static let defaultDensity = StudioToolDensity.expanded

  var density = defaultDensity
  var activeCategoryByWorkspace: [StudioWorkspaceKind: String] = [:]
  var openCompactGroupByWorkspace: [StudioWorkspaceKind: String] = [:]

  func activeCategory(for workspace: StudioWorkspaceKind, fallback: String) -> String {
    activeCategoryByWorkspace[workspace] ?? fallback
  }

  func setActiveCategory(_ category: String, for workspace: StudioWorkspaceKind) {
    activeCategoryByWorkspace[workspace] = category
  }

  func isCompactGroupOpen(_ groupID: String, for workspace: StudioWorkspaceKind) -> Bool {
    openCompactGroupByWorkspace[workspace] == groupID
  }

  func toggleCompactGroup(_ groupID: String, for workspace: StudioWorkspaceKind) {
    openCompactGroupByWorkspace[workspace] =
      isCompactGroupOpen(groupID, for: workspace) ? nil : groupID
  }

  func closeCompactGroup(for workspace: StudioWorkspaceKind) {
    openCompactGroupByWorkspace[workspace] = nil
  }
}

enum StudioToolPayload: Sendable {
  case addPart(RigPrimitiveKind)
  case createRevoluteMate
  case createRelation(kindID: String)
  case designPlaceholder(toolID: String)
}

enum StudioToolBehavior: Sendable {
  case arm(StudioToolPayload)
  case command(WorkspaceRibbonAction)
  case unavailable
}

struct StudioToolDescriptor: Identifiable, Sendable {
  let id: String
  let title: String
  let systemImage: String
  let help: String
  let behavior: StudioToolBehavior
  /// Standard density keeps primary tools inline and moves the rest into the
  /// group's overflow popover. This is catalog data, not a view heuristic.
  var primary = true
}

struct StudioToolGroup: Identifiable, Sendable {
  let id: String
  let title: String
  let tools: [StudioToolDescriptor]
  private let explicitCategoryIcon: String?

  init(
    id: String,
    title: String,
    tools: [StudioToolDescriptor],
    categoryIcon: String? = nil
  ) {
    self.id = id
    self.title = title
    self.tools = tools
    self.explicitCategoryIcon = categoryIcon
  }

  var categoryIcon: String {
    explicitCategoryIcon ?? tools.first?.systemImage ?? "square.grid.2x2"
  }

  var primaryTools: [StudioToolDescriptor] { tools.filter(\.primary) }
  var overflowTools: [StudioToolDescriptor] { tools.filter { !$0.primary } }
}

struct StudioToolCategory: Identifiable, Sendable {
  let id: String
  let title: String
  let groups: [StudioToolGroup]
}

enum StudioToolCategoryPresentation {
  /// A single expanded ribbon remains easier to scan until the complete tool
  /// catalog becomes too wide to be useful. Above this count, category tabs
  /// bound the visible row while preserving every tool.
  static let expandedToolLimit = 24

  static func usesTabs(
    groups: [StudioToolGroup],
    categories: [StudioToolCategory]
  ) -> Bool {
    guard categories.count > 1 else { return false }
    let completeCatalog = groups.isEmpty ? categories.flatMap(\.groups) : groups
    return completeCatalog.reduce(0) { $0 + $1.tools.count } > expandedToolLimit
  }
}

@MainActor
@Observable
final class StudioToolState {
  static let shared = StudioToolState()

  var armedTool: StudioToolDescriptor?
  var staysArmed = false
  /// Installed by the active workspace from `.onAppear`. Returning true marks
  /// an immediate command as handled so it never enters the armed-tool state.
  var actionHandler: ((StudioToolDescriptor) -> Bool)?

  var isArmed: Bool { armedTool != nil }

  var prompt: String {
    guard let armedTool else { return "" }
    return "\(armedTool.title) — click in the viewport. Esc to cancel."
  }

  func activate(_ tool: StudioToolDescriptor) {
    if actionHandler?(tool) == true {
      disarm()
      return
    }
    arm(tool)
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

  static func resolve(renderStyle: ViewportRenderStyle) -> Self {
    switch renderStyle {
    case .wireframe: .wireframe
    case .shadedWithEdges: .hiddenLine
    case .shaded, .unshaded, .translucent: .shaded
    }
  }

  var renderStyle: ViewportRenderStyle {
    switch self {
    case .wireframe: .wireframe
    case .hiddenLine: .shadedWithEdges
    case .shaded: .shaded
    }
  }
}

@MainActor
@Observable
final class StudioViewSidebarState {
  static let shared = StudioViewSidebarState()

  let panels = StudioPanelStackState(
    order: StudioViewSidebarTab.allCases.map(\.rawValue),
    defaults: [],
    side: .trailing
  )
  var navigationMode = StudioCameraNavigationMode.select
  var viewPreset = "Standard"
  var showsHiddenEdges = true
  var showsOrigin = true
  var keepsImportedColors = true
  var opacity = 1.0

  var selectedTab: StudioViewSidebarTab {
    get { StudioViewSidebarTab(rawValue: panels.focusedID ?? "") ?? .view }
    set { panels.focusedID = newValue.rawValue }
  }

  var isOpen: Bool {
    get { panels.isOpen }
    set {
      if newValue {
        panels.enable(selectedTab.rawValue)
      } else {
        panels.closeAll()
      }
    }
  }

  func select(_ tab: StudioViewSidebarTab) {
    panels.toggle(tab.rawValue)
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

/// Shared state engine for both sidebars. It owns open order, multi-panel
/// stacking, transient reorder feedback, and torn-off panel positions. Views
/// only project this state, so layout-branch changes cannot reset it.
@MainActor
@Observable
final class StudioPanelStackState {
  var order: [String]
  let side: StudioSidebarSide
  var exclusive: Bool
  var enabled: Set<String>
  var focusedID: String?
  var floatingOffset: [String: CGSize] = [:]
  var draggingID: String?
  var dragOffset: CGSize = .zero
  var dropIndex: Int?
  var willFloat = false

  init(
    order: [String],
    defaults: [String] = [],
    side: StudioSidebarSide,
    exclusive: Bool = false
  ) {
    self.order = order
    self.side = side
    self.exclusive = exclusive
    self.enabled = Set(defaults)
    self.focusedID = defaults.last
  }

  var ordered: [String] { order.filter(enabled.contains) }
  var stacked: [String] { ordered.filter { floatingOffset[$0] == nil } }
  var floating: [String] { ordered.filter { floatingOffset[$0] != nil } }
  var isOpen: Bool { !enabled.isEmpty }

  func configure(order newOrder: [String]) {
    guard newOrder != order else { return }
    let valid = Set(newOrder)
    order = newOrder
    enabled.formIntersection(valid)
    floatingOffset = floatingOffset.filter { valid.contains($0.key) }
    if focusedID.map({ !valid.contains($0) }) == true { focusedID = nil }
  }

  func isEnabled(_ id: String) -> Bool { enabled.contains(id) }

  func enable(_ id: String) {
    guard order.contains(id) else { return }
    if exclusive {
      enabled.removeAll()
      floatingOffset.removeAll()
    }
    enabled.insert(id)
    focusedID = id
  }

  func toggle(_ id: String) {
    guard order.contains(id) else { return }
    if enabled.contains(id) {
      enabled.remove(id)
      floatingOffset[id] = nil
      if focusedID == id { focusedID = ordered.last }
    } else {
      enable(id)
    }
  }

  func closeAll() {
    enabled.removeAll()
    floatingOffset.removeAll()
  }

  func reorderStacked(_ id: String, to index: Int) {
    guard stacked.contains(id) else { return }
    let others = stacked.filter { $0 != id }
    var open = others
    open.insert(id, at: min(max(index, 0), others.count))
    let closed = order.filter { !enabled.contains($0) }
    order = open + floating.filter { $0 != id } + closed
  }

  func detach(_ id: String, offset: CGSize? = nil) {
    guard enabled.contains(id) else { return }
    let count = floatingOffset.count
    let defaultX = side == .leading ? 230.0 : -230.0
    floatingOffset[id] =
      offset
      ?? CGSize(
        width: defaultX + CGFloat(count) * (side == .leading ? 18 : -18),
        height: 40 + CGFloat(count) * 28
      )
  }

  func restack(_ id: String) { floatingOffset[id] = nil }
  func isFloating(_ id: String) -> Bool { floatingOffset[id] != nil }

  func nearHomeEdge(_ offset: CGSize) -> Bool {
    side == .leading ? offset.width < 110 : offset.width > -110
  }

  func endDrag() {
    draggingID = nil
    dragOffset = .zero
    dropIndex = nil
    willFloat = false
  }

  static func reorderIndex(
    locationY: CGFloat,
    excluding id: String,
    stacked: [String],
    cardMidpoints: [String: CGFloat]
  ) -> Int {
    stacked.filter { $0 != id }.reduce(0) { result, candidate in
      result + ((cardMidpoints[candidate].map { locationY > $0 } ?? false) ? 1 : 0)
    }
  }
}

enum StudioSidebarArrangement {
  static func railPrecedesStack(side: StudioSidebarSide, panelsOnOuterEdge: Bool) -> Bool {
    (side == .leading) != panelsOnOuterEdge
  }
}

enum StudioSidebarMotion {
  static let stackLayer = 1.0
  static let railLayer = 2.0

  static func revealEdge(for side: StudioSidebarSide) -> Edge {
    side == .leading ? .leading : .trailing
  }

  static func panelTransition(for side: StudioSidebarSide) -> AnyTransition {
    .move(edge: revealEdge(for: side)).combined(with: .opacity)
  }
}

enum StudioFloatingPanelGeometry {
  static let leftInset: CGFloat = 72
  static let rightInset: CGFloat = 72
  static let topInset: CGFloat = 56
  static let bottomInset: CGFloat = 24
  static let minimumVisibleHeight: CGFloat = 140

  static func base(side: StudioSidebarSide, canvasSize: CGSize, panelWidth: CGFloat) -> CGSize {
    side == .leading
      ? CGSize(width: 64, height: 60)
      : CGSize(width: canvasSize.width - 64 - panelWidth, height: 60)
  }

  static func clamp(
    _ offset: CGSize,
    side: StudioSidebarSide,
    canvasSize: CGSize,
    panelWidth: CGFloat
  ) -> CGSize {
    let origin = base(side: side, canvasSize: canvasSize, panelWidth: panelWidth)
    let minimumX = leftInset - origin.width
    let maximumX = canvasSize.width - rightInset - panelWidth - origin.width
    let minimumY = topInset - origin.height
    let maximumY = canvasSize.height - bottomInset - minimumVisibleHeight - origin.height
    return CGSize(
      width: min(max(offset.width, minimumX), max(minimumX, maximumX)),
      height: min(max(offset.height, minimumY), max(minimumY, maximumY))
    )
  }
}

enum StudioWorkspaceSidebarCatalog {
  static func tabs(for workspace: StudioWorkspaceKind) -> [StudioWorkspaceSidebarTab] {
    switch workspace {
    case .assets:
      [
        tab("Characters", "person.2"), tab("Collections", "square.stack.3d.up"),
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
    case .design:
      [
        tab("Documents", "doc.on.doc"), tab("Features", "list.bullet.rectangle"),
        tab("Bodies", "cube"), tab("Mates", "link"),
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
    let production = WorkspaceRibbonCatalog.groups(for: workspace).map { group in
      StudioToolGroup(
        id: group.id,
        title: group.title,
        tools: group.tools.enumerated().map { index, tool in
          StudioToolDescriptor(
            id: "\(workspace.rawValue).\(group.id).\(tool.id)",
            title: tool.title,
            systemImage: tool.systemImage,
            help: tool.help,
            behavior: tool.action.map(StudioToolBehavior.command) ?? .unavailable,
            primary: primaryToolTitles(for: group.title).contains(tool.title)
              || (primaryToolTitles(for: group.title).isEmpty && index < 2)
          )
        },
        categoryIcon: group.systemImage
      )
    }
    return DemoWorkspaceToolCatalog.merge(
      production: production,
      incoming: DemoWorkspaceToolCatalog.groups(for: workspace)
    )
  }

  private static func primaryToolTitles(for groupTitle: String) -> Set<String> {
    switch groupTitle {
    case "Import": ["Character", "3D Model"]
    case "Manage": ["Replace", "Reveal"]
    case "Prepare": ["Units", "Validate"]
    default: []
    }
  }

  static func categories(for workspace: StudioWorkspaceKind) -> [StudioToolCategory] {
    if workspace == .design { return DemoWorkspaceToolCatalog.designCategories }
    if workspace == .nodes { return nodeCategories() }
    return groups(for: workspace).map { group in
      StudioToolCategory(id: group.id, title: group.title, groups: [group])
    }
  }

  private static func nodeCategories() -> [StudioToolCategory] {
    let nodeGroups = groups(for: .nodes)

    func category(_ id: String, _ title: String, groups titles: [String]) -> StudioToolCategory {
      StudioToolCategory(
        id: id,
        title: title,
        groups: titles.compactMap { title in
          nodeGroups.first { $0.title == title }
        }
      )
    }

    return [
      category("nodes.canvas", "Canvas", groups: ["Graph"]),
      category("nodes.authoring", "Authoring", groups: ["Flow", "Actions"]),
      category("nodes.logic", "Logic", groups: ["Program Logic", "Conditions"]),
      category("nodes.data", "Data", groups: ["I/O & Registers", "Background"]),
      category("nodes.ai", "AI + Voice", groups: ["Inputs", "Voice & AI"]),
      category("nodes.outputs", "Outputs", groups: ["Outputs"]),
    ]
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
        behavior: .arm(.addPart(kind))
      )
    }
    let mateTools = MateCreationToolKind.allCases.map { kind in
      StudioToolDescriptor(
        id: "rig.mate.\(kind.id)",
        title: kind.title,
        systemImage: kind.systemImage,
        help: kind.motionSummary,
        behavior: kind == .revolute && canCreateRevoluteJoint
          ? .arm(.createRevoluteMate) : .unavailable
      )
    }
    let relationTools = workspace.engineRelationTypes.map { relation in
      StudioToolDescriptor(
        id: "rig.relation.\(relation.kind.rawValue)",
        title: relation.label,
        systemImage: relation.kind.systemImage,
        help: "Create an engine-backed \(relation.label.lowercased()) relation.",
        behavior: .arm(.createRelation(kindID: relation.kind.rawValue))
      )
    }
    let production = [
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

    // Rig is category-driven, so the Demo catalog must be folded into the
    // live categories rather than only appearing in the flat catalog. Keep
    // production behaviors for collisions and append only the missing demo
    // concepts as an additional group in their matching category.
    let incomingByCategory = Dictionary(
      uniqueKeysWithValues: DemoWorkspaceToolCatalog.groups(for: .rig).map { group in
        let categoryTitle = group.title == "Structure" ? "Build" : group.title
        return (categoryTitle, group)
      }
    )

    return production.map { category in
      guard let incoming = incomingByCategory[category.title] else { return category }
      let existingTitles = Set(category.groups.flatMap(\.tools).map(\.title))
      let additions = incoming.tools.filter { !existingTitles.contains($0.title) }
      guard !additions.isEmpty else { return category }
      let additiveGroup = StudioToolGroup(
        id: "\(incoming.id).additive",
        title: incoming.title,
        tools: additions,
        categoryIcon: incoming.categoryIcon
      )
      return StudioToolCategory(
        id: category.id,
        title: category.title,
        groups: category.groups + [additiveGroup]
      )
    }
  }
}

@MainActor
enum WorkspaceRibbonActionDispatcher {
  static func perform(
    _ action: WorkspaceRibbonAction,
    workspace: StudioWorkspaceModel,
    importModel: () -> Void,
    importAnimaCharacter: () -> Void
  ) {
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

  static func isEnabled(
    _ action: WorkspaceRibbonAction,
    workspace: StudioWorkspaceModel
  ) -> Bool {
    switch action {
    case .importAnimaCharacter: workspace.animaCoreState != .connecting
    case .importModel: !workspace.isLoadingModelHierarchy
    case .frameSelection: workspace.canFrameSelection
    case .stopPlayback, .togglePlayback, .toggleLoop, .previousKeyframe, .nextKeyframe,
      .toggleGrid, .toggleBottomEditor:
      true
    }
  }

  static func isSelected(
    _ action: WorkspaceRibbonAction,
    workspace: StudioWorkspaceModel
  ) -> Bool {
    switch action {
    case .toggleLoop: workspace.loopsPreviewPlayback
    case .toggleGrid: workspace.showsPreviewGrid
    case .toggleBottomEditor:
      workspace.activeCenterView != .threeD
    default: false
    }
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
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }
  }
}

extension View {
  func sidebarChrome(docked: Bool, cornerRadius: CGFloat = 12) -> some View {
    modifier(SidebarChrome(docked: docked, cornerRadius: cornerRadius))
  }
}

private struct StudioStackRail: View {
  let tabs: [StudioWorkspaceSidebarTab]
  let state: StudioPanelStackState
  let docked: Bool
  var onToggle: (String) -> Void = { _ in }

  var body: some View {
    VStack(spacing: 3) {
      ForEach(tabs) { tab in
        let active = state.isEnabled(tab.id)
        Button {
          withAnimation(.easeOut(duration: 0.18)) {
            state.toggle(tab.id)
            onToggle(tab.id)
          }
        } label: {
          Image(systemName: tab.systemImage)
            .font(.system(size: 15, weight: .medium))
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

// MARK: - Tool sidebar

struct StudioToolSidebar: View {
  let workspaceKind: StudioWorkspaceKind
  var groups: [StudioToolGroup]
  var categories: [StudioToolCategory]
  let docked: Bool

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
  private var allGroups: [StudioToolGroup] {
    groups.isEmpty ? categories.flatMap(\.groups) : groups
  }
  private var usesCategoryTabs: Bool {
    density == .expanded
      && StudioToolCategoryPresentation.usesTabs(groups: groups, categories: categories)
  }
  private var activeGroups: [StudioToolGroup] {
    usesCategoryTabs ? (activeCategory?.groups ?? allGroups) : allGroups
  }

  var body: some View {
    VStack(spacing: 0) {
      if usesCategoryTabs {
        categoryStrip
      }
      toolRow
    }
    .padding(.horizontal, density == .expanded ? 18 : 7)
    .padding(.vertical, density == .expanded ? 8 : 5)
    .frame(
      maxWidth: docked || StudioToolBarSizing.fillsAvailableWidth(density) ? .infinity : nil,
      alignment: .leading
    )
    .frame(height: StudioToolBarSizing.height(for: density))
    .sidebarChrome(
      docked: docked,
      cornerRadius: StudioToolBarSizing.height(for: density) / 2
    )
  }

  private var categoryStrip: some View {
    ScrollView(.horizontal) {
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
      }
    }
    .scrollIndicators(.hidden)
    .padding(.bottom, 2)
  }

  @ViewBuilder
  private var toolRow: some View {
    if density == .expanded {
      ScrollView(.horizontal) {
        toolGroupRow
      }
      .scrollIndicators(.hidden)
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      toolGroupRow
        .fixedSize(horizontal: true, vertical: true)
    }
  }

  private var toolGroupRow: some View {
    HStack(alignment: .top, spacing: density == .expanded ? 13 : 2) {
      ForEach(Array(activeGroups.enumerated()), id: \.element.id) { index, group in
        if index > 0, density != .compact {
          Divider()
            .frame(height: density == .expanded ? 58 : 48)
            .padding(.horizontal, density == .expanded ? 2 : 5)
        }
        if density.usesVisualCategoryPalette {
          compactCategoryButton(group)
        } else if density.usesGroupedMenus {
          standardGroup(group)
        } else {
          expandedGroup(group)
        }
      }
      densityMenu
    }
  }

  private func expandedGroup(_ group: StudioToolGroup) -> some View {
    VStack(spacing: 1) {
      HStack(spacing: 2) { ForEach(group.tools) { toolButton($0) } }
      Text(group.title.uppercased())
        .font(.system(size: 8.5, weight: .semibold))
        .tracking(0.7)
        .foregroundStyle(StudioPalette.muted)
    }
  }

  private func standardGroup(_ group: StudioToolGroup) -> some View {
    return HStack(spacing: 3) {
      ForEach(group.primaryTools) { tool in
        standardToolButton(tool)
      }
      if !group.overflowTools.isEmpty {
        Menu {
          ForEach(group.overflowTools) { tool in
            Button {
              activate(tool)
            } label: {
              Label(tool.title, systemImage: tool.systemImage)
            }
            .disabled(!isEnabled(tool))
          }
        } label: {
          Image(systemName: "chevron.down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(StudioPalette.muted)
            .frame(width: 26, height: 48)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("More \(group.title.lowercased()) tools")
      }
    }
  }

  private func standardToolButton(_ tool: StudioToolDescriptor) -> some View {
    let active = state.armedTool?.id == tool.id
    let enabled = isEnabled(tool)
    return Button {
      activate(tool)
    } label: {
      VStack(spacing: 4) {
        Image(systemName: tool.systemImage)
          .font(.system(size: 19, weight: .medium))
          .frame(height: 22)
        Text(tool.title)
          .font(.system(size: 11, weight: .medium))
          .lineLimit(1)
          .foregroundStyle(active ? Color.white : Color.white.opacity(0.62))
      }
      .foregroundStyle(active ? Color.white : Color.white.opacity(0.9))
      .frame(width: 66, height: 50)
      .background(
        active ? StudioPalette.accent : Color.clear,
        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.35)
    .help(tool.help)
  }

  private func compactCategoryButton(_ group: StudioToolGroup) -> some View {
    let open = settings.isCompactGroupOpen(group.id, for: workspaceKind)
    let active = group.tools.contains { $0.id == state.armedTool?.id }
    return Button {
      settings.toggleCompactGroup(group.id, for: workspaceKind)
    } label: {
      Image(systemName: group.categoryIcon)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(open || active ? Color.white : StudioPalette.accent)
        .frame(width: 36, height: 36)
        .background(
          open || active ? StudioPalette.accent : Color.clear,
          in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(group.title)
    .popover(
      isPresented: Binding(
        get: { settings.isCompactGroupOpen(group.id, for: workspaceKind) },
        set: { presented in
          if !presented { settings.closeCompactGroup(for: workspaceKind) }
        }
      ),
      arrowEdge: .top
    ) {
      compactToolPalette(group)
    }
  }

  private func compactToolPalette(_ group: StudioToolGroup) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(group.title.uppercased())
          .font(.system(size: 9.5, weight: .semibold))
          .tracking(0.6)
          .foregroundStyle(StudioPalette.muted)
        Spacer()
        Image(systemName: group.categoryIcon)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(StudioPalette.accent)
      }
      .padding(.horizontal, 10)
      .padding(.top, 8)
      .padding(.bottom, 2)

      ForEach(group.tools) { tool in
        compactPaletteToolButton(tool)
      }
    }
    .padding(6)
    .frame(width: 210)
  }

  private func compactPaletteToolButton(_ tool: StudioToolDescriptor) -> some View {
    let active = state.armedTool?.id == tool.id
    let enabled = isEnabled(tool)
    return Button {
      settings.closeCompactGroup(for: workspaceKind)
      activate(tool)
    } label: {
      HStack(spacing: 10) {
        Image(systemName: tool.systemImage)
          .font(.system(size: 13, weight: .medium))
          .frame(width: 20)
        Text(tool.title)
          .font(.system(size: 12.5))
          .lineLimit(1)
        Spacer(minLength: 12)
        if active {
          Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
        }
      }
      .foregroundStyle(active ? StudioPalette.accent : Color.white.opacity(0.88))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        active ? StudioPalette.accent.opacity(0.10) : Color.clear,
        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.35)
    .help(tool.help)
  }

  private func toolButton(_ tool: StudioToolDescriptor) -> some View {
    let active = state.armedTool?.id == tool.id
    let compact = density == .compact
    let enabled = isEnabled(tool)
    return Button {
      activate(tool)
    } label: {
      VStack(spacing: 3) {
        Image(systemName: tool.systemImage)
          .font(.system(size: compact ? 14 : 16, weight: .medium))
        if !compact {
          Text(tool.title).font(.system(size: 9.5, weight: .medium)).lineLimit(1)
            .foregroundStyle(active ? Color.white : Color.white.opacity(0.62))
        }
      }
      .foregroundStyle(active ? Color.white : Color.white.opacity(0.9))
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

  private func isEnabled(_ tool: StudioToolDescriptor) -> Bool {
    // Tools always render bright and clickable, like the demo. A tool with no
    // wired action simply no-ops on tap (activate → arm guards on `.arm`); we
    // never grey the ribbon out.
    true
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
    state.activate(tool)
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

private struct StudioPanelSidebar<Content: View>: View {
  let tabs: [StudioWorkspaceSidebarTab]
  let state: StudioPanelStackState
  let docked: Bool
  var onToggle: (String) -> Void = { _ in }
  @ViewBuilder let content: (String) -> Content
  @State private var cardMidpoints: [String: CGFloat] = [:]

  private var panelWidth: CGFloat {
    state.side == .leading
      ? StudioSidebarSizing.workspacePanelWidth
      : StudioSidebarSizing.viewPanelWidth
  }
  private var panelsOnOuterEdge: Bool { StudioLayoutState.shared.panelsOnOuterEdge }
  private var edgePadding: Edge.Set { state.side == .leading ? .leading : .trailing }
  private var spaceName: String { "studio-sidebar-\(state.side.rawValue)" }

  var body: some View {
    if docked { dockedLayout } else { floatingLayout }
  }

  private var rail: some View {
    StudioStackRail(tabs: tabs, state: state, docked: docked, onToggle: onToggle)
  }

  private var dockedLayout: some View {
    HStack(alignment: .top, spacing: 0) {
      let railFirst = StudioSidebarArrangement.railPrecedesStack(
        side: state.side,
        panelsOnOuterEdge: panelsOnOuterEdge
      )
      if railFirst { rail }
      if !state.stacked.isEmpty {
        Divider().overlay(StudioPalette.border)
        stackColumn(docked: true)
      }
      if !railFirst {
        if !state.stacked.isEmpty { Divider().overlay(StudioPalette.border) }
        rail
      }
    }
  }

  private var floatingLayout: some View {
    GeometryReader { geo in
      // Floating panels get a bounded height so their List/content self-contains
      // and never overlaps (docked panels are bounded by their in-flow column).
      let panelMax = min(560, max(220, geo.size.height - 120))
      ZStack(alignment: state.side == .leading ? .leading : .trailing) {
        rail
          .frame(maxHeight: .infinity, alignment: .center)
          .padding(
            panelsOnOuterEdge && !state.stacked.isEmpty ? edgePadding : [],
            panelWidth + 10
          )
          // The stack reveals from beneath this fixed rail. Keeping the rail on
          // the upper layer makes its icons continuously readable and clickable
          // during both the opening and closing animation on either side.
          .zIndex(StudioSidebarMotion.railLayer)
        if !state.stacked.isEmpty {
          stackColumn(docked: false, maxContentHeight: panelMax)
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(
              panelsOnOuterEdge ? [] : edgePadding,
              StudioSidebarSizing.railWidth + 10
            )
            .transition(StudioSidebarMotion.panelTransition(for: state.side))
            .zIndex(StudioSidebarMotion.stackLayer)
        }
      }
    }
    .frame(maxHeight: .infinity)
  }

  private func stackColumn(docked: Bool, maxContentHeight: CGFloat? = nil) -> some View {
    let cards = VStack(spacing: docked ? 0 : 10) {
      ForEach(Array(state.stacked.enumerated()), id: \.element) { index, id in
        if !docked, state.draggingID != nil, !state.willFloat, state.dropIndex == index {
          dropIndicator
        }
        if docked, index > 0 { Divider().overlay(StudioPalette.border) }
        panelCard(id, docked: docked, maxContentHeight: maxContentHeight)
      }
      if !docked, state.draggingID != nil, !state.willFloat,
        state.dropIndex == state.stacked.count
      {
        dropIndicator
      }
    }
    .coordinateSpace(name: spaceName)
    .onPreferenceChange(StudioPanelCardMidpointKey.self) { cardMidpoints = $0 }

    return Group {
      if docked {
        ScrollView { cards }
          .frame(width: panelWidth, alignment: .top)
          .frame(maxHeight: .infinity)
      } else {
        cards.frame(width: panelWidth)
      }
    }
  }

  private var dropIndicator: some View {
    Capsule()
      .fill(StudioPalette.accent)
      .frame(width: panelWidth - 16, height: 3)
      .transition(.opacity)
  }

  private func panelCard(_ id: String, docked: Bool, maxContentHeight: CGFloat? = nil) -> some View {
    let lifted = state.draggingID == id
    return content(id)
      .frame(width: panelWidth)
      .frame(maxHeight: docked ? nil : maxContentHeight, alignment: .top)
      .environment(\.studioPanelSurfaceMode, docked ? .docked : .floating)
      .background {
        GeometryReader { geometry in
          Color.clear.preference(
            key: StudioPanelCardMidpointKey.self,
            value: [id: geometry.frame(in: .named(spaceName)).midY]
          )
        }
      }
      .overlay(alignment: .topLeading) {
        if !docked {
          Color.clear
            .frame(height: 32)
            .padding(.trailing, 40)
            .contentShape(Rectangle())
            .gesture(reorderGesture(id))
        }
      }
      .offset(lifted ? state.dragOffset : .zero)
      .scaleEffect(lifted ? 1.01 : 1)
      .shadow(color: .black.opacity(lifted ? 0.3 : 0), radius: lifted ? 16 : 0, y: 8)
      .opacity(lifted && state.willFloat ? 0.88 : 1)
      .zIndex(lifted ? 1 : 0)
  }

  private func reorderGesture(_ id: String) -> some Gesture {
    DragGesture(coordinateSpace: .named(spaceName))
      .onChanged { gesture in
        state.draggingID = id
        state.dragOffset = gesture.translation
        let sideways = abs(gesture.translation.width)
        state.willFloat =
          sideways > panelWidth * 0.5
          || sideways > abs(gesture.translation.height) * 1.5
        state.dropIndex =
          state.willFloat
          ? nil
          : StudioPanelStackState.reorderIndex(
            locationY: gesture.location.y,
            excluding: id,
            stacked: state.stacked,
            cardMidpoints: cardMidpoints
          )
      }
      .onEnded { _ in
        let tearOff = state.willFloat
        let translation = state.dragOffset
        let dropIndex = state.dropIndex
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          if tearOff {
            state.detach(id, offset: translation)
          } else if let dropIndex {
            state.reorderStacked(id, to: dropIndex)
          }
          state.endDrag()
        }
      }
  }
}

private struct StudioPanelCardMidpointKey: PreferenceKey {
  static let defaultValue: [String: CGFloat] = [:]

  static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
    value.merge(nextValue(), uniquingKeysWith: { _, newer in newer })
  }
}

private enum StudioShellEdge: Hashable {
  case top
  case leading
  case trailing
}

private struct StudioVisibleZoneOverlay: View {
  let insets: StudioVisibleZoneInsets

  var body: some View {
    GeometryReader { geometry in
      let rect = CGRect(
        x: insets.leading,
        y: insets.top,
        width: max(geometry.size.width - insets.leading - insets.trailing, 0),
        height: max(geometry.size.height - insets.top - insets.bottom, 0)
      )
      ZStack(alignment: .topLeading) {
        Path { path in path.addRect(rect) }
          .stroke(
            StudioPalette.sourceModel.opacity(0.86),
            style: StrokeStyle(lineWidth: 1, dash: [6, 5])
          )

        zoneLabel("VISIBLE ZONE")
          .offset(x: rect.minX + 8, y: rect.minY + 8)
        zoneLabel("TOP · TOOLS")
          .position(x: rect.midX, y: max(rect.minY - 10, 10))
        zoneLabel("BOTTOM · CENTER VIEW")
          .position(x: rect.midX, y: min(rect.maxY + 10, geometry.size.height - 10))
        zoneLabel("LEFT · WORKSPACE")
          .rotationEffect(.degrees(-90))
          .position(x: max(rect.minX - 10, 10), y: rect.midY)
        zoneLabel("RIGHT · VIEW")
          .rotationEffect(.degrees(90))
          .position(x: min(rect.maxX + 10, geometry.size.width - 10), y: rect.midY)
      }
    }
  }

  private func zoneLabel(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 8, weight: .bold, design: .monospaced))
      .tracking(0.6)
      .foregroundStyle(StudioPalette.sourceModel)
      .padding(.horizontal, 4)
      .padding(.vertical, 2)
      .background(StudioPalette.canvas.opacity(0.88), in: RoundedRectangle(cornerRadius: 3))
  }
}

struct StudioWorkspaceScaffold<Center: View, Left: View, Right: View>: View {
  let workspaceKind: StudioWorkspaceKind
  var toolGroups: [StudioToolGroup]
  var toolCategories: [StudioToolCategory]
  var centerModes: [StudioCenterViewMode]
  let centerSelection: Binding<StudioCenterViewMode>?
  let leftTabs: [StudioWorkspaceSidebarTab]
  let leftPanels: StudioPanelStackState
  var didToggleLeftPanel: (String) -> Void = { _ in }
  let performCommand: (WorkspaceRibbonAction) -> Void
  @ViewBuilder let center: Center
  @ViewBuilder let left: (String) -> Left
  @ViewBuilder let right: (StudioViewSidebarTab) -> Right

  private var layout: StudioLayoutState { .shared }
  private var tools: StudioToolState { .shared }
  private var viewPanels: StudioPanelStackState { StudioViewSidebarState.shared.panels }
  @State private var hoveredZones: Set<StudioShellEdge> = []
  @State private var hoveredSidebars: Set<StudioShellEdge> = []
  @State private var revealedEdges: Set<StudioShellEdge> = []
  @State private var hideTasks: [StudioShellEdge: Task<Void, Never>] = [:]

  private var isDocked: Bool { layout.detectedPreset == .docked }
  private var isCanvas: Bool { layout.detectedPreset == .canvas }
  private var resolvedToolDensity: StudioToolDensity {
    StudioToolDensity.resolved(
      preference: StudioToolSettings.shared.density,
      docked: isDocked
    )
  }
  private var toolOverlayInset: CGFloat {
    StudioToolBarSizing.height(for: resolvedToolDensity) + 24
  }

  var body: some View {
    GeometryReader { geometry in
      let insets = visibleZoneInsets(canvasSize: geometry.size)
      Group {
        if isDocked { dockedBody } else { floatingBody }
      }
      .environment(\.studioVisibleZoneInsets, insets)
      .animation(.spring(response: 0.24, dampingFraction: 0.9), value: insets)
      .overlay {
        ZStack(alignment: .topLeading) {
          floatingPanels(
            state: leftPanels,
            canvasSize: geometry.size,
            content: left
          )
          floatingPanels(
            state: viewPanels,
            canvasSize: geometry.size,
            content: { id in right(StudioViewSidebarTab(rawValue: id) ?? .view) }
          )
        }
      }
      .overlay(alignment: .bottom) {
        if !centerModes.isEmpty, centerSelection != nil {
          centerSwitcher
            .padding(.bottom, 14)
        }
      }
      .overlay {
        if layout.showsLayoutZones {
          StudioVisibleZoneOverlay(insets: insets)
            .allowsHitTesting(false)
        }
      }
    }
    .animation(.spring(response: 0.28, dampingFraction: 0.88), value: layout.detectedPreset)
    // Immediate tools are routed through the active workspace when this
    // scaffold becomes live. Installing here avoids the lost-event bug caused
    // by observing an armed tool after a child view already changed it.
    .onAppear(perform: installToolActionHandler)
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
      .overlay(alignment: .top) {
        reveal(edge: .top) { toolSidebar(docked: false).padding(.top, 14) }
      }
      .overlay(alignment: .top) {
        if tools.isArmed {
          StudioToolPromptBar().padding(.top, toolOverlayInset + 8)
        }
      }
      .overlay(alignment: .leading) {
        reveal(edge: .leading) {
          workspaceSidebar(docked: false)
            .padding(.leading, 14)
            .frame(maxHeight: .infinity, alignment: .center)
        }
      }
      .overlay(alignment: .trailing) {
        reveal(edge: .trailing) {
          viewSidebar(docked: false)
            .padding(.trailing, 14)
            .frame(maxHeight: .infinity, alignment: .center)
        }
      }
  }

  private func visibleZoneInsets(canvasSize: CGSize) -> StudioVisibleZoneInsets {
    StudioVisibleZoneLayout.insets(
      preset: layout.detectedPreset ?? .floating,
      toolInset: toolOverlayInset,
      hasCenterSwitcher: !centerModes.isEmpty,
      leftStackOpen: !leftPanels.stacked.isEmpty,
      rightStackOpen: !viewPanels.stacked.isEmpty,
      revealedTop: revealedEdges.contains(.top),
      revealedLeading: revealedEdges.contains(.leading),
      revealedTrailing: revealedEdges.contains(.trailing),
      canvasWidth: canvasSize.width,
      floatingPanels: floatingPanelFootprints(canvasSize: canvasSize)
    )
  }

  private func floatingPanelFootprints(canvasSize: CGSize) -> [StudioFloatingPanelFootprint] {
    guard !isDocked else { return [] }
    return [leftPanels, viewPanels].flatMap { state in
      let panelWidth =
        state.side == .leading
        ? StudioSidebarSizing.workspacePanelWidth
        : StudioSidebarSizing.viewPanelWidth
      let base = StudioFloatingPanelGeometry.base(
        side: state.side,
        canvasSize: canvasSize,
        panelWidth: panelWidth
      )
      return state.floating.map { id in
        let offset = StudioFloatingPanelGeometry.clamp(
          state.floatingOffset[id] ?? .zero,
          side: state.side,
          canvasSize: canvasSize,
          panelWidth: panelWidth
        )
        let minimumX = base.width + offset.width
        return StudioFloatingPanelFootprint(
          side: state.side,
          minimumX: minimumX,
          maximumX: minimumX + panelWidth
        )
      }
    }
  }

  @ViewBuilder private var centerSwitcher: some View {
    if let centerSelection {
      HStack(spacing: 4) {
        ForEach(centerModes) { mode in
          Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
              centerSelection.wrappedValue = mode
            }
          } label: {
            Label(mode.title, systemImage: mode.systemImage)
              .font(.system(size: 11, weight: .semibold))
              .labelStyle(.titleAndIcon)
              .padding(.horizontal, 10)
              .frame(height: 30)
              .foregroundStyle(centerSelection.wrappedValue == mode ? .white : StudioPalette.muted)
              .background(
                centerSelection.wrappedValue == mode ? StudioPalette.accent : Color.clear,
                in: Capsule()
              )
          }
          .buttonStyle(.plain)
          .help("Show \(mode.title) in the center")
          .accessibilityAddTraits(centerSelection.wrappedValue == mode ? .isSelected : [])
        }
      }
      .padding(5)
      .background(.regularMaterial, in: Capsule())
      .overlay(Capsule().stroke(StudioPalette.border, lineWidth: 1))
      .shadow(color: .black.opacity(0.28), radius: 14, y: 5)
    }
  }

  private func toolSidebar(docked: Bool) -> some View {
    StudioToolSidebar(
      workspaceKind: workspaceKind,
      groups: toolGroups,
      categories: toolCategories,
      docked: docked
    )
  }

  private func installToolActionHandler() {
    tools.actionHandler = { tool in
      guard case .command(let command) = tool.behavior else { return false }
      performCommand(command)
      return true
    }
  }

  private func workspaceSidebar(docked: Bool) -> some View {
    StudioPanelSidebar(
      tabs: leftTabs,
      state: leftPanels,
      docked: docked,
      onToggle: didToggleLeftPanel,
      content: left
    )
  }

  private func viewSidebar(docked: Bool) -> some View {
    StudioPanelSidebar(
      tabs: viewSidebarTabs,
      state: viewPanels,
      docked: docked,
      onToggle: { id in
        if let tab = StudioViewSidebarTab(rawValue: id), viewPanels.isEnabled(id) {
          StudioViewSidebarState.shared.selectedTab = tab
          StudioToolState.shared.disarm()
        }
      },
      content: { id in right(StudioViewSidebarTab(rawValue: id) ?? .view) }
    )
  }

  private var viewSidebarTabs: [StudioWorkspaceSidebarTab] {
    StudioViewSidebarTab.allCases.map {
      StudioWorkspaceSidebarTab(
        id: $0.rawValue,
        title: $0.rawValue,
        systemImage: $0.systemImage
      )
    }
  }

  @ViewBuilder
  private func floatingPanels<PanelContent: View>(
    state: StudioPanelStackState,
    canvasSize: CGSize,
    @ViewBuilder content: @escaping (String) -> PanelContent
  ) -> some View {
    let panelWidth =
      state.side == .leading
      ? StudioSidebarSizing.workspacePanelWidth
      : StudioSidebarSizing.viewPanelWidth
    ForEach(state.floating, id: \.self) { id in
      let origin = StudioFloatingPanelGeometry.base(
        side: state.side,
        canvasSize: canvasSize,
        panelWidth: panelWidth
      )
      let offset = StudioFloatingPanelGeometry.clamp(
        state.floatingOffset[id] ?? .zero,
        side: state.side,
        canvasSize: canvasSize,
        panelWidth: panelWidth
      )
      content(id)
        .frame(width: panelWidth)
        .environment(\.studioPanelSurfaceMode, .floating)
        .overlay(alignment: .topLeading) {
          Color.clear
            .frame(height: 32)
            .padding(.trailing, 40)
            .contentShape(Rectangle())
            .gesture(
              floatingMoveGesture(
                id,
                state: state,
                canvasSize: canvasSize,
                panelWidth: panelWidth
              )
            )
        }
        .offset(x: origin.width + offset.width, y: origin.height + offset.height)
        .zIndex(10)
    }
  }

  private func floatingMoveGesture(
    _ id: String,
    state: StudioPanelStackState,
    canvasSize: CGSize,
    panelWidth: CGFloat
  ) -> some Gesture {
    DragGesture(coordinateSpace: .global)
      .onChanged { gesture in
        if state.draggingID != id {
          state.draggingID = id
          state.dragOffset = state.floatingOffset[id] ?? .zero
        }
        let proposed = CGSize(
          width: state.dragOffset.width + gesture.translation.width,
          height: state.dragOffset.height + gesture.translation.height
        )
        state.floatingOffset[id] = StudioFloatingPanelGeometry.clamp(
          proposed,
          side: state.side,
          canvasSize: canvasSize,
          panelWidth: panelWidth
        )
      }
      .onEnded { _ in
        let shouldDock = state.nearHomeEdge(state.floatingOffset[id] ?? .zero)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          if shouldDock { state.restack(id) }
          state.endDrag()
        }
      }
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

struct StudioViewportSidebarBindings {
  let renderStyle: Binding<ViewportRenderStyle>
  let edgeDisplay: Binding<ViewportEdgeDisplay>
  let showsGrid: Binding<Bool>
  let showsShadows: Binding<Bool>
  let lightingIntensity: Binding<Double>
  let appearance: Binding<PreviewAppearance>
}

struct StudioViewSidebarPanel<Inspector: View>: View {
  let tab: StudioViewSidebarTab
  let viewport: StudioViewportSidebarBindings
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
            displayMode.wrappedValue = mode
          } label: {
            Image(systemName: mode.systemImage)
              .frame(width: 34, height: 30)
              .background(
                displayMode.wrappedValue == mode
                  ? StudioPalette.accent : StudioPalette.panelInset,
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
      Toggle("Grid", isOn: viewport.showsGrid)
      Toggle("Origin", isOn: Binding(get: { state.showsOrigin }, set: { state.showsOrigin = $0 }))
      Toggle("Ground shadow", isOn: viewport.showsShadows)
      Text("KEY LIGHT").studioSidebarCaption()
      Slider(value: viewport.lightingIntensity, in: 0.1...3)
    }
    .controlSize(.small)
  }

  private var appearanceControls: some View {
    Group {
      Picker(
        "Theme",
        selection: viewport.appearance
      ) {
        ForEach(PreviewAppearance.allCases) { appearance in
          Text(appearance.title).tag(appearance)
        }
      }
      .controlSize(.small)
      Toggle("Show edges", isOn: showsEdges)
      Toggle(
        "Keep imported colors",
        isOn: Binding(get: { state.keepsImportedColors }, set: { state.keepsImportedColors = $0 })
      )
      Text("OPACITY").studioSidebarCaption()
      Slider(value: Binding(get: { state.opacity }, set: { state.opacity = $0 }), in: 0.2...1)
    }
    .controlSize(.small)
  }

  private var displayMode: Binding<StudioViewportDisplayMode> {
    Binding(
      get: { StudioViewportDisplayMode.resolve(renderStyle: viewport.renderStyle.wrappedValue) },
      set: { viewport.renderStyle.wrappedValue = $0.renderStyle }
    )
  }

  private var showsEdges: Binding<Bool> {
    Binding(
      get: { viewport.edgeDisplay.wrappedValue != .hidden },
      set: { viewport.edgeDisplay.wrappedValue = $0 ? .mesh : .hidden }
    )
  }
}

extension View {
  fileprivate func studioSidebarCaption() -> some View {
    font(.system(size: 9.5, weight: .semibold))
      .tracking(0.6)
      .foregroundStyle(StudioPalette.muted)
  }
}
