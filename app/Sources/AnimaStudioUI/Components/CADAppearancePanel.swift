import AnimaCADViewport
import SwiftUI

/// The right-hand appearance/environment panel for the CAD viewport (Metal +
/// WebGPU). Every control is bound to the CAD theme's AppStorage keys, which
/// `cadViewportTheme` reads — so changing one here re-themes the live viewport
/// on both engines. This replaces the RealityKit-only environment panel that
/// had no effect when the CAD pipeline is active.
struct CADAppearancePanel: View {
  @Bindable var workspace: StudioWorkspaceModel

  @AppStorage(StudioPreferenceKey.cadThemeName) private var themeName =
    CADViewportTheme.studioBlue.name
  @AppStorage(StudioPreferenceKey.cadPreservesImportedColors) private var preservesColors = true
  @AppStorage(StudioPreferenceKey.cadShowsFeatureEdges) private var showsEdges = true
  @AppStorage(StudioPreferenceKey.cadEdgeStrength) private var edgeStrength = 0.7
  @AppStorage(StudioPreferenceKey.cadRoughness) private var roughness = 0.5
  @AppStorage(StudioPreferenceKey.cadMetallic) private var metallic = 0.0
  @AppStorage(StudioPreferenceKey.cadKeyLightIntensity) private var keyLight = 3_000.0
  @AppStorage(StudioPreferenceKey.cadFillLightIntensity) private var fillLight = 1_200.0
  @AppStorage(StudioPreferenceKey.cadRimLightIntensity) private var rimLight = 900.0
  @AppStorage(StudioPreferenceKey.cadBackgroundColorHex) private var backgroundHex = ""
  @AppStorage(StudioPreferenceKey.cadNeutralColorHex) private var neutralHex = ""
  @AppStorage(StudioPreferenceKey.cadFaceSelectionColorHex) private var faceSelectionHex = ""
  @AppStorage(StudioPreferenceKey.cadEdgeColorHex) private var edgeHex = ""
  @AppStorage(StudioPreferenceKey.cadSelectedEdgeColorHex) private var selectedEdgeHex = ""

  private var theme: CADViewportTheme { CADViewportTheme.named(themeName) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        themeSection
        referenceGeometrySection
        colorsSection
        materialSection
        lightingSection
      }
      .padding(14)
    }
    .background(StudioPalette.panel)
  }

  private var themeSection: some View {
    card("THEME") {
      Picker("Preset", selection: $themeName) {
        ForEach(CADViewportTheme.all) { Text($0.name).tag($0.name) }
      }
      .pickerStyle(.menu)
      Toggle("Preserve STEP / XDE colors", isOn: $preservesColors)
        .toggleStyle(.switch)
    }
  }

  private var referenceGeometrySection: some View {
    card("REFERENCE GEOMETRY") {
      ForEach(CADReferenceGeometry.allCases, id: \.self) { geometry in
        Toggle(
          referenceGeometryLabel(geometry),
          isOn: Binding(
            get: { workspace.cadReferenceGeometryVisibility.contains(geometry) },
            set: { _ in workspace.toggleCADReferenceGeometry(geometry) }
          )
        )
        .toggleStyle(.switch)
      }
    }
  }

  private var colorsSection: some View {
    card("SCENE COLORS") {
      colorRow("Background", $backgroundHex, default: theme.background)
      colorRow("Unspecified model", $neutralHex, default: simd3(theme.neutralColor))
      colorRow("Face selection", $faceSelectionHex, default: theme.selectionColor)
      colorRow("Edges", $edgeHex, default: theme.edgeColor)
      colorRow("Selected edges", $selectedEdgeHex, default: theme.edgeSelectionColor)
    }
  }

  private var materialSection: some View {
    card("MATERIAL & EDGES") {
      slider("Roughness", $roughness, 0...1)
      slider("Metallic", $metallic, 0...1)
      Toggle("Show feature edges", isOn: $showsEdges).toggleStyle(.switch)
      slider("Edge strength", $edgeStrength, 0...1)
    }
  }

  private var lightingSection: some View {
    card("LIGHTING") {
      slider("Key light", $keyLight, 0...8_000)
      slider("Fill light", $fillLight, 0...8_000)
      slider("Rim light", $rimLight, 0...8_000)
    }
  }

  // MARK: Helpers

  private func card<Content: View>(
    _ title: String, @ViewBuilder _ content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.system(size: 10, weight: .semibold))
        .tracking(0.6)
        .foregroundStyle(StudioPalette.muted)
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 9))
    .overlay(RoundedRectangle(cornerRadius: 9).stroke(StudioPalette.border))
  }

  private func colorRow(
    _ label: String, _ hex: Binding<String>, default themeDefault: SIMD3<Float>
  ) -> some View {
    HStack {
      Text(label).font(.system(size: 12))
      Spacer()
      ColorPicker("", selection: hex.cadColor(themeDefault: themeDefault), supportsOpacity: false)
        .labelsHidden()
    }
  }

  private func slider(
    _ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>
  ) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
      Slider(value: value, in: range)
    }
  }

  private func simd3(_ value: SIMD4<Float>) -> SIMD3<Float> { SIMD3(value.x, value.y, value.z) }

  private func referenceGeometryLabel(_ geometry: CADReferenceGeometry) -> String {
    switch geometry {
    case .origin: "Origin"
    case .frontPlane: "Front Plane"
    case .topPlane: "Top Plane"
    case .rightPlane: "Right Plane"
    }
  }
}
