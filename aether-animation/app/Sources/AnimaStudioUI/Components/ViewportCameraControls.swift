import SwiftUI

/// The viewport-local camera control. Non-spatial configuration belongs in
/// the right View sidebar so this HUD stays intentionally singular.
struct ViewportCameraControls: View {
  @Bindable var workspace: StudioWorkspaceModel

  var body: some View {
    Button {
      workspace.setCameraViewpoint(.home)
    } label: {
      Image(systemName: "house")
        .frame(width: 25, height: 25)
    }
    .buttonStyle(.plain)
    .help("Home camera view")
    .accessibilityLabel("Home camera view")
    .padding(6)
    .foregroundStyle(StudioPalette.ink)
    .background(StudioPalette.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 9))
    .overlay {
      RoundedRectangle(cornerRadius: 9)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.3), radius: 7, y: 3)
  }

}
