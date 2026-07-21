import SwiftUI

enum WorkspaceSelectorMetrics {
  static let minimumWidth: CGFloat = 300
  static let idealWidth: CGFloat = 350
  static let maximumWidth: CGFloat = 430
  static let menuWidth: CGFloat = 280
  static let compactWidth: CGFloat = 1_420
  static let chipHeight: CGFloat = 30
  static let compactChipHeight: CGFloat = 28
}

/// The production app's single workspace navigator.
///
/// It replaces the old left-hand workspace dropdown with the accepted
/// CodexUI centered stage strip. The authoring path stays readable as a flow;
/// Nodes and UI Dev remain adjacent utilities rather than a second navigator.
struct WorkspaceStageTabs: View {
  @Bindable var workspace: StudioWorkspaceModel
  @Binding var isUIDevWorkspace: Bool
  let compact: Bool

  @Namespace private var activeTab
  @State private var hoveredID: String?

  var body: some View {
    HStack(spacing: 2) {
      ForEach(StudioWorkspaceKind.centeredNavigation) { kind in
        if kind == .nodes {
          divider
        }
        workspaceTab(
          id: kind.rawValue,
          title: kind.descriptor.title,
          purpose: kind.descriptor.purpose,
          systemImage: kind.descriptor.systemImage,
          shortcutNumber: kind.shortcutNumber,
          isActive: !isUIDevWorkspace && workspace.activeWorkspace == kind
        ) {
          isUIDevWorkspace = false
          workspace.switchWorkspace(to: kind)
        }
      }

      divider

      workspaceTab(
        id: "ui-dev",
        title: UIDevWorkspaceDescriptor.title,
        purpose: UIDevWorkspaceDescriptor.purpose,
        systemImage: UIDevWorkspaceDescriptor.systemImage,
        shortcutNumber: UIDevWorkspaceDescriptor.shortcutNumber,
        isActive: isUIDevWorkspace
      ) {
        isUIDevWorkspace = true
      }
    }
    .padding(4)
    .background(StudioPalette.panelInset, in: Capsule())
    .overlay(Capsule().stroke(StudioPalette.border, lineWidth: 1))
    .shadow(color: .black.opacity(0.10), radius: 4, y: 1)
    .frame(
      minWidth: WorkspaceSelectorMetrics.minimumWidth,
      idealWidth: WorkspaceSelectorMetrics.idealWidth,
      maxWidth: WorkspaceSelectorMetrics.maximumWidth
    )
    .animation(.spring(response: 0.30, dampingFraction: 0.86), value: activeID)
  }

  private var divider: some View {
    Rectangle()
      .fill(StudioPalette.border)
      .frame(width: 1, height: 21)
      .padding(.horizontal, 3)
  }

  private var activeID: String {
    isUIDevWorkspace ? "ui-dev" : workspace.activeWorkspace.rawValue
  }

  private func workspaceTab(
    id: String,
    title: String,
    purpose: String,
    systemImage: String,
    shortcutNumber: Int,
    isActive: Bool,
    action: @escaping () -> Void
  ) -> some View {
    let isHovered = hoveredID == id
    // Keep the header quiet and spatially stable: the selected stage names
    // the current workspace while every other destination remains a familiar
    // icon with a tooltip and keyboard shortcut.
    let showsLabel = isActive

    return Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: systemImage)
          .font(.system(size: compact ? 11 : 12, weight: .semibold))
        if showsLabel {
          Text(title)
            .font(.system(size: compact ? 10.5 : 12, weight: .semibold))
            .lineLimit(1)
        }
      }
      .foregroundStyle(isActive ? Color.white : StudioPalette.muted)
      .padding(.horizontal, compact ? (showsLabel ? 10 : 8) : 13)
      .frame(
        height: compact
          ? WorkspaceSelectorMetrics.compactChipHeight
          : WorkspaceSelectorMetrics.chipHeight
      )
      .background {
        if isActive {
          Capsule()
            .fill(StudioPalette.accent)
            .matchedGeometryEffect(id: "active-workspace", in: activeTab)
        } else if isHovered {
          Capsule().fill(Color.white.opacity(0.07))
        }
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .onHover { hoveredID = $0 ? id : nil }
    .keyboardShortcut(
      KeyEquivalent(Character(String(shortcutNumber))),
      modifiers: .command
    )
    .help("\(title) — \(purpose) (⌘\(shortcutNumber))")
    .accessibilityLabel("\(title) workspace")
    .accessibilityAddTraits(isActive ? .isSelected : [])
  }
}
