import CodexUICore
import SwiftUI

/// One tool catalog with two presentations: a full docked ribbon and a compact
/// floating palette. This mirrors the panel contract instead of maintaining a
/// second set of workspace tools.
struct AdaptiveRibbon: View {
  @Environment(\.prototypeTheme) private var theme
  @Bindable var model: PrototypeModel
  let workspace: UIWorkspace
  @State private var selectedGroupID: String?
  @State private var hoveredGroupID: String?
  @State private var hoveredToolID: String?

  var body: some View {
    Group {
      if model.ribbonPlacement == .floating {
        floatingRibbon
      } else if model.ribbonPlacement == .docked {
        dockedRibbon
      }
    }
    .animation(.snappy(duration: 0.22), value: model.ribbonPlacement)
  }

  private var dockedRibbon: some View {
    HStack(spacing: 0) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 0) {
          ForEach(workspace.ribbonGroups) { group in
            ribbonGroup(group)
            Rectangle().fill(theme.line).frame(width: 1, height: 68)
          }
        }
      }
      ribbonPlacementMenu
        .padding(.horizontal, 12)
    }
    .frame(height: 88)
    .background(theme.toolbar)
    .overlay(alignment: .bottom) { Rectangle().fill(theme.line).frame(height: 1) }
  }

  private func ribbonGroup(_ group: RibbonGroup) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 13) {
        ForEach(group.tools) { tool in
          toolButton(tool, tint: theme.ribbonTint(group.tint), compact: false)
        }
      }
      Text(group.title.uppercased())
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(theme.secondaryText)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
  }

  private var floatingRibbon: some View {
    HStack(spacing: 2) {
      ForEach(workspace.ribbonGroups) { group in
        let highlighted = selectedGroupID == group.id || hoveredGroupID == group.id
        let selected = selectedGroupID == group.id
        Button {
          selectedGroupID = selectedGroupID == group.id ? nil : group.id
        } label: {
          Image(systemName: group.tools.first?.systemImage ?? "square.grid.2x2")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(
              selected ? Color.white : theme.ribbonTint(group.tint)
            )
            .frame(width: 36, height: 36)
            .background(
              selected
                ? theme.ribbonTint(group.tint)
                : (highlighted ? theme.ribbonTint(group.tint).opacity(0.12) : Color.clear),
              in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
          hoveredGroupID = hovering ? group.id : nil
        }
        .popover(
          isPresented: Binding(
            get: { selectedGroupID == group.id },
            set: { if !$0 { selectedGroupID = nil } }
          ),
          arrowEdge: model.floatingRibbonEdge == .top ? .top : .bottom
        ) {
          toolPopover(group)
        }
        .help(group.title)
      }

      Rectangle().fill(theme.line).frame(width: 1, height: 28)
      ribbonPlacementMenu
        .padding(.horizontal, 5)
    }
    .padding(6)
    .background(.regularMaterial, in: Capsule())
    .overlay(Capsule().stroke(theme.line, lineWidth: 1))
    .shadow(
      color: .black.opacity(0.22), radius: 18, x: 0,
      y: model.floatingRibbonEdge == .top ? 8 : -8
    )
  }

  private func toolPopover(_ group: RibbonGroup) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(group.title).font(.system(size: 12, weight: .semibold))
        }
        Spacer()
        Image(systemName: group.tools.first?.systemImage ?? "square.grid.2x2")
          .foregroundStyle(theme.ribbonTint(group.tint))
      }

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 7)], spacing: 7) {
        ForEach(group.tools) { tool in
          toolButton(tool, tint: theme.ribbonTint(group.tint), compact: true)
        }
      }
    }
    .padding(12)
    .frame(width: min(CGFloat(group.tools.count) * 82 + 32, 390))
  }

  private func toolButton(_ tool: RibbonTool, tint: Color, compact: Bool) -> some View {
    let highlighted = hoveredToolID == tool.id
    return Button {
    } label: {
      VStack(spacing: 5) {
        Image(systemName: tool.systemImage)
          .font(.system(size: compact ? 18 : 19, weight: .medium))
          .frame(height: 22)
        Text(tool.title)
          .font(.system(size: compact ? 9 : 8.5, weight: .medium))
          .lineLimit(1)
      }
      .frame(minWidth: compact ? 68 : 45, minHeight: compact ? 54 : 42)
      .foregroundStyle(tool.enabled ? tint : theme.secondaryText.opacity(0.4))
      .background(
        highlighted ? tint.opacity(0.15) : Color.clear,
        in: RoundedRectangle(cornerRadius: 7)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 7)
          .stroke(highlighted ? tint.opacity(0.5) : Color.clear, lineWidth: 1)
      )
      .scaleEffect(highlighted ? 1.025 : 1)
    }
    .buttonStyle(.plain)
    .disabled(!tool.enabled)
    .onHover { hovering in
      guard tool.enabled else { return }
      hoveredToolID = hovering ? tool.id : nil
    }
    .animation(.easeOut(duration: 0.12), value: highlighted)
  }

  private var ribbonPlacementMenu: some View {
    Menu {
      Button("Dock Tool Ribbon", systemImage: "rectangle.tophalf.inset.filled") {
        model.ribbonPlacement = .docked
      }
      Button("Float at Top", systemImage: "rectangle.tophalf.inset.filled") {
        model.floatingRibbonEdge = .top
        model.ribbonPlacement = .floating
      }
      Button("Float at Bottom", systemImage: "rectangle.bottomhalf.inset.filled") {
        model.floatingRibbonEdge = .bottom
        model.ribbonPlacement = .floating
      }
      Divider()
      Button("Hide Tool Ribbon", systemImage: "eye.slash") {
        model.ribbonPlacement = .hidden
      }
    } label: {
      Image(
        systemName: model.ribbonPlacement == .docked
          ? "macwindow"
          : (model.floatingRibbonEdge == .top
            ? "rectangle.tophalf.inset.filled" : "rectangle.bottomhalf.inset.filled")
      )
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(theme.iconText)
      .frame(width: 28, height: 28)
      .background(theme.controlFill, in: RoundedRectangle(cornerRadius: 7))
      .overlay(RoundedRectangle(cornerRadius: 7).stroke(theme.line))
      .contentShape(Rectangle())
    } primaryAction: {
      model.cycleRibbonDocking()
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .help(
      model.ribbonPlacement == .docked
        ? "Click to float at \(model.floatingRibbonEdge.label.lowercased()) · open menu for all states"
        : "Click to dock · open menu for top, bottom, and hidden states"
    )
  }
}
