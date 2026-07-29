import SwiftUI

enum WorkspaceSelectorMetrics {
  static let minimumWidth: CGFloat = 300
  static let idealWidth: CGFloat = 480
  static let maximumWidth: CGFloat = 540
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
  @AppStorage(StudioPreferenceKey.showsNodesWorkspaceTab) private var showsNodesWorkspaceTab =
    StudioWorkspaceTabDefaults.showsNodes
  @AppStorage(StudioPreferenceKey.showsDesignWorkspaceTab) private var showsDesignWorkspaceTab =
    StudioWorkspaceTabDefaults.showsDesign
  @AppStorage(StudioPreferenceKey.showsUIDevWorkspaceTab) private var showsUIDevWorkspaceTab =
    StudioWorkspaceTabDefaults.showsUIDev

  var body: some View {
    HStack(spacing: 8) {
      characterTypePicker
      tabCapsule
    }
  }

  private var characterTypePicker: some View {
    Menu {
      ForEach(StudioCharacterType.allCases) { type in
        Button {
          isUIDevWorkspace = false
          workspace.characterType = type
        } label: {
          Label(type.title, systemImage: type.systemImage)
        }
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: workspace.characterType.systemImage)
        Text(workspace.characterType.title)
        Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
      }
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(StudioPalette.ink)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(StudioPalette.panelInset, in: Capsule())
      .overlay(Capsule().stroke(StudioPalette.border, lineWidth: 1))
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .help("Character type — routes the authoring tab (3D / 2D / VR)")
  }

  private var tabCapsule: some View {
    HStack(spacing: 2) {
      ForEach(visibleStages) { kind in
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

      if showsUIDevWorkspaceTab {
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
    }
    .padding(4)
    .background(StudioPalette.panelInset, in: Capsule())
    .overlay(Capsule().stroke(StudioPalette.border, lineWidth: 1))
    .shadow(color: .black.opacity(0.10), radius: 4, y: 1)
    // Size to content — never clamp the strip, or labeled chips truncate to
    // "Ch…". The compact breakpoint (icon-only) is the only width control.
    .fixedSize()
    .animation(.spring(response: 0.30, dampingFraction: 0.86), value: activeID)
    .onChange(of: showsUIDevWorkspaceTab) { _, isVisible in
      if !isVisible { isUIDevWorkspace = false }
    }
    .onChange(of: visibleStages) { _, stages in
      if !isUIDevWorkspace, !stages.contains(workspace.activeWorkspace) {
        workspace.switchWorkspace(to: .assets)
      }
    }
  }

  private var visibleStages: [StudioWorkspaceKind] {
    StudioWorkspaceNavigation.visibleStages(
      characterType: workspace.characterType,
      showNodes: showsNodesWorkspaceTab,
      showDesign: showsDesignWorkspaceTab
    )
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
    // Match the accepted demo: the full pipeline is readable until the header
    // reaches its compact-tabs breakpoint, where every stage becomes an icon.
    let showsLabel = !compact

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
