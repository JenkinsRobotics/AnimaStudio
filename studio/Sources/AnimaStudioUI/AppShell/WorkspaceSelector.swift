import SwiftUI

enum WorkspaceSelectorMetrics {
  static let minimumWidth: CGFloat = 228
  static let idealWidth: CGFloat = 242
  static let maximumWidth: CGFloat = 260
  static let menuWidth: CGFloat = 280
}

struct WorkspaceRibbonSelector: View {
  @Bindable var workspace: StudioWorkspaceModel
  @Binding var isUIDevWorkspace: Bool

  @State private var showsWorkspaceMenu = false

  var body: some View {
    Button {
      showsWorkspaceMenu.toggle()
    } label: {
      HStack(spacing: 11) {
        Image(systemName: activeSystemImage)
          .font(.title2.weight(.medium))
          .foregroundStyle(StudioPalette.accent)
          .frame(width: 38, height: 38)
          .background(StudioPalette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))

        VStack(alignment: .leading, spacing: 3) {
          Text(activeTitle.uppercased())
            .font(.callout.weight(.bold))
            .lineLimit(1)
          Text(activePurpose)
            .font(.system(size: 9.5))
            .foregroundStyle(StudioPalette.muted)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 6)

        Image(systemName: showsWorkspaceMenu ? "chevron.up" : "chevron.down")
          .font(.caption.weight(.bold))
          .foregroundStyle(showsWorkspaceMenu ? StudioPalette.accent : StudioPalette.muted)
      }
      .padding(.horizontal, 11)
      .frame(height: 72)
      .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 13))
      .overlay {
        RoundedRectangle(cornerRadius: 13)
          .stroke(
            showsWorkspaceMenu ? StudioPalette.accent : StudioPalette.border,
            lineWidth: showsWorkspaceMenu ? 1.5 : 1
          )
      }
      .contentShape(RoundedRectangle(cornerRadius: 13))
    }
    .buttonStyle(.plain)
    .frame(
      minWidth: WorkspaceSelectorMetrics.minimumWidth,
      idealWidth: WorkspaceSelectorMetrics.idealWidth,
      maxWidth: WorkspaceSelectorMetrics.maximumWidth,
      maxHeight: .infinity
    )
    .padding(.horizontal, 7)
    .popover(
      isPresented: $showsWorkspaceMenu,
      attachmentAnchor: .rect(.bounds),
      arrowEdge: .top
    ) {
      WorkspaceSelectorMenu(
        workspace: workspace,
        isUIDevWorkspace: $isUIDevWorkspace,
        dismiss: { showsWorkspaceMenu = false }
      )
      .frame(width: WorkspaceSelectorMetrics.menuWidth)
      .padding(8)
      .background(StudioPalette.chrome)
      .presentationBackground(StudioPalette.chrome)
      .preferredColorScheme(.dark)
    }
    .accessibilityLabel("Workspace: \(activeTitle)")
    .accessibilityHint(
      "Open the task-focused workspace menu. Command 1 through 7 switches directly."
    )
    .help("Switch task-focused workspace (⌘1–7)")
  }

  private var activeTitle: String {
    isUIDevWorkspace ? UIDevWorkspaceDescriptor.title : workspace.activeWorkspace.descriptor.title
  }

  private var activeSystemImage: String {
    isUIDevWorkspace
      ? UIDevWorkspaceDescriptor.systemImage : workspace.activeWorkspace.descriptor.systemImage
  }

  private var activePurpose: String {
    isUIDevWorkspace
      ? UIDevWorkspaceDescriptor.purpose : workspace.activeWorkspace.descriptor.purpose
  }
}

private struct WorkspaceSelectorMenu: View {
  @Bindable var workspace: StudioWorkspaceModel
  @Binding var isUIDevWorkspace: Bool
  let dismiss: () -> Void

  var body: some View {
    VStack(spacing: 6) {
      ForEach(StudioWorkspaceKind.allCases) { kind in
        workspaceButton(
          title: kind.descriptor.title,
          purpose: kind.descriptor.purpose,
          systemImage: kind.descriptor.systemImage,
          shortcutNumber: kind.shortcutNumber,
          isSelected: !isUIDevWorkspace && workspace.activeWorkspace == kind
        ) {
          isUIDevWorkspace = false
          workspace.switchWorkspace(to: kind)
          dismiss()
        }
        .keyboardShortcut(
          KeyEquivalent(Character(String(kind.shortcutNumber))),
          modifiers: .command
        )
      }

      Divider()
        .padding(.horizontal, 6)

      workspaceButton(
        title: UIDevWorkspaceDescriptor.title,
        purpose: UIDevWorkspaceDescriptor.purpose,
        systemImage: UIDevWorkspaceDescriptor.systemImage,
        shortcutNumber: UIDevWorkspaceDescriptor.shortcutNumber,
        isSelected: isUIDevWorkspace
      ) {
        isUIDevWorkspace = true
        dismiss()
      }
      .keyboardShortcut("7", modifiers: .command)
    }
    .padding(5)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }

  private func workspaceButton(
    title: String,
    purpose: String,
    systemImage: String,
    shortcutNumber: Int,
    isSelected: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 11) {
        Image(systemName: systemImage)
          .font(.title3.weight(.medium))
          .foregroundStyle(isSelected ? .white : StudioPalette.accent)
          .frame(width: 34, height: 34)
          .background(
            isSelected ? Color.white.opacity(0.14) : StudioPalette.panelInset,
            in: RoundedRectangle(cornerRadius: 8)
          )

        VStack(alignment: .leading, spacing: 2) {
          Text(title.uppercased())
            .font(.callout.weight(.semibold))
            .lineLimit(1)
          Text(purpose)
            .font(.caption2)
            .foregroundStyle(isSelected ? Color.white.opacity(0.76) : StudioPalette.muted)
            .lineLimit(1)
        }

        Spacer(minLength: 6)

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.white)
        }
        Text("⌘\(shortcutNumber)")
          .font(.system(.caption2, design: .monospaced))
          .foregroundStyle(isSelected ? Color.white.opacity(0.72) : StudioPalette.muted)
      }
      .padding(.horizontal, 9)
      .frame(height: 54)
      .background(
        isSelected ? StudioPalette.accent : Color.clear,
        in: RoundedRectangle(cornerRadius: 11)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 11)
          .stroke(isSelected ? StudioPalette.accent : StudioPalette.border, lineWidth: 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 11))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(title), Command \(shortcutNumber)")
    .accessibilityValue(isSelected ? "Selected" : "")
    .help(purpose)
  }
}
