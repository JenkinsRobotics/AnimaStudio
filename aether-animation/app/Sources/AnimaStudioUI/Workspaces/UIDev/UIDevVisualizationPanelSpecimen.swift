import RealityKitViewport
import SwiftUI

struct UIDevVisualizationPanelSpecimen: View {
  @State private var selectedTab = ViewportVisualizationTab.material
  @State private var selectedAppearance =
    PreviewPartAppearance(hexRGB: "#54B4DC", finish: .satin)
    ?? .defaultAppearance(for: .mesh)
  @State private var background = ViewportBackgroundSettings()
  @State private var sectionPlane = ViewportSectionPlane()
  @State private var lightingIntensity = 1.0
  @State private var environmentPreset = ViewportEnvironmentPreset.softbox
  @State private var environmentRotationDegrees = 0.0

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        HStack(spacing: 8) {
          VisualizationColorWheelIcon()
            .frame(width: 20, height: 20)
          Text("Visualization")
            .font(.callout.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).stroke(StudioPalette.accent) }

        Spacer()
        Text("PRODUCTION COMPONENT")
          .font(.caption2.weight(.bold).monospaced())
          .foregroundStyle(StudioPalette.muted)
      }

      VStack(spacing: 0) {
        Picker("Visualization", selection: $selectedTab) {
          ForEach(ViewportVisualizationTab.allCases) { tab in
            Text(tab.title).tag(tab)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .padding(12)

        Divider()

        switch selectedTab {
        case .material:
          VisualizationMaterialBrowser(
            selectedPartName: "Head Pan Housing",
            usedMaterials: [
              VisualizationUsedMaterial(
                id: "sample-blue",
                name: "Default Material",
                appearance: selectedAppearance,
                assignmentCount: 3
              ),
              VisualizationUsedMaterial(
                id: "sample-glass",
                name: "Clear Glass - Thin",
                appearance: VisualizationMaterialCatalog.presets.first {
                  $0.id == "glass-clear-thin"
                }?.appearance ?? selectedAppearance,
                assignmentCount: 1
              ),
            ],
            applyPreset: { selectedAppearance = $0.appearance },
            applyUsedMaterial: { selectedAppearance = $0 }
          )
        case .environment:
          VisualizationEnvironmentBrowser(
            background: $background,
            sectionPlane: $sectionPlane,
            lightingIntensity: $lightingIntensity,
            environmentPreset: $environmentPreset,
            environmentRotationDegrees: $environmentRotationDegrees
          )
        }
      }
      .frame(height: 560)
      .background(StudioPalette.panel)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay { RoundedRectangle(cornerRadius: 10).stroke(StudioPalette.border) }
    }
  }
}
