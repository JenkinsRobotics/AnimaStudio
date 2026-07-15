import RealityKitViewport
import SwiftUI

struct WorkspaceSwitcherBar: View {
  @Bindable var workspace: StudioWorkspaceModel
  @Binding var viewportAppearance: PreviewAppearance
  let closeProject: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button(action: closeProject) {
        Image(systemName: "xmark")
          .font(.caption.bold())
          .frame(width: 27, height: 27)
          .background(Color.white.opacity(0.12), in: Circle())
      }
      .buttonStyle(.plain)
      .help("Close project and return home")

      Menu {
        Section("Viewport Appearance") {
          ForEach(PreviewAppearance.allCases) { appearance in
            Button {
              viewportAppearance = appearance
            } label: {
              Label(
                appearance.title,
                systemImage: viewportAppearance == appearance
                  ? "checkmark.circle.fill" : appearance.systemImage
              )
            }
          }
        }
        Divider()
        Section("About") {
          Text("Anima Studio 0.1.0")
          Text("Kinematic preview · Open source")
        }
      } label: {
        Image(systemName: "gearshape.fill")
          .frame(width: 27, height: 27)
          .background(Color.white.opacity(0.12), in: Circle())
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .help("Studio settings and viewport appearance")

      ForEach(StudioWorkspaceKind.allCases) { kind in
        let descriptor = kind.descriptor
        Button {
          workspace.switchWorkspace(to: kind)
        } label: {
          Label(descriptor.title, systemImage: descriptor.systemImage)
            .font(.callout.weight(workspace.activeWorkspace == kind ? .semibold : .regular))
            .foregroundStyle(
              workspace.activeWorkspace == kind ? Color.white : StudioPalette.muted
            )
            .frame(maxWidth: .infinity)
            .frame(height: 29)
            .background(
              workspace.activeWorkspace == kind
                ? Color.white.opacity(0.18) : Color.black.opacity(0.16),
              in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 170)
        .keyboardShortcut(
          KeyEquivalent(Character(String(kind.shortcutNumber))),
          modifiers: .command
        )
        .help("\(descriptor.purpose) (⌘\(kind.shortcutNumber))")
      }

      Spacer(minLength: 16)

      HStack(spacing: 7) {
        Circle()
          .fill(Color.secondary)
          .frame(width: 8, height: 8)
        Text("No Driver")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }

      Divider()
        .frame(height: 26)

      VStack(alignment: .trailing, spacing: 0) {
        Text("MASTER LIVE")
          .font(.caption2.weight(.semibold))
        Text("Hardware output unavailable")
          .font(.system(size: 9))
          .foregroundStyle(StudioPalette.muted)
      }

      Toggle("", isOn: .constant(false))
        .labelsHidden()
        .toggleStyle(.switch)
        .disabled(true)
    }
    .padding(.horizontal, 12)
    .frame(height: StudioMetrics.modeBarHeight)
    .background(StudioPalette.chrome)
  }
}

struct WorkspaceToolBar: View {
  @Bindable var workspace: StudioWorkspaceModel
  let importModel: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      globalProjectControls

      Divider()
        .frame(height: 28)

      workspaceIdentity
      WorkspaceContextualTools(workspace: workspace, importModel: importModel)

      Spacer(minLength: 12)

      if workspace.isLoadingModelHierarchy {
        ProgressView()
          .controlSize(.small)
        Text("Reading model…")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }

      workspaceLayoutMenu
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 14)
    .frame(height: StudioMetrics.toolBarHeight)
    .background(StudioPalette.chrome.opacity(0.96))
  }

  private var globalProjectControls: some View {
    Group {
      TextField("Project name", text: $workspace.project.name)
        .textFieldStyle(.plain)
        .font(.title3.italic())
        .lineLimit(1)
        .padding(.horizontal, 8)
        .frame(height: StudioMetrics.fieldHeight)
        .frame(minWidth: 150, maxWidth: 230, alignment: .leading)
        .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
          RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
            .stroke(StudioPalette.border, lineWidth: 1)
        }
        .help("Editable project name")

      Button("Save", systemImage: "square.and.arrow.down") {}
        .labelStyle(.iconOnly)
        .disabled(true)
        .help("Project saving arrives with the document layer")
      Button("Open", systemImage: "folder") {}
        .labelStyle(.iconOnly)
        .disabled(true)
        .help("Project opening arrives with the document layer")
      Button("Undo", systemImage: "arrow.uturn.backward") {}
        .labelStyle(.iconOnly)
        .disabled(true)
        .help("Undo history is planned for the durable document")
      Button("Redo", systemImage: "arrow.uturn.forward") {}
        .labelStyle(.iconOnly)
        .disabled(true)
        .help("Redo history is planned for the durable document")
    }
  }

  private var workspaceIdentity: some View {
    let descriptor = workspace.activeWorkspace.descriptor
    return Label(descriptor.title.uppercased(), systemImage: descriptor.systemImage)
      .font(.caption2.weight(.bold))
      .tracking(0.8)
      .foregroundStyle(StudioPalette.accent)
      .help(descriptor.purpose)
  }

  private var workspaceLayoutMenu: some View {
    Menu {
      Button {
        workspace.toggleNavigator()
      } label: {
        Label(
          "Navigator",
          systemImage: workspace.activePresentation.showsNavigator ? "checkmark" : "sidebar.left"
        )
      }
      Button {
        workspace.toggleInspector()
      } label: {
        Label(
          "Inspector",
          systemImage: workspace.activePresentation.showsInspector ? "checkmark" : "sidebar.right"
        )
      }
      if workspace.activeWorkspace == .animate || workspace.activeWorkspace == .show {
        Button {
          workspace.toggleBottomEditor()
        } label: {
          Label(
            "Bottom Editor",
            systemImage: workspace.activePresentation.showsBottomEditor
              ? "checkmark" : "rectangle.bottomthird.inset.filled"
          )
        }
      }
      Divider()
      Button("Reset \(workspace.activeWorkspace.descriptor.title) Layout") {
        workspace.resetActivePresentation()
      }
    } label: {
      Label("Workspace Layout", systemImage: "rectangle.3.group")
    }
    .labelStyle(.iconOnly)
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .help("Show, hide, or reset panels for this workspace")
  }
}

private struct WorkspaceContextualTools: View {
  @Bindable var workspace: StudioWorkspaceModel
  let importModel: () -> Void

  var body: some View {
    switch workspace.activeWorkspace {
    case .assets:
      assetTools
    case .rig:
      rigTools
    case .animate:
      animationTools
    case .show:
      showTools
    case .hardware:
      hardwareTools
    }
  }

  private var assetTools: some View {
    Group {
      Button(action: importModel) {
        Label("Import Model", systemImage: "plus.square.on.square")
      }
      .disabled(workspace.isLoadingModelHierarchy)
      .help("Import a USD, USDZ, or RealityKit model")

      Button("Relink Asset", systemImage: "link") {}
        .disabled(true)
        .help("Asset relinking arrives with durable projects")
    }
  }

  private var rigTools: some View {
    Group {
      gridButton
      Button("Move", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {}
        .disabled(true)
        .help("Move gizmos arrive with semantic parts")
      Button("Rotate", systemImage: "rotate.right") {}
        .disabled(true)
        .help("Rotation gizmos arrive with typed joints and DOFs")
      Button("Scale", systemImage: "arrow.up.left.and.arrow.down.right") {}
        .disabled(true)
        .help("Scale gizmos arrive with semantic parts")
      frameSelectionButton
      Button("Create Part", systemImage: "plus.square.dashed") {
        workspace.showCreationTools()
      }
      .help("Open the rig creation palette")
    }
  }

  private var animationTools: some View {
    Group {
      Button(action: workspace.stopPlayback) {
        Label("Stop", systemImage: "stop.fill")
      }
      .help("Stop playback")
      Button(action: workspace.togglePlayback) {
        Label(
          workspace.isPlaying ? "Pause" : "Play",
          systemImage: workspace.isPlaying ? "pause.fill" : "play.fill")
      }
      .help(workspace.isPlaying ? "Pause playback" : "Play animation")
      gridButton
      frameSelectionButton
      Button("Auto Key", systemImage: "record.circle") {}
        .disabled(true)
        .help("Auto-key arrives with editable animation commands")
      bottomEditorButton(title: "Timeline")
    }
  }

  private var showTools: some View {
    Group {
      gridButton
      Button("Add Cue", systemImage: "plus.rectangle.on.rectangle") {}
        .disabled(true)
        .help("Show cues arrive with scene documents")
      Button("Add Track", systemImage: "plus.rectangle.on.folder") {}
        .disabled(true)
        .help("Show tracks arrive with scene documents")
      bottomEditorButton(title: "Show Timeline")
    }
  }

  private var hardwareTools: some View {
    Group {
      Button("Connect", systemImage: "cable.connector.horizontal") {}
        .disabled(true)
        .help("Studio transport integration is not connected yet")
      Button("Add Driver", systemImage: "plus") {}
        .disabled(true)
        .help("Driver configuration follows actuator mapping")
      Button("Emergency Stop", systemImage: "stop.circle.fill") {}
        .disabled(true)
        .help("No hardware session is active")
    }
  }

  private var gridButton: some View {
    Button {
      workspace.showsPreviewGrid.toggle()
    } label: {
      Label(
        workspace.showsPreviewGrid ? "Hide Grid" : "Show Grid",
        systemImage: workspace.showsPreviewGrid ? "eye.fill" : "eye.slash"
      )
    }
    .help(workspace.showsPreviewGrid ? "Hide viewport grid" : "Show viewport grid")
  }

  private var frameSelectionButton: some View {
    Button {
      workspace.frameSelection()
    } label: {
      Label("Frame Selection", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
    }
    .disabled(!workspace.canFrameSelection)
    .help("Move the camera to frame the selected model node")
  }

  private func bottomEditorButton(title: String) -> some View {
    Button {
      workspace.toggleBottomEditor()
    } label: {
      Label(
        workspace.activePresentation.showsBottomEditor ? "Hide \(title)" : "Show \(title)",
        systemImage: "rectangle.bottomthird.inset.filled"
      )
    }
    .help("Toggle this workspace's bottom editor")
  }
}

struct WorkspacePanelHeader: View {
  let title: String
  let systemImage: String
  var closeAction: (() -> Void)?

  var body: some View {
    HStack(spacing: 8) {
      Label(title, systemImage: systemImage)
        .font(.callout.weight(.semibold))
      Spacer(minLength: 8)
      if let closeAction {
        Button(action: closeAction) {
          Image(systemName: "xmark")
            .font(.caption.bold())
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Clear selection")
      }
    }
    .foregroundStyle(.white)
    .padding(.horizontal, StudioMetrics.panelPadding)
    .frame(height: StudioMetrics.panelHeaderHeight)
    .background(StudioPalette.accent)
  }
}
