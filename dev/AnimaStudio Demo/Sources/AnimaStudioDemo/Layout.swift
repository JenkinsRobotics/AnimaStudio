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
  var showStatusBar = true              // the bottom status/footer bar
  /// Panel stacks sit on the OUTER edge (rail pushed inboard) instead of the
  /// default inboard position (rail on the edge, panels toward the centre).
  var panelsOnOuterEdge = false
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


enum SidebarSide { case left, right }


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
