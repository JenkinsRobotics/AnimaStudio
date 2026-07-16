import RealityKitViewport
import SwiftUI

struct StudioDocumentBar: View {
  @Bindable var workspace: StudioWorkspaceModel
  let closeProject: () -> Void

  var body: some View {
    ZStack {
      HStack(spacing: 5) {
        Button(action: closeProject) {
          Image(systemName: "house.fill")
        }
        .help("Return to Anima Studio home")

        Button("Projects", systemImage: "square.grid.2x2") {}
          .disabled(true)
          .help("Project browser arrives with the document layer")

        Menu {
          Button("New Project", systemImage: "doc.badge.plus") {}
            .disabled(true)
          Button("Open Project…", systemImage: "folder") {}
            .disabled(true)
        } label: {
          Image(systemName: "doc")
        }
        .menuIndicator(.visible)
        .help("Project file commands")

        Divider()
          .frame(height: 18)

        Button("Save", systemImage: "square.and.arrow.down") {}
          .disabled(true)
          .help("Project saving arrives with the document layer")
        Button("Undo", systemImage: "arrow.uturn.backward") {}
          .disabled(true)
          .help("Undo history arrives with durable projects")
        Button("Redo", systemImage: "arrow.uturn.forward") {}
          .disabled(true)
          .help("Redo history arrives with durable projects")

        Spacer()
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)

      HStack(spacing: 7) {
        Image(systemName: "cube.fill")
          .font(.caption)
          .foregroundStyle(StudioPalette.hardware)
        TextField("Project name", text: $workspace.project.name)
          .textFieldStyle(.plain)
          .font(.callout.weight(.medium))
          .multilineTextAlignment(.center)
          .frame(width: 250)
          .accessibilityLabel("Project name")
      }

      HStack(spacing: 9) {
        Spacer()

        Circle()
          .fill(Color.secondary)
          .frame(width: 7, height: 7)
        Text("No Driver")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)

        Divider()
          .frame(height: 18)

        Text("MASTER LIVE")
          .font(.system(size: 9, weight: .semibold))
        Toggle("", isOn: .constant(false))
          .labelsHidden()
          .toggleStyle(.switch)
          .controlSize(.mini)
          .disabled(true)
          .help("Hardware output is unavailable")
      }
    }
    .padding(.horizontal, 10)
    .frame(height: StudioMetrics.documentBarHeight)
    .background(StudioPalette.documentChrome)
  }
}

struct WorkspaceRibbonControls: View {
  @Bindable var workspace: StudioWorkspaceModel
  @Binding var viewportAppearance: PreviewAppearance
  let isCompact: Bool

  var body: some View {
    Group {
      if isCompact {
        HStack(spacing: 4) {
          settingsMenu
          workspaceLayoutMenu
        }
      } else {
        VStack(spacing: 7) {
          settingsMenu
          workspaceLayoutMenu
        }
      }
    }
    .frame(width: isCompact ? 72 : 42)
  }

  private var settingsMenu: some View {
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
      Image(systemName: "gearshape")
        .frame(width: 28, height: 28)
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .help("Studio settings and viewport appearance")
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
      Image(systemName: "rectangle.3.group")
        .frame(width: 28, height: 28)
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .help("Show, hide, or reset workspace panels")
  }
}

enum WorkspaceRibbonPresentation: Equatable {
  case compactRig
  case rigCreation
  case workspaceTools

  static func resolve(
    workspace: StudioWorkspaceKind,
    showsRigCreationTools: Bool
  ) -> Self {
    guard workspace == .rig else { return .workspaceTools }
    return showsRigCreationTools ? .rigCreation : .compactRig
  }

  var height: CGFloat {
    switch self {
    case .compactRig: StudioMetrics.compactRibbonHeight
    case .rigCreation, .workspaceTools: StudioMetrics.rigCreationRibbonHeight
    }
  }
}

struct WorkspaceToolBar: View {
  @Bindable var workspace: StudioWorkspaceModel
  @Binding var viewportAppearance: PreviewAppearance
  @Binding var isUIDevWorkspace: Bool
  @Binding var uiDevSection: UIDevSection
  let importModel: () -> Void
  let toggleAgentPanel: () -> Void

  var body: some View {
    let presentation =
      isUIDevWorkspace
      ? WorkspaceRibbonPresentation.workspaceTools
      : WorkspaceRibbonPresentation.resolve(
        workspace: workspace.activeWorkspace,
        showsRigCreationTools: workspace.showsCreationPalette
      )
    HStack(spacing: 0) {
      WorkspaceRibbonSelector(
        workspace: workspace,
        isUIDevWorkspace: $isUIDevWorkspace
      )

      Divider()
        .padding(.vertical, 10)

      Group {
        if isUIDevWorkspace {
          UIDevRibbonView(
            selectedSection: $uiDevSection,
            toggleAgentPanel: toggleAgentPanel
          )
        } else {
          switch presentation {
          case .compactRig:
            compactRibbon
          case .rigCreation:
            CreationPaletteView(workspace: workspace)
          case .workspaceTools:
            WorkspaceRibbonCatalogView(workspace: workspace, importModel: importModel)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Divider()
        .padding(.vertical, 10)

      if isUIDevWorkspace {
        UIDevRibbonTrailingControls(selectedSection: $uiDevSection)
      } else {
        WorkspaceRibbonControls(
          workspace: workspace,
          viewportAppearance: $viewportAppearance,
          isCompact: presentation == .compactRig
        )
      }
    }
    .frame(height: presentation.height)
    .background(StudioPalette.ribbonChrome)
  }

  private var compactRibbon: some View {
    HStack(spacing: 12) {
      WorkspaceContextualTools(workspace: workspace, importModel: importModel)

      Spacer(minLength: 12)

      if workspace.isLoadingModelHierarchy {
        ProgressView()
          .controlSize(.small)
        Text("Reading model…")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 12)
  }
}

private struct UIDevRibbonTrailingControls: View {
  @Binding var selectedSection: UIDevSection

  var body: some View {
    VStack(spacing: 7) {
      Button("Overview", systemImage: "house") {
        selectedSection = .templateMatrix
      }
      .labelStyle(.iconOnly)
      .buttonStyle(StudioIconButtonStyle(isSelected: selectedSection == .templateMatrix))
      .help("Return to the all-surfaces template matrix")

      Button("Reset UI gallery", systemImage: "arrow.counterclockwise") {
        selectedSection = .templateMatrix
      }
      .labelStyle(.iconOnly)
      .buttonStyle(StudioIconButtonStyle())
      .help("Reset the UI Dev gallery to the template matrix")
    }
    .frame(width: 42)
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
    case .nodes:
      nodeTools
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
        .help("Rotation gizmos arrive with typed mates and DOFs")
      Button("Scale", systemImage: "arrow.up.left.and.arrow.down.right") {}
        .disabled(true)
        .help("Scale gizmos arrive with semantic parts")
      frameSelectionButton
      Button("Add Components", systemImage: "plus.square.dashed") {
        workspace.showCreationTools()
      }
      .help("Expand the Rig creation ribbon")
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

  private var nodeTools: some View {
    Group {
      Button("Select", systemImage: "cursorarrow") {}
        .disabled(true)
        .help("Use Select in the node canvas toolbar")
      Button("Add Node", systemImage: "plus.square.dashed") {}
        .disabled(true)
        .help("Use the docked Node Library to add scene actions")
      Button("Connect", systemImage: "point.3.connected.trianglepath.dotted") {}
        .disabled(true)
        .help("Interactive edge authoring arrives with the graph compiler contract")
      Button("Validate", systemImage: "checkmark.shield") {}
        .disabled(true)
        .help("Use Validate in the node canvas toolbar for draft-structure feedback")
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
