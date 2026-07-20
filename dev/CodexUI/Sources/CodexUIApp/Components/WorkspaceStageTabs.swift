import CodexUICore
import SwiftUI

/// The app's single workspace navigator, adapted from the AnimaStudio Demo
/// shell. A divider distinguishes the primary authoring path from utilities
/// without duplicating workspace selection elsewhere in the header.
struct WorkspaceStageTabs: View {
  @Environment(\.prototypeTheme) private var theme
  @Bindable var model: PrototypeModel
  let compact: Bool
  @Namespace private var activeTab
  @State private var hoveredWorkspace: UIWorkspace?

  var body: some View {
    HStack(spacing: 2) {
      ForEach(UIWorkspace.centeredNavigation) { workspace in
        if workspace == UIWorkspace.utilityWorkspaces.first {
          Rectangle()
            .fill(theme.line)
            .frame(width: 1, height: 22)
            .padding(.horizontal, 3)
        }
        tab(workspace)
      }
    }
    .padding(CGFloat(WorkspaceHeaderMetrics.capsuleInset))
    .background(theme.raised, in: Capsule())
    .overlay(Capsule().stroke(theme.line, lineWidth: 1))
    .shadow(color: .black.opacity(0.10), radius: 4, y: 1)
    .animation(.spring(response: 0.30, dampingFraction: 0.86), value: model.workspace)
  }

  private func tab(_ workspace: UIWorkspace) -> some View {
    let isActive = model.workspace == workspace
    let isHovered = hoveredWorkspace == workspace
    let showsLabel = model.workspaceTabLabelMode.showsLabel(
      isSelected: isActive, compact: compact)

    return Button {
      model.selectWorkspace(workspace)
    } label: {
      HStack(spacing: 6) {
        Image(systemName: workspace.systemImage)
          .font(.system(size: compact ? 11 : 12, weight: .semibold))
        if showsLabel {
          Text(workspace.name)
            .font(.system(size: compact ? 10.5 : 12, weight: .semibold))
        }
      }
      .foregroundStyle(isActive ? Color.white : theme.iconText)
      .padding(.horizontal, compact ? (showsLabel ? 10 : 8) : 13)
      .frame(
        height: CGFloat(
          compact
            ? WorkspaceHeaderMetrics.compactStageChipHeight
            : WorkspaceHeaderMetrics.stageChipHeight)
      )
      .background {
        if isActive {
          Capsule()
            .fill(theme.accent)
            .matchedGeometryEffect(id: "active-workspace", in: activeTab)
        } else if isHovered {
          Capsule().fill(theme.controlHover)
        }
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      hoveredWorkspace = hovering ? workspace : nil
    }
    .help("\(workspace.name) — \(workspace.purpose)")
    .accessibilityLabel("\(workspace.name) workspace")
    .accessibilityAddTraits(isActive ? .isSelected : [])
  }
}
