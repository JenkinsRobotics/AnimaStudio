// Floating sidebar layout — ShaprUI's canvas-forward idiom brought into
// ClaudeUI. The center content spans the full width; the left and right panels
// float over it with drop shadows and can be hidden (toggles live in the top
// bar). Visibility is global so it persists across workspaces.
import SwiftUI

// Universal sidebar logic: each side can be hidden, floating (over the canvas),
// or docked (in-flow, pushing the center). The float/dock control lives on the
// sidebar itself. Shared across every workspace so behavior is identical.
@Observable final class LayoutState {
  static let shared = LayoutState()
  var showLeft = true
  var showRight = true
  var leftDocked = false
  var rightDocked = false
  var rightPinned = false   // pin overrides the selection-driven auto-hide
  var ribbonDocked = false  // tool ribbon: false = floating pill, true = legacy full ribbon
  var leftFloatOffset: CGSize = .zero   // drag position of the floating left card
  var rightFloatOffset: CGSize = .zero  // drag position of the floating right card
  var showStatusBar = true              // the bottom status/footer bar
}

// Whole-app layout presets — flip every panel + ribbon between floating / docked
// / hidden at once (the "Studio layout" toggle). Mirrors CodexUI's preset model.
enum LayoutPreset: String, CaseIterable, Identifiable {
  case floating, docked, canvas
  var id: String { rawValue }
  var label: String {
    switch self {
    case .floating: return "Floating"
    case .docked: return "Docked"
    case .canvas: return "Canvas"
    }
  }
  var icon: String {
    switch self {
    case .floating: return "macwindow.on.rectangle"
    case .docked: return "rectangle.split.3x1"
    case .canvas: return "viewfinder"
    }
  }
  var next: LayoutPreset {
    switch self {
    case .floating: return .docked
    case .docked: return .canvas
    case .canvas: return .floating
    }
  }
}

extension LayoutState {
  func apply(_ preset: LayoutPreset) {
    switch preset {
    case .floating:
      showLeft = true; showRight = true; leftDocked = false; rightDocked = false; rightPinned = true; ribbonDocked = false
    case .docked:
      showLeft = true; showRight = true; leftDocked = true; rightDocked = true; rightPinned = true; ribbonDocked = true
    case .canvas:
      showLeft = false; showRight = false; leftDocked = false; rightDocked = false; rightPinned = false; ribbonDocked = false
    }
  }

  var detectedPreset: LayoutPreset? {
    LayoutPreset.allCases.first {
      switch $0 {
      case .floating: return showLeft && showRight && !leftDocked && !rightDocked && !ribbonDocked
      case .docked: return showLeft && showRight && leftDocked && rightDocked && ribbonDocked
      case .canvas: return !showLeft && !showRight && !leftDocked && !rightDocked && !ribbonDocked && !rightPinned
      }
    }
  }

  var layoutLabel: String { detectedPreset?.label ?? "Custom" }
  func cyclePreset() { apply((detectedPreset ?? .floating).next) }
}

// Floating panels are capped cards; docked panels stay full-height. A single
// shared rule, so no per-workspace patching. (CodexUI's FloatingPanelSizing.)
enum FloatingPanelSizing {
  static func height(
    available: CGFloat, preferredFraction: CGFloat = 0.72, minimum: CGFloat = 360, margins: CGFloat = 24
  ) -> CGFloat {
    let usable = max(0, available - margins)
    let preferred = max(minimum, available * preferredFraction)
    return min(usable, preferred)
  }
}

enum SidebarSide { case left, right }

struct FloatingWorkspace<L: View, C: View, R: View>: View {
  var leftWidth: CGFloat = 250
  var rightWidth: CGFloat = 268
  var edgeToEdge: Bool = false   // true = full-bleed canvas (no border/padding)
  var rightSelected: Bool = true // right panel auto-hides when false (unless pinned/docked)
  @ViewBuilder var left: () -> L
  @ViewBuilder var center: () -> C
  @ViewBuilder var right: () -> R

  private var layout: LayoutState { LayoutState.shared }
  @State private var peekLeft = false    // hover-reveal a hidden left panel
  @State private var peekRight = false
  @State private var leftDrag: CGSize = .zero    // live drag delta while moving a card
  @State private var rightDrag: CGSize = .zero
  // The right panel is contextual: visible while something is selected, or when
  // the user pins/docks it. The left panel is a plain manual show/hide.
  private var rightShown: Bool {
    layout.showRight && (layout.rightDocked || layout.rightPinned || rightSelected)
  }

  var body: some View {
    HStack(spacing: 0) {
      if layout.showLeft && layout.leftDocked {
        docked(left(), width: leftWidth, side: .left)
        Divider().overlay(UI.stroke)
      }

      GeometryReader { geo in
        ZStack(alignment: .topLeading) {
          center()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(edgeToEdge ? 0 : 12)

          if (layout.showLeft && !layout.leftDocked) || (!layout.showLeft && peekLeft) {
            floating(left(), width: leftWidth, side: .left, peek: !layout.showLeft, available: geo.size.height)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          }
          if (rightShown && !layout.rightDocked) || (!rightShown && peekRight) {
            floating(right(), width: rightWidth, side: .right, peek: !rightShown, available: geo.size.height)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          }

          // Hidden panels reveal on a hover strip at the window edge.
          if !layout.showLeft {
            edgeReveal(.left).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          }
          if !rightShown {
            edgeReveal(.right).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
          }
        }
      }

      if layout.rightDocked {
        Divider().overlay(UI.stroke)
        docked(right(), width: rightWidth, side: .right)
      }
    }
  }

  // Docked: in the layout flow, full height, flush to the window edge.
  private func docked(_ content: some View, width: CGFloat, side: SidebarSide) -> some View {
    content
      .frame(width: width)
      .frame(maxHeight: .infinity)
  }

  // Floating: a capped card over the canvas (never full-height — that's docked).
  private func floating(_ content: some View, width: CGFloat, side: SidebarSide, peek: Bool, available: CGFloat)
    -> some View
  {
    content
      .frame(width: width)
      // Right-side content-aware widgets hug their content (compact card); left-side
      // browsers/lists stay a capped, scrollable card.
      .fixedSize(horizontal: false, vertical: side == .right)
      .frame(height: side == .right ? nil : FloatingPanelSizing.height(available: available))
      .overlay(alignment: .topTrailing) { closeButton(side) }
      .contentShape(Rectangle())
      .gesture(cardDrag(side))
      .onTapGesture(count: 2) {
        withAnimation(.spring(response: 0.3)) {
          if side == .left { layout.leftFloatOffset = .zero } else { layout.rightFloatOffset = .zero }
        }
      }
      .compositingGroup()
      .shadow(color: .black.opacity(0.28), radius: 20, x: 0, y: 10)
      .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
      .padding(.top, edgeToEdge ? 14 : 12)
      .padding(side == .left ? .leading : .trailing, edgeToEdge ? 16 : 12)
      .offset(floatOffset(side))
      .onHover { hovering in
        if peek && !hovering {
          withAnimation(.spring(response: 0.3)) {
            if side == .left { peekLeft = false } else { peekRight = false }
          }
        }
      }
      .transition(.move(edge: side == .left ? .leading : .trailing).combined(with: .opacity))
  }

  private func floatOffset(_ side: SidebarSide) -> CGSize {
    let base = side == .left ? layout.leftFloatOffset : layout.rightFloatOffset
    let live = side == .left ? leftDrag : rightDrag
    return CGSize(width: base.width + live.width, height: base.height + live.height)
  }

  // Drag the whole card. Measured in GLOBAL space so applying `.offset` mid-drag
  // doesn't shift the gesture's frame and cause the translation to jitter.
  private func cardDrag(_ side: SidebarSide) -> some Gesture {
    DragGesture(minimumDistance: 4, coordinateSpace: .global)
      .onChanged { g in if side == .left { leftDrag = g.translation } else { rightDrag = g.translation } }
      .onEnded { g in
        if side == .left {
          layout.leftFloatOffset.width += g.translation.width
          layout.leftFloatOffset.height += g.translation.height
          leftDrag = .zero
        } else {
          layout.rightFloatOffset.width += g.translation.width
          layout.rightFloatOffset.height += g.translation.height
          rightDrag = .zero
        }
      }
  }

  private func closeButton(_ side: SidebarSide) -> some View {
    Button { closePanel(side) } label: {
      Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(UI.text3)
        .frame(width: 20, height: 20)
        .background(.regularMaterial, in: Circle())
        .overlay(Circle().stroke(UI.stroke, lineWidth: 1))
    }
    .buttonStyle(.plain).padding(8).help("Close (reveals on edge hover)")
  }

  private func closePanel(_ side: SidebarSide) {
    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
      if side == .left { layout.showLeft = false; peekLeft = false }
      else { layout.showRight = false; peekRight = false }
    }
  }

  private func edgeReveal(_ side: SidebarSide) -> some View {
    Color.clear
      .frame(width: 24)
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .onHover { hovering in
        if hovering {
          withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            if side == .left { peekLeft = true } else { peekRight = true }
          }
        }
      }
  }

}

// Floating bottom-center tray (ShaprUI-style). Each icon opens a popover so
// controls that would otherwise be hidden behind the floating sidebars live
// front-and-center over the canvas instead.
struct TrayItem: Identifiable {
  let id = UUID()
  let icon: String
  let label: String
  let content: AnyView?   // nil = plain action button (e.g. Bind / Arm)

  /// Action button — taps just select it (Bind, Arm, Calibrate, Test, Home).
  init(_ icon: String, _ label: String) {
    self.icon = icon
    self.label = label
    self.content = nil
  }

  /// Widget button — taps open a popover (Display, Performance, …).
  init(_ icon: String, _ label: String, @ViewBuilder content: () -> some View) {
    self.icon = icon
    self.label = label
    self.content = AnyView(content())
  }
}

struct CenterTray: View {
  let items: [TrayItem]
  var initialAction: Int = 0
  @State private var openPopover: UUID?
  @State private var activeAction: UUID?

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        let selectedAction = activeAction ?? actionID(at: initialAction)
        let active = openPopover == item.id || (item.content == nil && selectedAction == item.id)
        Button {
          if item.content != nil {
            openPopover = (openPopover == item.id ? nil : item.id)
          } else {
            activeAction = item.id
          }
        } label: {
          VStack(spacing: 5) {
            Image(systemName: item.icon).font(.system(size: 16, weight: .medium))
            Text(item.label).font(.system(size: 10.5, weight: .medium))
          }
          .foregroundStyle(active ? UI.accent : UI.text)
          .frame(width: 70, height: 50)
          .background(active ? UI.accent.opacity(0.14) : .clear,
            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(
          isPresented: Binding(get: { openPopover == item.id }, set: { if !$0 { openPopover = nil } }),
          arrowEdge: .bottom
        ) {
          if let content = item.content { content.padding(4) }
        }
        if index < items.count - 1 {
          Divider().frame(height: 30).overlay(UI.stroke)
        }
      }
    }
    .padding(6)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(UI.stroke, lineWidth: 1))
    .shadow(color: .black.opacity(0.22), radius: 22, x: 0, y: 11)
    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
  }

  private func actionID(at index: Int) -> UUID? {
    let actions = items.filter { $0.content == nil }
    return actions.indices.contains(index) ? actions[index].id : nil
  }
}

// Radial context menu — brought over from ShaprUI. Double-click the canvas to
// summon it; tap an item or the backdrop to dismiss. Theme-aware.
struct RadialMenu: View {
  var onDismiss: () -> Void = {}
  private var items: [(String, String, Color)] {
    [
      ("Move", "move.3d", UI.text),
      ("Rotate", "rotate.3d", UI.text),
      ("Mate", "link", UI.text),
      ("Hide", "eye.slash", UI.text),
      ("Material", "paintpalette", UI.text),
      ("Delete", "trash", UI.danger),
    ]
  }

  var body: some View {
    ZStack {
      Color.black.opacity(0.001).contentShape(Rectangle()).onTapGesture { onDismiss() }
      ZStack {
        Circle().fill(.regularMaterial).frame(width: 208, height: 208)
          .overlay(Circle().stroke(UI.stroke, lineWidth: 1))
          .shadow(color: .black.opacity(0.26), radius: 26, x: 0, y: 12)
        Circle().fill(UI.panel).frame(width: 54, height: 54)
          .overlay(Circle().stroke(UI.stroke, lineWidth: 1))
          .overlay(Image(systemName: "cube.transparent").font(.system(size: 16)).foregroundStyle(UI.accent))
          .shadow(color: .black.opacity(0.12), radius: 6)
        ForEach(Array(items.enumerated()), id: \.offset) { i, it in
          let angle = Double(i) / Double(items.count) * 2 * .pi - .pi / 2
          Button { onDismiss() } label: {
            VStack(spacing: 3) {
              Image(systemName: it.1).font(.system(size: 15, weight: .medium))
              Text(it.0).font(.system(size: 9.5, weight: .medium))
            }
            .foregroundStyle(it.2)
            .frame(width: 56, height: 56)
          }
          .buttonStyle(.plain)
          .offset(x: CGFloat(cos(angle)) * 76, y: CGFloat(sin(angle)) * 76)
        }
      }
    }
  }
}
