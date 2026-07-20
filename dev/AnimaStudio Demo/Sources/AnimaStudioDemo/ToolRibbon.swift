// One modular tool toolbar, two presentations — toggled by LayoutState.ribbonDocked:
//   • floating → a compact pill: group tabs + the active group's tools (ShaprUI idiom)
//   • docked   → the full labeled ribbon (the legacy Onshape/Bottango tool ribbon)
// Same tool catalog either way; the workspace decides placement (overlay vs in-flow).
import SwiftUI

// How a category's tools are shown in the floating popup — a named list or a
// bare icon matrix. User preference, set in Settings ▸ General.
enum ToolPopupStyle: String, CaseIterable, Identifiable {
  case list = "List", grid = "Icons"
  var id: String { rawValue }
}

@Observable final class RibbonSettings {
  static let shared = RibbonSettings()
  var popupStyle: ToolPopupStyle = .list
  var density: ToolDensity = .standard
  var activeCategory = ""   // expanded tool sidebar: selected category tab
}

/// The armed tool, shared app-wide so the viewport, prompt bar, and ribbon all
/// agree on what the pointer is currently doing. One tool armed at a time.
@MainActor @Observable final class ToolState {
  static let shared = ToolState()

  private(set) var tool: RibbonTool?
  private(set) var groupName = ""
  private(set) var tint: Color = .accentColor
  /// Stays armed after a commit, so you can place several in a row (CAD idiom).
  var repeats = true

  var isArmed: Bool { tool != nil }
  var prompt: String { tool.map { "\($0.label) — click in the viewport. Esc to cancel." } ?? "" }

  func arm(_ tool: RibbonTool, in group: RibbonGroup) {
    self.tool = tool
    groupName = group.name
    tint = group.tint
  }

  func disarm() { tool = nil }

  /// Call after a tool commits; honours `repeats`.
  func committed() { if !repeats { disarm() } }
}

struct RibbonTool: Identifiable {
  let id = UUID()
  let icon: String
  let label: String
  init(_ icon: String, _ label: String) { self.icon = icon; self.label = label }
}

struct RibbonGroup: Identifiable {
  let id = UUID()
  let name: String
  let icon: String       // the category glyph shown on the floating pill
  let tint: Color
  let tools: [RibbonTool]
  init(_ name: String, _ icon: String, _ tint: Color, _ tools: [RibbonTool]) {
    self.name = name; self.icon = icon; self.tint = tint; self.tools = tools
  }
}

struct ToolRibbon: View {
  let groups: [RibbonGroup]
  @State private var openGroupID: UUID?    // floating: which category popup is open
  private var layout: LayoutState { LayoutState.shared }
  private var activeToolID: UUID? { ToolState.shared.tool?.id }

  var body: some View {
    if layout.ribbonDocked { docked } else { floating }
  }

  // MARK: - Floating (compact): a row of category icons; tap one for its tool list
  private var floating: some View {
    HStack(spacing: 2) {
      ForEach(groups) { g in categoryIcon(g) }
    }
    .padding(6)
    .background(.regularMaterial, in: Capsule())
    .overlay(Capsule().stroke(UI.stroke, lineWidth: 1))
    .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 8)
  }

  private func categoryIcon(_ g: RibbonGroup) -> some View {
    let open = openGroupID == g.id
    return Button { openGroupID = open ? nil : g.id } label: {
      Image(systemName: g.icon).font(.system(size: 16, weight: .medium))
        .foregroundStyle(open ? .white : g.tint)
        .frame(width: 36, height: 36)
        .background(open ? g.tint : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
    .buttonStyle(.plain)
    .help(g.name)
    .popover(
      isPresented: Binding(get: { openGroupID == g.id }, set: { if !$0 { openGroupID = nil } }),
      arrowEdge: .bottom
    ) { toolList(g) }
  }

  private func toolList(_ g: RibbonGroup) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(g.name.uppercased()).font(.system(size: 9.5, weight: .semibold)).tracking(0.6)
        .foregroundStyle(UI.text3).padding(.horizontal, 10).padding(.top, 9)
      if RibbonSettings.shared.popupStyle == .grid {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 6), count: 4), spacing: 6) {
          ForEach(g.tools) { t in gridTool(t, g) }
        }.padding(.horizontal, 6).padding(.bottom, 6)
      } else {
        VStack(spacing: 2) { ForEach(g.tools) { t in listRow(t, g) } }
          .padding(.horizontal, 6).padding(.bottom, 6)
      }
    }
    .frame(width: 190)
  }

  private func listRow(_ t: RibbonTool, _ g: RibbonGroup) -> some View {
    let tint = g.tint
    return Button { ToolState.shared.arm(t, in: g); openGroupID = nil } label: {
      HStack(spacing: 10) {
        Image(systemName: t.icon).font(.system(size: 13, weight: .medium)).foregroundStyle(tint).frame(width: 20)
        Text(t.label).font(.system(size: 12.5)).foregroundStyle(UI.text)
        Spacer(minLength: 16)
        if activeToolID == t.id {
          Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(tint)
        }
      }
      .padding(.horizontal, 10).padding(.vertical, 7)
      .background(activeToolID == t.id ? tint.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7))
      .contentShape(Rectangle())
    }.buttonStyle(.plain)
  }

  private func gridTool(_ t: RibbonTool, _ g: RibbonGroup) -> some View {
    let tint = g.tint
    let active = activeToolID == t.id
    return Button { ToolState.shared.arm(t, in: g); openGroupID = nil } label: {
      Image(systemName: t.icon).font(.system(size: 16, weight: .medium))
        .foregroundStyle(active ? .white : tint)
        .frame(width: 40, height: 40)
        .background(active ? tint : tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }.buttonStyle(.plain).help(t.label)
  }

  // MARK: - Docked (legacy ribbon): every group expanded with labels
  private var docked: some View {
    HStack(alignment: .top, spacing: 0) {
      ForEach(Array(groups.enumerated()), id: \.element.id) { i, g in
        VStack(alignment: .leading, spacing: 5) {
          HStack(spacing: 4) {
            ForEach(g.tools) { t in dockedTool(t, in: g) }
          }
          Text(g.name.uppercased()).font(.system(size: 9.5, weight: .semibold)).tracking(0.6)
            .foregroundStyle(UI.text3).padding(.leading, 6)
        }
        .padding(.horizontal, 14)
        if i < groups.count - 1 { Divider().frame(height: 58).overlay(UI.stroke) }
      }
      Spacer(minLength: 8)
    }
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(UI.panel.opacity(0.6))
  }

  private func dockedTool(_ t: RibbonTool, in g: RibbonGroup) -> some View {
    let tint = g.tint
    let active = activeToolID == t.id
    return Button { ToolState.shared.arm(t, in: g) } label: {
      VStack(spacing: 5) {
        Image(systemName: t.icon).font(.system(size: 19, weight: .regular)).foregroundStyle(tint)
        Text(t.label).font(.system(size: 10.5)).foregroundStyle(UI.text2)
      }
      .frame(width: 62, height: 52)
      .background(active ? tint.opacity(0.14) : .clear,
        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }.buttonStyle(.plain)
  }

}
