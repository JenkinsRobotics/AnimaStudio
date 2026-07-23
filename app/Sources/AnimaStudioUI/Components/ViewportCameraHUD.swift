import SwiftUI

struct ViewportCameraHUD: View {
  @Bindable var workspace: StudioWorkspaceModel
  var showsViewCube = true

  var body: some View {
    VStack(alignment: .trailing, spacing: 7) {
      if showsViewCube {
        ViewportViewCube(
          orientation: workspace.cameraState.orientation,
          onSelectDirection: workspace.setCameraDirection,
          onNudge: { horizontalRadians, verticalRadians in
            workspace.nudgeCamera(
              horizontalRadians: horizontalRadians,
              verticalRadians: verticalRadians
            )
          },
          onRoll: workspace.rollCamera
        )
      }

      ViewportCameraControls(workspace: workspace)
    }
  }
}
