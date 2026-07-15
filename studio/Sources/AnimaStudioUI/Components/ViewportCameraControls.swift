import RealityKitViewport
import SwiftUI

struct ViewportCameraControls: View {
  @Bindable var workspace: StudioWorkspaceModel
  let navigationProfile: PreviewNavigationProfile
  let customNavigationMapping: CustomNavigationMapping

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

      Menu {
        Section("CAD Navigation") {
          ForEach(navigationInstructions, id: \.self) { instruction in
            Text(instruction)
          }
          Text("Scroll or pinch — zoom")
        }
        Section("Trackpad") {
          Text("Two-finger drag — pan")
          Text("Pinch — zoom")
        }
        Section("Selection") {
          Text("Click geometry — select part")
          Text("Drag arrows — move from part origin")
          Text("Drag rings — rotate around part origin")
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

  private var navigationInstructions: [String] {
    switch navigationProfile {
    case .default, .onshape:
      ["Right-drag — orbit / tilt", "Middle-drag — pan"]
    case .solidWorks:
      [
        "Middle-drag — orbit / tilt",
        "Control or Shift + middle-drag — pan",
      ]
    case .fusion360:
      ["Shift + middle-drag — orbit / tilt", "Middle-drag — pan"]
    case .custom:
      [
        "\(customNavigationMapping.rotateDrag.title) — orbit / tilt",
        "\(customNavigationMapping.panDrag.title) — pan",
      ]
    }
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
