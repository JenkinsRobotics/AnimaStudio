import SwiftUI

enum StudioPalette {
  static let canvas = Color(red: 0.105, green: 0.105, blue: 0.125)
  static let chrome = Color(red: 0.15, green: 0.15, blue: 0.18)
  static let panel = Color(red: 0.22, green: 0.23, blue: 0.26)
  static let panelInset = Color(red: 0.16, green: 0.17, blue: 0.19)
  static let accent = Color(red: 0.12, green: 0.58, blue: 0.90)
  static let muted = Color.white.opacity(0.62)
}

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
    .frame(height: 43)
    .background(StudioPalette.chrome)
  }
}

struct WorkspaceToolBar: View {
  @Bindable var workspace: StudioWorkspaceModel
  let importModel: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Text(workspace.project.name)
        .font(.title3.italic())
        .lineLimit(1)
        .frame(minWidth: 150, alignment: .leading)

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

      Button(action: importModel) {
        Label("Import Model", systemImage: "square.and.arrow.down.on.square")
      }
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

      Label("Orbit Camera", systemImage: "rotate.3d")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 14)
    .frame(height: 47)
    .background(StudioPalette.chrome.opacity(0.96))
  }
}

struct WorkspacePanelHeader: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.callout.weight(.semibold))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .frame(height: 38)
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
