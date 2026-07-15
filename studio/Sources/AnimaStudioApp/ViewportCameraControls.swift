import RealityKitViewport
import SwiftUI

struct ViewportCameraControls: View {
  @Bindable var workspace: StudioWorkspaceModel

  var body: some View {
    HStack(spacing: 5) {
      cameraButton("Home", systemImage: "house") {
        workspace.setCameraViewpoint(.home)
      }
      cameraButton("Front", systemImage: "square") {
        workspace.setCameraViewpoint(.front)
      }
      cameraButton("Right", systemImage: "square.split.2x1") {
        workspace.setCameraViewpoint(.right)
      }
      cameraButton("Top", systemImage: "square.dashed") {
        workspace.setCameraViewpoint(.top)
      }

      Divider()
        .frame(height: 22)

      Button {
        workspace.cameraProjection =
          workspace.cameraProjection == .perspective ? .orthographic : .perspective
      } label: {
        Image(
          systemName: workspace.cameraProjection == .perspective
            ? "cube.transparent" : "square.grid.3x3"
        )
        .frame(width: 25, height: 25)
      }
      .buttonStyle(.plain)
      .help(
        workspace.cameraProjection == .perspective
          ? "Switch to orthographic projection" : "Switch to perspective projection"
      )

      Menu {
        Section("Mouse and Trackpad") {
          Text("Scroll — zoom")
          Text("Right-drag — orbit")
          Text("Middle-drag — pan")
        }
        Section("Mac Alternatives") {
          Text("Option + left-drag — orbit")
          Text("Option + Command + left-drag — pan")
        }
        Section("Selection") {
          Text("Use Frame Selection in the toolbar")
          Text("Escape — clear selection")
        }
      } label: {
        Image(systemName: "questionmark.circle")
          .frame(width: 25, height: 25)
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .help("Camera controls")
    }
    .padding(6)
    .foregroundStyle(.white)
    .background(StudioPalette.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 9))
    .overlay {
      RoundedRectangle(cornerRadius: 9)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.3), radius: 7, y: 3)
  }

  private func cameraButton(
    _ title: String,
    systemImage: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .frame(width: 25, height: 25)
    }
    .buttonStyle(.plain)
    .help("\(title) camera view")
    .accessibilityLabel("\(title) camera view")
  }
}
