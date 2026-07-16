import RealityKitViewport
import SwiftUI

struct ViewportCameraHUD: View {
  @Bindable var workspace: StudioWorkspaceModel
  @Binding var projection: PreviewCameraProjection
  @Binding var renderStyle: ViewportRenderStyle
  @Binding var edgeDisplay: ViewportEdgeDisplay
  @Binding var lightingPreset: ViewportLightingPreset
  @Binding var materialFinish: ViewportMaterialFinish
  @Binding var reflectionMode: ViewportReflectionMode
  @Binding var showsShadows: Bool
  @Binding var showsGrid: Bool
  @Binding var appearance: PreviewAppearance
  @Binding var fieldOfViewDegrees: Float
  @Binding var navigationProfile: PreviewNavigationProfile
  @Binding var customRotateDrag: NavigationDragBinding
  @Binding var customPanDrag: NavigationDragBinding
  @Binding var orbitSpeed: PreviewNavigationSpeed
  @Binding var panSpeed: PreviewNavigationSpeed
  @Binding var zoomSpeed: PreviewNavigationSpeed

  var body: some View {
    VStack(alignment: .trailing, spacing: 7) {
      ViewportViewCube(
        orientation: workspace.cameraState.orientation,
        onSelectDirection: workspace.setCameraDirection,
        onNudge: { horizontalRadians, verticalRadians in
          workspace.nudgeCamera(
            horizontalRadians: horizontalRadians,
            verticalRadians: verticalRadians
          )
        }
      )

      ViewportCameraControls(
        workspace: workspace,
        navigationProfile: navigationProfile,
        customNavigationMapping: CustomNavigationMapping(
          rotateDrag: customRotateDrag,
          panDrag: customPanDrag
        ),
        displayMenu: ViewportRenderMenu(
          projection: $projection,
          renderStyle: $renderStyle,
          edgeDisplay: $edgeDisplay,
          lightingPreset: $lightingPreset,
          materialFinish: $materialFinish,
          reflectionMode: $reflectionMode,
          showsShadows: $showsShadows,
          showsGrid: $showsGrid,
          appearance: $appearance,
          fieldOfViewDegrees: $fieldOfViewDegrees,
          navigationProfile: $navigationProfile,
          customRotateDrag: $customRotateDrag,
          customPanDrag: $customPanDrag,
          orbitSpeed: $orbitSpeed,
          panSpeed: $panSpeed,
          zoomSpeed: $zoomSpeed,
          canFrameSelection: workspace.canFrameSelection,
          frameSelection: workspace.frameSelection
        )
      )
    }
  }
}
