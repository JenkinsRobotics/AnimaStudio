import RealityKitViewport
import SwiftUI

struct ViewportRenderMenu: View {
  @Binding var projection: PreviewCameraProjection
  @Binding var renderStyle: ViewportRenderStyle
  @Binding var edgeDisplay: ViewportEdgeDisplay
  @Binding var lightingPreset: ViewportLightingPreset
  @Binding var showsGrid: Bool
  @Binding var appearance: PreviewAppearance
  @Binding var fieldOfViewDegrees: Float
  @Binding var navigationProfile: PreviewNavigationProfile
  @Binding var customRotateDrag: NavigationDragBinding
  @Binding var customPanDrag: NavigationDragBinding
  let canFrameSelection: Bool
  let frameSelection: () -> Void

  var body: some View {
    Menu {
      Section("Camera") {
        Picker("Projection", selection: $projection) {
          ForEach(PreviewCameraProjection.allCases) { projection in
            Text(projection.title).tag(projection)
          }
        }

        Menu("Field of View") {
          Picker("Field of View", selection: $fieldOfViewDegrees) {
            ForEach(Self.fieldOfViewPresets, id: \.self) { degrees in
              Text("\(Int(degrees))°").tag(degrees)
            }
          }
        }
        .disabled(projection == .orthographic)

        Button("Frame Selection", systemImage: "viewfinder", action: frameSelection)
          .disabled(!canFrameSelection)
      }

      Section("Viewport Display") {
        Picker("Lighting", selection: $lightingPreset) {
          ForEach(ViewportLightingPreset.allCases) { preset in
            Label(preset.title, systemImage: preset.systemImage)
              .tag(preset)
          }
        }

        Picker("Surface", selection: $renderStyle) {
          ForEach(ViewportRenderStyle.allCases) { style in
            Label(style.title, systemImage: style.systemImage)
              .tag(style)
          }
        }

        Picker("Edges", selection: $edgeDisplay) {
          ForEach(ViewportEdgeDisplay.allCases) { display in
            Label(display.title, systemImage: display.systemImage)
              .tag(display)
          }
        }
        .disabled(renderStyle == .wireframe)

        Toggle("Show Grid", systemImage: "grid", isOn: $showsGrid)
      }

      Section("Viewport Appearance") {
        Picker("Appearance", selection: $appearance) {
          ForEach(PreviewAppearance.allCases) { appearance in
            Text(appearance.title).tag(appearance)
          }
        }
      }

      Section("Input") {
        Picker("Mouse Profile", selection: $navigationProfile) {
          ForEach(PreviewNavigationProfile.allCases) { profile in
            Text(profile.displayName).tag(profile)
          }
        }

        if navigationProfile == .custom {
          Picker("Rotate", selection: $customRotateDrag) {
            ForEach(NavigationDragBinding.allCases) { binding in
              Text(binding.title).tag(binding)
            }
          }

          Picker("Pan", selection: $customPanDrag) {
            ForEach(NavigationDragBinding.allCases) { binding in
              Text(binding.title).tag(binding)
            }
          }
        }

        Label("Zoom · Scroll Wheel", systemImage: "computermouse")
      }
    } label: {
      HStack(spacing: 5) {
        Image(
          systemName: ViewportRenderMenuPresentation.icon(
            renderStyle: renderStyle,
            edgeDisplay: edgeDisplay
          )
        )
        Text("Display")
          .font(.caption2.weight(.semibold))
        Image(systemName: "chevron.down")
          .font(.system(size: 8, weight: .bold))
      }
      .frame(width: 78, height: 25)
      .foregroundStyle(.white)
      .background(StudioPalette.panel.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
      .overlay {
        RoundedRectangle(cornerRadius: 6)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .help("Camera and render options")
    .accessibilityLabel("Camera and render options")
  }

  private static let fieldOfViewPresets: [Float] = [30, 45, 60, 75, 90]
}

enum ViewportRenderMenuPresentation {
  static func icon(
    renderStyle: ViewportRenderStyle,
    edgeDisplay: ViewportEdgeDisplay
  ) -> String {
    guard renderStyle == .shaded else { return renderStyle.systemImage }
    return edgeDisplay == .mesh ? "cube" : renderStyle.systemImage
  }
}
