import AetherKernel
import AnimaCADViewport
import AnimaModel
import SwiftUI

/// The CAD viewport's four right-sidebar surfaces.
///
/// The rail is intentionally split by responsibility:
/// - View configures the camera/render path and CAD display aids.
/// - Environment configures the scene, theme, and lights.
/// - Appearance edits the selected Part and imported-model defaults.
/// - Inspector remains the context-aware model inspector supplied by the workspace.
struct CADAppearancePanel<Inspector: View>: View {
  @Bindable var workspace: StudioWorkspaceModel
  let tab: StudioViewSidebarTab
  @Binding var renderBackend: CADRenderBackend
  let performance: CADViewportPerformanceSnapshot
  @Binding var showsPerformanceHUD: Bool
  @Binding var showsTelemetry: Bool
  @Binding var themeName: String
  @Binding var ambientStrength: Double
  @Binding var shadowStrength: Double
  @Binding var keyLight: Double
  @Binding var fillLight: Double
  @Binding var rimLight: Double
  @Binding var keyLightHex: String
  @Binding var fillLightHex: String
  @Binding var rimLightHex: String
  @ViewBuilder let inspector: Inspector

  @Environment(\.studioPanelSurfaceMode) private var surfaceMode

  @AppStorage(StudioPreferenceKey.cadPreservesImportedColors) private var preservesColors = true
  @AppStorage(StudioPreferenceKey.cadShowsFeatureEdges) private var showsEdges = true
  @AppStorage(StudioPreferenceKey.cadEdgeStrength) private var edgeStrength =
    Double(CADThemePreferences.defaultTheme.edgeStrength)
  @AppStorage(StudioPreferenceKey.cadRoughness) private var roughness =
    Double(CADThemePreferences.defaultTheme.roughness)
  @AppStorage(StudioPreferenceKey.cadMetallic) private var metallic =
    Double(CADThemePreferences.defaultTheme.metallic)
  @AppStorage(StudioPreferenceKey.cadBackgroundColorHex) private var backgroundHex = ""
  @AppStorage(StudioPreferenceKey.cadNeutralColorHex) private var neutralHex = ""
  @AppStorage(StudioPreferenceKey.cadFaceSelectionColorHex) private var faceSelectionHex = ""
  @AppStorage(StudioPreferenceKey.cadEdgeColorHex) private var edgeHex = ""
  @AppStorage(StudioPreferenceKey.cadSelectedEdgeColorHex) private var selectedEdgeHex = ""
  @AppStorage(StudioPreferenceKey.cadShowsFloorGrid) private var showsFloorGrid = true
  @AppStorage(StudioPreferenceKey.cadFloorGridSpacingMeters) private
    var floorGridSpacingMeters = 0.1
  @AppStorage(StudioPreferenceKey.cadFloorGridExtentMultiplier) private
    var floorGridExtentMultiplier = 4.0
  @AppStorage(StudioPreferenceKey.cadFloorGridMajorLineInterval) private
    var floorGridMajorLineInterval = 5
  @AppStorage(StudioPreferenceKey.cadFloorGridOpacity) private var floorGridOpacity = 0.24
  @AppStorage(StudioPreferenceKey.cadShowsSolidFloor) private var showsSolidFloor = false
  @AppStorage(StudioPreferenceKey.cadFloorColorHex) private var floorColorHex = ""
  @AppStorage(StudioPreferenceKey.cadBackgroundGradientEnabled) private
    var backgroundGradientEnabled = false
  @AppStorage(StudioPreferenceKey.cadBackgroundBottomColorHex) private
    var backgroundBottomHex = ""
  @AppStorage(StudioPreferenceKey.cadMasterBrightness) private var masterBrightness = 0.5

  private var theme: CADViewportTheme { CADViewportTheme.named(themeName) }

  /// The Environment panel's floor layer as one mode, projected onto the two
  /// persisted bools shared with the renderers.
  private enum FloorMode: String, CaseIterable, Identifiable {
    case none = "None"
    case grid = "Grid"
    case floor = "Floor"
    case gridAndFloor = "Both"
    var id: String { rawValue }
  }

  private var floorMode: Binding<FloorMode> {
    Binding(
      get: {
        switch (showsFloorGrid, showsSolidFloor) {
        case (false, false): .none
        case (true, false): .grid
        case (false, true): .floor
        case (true, true): .gridAndFloor
        }
      },
      set: { mode in
        showsFloorGrid = mode == .grid || mode == .gridAndFloor
        showsSolidFloor = mode == .floor || mode == .gridAndFloor
      }
    )
  }

  /// Perceptual slider over a raw persisted intensity: far left is off,
  /// mid-slider is the preset's nominal value, far right is 4x (blinding).
  private func lightPosition(
    _ raw: Binding<Double>, nominal: Float, fallback: Float
  ) -> Binding<Double> {
    Binding(
      get: {
        Double(
          CADLightingScale.position(
            intensity: Float(raw.wrappedValue), nominal: nominal, fallbackNominal: fallback))
      },
      set: {
        raw.wrappedValue = Double(
          CADLightingScale.intensity(
            position: Float($0), nominal: nominal, fallbackNominal: fallback))
      }
    )
  }

  var body: some View {
    if tab == .inspector {
      inspector
    } else {
      VStack(alignment: .leading, spacing: 0) {
        WorkspacePanelHeader(title: panelTitle, systemImage: tab.systemImage)
        ScrollView {
          panelContent
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        if surfaceMode == .docked { Spacer(minLength: 0) }
      }
      .studioPanelSurface()
    }
  }

  @ViewBuilder
  private var panelContent: some View {
    switch tab {
    case .view:
      viewControls
    case .environment:
      environmentControls
    case .appearance:
      appearanceControls
    case .performance:
      performanceControls
    case .inspector:
      EmptyView()
    }
  }

  private var panelTitle: String {
    switch tab {
    case .view: "Camera & Display"
    case .environment: "Environment"
    case .appearance: "Part Appearance"
    case .performance: "Performance"
    case .inspector: "Inspector"
    }
  }

  private var viewControls: some View {
    VStack(alignment: .leading, spacing: 14) {
      card("RENDERER") {
        Picker("Engine", selection: $renderBackend) {
          ForEach(CADRenderBackend.selectable) { backend in
            Text(backend.title).tag(backend)
          }
        }
        .pickerStyle(.menu)
        Text(renderBackend.role)
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }

      card("CAMERA") {
        Button("Home View", systemImage: "house") {
          workspace.setCameraViewpoint(.home)
        }
        .buttonStyle(StudioButtonStyle(role: .secondary, density: .compact))
        Text("Use the ViewCube in the viewport for orthographic and isometric views.")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }

      referenceGeometrySection

      card("LAYERS") {
        Text(
          "Background, environment floor, and object lighting/shading live in the Environment panel's Background / Environment / Object sections."
        )
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      }
    }
  }

  private var performanceControls: some View {
    VStack(alignment: .leading, spacing: 14) {
      card("VIEWPORT HUD") {
        Toggle("Show engine frame status", isOn: $showsPerformanceHUD)
          .toggleStyle(.switch)
        Toggle("Show detailed CAD metrics", isOn: $showsTelemetry)
          .toggleStyle(.switch)
        Text(
          "The compact status card stays at bottom-right. Detailed renderer, FPS, CPU, memory, and geometry metrics appear directly above it."
        )
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      }

      card("LIVE STATUS") {
        LabeledContent("Engine", value: workspace.animaCoreStatusLabel)
        LabeledContent(
          "Renderer FPS",
          value: performance.framesPerSecond > 0.01
            ? String(format: "%.1f", performance.framesPerSecond) : "Measuring"
        )
        LabeledContent(
          "GPU frame",
          value: performance.frameTimeMilliseconds.map {
            String(format: "%.2f ms", $0)
          } ?? "Measuring"
        )
        LabeledContent("App CPU", value: String(format: "%.1f %%", performance.cpuPercent))
        LabeledContent("App memory", value: String(format: "%.1f MB", performance.memoryMegabytes))
        LabeledContent("Renderer", value: renderBackend.title)
        LabeledContent("Kernel", value: "Open CASCADE \(CADGeometryKernel.version)")
      }
    }
  }

  private var environmentControls: some View {
    VStack(alignment: .leading, spacing: 14) {
      card("BACKGROUND") {
        Picker("Preset", selection: themeSelection) {
          ForEach(CADViewportTheme.all) { Text($0.name).tag($0.name) }
        }
        .pickerStyle(.menu)
        Picker("Style", selection: $backgroundGradientEnabled) {
          Text("Solid").tag(false)
          Text("Gradient").tag(true)
        }
        .pickerStyle(.segmented)
        colorRow(
          backgroundGradientEnabled ? "Top color" : "Background",
          $backgroundHex, default: theme.background)
        if backgroundGradientEnabled {
          colorRow("Bottom color", $backgroundBottomHex, default: theme.background * 0.35)
        }
      }

      card("ENVIRONMENT") {
        Picker("Floor", selection: floorMode) {
          ForEach(FloorMode.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        if showsSolidFloor {
          colorRow("Floor color", $floorColorHex, default: theme.floorColor)
        }
        if showsFloorGrid {
          slider(
            "Grid spacing · \(formattedGridSpacing)",
            $floorGridSpacingMeters,
            0.001...1
          )
          slider(
            "Extent · \(String(format: "%.1f", floorGridExtentMultiplier))× model",
            $floorGridExtentMultiplier,
            1.5...20
          )
          Stepper(
            "Major line every \(floorGridMajorLineInterval) minor lines",
            value: $floorGridMajorLineInterval,
            in: 2...20
          )
          .font(.system(size: 12))
          slider("Grid opacity", $floorGridOpacity, 0.02...0.9)
        }
        Text(
          "The floor is a world-space display aid shared by MetalKit and Three.js/WebGPU. The semantic Top Plane remains a separate assembly reference."
        )
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      }

      card("OBJECT") {
        HStack {
          Text(lightingDisabled ? "All lights are off" : "Live viewport lighting")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(lightingDisabled ? Color.orange : StudioPalette.muted)
          Spacer()
          Button("Reset") {
            resetLightingToPreset()
          }
          .buttonStyle(.borderless)
          .font(.system(size: 11, weight: .semibold))
        }
        slider("Brightness", $masterBrightness, 0...1)
        slider(
          "Ambient light",
          lightPosition(
            $ambientStrength,
            nominal: CADViewportTheme.named(themeName).ambientStrength,
            fallback: 0.30),
          0...1
        )
        slider("Contact shadows", $shadowStrength, 0...1)
        Text(
          lightingDisabled
            ? "The model is intentionally unlit. Raise Brightness, Ambient, Key, Fill, or Rim—or press Reset—to restore a readable authoring view."
            : "Every slider is live: far left disables that light, mid-slider is the preset's nominal level, and far right overexposes. Brightness scales all lights at once."
        )
        .font(.caption)
        .foregroundStyle(lightingDisabled ? Color.orange : StudioPalette.muted)
        Divider()
        lightControl(
          "Key light",
          intensity: lightPosition($keyLight, nominal: theme.key.intensity, fallback: 4_400),
          colorHex: $keyLightHex,
          defaultColor: theme.key.color
        )
        Divider()
        lightControl(
          "Fill light",
          intensity: lightPosition($fillLight, nominal: theme.fill.intensity, fallback: 1_650),
          colorHex: $fillLightHex,
          defaultColor: theme.fill.color
        )
        Divider()
        lightControl(
          "Rim light",
          intensity: lightPosition($rimLight, nominal: theme.rim.intensity, fallback: 1_200),
          colorHex: $rimLightHex,
          defaultColor: theme.rim.color
        )
        Divider()
        Toggle("Show feature edges", isOn: $showsEdges).toggleStyle(.switch)
        slider("Edge definition", $edgeStrength, 0...1)
        colorRow("Edges", $edgeHex, default: theme.edgeColor)
        colorRow("Selected edges", $selectedEdgeHex, default: theme.edgeSelectionColor)
        colorRow("Face selection", $faceSelectionHex, default: theme.selectionColor)
      }
    }
  }

  private var appearanceControls: some View {
    VStack(alignment: .leading, spacing: 14) {
      if renderBackend == .rawWebGPU {
        card("RENDERER LIMIT") {
          Label(
            "Raw WebGPU is a diagnostic renderer. Use MetalKit or Three.js WebGPU for per-Part materials.",
            systemImage: "exclamationmark.triangle"
          )
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
        }
      } else if let selectedPart {
        card("SELECTED PART · \(selectedPart.displayName.uppercased())") {
          Form {
            ComponentAppearanceEditor(workspace: workspace, part: selectedPart)
          }
          .formStyle(.grouped)
          .scrollDisabled(true)
          .frame(minHeight: 560)
        }
      } else {
        card("SELECTED PART") {
          Label("Select a Part to edit its color and material.", systemImage: "cursorarrow.click")
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
      }

      card("IMPORTED CAD DEFAULTS") {
        Toggle("Preserve STEP / XDE colors", isOn: $preservesColors)
          .toggleStyle(.switch)
        colorRow("Unspecified model", $neutralHex, default: simd3(theme.neutralColor))
        slider("Roughness", $roughness, 0...1)
        slider("Metallic", $metallic, 0...1)
        Text(
          preservesColors
            ? "Source colors remain visible. The fallback color applies only where STEP/XDE has no color; a selected Part override still wins."
            : "The fallback color replaces imported STEP/XDE colors."
        )
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      }
    }
  }

  private var selectedPart: RigPartDefinition? {
    guard let selectedPartID = workspace.selectedPartID else { return nil }
    return workspace.project.rig.parts.first { $0.id == selectedPartID }
  }

  private var themeSelection: Binding<String> {
    Binding(
      get: { themeName },
      set: { applyPreset(named: $0) }
    )
  }

  private var lightingDisabled: Bool {
    masterBrightness <= 0.000_1
      || (ambientStrength <= 0.000_1
        && keyLight <= 0.5
        && fillLight <= 0.5
        && rimLight <= 0.5)
  }

  private func resetLightingToPreset() {
    let preset = CADViewportTheme.named(themeName)
    ambientStrength = Double(preset.ambientStrength)
    shadowStrength = Double(preset.shadowStrength)
    keyLight = Double(preset.key.intensity)
    fillLight = Double(preset.fill.intensity)
    rimLight = Double(preset.rim.intensity)
    masterBrightness = 0.5
    keyLightHex = ""
    fillLightHex = ""
    rimLightHex = ""
  }

  private func applyPreset(named name: String) {
    let preset = CADViewportTheme.named(name)
    themeName = preset.name
    edgeStrength = Double(preset.edgeStrength)
    roughness = Double(preset.roughness)
    metallic = Double(preset.metallic)
    backgroundHex = ""
    neutralHex = ""
    faceSelectionHex = ""
    edgeHex = ""
    selectedEdgeHex = ""
    resetLightingToPreset()
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

  private var formattedGridSpacing: String {
    let millimeters = floorGridSpacingMeters * 1_000
    if millimeters >= 10 {
      return "\(Int(millimeters.rounded())) mm"
    }
    return String(format: "%.1f mm", millimeters)
  }

  private func lightControl(
    _ label: String,
    intensity: Binding<Double>,
    colorHex: Binding<String>,
    defaultColor: SIMD3<Float>
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      colorRow(label, colorHex, default: defaultColor)
      // Perceptual position: 0 = off, mid = the preset's nominal, 1 = 4x.
      Slider(value: intensity, in: 0...1)
      Text(
        "\(Int((CADLightingScale.multiplier(position: Float(intensity.wrappedValue)) * 100).rounded()))% of nominal"
      )
      .font(.system(.caption, design: .monospaced))
      .foregroundStyle(StudioPalette.muted)
    }
  }

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

  private func simd3(_ value: SIMD4<Float>) -> SIMD3<Float> {
    SIMD3(value.x, value.y, value.z)
  }

  private func referenceGeometryLabel(_ geometry: CADReferenceGeometry) -> String {
    switch geometry {
    case .origin: "Origin"
    case .frontPlane: "Front Plane"
    case .topPlane: "Top Plane"
    case .rightPlane: "Right Plane"
    }
  }
}
