// The shared workspace shell: the top tool sidebar, the float/dock/canvas body,
// and the canvas-mode edge reveal. Every workspace is the same three sidebars
// (tools on top, workspace on the left, view on the right) over a center; only
// the catalog and content differ. This file owns that frame so no workspace
// re-implements it.
import SwiftUI

// MARK: - Tool sidebar

/// How much of the tool sidebar is shown. A workspace's tool count can grow a
/// lot, so density is the user's lever: icons only when they know the palette,
/// grouped labels when they are learning it.
enum ToolDensity: String, CaseIterable, Identifiable {
  case compact = "Compact", standard = "Standard", expanded = "Expanded"

  var id: String { rawValue }
  var detail: String {
    switch self {
    case .compact: return "Icons only"
    case .standard: return "Icons and labels"
    case .expanded: return "Grouped, with headings"
    }
  }
  var icon: String {
    switch self {
    case .compact: return "square.grid.3x3"
    case .standard: return "rectangle.grid.1x2"
    case .expanded: return "square.grid.2x2"
    }
  }
}

/// A named run of related tools. Shown as a heading only at `.expanded`; at the
/// tighter densities a group is just a divider.
struct ToolGroup: Identifiable {
  let id = UUID()
  let name: String
  let tools: [RibbonTool]
  private let explicitIcon: String?
  init(_ name: String, _ tools: [RibbonTool]) {
    self.name = name; self.tools = tools; self.explicitIcon = nil
  }
  init(_ name: String, icon: String, _ tools: [RibbonTool]) {
    self.name = name; self.tools = tools; self.explicitIcon = icon
  }
  /// The category glyph shown at Compact density.
  var categoryIcon: String { explicitIcon ?? tools.first?.icon ?? "square.grid.2x2" }
  var primaryTools: [RibbonTool] { tools.filter(\.primary) }
  var overflowTools: [RibbonTool] { tools.filter { !$0.primary } }
}

/// A top-level tool category (Design · Sketch · Surface · Sheet Metal …). A
/// workspace with a large tool count splits it into categories, each holding
/// its own groups. The expanded tool sidebar shows these as tabs, Fusion-style.
struct ToolCategory: Identifiable {
  let id = UUID()
  let name: String
  let groups: [ToolGroup]
  init(_ name: String, _ groups: [ToolGroup]) { self.name = name; self.groups = groups }
}

/// The top sidebar, driven by a per-workspace catalog. Tools arm through
/// ToolState, so the arm → prompt → commit lifecycle is identical everywhere.
struct ToolSidebar: View {
  var groups: [ToolGroup] = []
  /// Optional category layer. When present the expanded bar shows category tabs
  /// and the active category's groups; compact/standard show the active
  /// category's tools inline. Empty → the flat `groups` are used directly.
  var categories: [ToolCategory] = []
  var overflow: [RibbonTool] = []
  /// The group tools arm into — carries the tint shown in the prompt bar.
  var armGroup = RibbonGroup("Tools", "wrench", .accentColor, [])
  var docked = false

  private var tools: ToolState { ToolState.shared }
  private var settings: RibbonSettings { RibbonSettings.shared }
  @State private var showOverflow = false

  /// Docked is the full legacy ribbon, so it always shows the expanded, grouped
  /// list regardless of the floating-mode density preference.
  private var density: ToolDensity { docked ? .expanded : settings.density }

  private var hasCategories: Bool { !categories.isEmpty }

  /// The category currently shown (first one until the user picks another).
  private var activeCategory: ToolCategory? {
    categories.first { $0.name == settings.activeCategory } ?? categories.first
  }

  /// The groups the icon row / expanded bar draws right now.
  private var activeGroups: [ToolGroup] { activeCategory?.groups ?? groups }

  @State private var openGroup: UUID?

  var body: some View {
    switch density {
    case .compact: compactRow
    case .standard: standardRow
    case .expanded: hasCategories ? AnyView(categoryRibbon) : AnyView(expandedRow)
    }
  }

  // MARK: Compact — one icon per category; its tools live in a popover.
  private var compactRow: some View {
    HStack(spacing: 2) {
      ForEach(activeGroups) { group in categoryIcon(group) }
      Divider().frame(height: 30).overlay(UI.stroke)
      settingsMenu
    }
    .padding(.horizontal, 8).padding(.vertical, 3)
    .modifier(SidebarChrome(docked: docked, radius: 14))
    .frame(maxWidth: docked ? .infinity : nil, alignment: .leading)
  }

  private func categoryIcon(_ group: ToolGroup) -> some View {
    let open = openGroup == group.id
    let active = group.tools.contains { $0.id == tools.tool?.id }
    return Button { openGroup = open ? nil : group.id } label: {
      Image(systemName: group.categoryIcon).font(.system(size: 16, weight: .medium))
        .foregroundStyle(open || active ? UI.accent : UI.text)
        .frame(width: 36, height: 36)
        .background(open || active ? UI.accent.opacity(0.14) : .clear,
          in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
    .buttonStyle(.plain).help(group.name)
    .popover(isPresented: Binding(
      get: { openGroup == group.id }, set: { if !$0 { openGroup = nil } }),
      arrowEdge: .bottom) { toolPopover(group) }
  }

  /// A category's tools as a labelled list — used by Compact + Standard overflow.
  private func toolPopover(_ group: ToolGroup, tools list: [RibbonTool]? = nil) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(group.name.uppercased()).font(.system(size: 9.5, weight: .semibold)).tracking(0.6)
        .foregroundStyle(UI.text3).padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 2)
      ForEach(list ?? group.tools) { tool in
        let active = tools.tool?.id == tool.id
        Button { arm(tool); openGroup = nil } label: {
          HStack(spacing: 10) {
            Image(systemName: tool.icon).font(.system(size: 13)).frame(width: 20)
              .foregroundStyle(active ? UI.accent : UI.text2)
            Text(tool.label).font(.system(size: 12.5)).foregroundStyle(UI.text)
            Spacer(minLength: 16)
            if active {
              Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                .foregroundStyle(UI.accent)
            }
          }
          .padding(.horizontal, 10).padding(.vertical, 6)
          .background(active ? UI.accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 7))
          .contentShape(Rectangle())
        }.buttonStyle(.plain)
      }
    }
    .padding(6).frame(width: 190)
  }

  // MARK: Standard — key (primary) tools inline; the rest in a per-group overflow.
  private var standardRow: some View {
    HStack(spacing: 2) {
      ForEach(Array(activeGroups.enumerated()), id: \.element.id) { index, group in
        HStack(spacing: 2) {
          ForEach(group.primaryTools) { button($0) }
          if !group.overflowTools.isEmpty { overflowButton(group) }
        }
        if index < activeGroups.count - 1 {
          Divider().frame(height: 30).overlay(UI.stroke)
        }
      }
      Divider().frame(height: 30).overlay(UI.stroke)
      settingsMenu
    }
    .padding(.horizontal, 8).padding(.vertical, 4)
    .modifier(SidebarChrome(docked: docked, radius: 14))
    .frame(maxWidth: docked ? .infinity : nil, alignment: .leading)
  }

  private func overflowButton(_ group: ToolGroup) -> some View {
    Button { openGroup = openGroup == group.id ? nil : group.id } label: {
      Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
        .foregroundStyle(UI.text3).frame(width: 22, height: 52)
    }
    .buttonStyle(.plain).help("More \(group.name.lowercased())")
    .popover(isPresented: Binding(
      get: { openGroup == group.id }, set: { if !$0 { openGroup = nil } }),
      arrowEdge: .bottom) { toolPopover(group, tools: group.overflowTools) }
  }

  // MARK: Expanded (no categories) — every tool, grouped with captions.
  private var expandedRow: some View {
    HStack(spacing: 2) {
      ForEach(Array(activeGroups.enumerated()), id: \.element.id) { index, group in
        expandedGroup(group)
        if index < activeGroups.count - 1 {
          Divider().frame(height: 46).overlay(UI.stroke)
        }
      }
      Divider().frame(height: 46).overlay(UI.stroke)
      settingsMenu
    }
    .padding(.horizontal, 8).padding(.vertical, 4)
    .modifier(SidebarChrome(docked: docked, radius: 14))
    .frame(maxWidth: docked ? .infinity : nil, alignment: .leading)
  }

  // MARK: Expanded with categories — Fusion ribbon: a thin category-tab strip
  // over a tool row whose groups are captioned underneath.
  private var categoryRibbon: some View {
    VStack(spacing: 0) {
      // Thin tab strip.
      HStack(spacing: 2) {
        ForEach(categories) { category in
          let active = activeCategory?.id == category.id
          Button {
            withAnimation(.easeOut(duration: 0.15)) { settings.activeCategory = category.name }
          } label: {
            Text(category.name.uppercased())
              .font(.system(size: 10, weight: .medium)).tracking(0.2)
              .foregroundStyle(active ? UI.accent : UI.text3)
              .padding(.horizontal, 9).padding(.vertical, 3)
              .background(active ? UI.accent.opacity(0.14) : .clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
          }.buttonStyle(.plain)
        }
        // Only stretch to fill in docked mode; floating hugs its content.
        if docked { Spacer(minLength: 8) }
      }
      .padding(.horizontal, 8).padding(.top, 5).padding(.bottom, 3)

      // Tool row: each group's tools with its name captioned beneath.
      HStack(alignment: .top, spacing: 14) {
        ForEach(activeGroups) { group in expandedGroup(group) }
        if docked { Spacer(minLength: 8) }
        settingsMenu
      }
      .padding(.horizontal, 10).padding(.top, 5).padding(.bottom, 3)
    }
    .modifier(SidebarChrome(docked: docked, radius: 14))
    .frame(maxWidth: docked ? .infinity : nil, alignment: .leading)
  }

  /// Expanded adds the group heading beneath its tools, Fusion-style.
  private func expandedGroup(_ group: ToolGroup) -> some View {
    VStack(spacing: 1) {
      HStack(spacing: 2) { ForEach(group.tools) { button($0) } }
      Text(group.name.uppercased())
        .font(.system(size: 8.5, weight: .semibold)).tracking(0.7)
        .foregroundStyle(UI.text3)
    }
  }

  private func button(_ tool: RibbonTool) -> some View {
    let active = tools.tool?.id == tool.id
    let compact = density == .compact
    return Button { arm(tool) } label: {
      VStack(spacing: 4) {
        Image(systemName: tool.icon)
          .font(.system(size: compact ? 15 : 17, weight: .light))
          .foregroundStyle(active ? UI.accent : UI.text)
        if !compact {
          Text(tool.label).font(.system(size: 10))
            .foregroundStyle(active ? UI.accent : UI.text2)
        }
      }
      .frame(width: compact ? 34 : 58, height: compact ? 34 : 52)
      .background(active ? UI.accent.opacity(0.12) : .clear,
        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
    .buttonStyle(.plain)
    .help(tool.label)
  }

  /// The ··· button — overflow tools plus the sidebar's own density settings.
  private var settingsMenu: some View {
    Button { showOverflow.toggle() } label: {
      Image(systemName: "ellipsis").font(.system(size: 14, weight: .medium))
        .foregroundStyle(UI.text2)
        .frame(width: 30, height: density == .compact ? 34 : 52)
    }
    .buttonStyle(.plain)
    .help("More tools and toolbar settings")
    .popover(isPresented: $showOverflow, arrowEdge: .bottom) {
      VStack(alignment: .leading, spacing: 2) {
        if !overflow.isEmpty {
          caption("MORE TOOLS")
          ForEach(overflow) { tool in
            Button { arm(tool); showOverflow = false } label: {
              HStack(spacing: 10) {
                Image(systemName: tool.icon).font(.system(size: 13)).frame(width: 20)
                  .foregroundStyle(UI.accent)
                Text(tool.label).font(.system(size: 12.5)).foregroundStyle(UI.text)
                Spacer(minLength: 12)
              }
              .padding(.horizontal, 10).padding(.vertical, 6).contentShape(Rectangle())
            }.buttonStyle(.plain)
          }
          Divider().overlay(UI.stroke).padding(.vertical, 4)
        }
        caption("DENSITY")
        ForEach(ToolDensity.allCases) { d in
          Button { withAnimation(.easeOut(duration: 0.18)) { settings.density = d } } label: {
            HStack(spacing: 10) {
              Image(systemName: d.icon).font(.system(size: 12)).frame(width: 20)
                .foregroundStyle(settings.density == d ? UI.accent : UI.text3)
              VStack(alignment: .leading, spacing: 1) {
                Text(d.rawValue).font(.system(size: 12.5)).foregroundStyle(UI.text)
                Text(d.detail).font(.system(size: 10)).foregroundStyle(UI.text3)
              }
              Spacer(minLength: 12)
              if settings.density == d {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                  .foregroundStyle(UI.accent)
              }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(settings.density == d ? UI.accent.opacity(0.10) : .clear,
              in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
          }.buttonStyle(.plain)
        }
      }
      .padding(6).frame(width: 232)
    }
  }

  private func caption(_ text: String) -> some View {
    Text(text).font(.system(size: 9.5, weight: .semibold)).tracking(0.6)
      .foregroundStyle(UI.text3).padding(.horizontal, 10).padding(.top, 5)
  }

  private func arm(_ tool: RibbonTool) {
    withAnimation(.easeOut(duration: 0.16)) { tools.arm(tool, in: armGroup) }
  }
}

// MARK: - Scaffold

/// The whole workspace frame: tool sidebar on top, workspace sidebar on the
/// left, view sidebar on the right, a caller-supplied center between them, and
/// the float / dock / canvas presets wired to the Studio layout button.
///
/// A workspace supplies its catalog and content; the frame is identical for all.
struct WorkspaceScaffold<Center: View, Left: View, Inspector: View>: View {
  var toolGroups: [ToolGroup] = []
  var toolCategories: [ToolCategory] = []
  var toolOverflow: [RibbonTool] = []
  var toolArmGroup = RibbonGroup("Tools", "wrench", .accentColor, [])
  let leftTabs: [SidebarTab]
  var leftPanels: PanelStackState
  @ViewBuilder var center: Center
  @ViewBuilder var left: (String) -> Left
  @ViewBuilder var inspector: Inspector

  private var tools: ToolState { ToolState.shared }
  private var layout: LayoutState { LayoutState.shared }
  @State private var hoverTop = false
  @State private var hoverLeft = false
  @State private var hoverRight = false

  /// Canvas is the third Studio-layout preset: same floating look, but the
  /// sidebars start hidden and the center gets the whole window.
  private var isCanvas: Bool { layout.detectedPreset == .canvas }
  /// Floating sidebars always keep their margin off the window edge.
  private let edgePad: CGFloat = 14

  private var viewPanels: PanelStackState { ViewSidebarState.shared.panels }

  var body: some View {
    Group {
      if layout.ribbonDocked { dockedBody } else { floatingBody }
    }
    // Torn-off panels float over the workspace but stay inside the visible
    // canvas — they can't cover the sidebars or leave the center.
    .overlay {
      GeometryReader { geo in
        ZStack(alignment: .topLeading) {
          floatingCards(leftPanels, tabs: leftTabs, size: geo.size) { id in left(id) }
          floatingCards(viewPanels, tabs: ViewSidebarSpec.tabs, size: geo.size) { id in
            ViewTabContent(tab: ViewTab(rawValue: id) ?? .view) { inspector }
          }
        }
      }
    }
  }

  // The center region a floating panel may occupy — reserves the sidebar rails,
  // the tool sidebar on top, and the status strip below.
  private let floatInset = (left: 72.0, right: 72.0, top: 56.0, bottom: 24.0, minH: 140.0)

  /// Where a card of `state.side` sits before its user offset (top-left origin).
  private func floatBase(_ side: SidebarSide, size: CGSize, cardW: CGFloat) -> CGSize {
    side == .left
      ? CGSize(width: 64, height: 60)
      : CGSize(width: size.width - 64 - cardW, height: 60)
  }

  /// Clamp the user offset so the card stays fully inside the center region.
  private func floatClamp(_ off: CGSize, side: SidebarSide, size: CGSize, cardW: CGFloat) -> CGSize {
    let base = floatBase(side, size: size, cardW: cardW)
    let minW = floatInset.left - base.width
    let maxW = size.width - floatInset.right - cardW - base.width
    let minH = floatInset.top - base.height
    let maxH = size.height - floatInset.bottom - floatInset.minH - base.height
    return CGSize(
      width: min(max(off.width, minW), max(minW, maxW)),
      height: min(max(off.height, minH), max(minH, maxH)))
  }

  @ViewBuilder private func floatingCards<C: View>(
    _ state: PanelStackState, tabs: [SidebarTab], size: CGSize,
    @ViewBuilder content: @escaping (String) -> C) -> some View
  {
    let cardW: CGFloat = state.side == .left ? 232 : 200
    ForEach(state.floating, id: \.self) { id in
      let tab = tabs.first { $0.id == id }
      let base = floatBase(state.side, size: size, cardW: cardW)
      let off = floatClamp(state.floatingOffset[id] ?? .zero, side: state.side, size: size, cardW: cardW)
      StackCard(id: id, title: id, icon: tab?.icon ?? "square",
        state: state, floating: true, width: cardW,
        dragGesture: AnyGesture(floatMoveGesture(id, state: state, size: size, cardW: cardW).map { _ in () })) {
        content(id)
      }
      .offset(x: base.width + off.width, y: base.height + off.height)
    }
  }

  /// Drag a floating panel; releasing near its home edge docks it back.
  private func floatMoveGesture(_ id: String, state: PanelStackState, size: CGSize,
    cardW: CGFloat) -> some Gesture
  {
    DragGesture(coordinateSpace: .global)
      .onChanged { g in
        // dragOffset holds the panel's offset at gesture start.
        if state.draggingID != id {
          state.draggingID = id
          state.dragOffset = state.floatingOffset[id] ?? .zero
        }
        let proposed = CGSize(
          width: state.dragOffset.width + g.translation.width,
          height: state.dragOffset.height + g.translation.height)
        state.floatingOffset[id] = floatClamp(proposed, side: state.side, size: size, cardW: cardW)
      }
      .onEnded { _ in
        let docks = state.nearHomeEdge(state.floatingOffset[id] ?? .zero)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          if docks { state.restack(id) }
          state.endDrag()
        }
      }
  }

  // Overlays (not ZStack layers) so each surface only hit-tests its own bounds.
  private var floatingBody: some View {
    center
      .overlay(alignment: .top) {
        edgeReveal(.top, shown: $hoverTop) { toolSidebar(docked: false).padding(.top, 14) }
      }
      .overlay(alignment: .top) { if tools.isArmed { PromptBar() } }
      .overlay(alignment: .leading) {
        edgeReveal(.leading, shown: $hoverLeft) {
          workspaceSidebar(docked: false).padding(.leading, edgePad)
        }
      }
      .overlay(alignment: .trailing) {
        edgeReveal(.trailing, shown: $hoverRight) {
          ViewSidebar { inspector }.padding(.trailing, edgePad)
        }
      }
  }

  // Docked: side sidebars span the FULL height; the tool bar lives at the top of
  // the centre column (with the viewport/timeline below it), so the sidebars
  // aren't shortened by a full-width toolbar.
  private var dockedBody: some View {
    HStack(spacing: 0) {
      workspaceSidebar(docked: true)
      Divider().overlay(UI.stroke)
      VStack(spacing: 0) {
        toolSidebar(docked: true)
        Divider().overlay(UI.stroke)
        center
          .overlay(alignment: .top) { if tools.isArmed { PromptBar() } }
      }
      Divider().overlay(UI.stroke)
      ViewSidebar(docked: true) { inspector }
    }
  }

  private func toolSidebar(docked: Bool) -> some View {
    ToolSidebar(groups: toolGroups, categories: toolCategories,
      overflow: toolOverflow, armGroup: toolArmGroup, docked: docked)
  }

  private func workspaceSidebar(docked: Bool) -> some View {
    WorkspaceSidebar(tabs: leftTabs, state: leftPanels, docked: docked) { tab in left(tab) }
  }

  // MARK: Canvas-mode edge reveal

  /// In floating/docked the surface is always shown. In canvas mode it is hidden
  /// behind a thin hot-zone on `edge`; hovering the zone (or the revealed
  /// surface) shows it, moving away hides it again. A plain capsule handle marks
  /// the hover target while hidden.
  @ViewBuilder private func edgeReveal<Content: View>(
    _ edge: Edge, shown: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View
  {
    if !isCanvas {
      content()
    } else {
      ZStack(alignment: alignment(for: edge)) {
        Color.clear
          .frame(width: edge == .leading || edge == .trailing ? 16 : nil,
            height: edge == .top ? 16 : nil)
          .frame(maxWidth: edge == .top ? .infinity : nil,
            maxHeight: edge == .top ? nil : .infinity)
          .contentShape(Rectangle())
          .onHover { if $0 { withAnimation(.easeOut(duration: 0.16)) { shown.wrappedValue = true } } }

        if shown.wrappedValue {
          content()
            .onHover { over in withAnimation(.easeOut(duration: 0.16)) { shown.wrappedValue = over } }
            .transition(.move(edge: edge).combined(with: .opacity))
        } else {
          edgeHandle(edge, shown: shown).transition(.opacity)
        }
      }
    }
  }

  private func alignment(for edge: Edge) -> Alignment {
    switch edge {
    case .top: return .top
    case .leading: return .leading
    case .trailing: return .trailing
    case .bottom: return .bottom
    }
  }

  /// A plain capsule grab-handle hugging the edge — no icon, just the bar.
  @ViewBuilder private func edgeHandle(_ edge: Edge, shown: Binding<Bool>) -> some View {
    let horizontal = edge == .top
    Capsule()
      .fill(UI.text3.opacity(0.5))
      .frame(width: horizontal ? 34 : 4, height: horizontal ? 4 : 34)
      .padding(horizontal ? .top : (edge == .leading ? .leading : .trailing), 5)
      .contentShape(Rectangle().inset(by: -8))
      .onHover { if $0 { withAnimation(.easeOut(duration: 0.16)) { shown.wrappedValue = true } } }
  }
}

/// The armed-tool banner, shared by every workspace's scaffold.
struct PromptBar: View {
  private var tools: ToolState { ToolState.shared }

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: tools.tool?.icon ?? "cursorarrow")
        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(tools.tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
      Text(tools.prompt).font(.system(size: 11.5)).foregroundStyle(UI.text)
      Button { tools.disarm() } label: {
        Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(UI.text3)
      }.buttonStyle(.plain)
    }
    .padding(.horizontal, 12).padding(.vertical, 8)
    .background(.regularMaterial, in: Capsule())
    .overlay(Capsule().stroke(tools.tint.opacity(0.55), lineWidth: 1))
    .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    .padding(.top, 104)
    .frame(maxWidth: .infinity, alignment: .center)
    .transition(.move(edge: .top).combined(with: .opacity))
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tools.tool?.id)
  }
}
