// The three sidebars, shared by every workspace.
//
//   TOP   → ToolSidebar       tools that act on OBJECTS
//   LEFT  → WorkspaceSidebar  what you are working ON (browser/tree/library)
//   RIGHT → ViewSidebar       how it is PRESENTED (view, environment, appearance, inspector)
//
// A sidebar never acts on the model except through the tool it arms. Both side
// sidebars follow one rule: click a different tab to switch and open it, click
// the active tab to collapse the panel.
import SwiftUI

/// Chrome for every Design surface. Floating → a translucent pill; docked → a
/// flat panel that meets its neighbours edge to edge.
struct SidebarChrome: ViewModifier {
  var docked: Bool
  var radius: CGFloat = 12

  @ViewBuilder func body(content: Content) -> some View {
    if docked {
      content.background(UI.panel)
    } else {
      content
        .background(.regularMaterial,
          in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(UI.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }
  }
}

/// Which panel the VIEW sidebar (right) is showing. Panel switches, not tools —
/// everything reachable here affects presentation, never the model.
enum ViewTab: String, CaseIterable, Identifiable {
  case view = "View", environment = "Environment"
  case appearance = "Appearance", inspector = "Inspector"

  var id: String { rawValue }
  var icon: String {
    switch self {
    case .view: return "cube"
    case .environment: return "sun.max"
    case .appearance: return "paintpalette"
    case .inspector: return "slider.horizontal.3"
    }
  }
}

/// How the mouse drives the CAMERA. Lives inside the View panel because it is a
/// navigation preference, not a sidebar destination.
enum NavMode: String, CaseIterable, Identifiable {
  case select = "Select", pan = "Pan", orbit = "Orbit", measure = "Measure"

  var id: String { rawValue }
  var icon: String {
    switch self {
    case .select: return "cursorarrow"
    case .pan: return "hand.raised"
    case .orbit: return "arrow.triangle.2.circlepath"
    case .measure: return "ruler"
    }
  }
}

enum DisplayMode: String, CaseIterable, Identifiable {
  case wireframe = "Wireframe", hiddenLine = "Hidden line", shaded = "Shaded"

  var id: String { rawValue }
  var icon: String {
    switch self {
    case .wireframe: return "cube.transparent"
    case .hiddenLine: return "cube"
    case .shaded: return "cube.fill"
    }
  }
}

/// Right-sidebar state. App-wide, so presentation settings persist as you move
/// between workspaces (a wireframe view stays wireframe when you switch tabs).
@MainActor @Observable final class ViewSidebarState {
  static let shared = ViewSidebarState()

  /// Which panels are open + where any torn-off ones float. Same shared engine
  /// the left sidebar uses. Stack-by-default (not exclusive) since View,
  /// Environment, Appearance, Inspector are parallel concerns.
  let panels = PanelStackState(
    order: ViewTab.allCases.map(\.rawValue),
    defaults: [], side: .right)

  // View
  var viewPreset = "Standard"
  var displayMode: DisplayMode = .shaded
  var showHiddenEdges = true
  var navMode: NavMode = .select
  var panSpeed = 1.0
  var invertPan = false
  var orbitSensitivity = 1.0
  var turntable = true
  var measureUnits = "mm"
  var snapToGeometry = true

  // Environment
  var showGrid = true
  var showOrigin = true
  var groundShadow = true
  var keyLight = 1.0

  // Appearance
  var themeName = "Studio Blue"
  var showEdges = true
  var keepImportedColors = true
  var opacity = 1.0
}

// MARK: - Shared panel-stack engine (both side sidebars use this)

/// One entry in a sidebar rail.
struct SidebarTab: Identifiable, Equatable {
  var id: String
  var icon: String
  init(_ id: String, _ icon: String) { self.id = id; self.icon = icon }
}

/// Which panels a sidebar has open, and where any torn-off ones float. One
/// engine drives both the left (workspace) and right (view) sidebars so their
/// behaviour is identical: a rail of tabs, each toggling its own stacked panel,
/// any panel tear-off-able to float over the canvas and dockable back.
@MainActor @Observable final class PanelStackState {
  var order: [String]
  let side: SidebarSide
  /// Exclusive = opening one panel closes the others (browser idiom). The left
  /// sidebar defaults to this; the right sidebar stacks freely.
  var exclusive: Bool
  var enabled: Set<String>
  var floatingOffset: [String: CGSize] = [:]

  // Live drag: which panel is being dragged, its follow offset, and where it
  // would land (an insertion index in the stack, or willFloat to tear off).
  var draggingID: String?
  var dragOffset: CGSize = .zero
  var dropIndex: Int?
  var willFloat = false

  init(order: [String], defaults: [String] = [], side: SidebarSide = .right,
    exclusive: Bool = false)
  {
    self.order = order
    self.side = side
    self.exclusive = exclusive
    self.enabled = Set(defaults)
  }

  /// Move a stacked panel to a new index among the currently stacked panels.
  func reorderStacked(_ id: String, to index: Int) {
    let others = stacked.filter { $0 != id }
    var open = others
    open.insert(id, at: min(max(index, 0), others.count))
    // Keep floating (in place) and closed tabs so they still work later.
    let closed = order.filter { !enabled.contains($0) }
    order = open + floating.filter { $0 != id } + closed
  }

  func endDrag() {
    draggingID = nil; dragOffset = .zero; dropIndex = nil; willFloat = false
  }

  func isEnabled(_ id: String) -> Bool { enabled.contains(id) }
  func toggle(_ id: String) {
    if enabled.contains(id) {
      enabled.remove(id); floatingOffset[id] = nil
    } else {
      if exclusive { enabled.removeAll(); floatingOffset.removeAll() }
      enabled.insert(id)
    }
  }

  var ordered: [String] { order.filter { enabled.contains($0) } }
  var isOpen: Bool { !enabled.isEmpty }

  // Tear-off.
  func isFloating(_ id: String) -> Bool { floatingOffset[id] != nil }
  func detach(_ id: String) {
    let n = floatingOffset.count
    let dx = side == .left ? 230 + CGFloat(n) * 18 : -230 - CGFloat(n) * 18
    floatingOffset[id] = CGSize(width: dx, height: 40 + CGFloat(n) * 28)
  }
  func restack(_ id: String) { floatingOffset[id] = nil }
  /// True when a floating panel has been dragged back over its home edge.
  func nearHomeEdge(_ offset: CGSize) -> Bool {
    side == .left ? offset.width < 110 : offset.width > -110
  }

  var stacked: [String] { ordered.filter { floatingOffset[$0] == nil } }
  var floating: [String] { ordered.filter { floatingOffset[$0] != nil } }
}

/// The icon rail. Every tab toggles its own panel; several can be open at once
/// (unless the state is exclusive, when opening one closes the rest).
struct StackRail: View {
  let tabs: [SidebarTab]
  var state: PanelStackState
  var docked = false

  var body: some View {
    VStack(spacing: 3) {
      ForEach(tabs) { tab in
        let active = state.isEnabled(tab.id)
        Button {
          withAnimation(.easeOut(duration: 0.18)) { state.toggle(tab.id) }
        } label: {
          Image(systemName: tab.icon).font(.system(size: 15, weight: .medium))
            .foregroundStyle(active ? .white : UI.text2)
            .frame(width: 34, height: 34)
            .background(active ? UI.accent : .clear,
              in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tab.id)
      }
    }
    .padding(5)
    .frame(maxHeight: docked ? .infinity : nil, alignment: docked ? .top : .center)
    .modifier(SidebarChrome(docked: docked))
  }
}

/// One panel card: a header (which doubles as the drag handle when floating)
/// over caller-supplied content. Used both stacked in the sidebar and floating
/// over the canvas.
struct StackCard<Content: View>: View {
  let id: String
  let title: String
  let icon: String
  var state: PanelStackState
  var docked = false
  var floating = false
  var width: CGFloat = 200
  /// The whole header is a drag handle. The parent (which knows the stack
  /// geometry) supplies the gesture; StackCard just renders + attaches it.
  var dragGesture: AnyGesture<Void>?
  /// Raised look while this card is the one being dragged.
  var lifted = false
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider().overlay(UI.stroke)
      scrollableContent
    }
    .frame(width: docked && !floating ? nil : width)
    .fixedSize(horizontal: false, vertical: true)
    .modifier(SidebarChrome(docked: docked && !floating))
    .scaleEffect(lifted ? 1.02 : 1)
    .shadow(color: .black.opacity(lifted ? 0.35 : 0), radius: lifted ? 18 : 0, y: lifted ? 10 : 0)
    .opacity(lifted && state.willFloat ? 0.9 : 1)
    .transition(.opacity.combined(with: .move(edge: state.side == .left ? .leading : .trailing)))
  }

  /// Docked panels scroll at the sidebar-column level; floating panels fit their
  /// content but scroll internally once they'd grow taller than `maxContentHeight`.
  private let maxContentHeight: CGFloat = 520
  @ViewBuilder private var scrollableContent: some View {
    if docked && !floating {
      content.padding(12)
    } else {
      ScrollView { content.padding(12) }
        .frame(maxHeight: maxContentHeight)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var header: some View {
    HStack(spacing: 6) {
      Image(systemName: icon).font(.system(size: 11)).foregroundStyle(UI.text3)
      Text(title.uppercased()).font(.system(size: 10.5, weight: .semibold))
        .tracking(0.4).foregroundStyle(UI.text)
      Spacer(minLength: 12)
      Button { withAnimation(.easeOut(duration: 0.18)) { state.toggle(id) } } label: {
        Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(UI.text3)
      }.buttonStyle(.plain).help("Hide \(title)")
    }
    .padding(.horizontal, 12).padding(.vertical, 9)
    .contentShape(Rectangle())
    .gesture(dragGesture)
  }
}

/// A full side sidebar: the rail plus the stack of open panels. `content` and
/// `title`/`icon` are looked up per tab id. Floating panels are drawn by the
/// scaffold (they must overlay the whole workspace), not here.
struct PanelSidebar<Content: View>: View {
  let tabs: [SidebarTab]
  var state: PanelStackState
  var docked = false
  @ViewBuilder var content: (String) -> Content

  @State private var cardMids: [String: CGFloat] = [:]

  /// Rail width incl. its padding — the stack sits just inboard of it.
  private let railWidth: CGFloat = 44
  private var cardWidth: CGFloat { state.side == .left ? 232 : 200 }
  /// When set, the stack sits on the OUTER edge and the rail is pushed inboard.
  private var outer: Bool { LayoutState.shared.panelsOnOuterEdge }
  private var edgeSet: Edge.Set { state.side == .left ? .leading : .trailing }

  var body: some View {
    if docked { dockedLayout } else { floatingLayout }
  }

  // Docked: rail + stack in-flow as one column. `outer` flips their order so the
  // rail ends up inboard.
  private var dockedLayout: some View {
    HStack(alignment: .top, spacing: 0) {
      let rail = StackRail(tabs: tabs, state: state, docked: true)
      let railFirst = (state.side == .left) != outer   // XOR: rail nearest the edge
      if railFirst { rail }
      if state.isOpen {
        Divider().overlay(UI.stroke)
        stackColumn(docked: true)
      }
      if !railFirst {
        if state.isOpen { Divider().overlay(UI.stroke) }
        rail
      }
    }
  }

  // Floating: the rail and the stack are INDEPENDENT elements, each vertically
  // centered to the window. The rail never moves as panels stack; the stack
  // grows about the window centre. `outer` swaps which one hugs the edge.
  private var floatingLayout: some View {
    ZStack(alignment: state.side == .left ? .leading : .trailing) {
      StackRail(tabs: tabs, state: state, docked: false)
        .frame(maxHeight: .infinity, alignment: .center)
        // Rail inboard (past the stack) when panels are on the outer edge.
        .padding(outer && state.isOpen ? edgeSet : [], cardWidth + 10)
      if state.isOpen {
        stackColumn(docked: false)
          .frame(maxHeight: .infinity, alignment: .center)
          // Stack inboard (past the rail) in the default inner arrangement.
          .padding(outer ? [] : edgeSet, railWidth + 10)
      }
    }
    .frame(maxHeight: .infinity)
  }

  private var spaceName: String { "sidebar-\(state.side == .left ? "L" : "R")" }

  private func stackColumn(docked: Bool) -> some View {
    let cards = VStack(spacing: docked ? 0 : 10) {
      ForEach(Array(state.stacked.enumerated()), id: \.element) { index, id in
        // Insertion indicator above the slot the dragged panel would land in.
        if !docked, state.draggingID != nil, !state.willFloat, state.dropIndex == index {
          dropIndicator
        }
        if docked, id != state.stacked.first { Divider().overlay(UI.stroke) }
        card(id)
      }
      if !docked, state.draggingID != nil, !state.willFloat,
        state.dropIndex == state.stacked.count {
        dropIndicator
      }
    }
    .coordinateSpace(name: spaceName)
    .onPreferenceChange(CardMidKey.self) { cardMids = $0 }
    return Group {
      if docked {
        // Fixed-width docked column — don't let it swallow the canvas.
        ScrollView { cards }.frame(width: cardWidth, alignment: .top).frame(maxHeight: .infinity)
      } else {
        // Fixed width so the stack (and the drop line) match the panel, not the
        // whole window.
        cards.frame(width: cardWidth)
      }
    }
  }

  private var dropIndicator: some View {
    Capsule().fill(UI.accent).frame(width: cardWidth - 16, height: 3)
      .transition(.opacity)
  }

  private func card(_ id: String) -> some View {
    let tab = tabs.first { $0.id == id }
    let lifted = state.draggingID == id
    return StackCard(id: id, title: id, icon: tab?.icon ?? "square",
      state: state, docked: docked, width: cardWidth,
      dragGesture: docked ? nil : AnyGesture(reorderGesture(id).map { _ in () }),
      lifted: lifted) {
      content(id)
    }
    .background(GeometryReader { geo in
      Color.clear.preference(key: CardMidKey.self,
        value: [id: geo.frame(in: .named(spaceName)).midY])
    })
    .offset(lifted ? state.dragOffset : .zero)
    .zIndex(lifted ? 1 : 0)
  }

  /// Header drag on a stacked panel: mostly vertical → reorder (drop line),
  /// pulled sideways off the stack → the panel becomes a window that follows the
  /// cursor (no line), and floats where it's dropped.
  private func reorderGesture(_ id: String) -> some Gesture {
    DragGesture(coordinateSpace: .named(spaceName))
      .onChanged { g in
        state.draggingID = id
        state.dragOffset = g.translation
        // Off the stack once dragged sideways beyond the panel edge.
        let sideways = abs(g.translation.width)
        state.willFloat = sideways > cardWidth * 0.5 || sideways > abs(g.translation.height) * 1.5
        if state.willFloat {
          state.dropIndex = nil
        } else {
          let others = state.stacked.filter { $0 != id }
          state.dropIndex = others.reduce(0) { acc, oid in
            acc + ((cardMids[oid].map { g.location.y > $0 } ?? false) ? 1 : 0)
          }
        }
      }
      .onEnded { _ in
        let tearOff = state.willFloat
        let translation = state.dragOffset
        let di = state.dropIndex
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          if tearOff {
            // Float where it was dragged to, not a fixed slot.
            state.floatingOffset[id] = translation
          } else if let di {
            state.reorderStacked(id, to: di)
          }
          state.endDrag()
        }
      }
  }
}

/// Collects each stacked card's vertical midpoint so a drag can compute where it
/// would drop.
private struct CardMidKey: PreferenceKey {
  static let defaultValue: [String: CGFloat] = [:]
  static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
    value.merge(nextValue(), uniquingKeysWith: { _, b in b })
  }
}

// MARK: - Left: workspace sidebar

/// Thin wrapper: the left sidebar over the shared engine.
struct WorkspaceSidebar<Content: View>: View {
  let tabs: [SidebarTab]
  var state: PanelStackState
  var docked = false
  @ViewBuilder var content: (String) -> Content

  var body: some View {
    PanelSidebar(tabs: tabs, state: state, docked: docked, content: content)
  }
}

// MARK: - Right: view sidebar

/// The right sidebar tabs, as a rail spec.
enum ViewSidebarSpec {
  static var tabs: [SidebarTab] { ViewTab.allCases.map { SidebarTab($0.rawValue, $0.icon) } }
}

/// Thin wrapper: the view sidebar over the shared engine. `inspector` is the
/// only per-workspace part; the rest is presentation settings.
struct ViewSidebar<Inspector: View>: View {
  var docked = false
  @ViewBuilder var inspector: Inspector

  var body: some View {
    PanelSidebar(tabs: ViewSidebarSpec.tabs,
      state: ViewSidebarState.shared.panels, docked: docked) { id in
      ViewTabContent(tab: ViewTab(rawValue: id) ?? .view) { inspector }
    }
  }
}

/// The body of one view-sidebar panel. Inspector is caller-supplied; the rest
/// are presentation settings.
struct ViewTabContent<Inspector: View>: View {
  let tab: ViewTab
  @ViewBuilder var inspector: Inspector
  private var view: ViewSidebarState { ViewSidebarState.shared }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      switch tab {
      case .view: viewSettings
      case .environment: environmentSettings
      case .appearance: appearanceSettings
      case .inspector: inspector
      }
    }
  }

  @ViewBuilder private var viewSettings: some View {
    Menu(view.viewPreset) {
      ForEach(["Standard", "Isometric", "Front", "Top", "Right"], id: \.self) { preset in
        Button(preset) { view.viewPreset = preset }
      }
    }
    .menuStyle(.borderlessButton).font(.system(size: 11.5)).fixedSize()

    Text("Display").font(.system(size: 10.5, weight: .medium)).foregroundStyle(UI.text3)
    HStack(spacing: 8) {
      ForEach(DisplayMode.allCases) { mode in
        let active = view.displayMode == mode
        Button { view.displayMode = mode } label: {
          Image(systemName: mode.icon).font(.system(size: 15, weight: .light))
            .foregroundStyle(active ? .white : UI.text2)
            .frame(width: 38, height: 32)
            .background(active ? UI.accent : UI.panelHi,
              in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }.buttonStyle(.plain).help(mode.rawValue)
      }
    }

    Toggle("Show hidden edges", isOn: Binding(
      get: { view.showHiddenEdges }, set: { view.showHiddenEdges = $0 }))
      .font(.system(size: 11.5)).toggleStyle(.switch).controlSize(.mini)

    Divider().overlay(UI.stroke)

    Text("Navigation").font(.system(size: 10.5, weight: .medium)).foregroundStyle(UI.text3)
    HStack(spacing: 6) {
      ForEach(NavMode.allCases) { mode in
        let active = view.navMode == mode
        Button {
          view.navMode = mode
          ToolState.shared.disarm()   // camera nav and object tools are exclusive
        } label: {
          Image(systemName: mode.icon).font(.system(size: 13, weight: .medium))
            .foregroundStyle(active ? .white : UI.text2)
            .frame(width: 34, height: 28)
            .background(active ? UI.accent : UI.panelHi,
              in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }.buttonStyle(.plain).help("\(mode.rawValue) (camera)")
      }
    }

    switch view.navMode {
    case .select: EmptyView()
    case .pan:
      slider("Speed", value: Binding(
        get: { view.panSpeed }, set: { view.panSpeed = $0 }), range: 0.25...3)
      Toggle("Invert direction", isOn: Binding(
        get: { view.invertPan }, set: { view.invertPan = $0 }))
        .font(.system(size: 11.5)).toggleStyle(.switch).controlSize(.mini)
    case .orbit:
      slider("Sensitivity", value: Binding(
        get: { view.orbitSensitivity }, set: { view.orbitSensitivity = $0 }),
        range: 0.25...3)
      Toggle("Turntable", isOn: Binding(
        get: { view.turntable }, set: { view.turntable = $0 }))
        .font(.system(size: 11.5)).toggleStyle(.switch).controlSize(.mini)
    case .measure:
      Picker("", selection: Binding(
        get: { view.measureUnits }, set: { view.measureUnits = $0 })) {
        ForEach(["mm", "cm", "in"], id: \.self) { Text($0).tag($0) }
      }
      .pickerStyle(.segmented).labelsHidden().controlSize(.small)
      Toggle("Snap to geometry", isOn: Binding(
        get: { view.snapToGeometry }, set: { view.snapToGeometry = $0 }))
        .font(.system(size: 11.5)).toggleStyle(.switch).controlSize(.mini)
    }
  }

  @ViewBuilder private var environmentSettings: some View {
    // Bound to RenderState — these actually drive the RealityKit viewport.
    let render = RenderState.shared
    Text("Scene").font(.system(size: 10.5, weight: .medium)).foregroundStyle(UI.text3)
    Toggle("Grid", isOn: Binding(get: { render.showGrid }, set: { render.showGrid = $0 }))
      .font(.system(size: 11.5)).toggleStyle(.switch).controlSize(.mini)
    Toggle("Origin", isOn: Binding(get: { render.showOrigin }, set: { render.showOrigin = $0 }))
      .font(.system(size: 11.5)).toggleStyle(.switch).controlSize(.mini)
    Toggle("View cube", isOn: Binding(get: { render.showViewCube }, set: { render.showViewCube = $0 }))
      .font(.system(size: 11.5)).toggleStyle(.switch).controlSize(.mini)
    Toggle("Ground shadow", isOn: Binding(
      get: { render.groundShadow }, set: { render.groundShadow = $0 }))
      .font(.system(size: 11.5)).toggleStyle(.switch).controlSize(.mini)
    slider("Key light", value: Binding(
      get: { render.keyLightScale }, set: { render.keyLightScale = $0 }), range: 0...2)
  }

  @ViewBuilder private var appearanceSettings: some View {
    Text("Theme").font(.system(size: 10.5, weight: .medium)).foregroundStyle(UI.text3)
    Menu(view.themeName) {
      ForEach(["Studio Blue", "Graphite", "Blueprint", "High Contrast"], id: \.self) { name in
        Button(name) { view.themeName = name }
      }
    }
    .menuStyle(.borderlessButton).font(.system(size: 11.5)).fixedSize()

    Toggle("Show edges", isOn: Binding(
      get: { view.showEdges }, set: { view.showEdges = $0 }))
      .font(.system(size: 11.5)).toggleStyle(.switch).controlSize(.mini)
    Toggle("Keep imported colors", isOn: Binding(
      get: { view.keepImportedColors }, set: { view.keepImportedColors = $0 }))
      .font(.system(size: 11.5)).toggleStyle(.switch).controlSize(.mini)
      .fixedSize(horizontal: false, vertical: true)
    slider("Opacity", value: Binding(
      get: { view.opacity }, set: { view.opacity = $0 }), range: 0.2...1)
  }

  private func slider(_ label: String, value: Binding<Double>,
    range: ClosedRange<Double>) -> some View
  {
    VStack(alignment: .leading, spacing: 3) {
      HStack {
        Text(label).font(.system(size: 10.5, weight: .medium)).foregroundStyle(UI.text3)
        Spacer()
        Text(String(format: "%.2f×", value.wrappedValue))
          .font(.system(size: 10)).foregroundStyle(UI.text3)
      }
      Slider(value: value, in: range).controlSize(.mini)
    }
  }
}
