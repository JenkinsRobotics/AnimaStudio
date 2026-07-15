import RealityKitViewport
import SwiftUI

struct ViewportRenderMenu: View {
  @Binding var projection: PreviewCameraProjection
  @Binding var renderStyle: ViewportRenderStyle
  @Binding var showsGrid: Bool
  @Binding var appearance: PreviewAppearance
  @Binding var fieldOfViewDegrees: Float
  @Binding var navigationProfile: PreviewNavigationProfile
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

      Section("Render Style") {
        Picker("Render Style", selection: $renderStyle) {
          ForEach(ViewportRenderStyle.allCases) { style in
            Label(style.title, systemImage: style.systemImage)
              .tag(style)
          }
        }

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
          ForEach(PreviewNavigationProfile.allCases, id: \.self) { profile in
            Text(profile.displayName).tag(profile)
          }
        }
      }
    } label: {
      HStack(spacing: 5) {
        Image(systemName: renderStyle.systemImage)
        Image(systemName: "chevron.down")
          .font(.system(size: 8, weight: .bold))
      }
      .frame(width: 44, height: 23)
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
