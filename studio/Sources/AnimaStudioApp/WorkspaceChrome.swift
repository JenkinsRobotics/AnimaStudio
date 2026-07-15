import SwiftUI

struct WorkspaceModeBar: View {
  @Bindable var workspace: StudioWorkspaceModel
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
        Text("Anima Studio 0.1.0")
        Divider()
        Text("Kinematic preview")
        Text("Open-source workspace")
      } label: {
        Image(systemName: "gearshape.fill")
          .frame(width: 27, height: 27)
          .background(Color.white.opacity(0.12), in: Circle())
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .help("Workspace information")

      ForEach(WorkspaceMode.allCases) { mode in
        Button {
          workspace.mode = mode
          if mode != .animate {
            workspace.isPlaying = false
          }
        } label: {
          Label(mode.rawValue, systemImage: mode.systemImage)
            .font(.callout.weight(workspace.mode == mode ? .semibold : .regular))
            .foregroundStyle(workspace.mode == mode ? Color.white : StudioPalette.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 29)
            .background(
              workspace.mode == mode ? Color.white.opacity(0.18) : Color.black.opacity(0.16),
              in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 190)
      }

      Spacer(minLength: 20)

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
      TextField("Project name", text: $workspace.project.name)
        .textFieldStyle(.plain)
        .font(.title3.italic())
        .lineLimit(1)
        .padding(.horizontal, 8)
        .frame(height: StudioMetrics.fieldHeight)
        .frame(minWidth: 150, maxWidth: 240, alignment: .leading)
        .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
          RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
            .stroke(StudioPalette.border, lineWidth: 1)
        }
        .help("Editable project name")

      Group {
        Button("Save", systemImage: "square.and.arrow.down") {}
          .disabled(true)
          .help("Project saving arrives with the document layer")
        Button("Open", systemImage: "folder") {}
          .disabled(true)
          .help("Project opening arrives with the document layer")
      }
      .labelStyle(.iconOnly)

      Divider()
        .frame(height: 28)

      Group {
        Button("Undo", systemImage: "arrow.uturn.backward") {}
        Button("Redo", systemImage: "arrow.uturn.forward") {}
      }
      .labelStyle(.iconOnly)
      .disabled(true)
      .help("Undo history is planned for the durable document")

      Divider()
        .frame(height: 28)

      Button {
        workspace.showsPreviewGrid.toggle()
      } label: {
        Label(
          workspace.showsPreviewGrid ? "Hide Grid" : "Show Grid",
          systemImage: workspace.showsPreviewGrid ? "eye.fill" : "eye.slash"
        )
      }
      .labelStyle(.iconOnly)
      .help(workspace.showsPreviewGrid ? "Hide viewport grid" : "Show viewport grid")

      Group {
        Button("Move", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {}
        Button("Rotate", systemImage: "rotate.right") {}
        Button("Scale", systemImage: "arrow.up.left.and.arrow.down.right") {}
      }
      .labelStyle(.iconOnly)
      .disabled(true)
      .help("Transform gizmos arrive with editable semantic parts")

      Button {
        workspace.frameSelection()
      } label: {
        Label("Frame Selection", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
      }
      .labelStyle(.iconOnly)
      .disabled(!workspace.canFrameSelection)
      .help("Move the camera to frame the selected model node")

      Divider()
        .frame(height: 28)

      Button(action: importModel) {
        Label("Import Model", systemImage: "plus.square.on.square")
      }
      .labelStyle(.iconOnly)
      .disabled(workspace.isLoadingModelHierarchy)
      .help("Import a USD, USDZ, or RealityKit model")

      Spacer()

      if workspace.isLoadingModelHierarchy {
        ProgressView()
          .controlSize(.small)
        Text("Reading model…")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }

    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 14)
    .frame(height: StudioMetrics.toolBarHeight)
    .background(StudioPalette.chrome.opacity(0.96))
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

extension WorkspaceMode {
  var systemImage: String {
    switch self {
    case .build: "point.3.connected.trianglepath.dotted"
    case .animate: "play.circle.fill"
    case .importAssets: "square.and.arrow.down"
    case .hardware: "cable.connector"
    }
  }
}
