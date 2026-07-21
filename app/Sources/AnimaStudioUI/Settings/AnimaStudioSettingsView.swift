import AnimaCAD
import AnimaCADViewport
import AppKit
import RealityKitViewport
import SwiftUI

enum StudioSettingsTab: String {
  case workspace
  case navigation
  case appearance
  case rendering
}

public struct AnimaStudioSettingsView: View {
  @AppStorage(StudioPreferenceKey.settingsSelectedTab) private var selectedTabRawValue =
    StudioSettingsTab.workspace.rawValue
  @AppStorage(StudioPreferenceKey.workspaceRootPath) private var workspaceRootPath = ""
  @AppStorage(StudioPreferenceKey.defaultLayoutPreset) private var defaultLayoutPresetRawValue =
    StudioLayoutPreset.floating.rawValue
  @AppStorage(StudioPreferenceKey.viewportAppearance) private var appearanceRawValue =
    PreviewAppearance.midnight.rawValue
  @AppStorage(StudioPreferenceKey.viewportNavigationProfile) private var profileRawValue =
    PreviewNavigationProfile.default.rawValue
  @AppStorage(StudioPreferenceKey.viewportCustomRotateDrag) private var rotateDragRawValue =
    NavigationDragBinding.rightMouse.rawValue
  @AppStorage(StudioPreferenceKey.viewportCustomPanDrag) private var panDragRawValue =
    NavigationDragBinding.middleMouse.rawValue
  @AppStorage(StudioPreferenceKey.viewportCustomPreciseZoomDrag) private
    var preciseZoomDragRawValue =
    NavigationDragBinding.shiftMiddleMouse.rawValue
  @AppStorage(StudioPreferenceKey.viewportOrbitSpeed) private var orbitSpeedRawValue =
    PreviewNavigationSpeed.standard.rawValue
  @AppStorage(StudioPreferenceKey.viewportPanSpeed) private var panSpeedRawValue =
    PreviewNavigationSpeed.standard.rawValue
  @AppStorage(StudioPreferenceKey.viewportZoomSpeed) private var zoomSpeedRawValue =
    PreviewNavigationSpeed.reduced.rawValue
  @AppStorage(StudioPreferenceKey.viewportReversesWheelZoom) private var reversesWheelZoom = false
  @AppStorage(StudioPreferenceKey.viewportRenderStyle) private var renderStyleRawValue =
    ViewportRenderStyle.shaded.rawValue
  @AppStorage(StudioPreferenceKey.viewportLightingPreset) private var lightingPresetRawValue =
    ViewportLightingPreset.balanced.rawValue
  @AppStorage(StudioPreferenceKey.viewportMaterialFinish) private var materialFinishRawValue =
    ViewportMaterialFinish.satin.rawValue
  @AppStorage(StudioPreferenceKey.viewportReflectionMode) private var reflectionModeRawValue =
    ViewportReflectionMode.subtle.rawValue
  @AppStorage(StudioPreferenceKey.viewportShowsShadows) private var showsShadows = true
  @AppStorage(StudioPreferenceKey.viewportLightingIntensity) private var lightingIntensity = 1.0
  @AppStorage(StudioPreferenceKey.viewportEnvironmentPreset) private var environmentPresetRawValue =
    ViewportEnvironmentPreset.softbox.rawValue
  @AppStorage(StudioPreferenceKey.viewportEnvironmentRotationDegrees) private
    var environmentRotationDegrees = 0.0
  @AppStorage(StudioPreferenceKey.viewportRenderQuality) private var renderQualityRawValue =
    ViewportRenderQuality.standard.rawValue
  @AppStorage(StudioPreferenceKey.cadRenderBackend) private var cadRenderBackendRawValue =
    CADRenderBackend.realityKit.rawValue
  @AppStorage(StudioPreferenceKey.cadThemeName) private var cadThemeName =
    CADViewportTheme.studioBlue.name
  @AppStorage(StudioPreferenceKey.cadPreservesImportedColors) private
    var cadPreservesImportedColors = true
  @AppStorage(StudioPreferenceKey.cadShowsFeatureEdges) private var cadShowsFeatureEdges = true
  @AppStorage(StudioPreferenceKey.cadEdgeStrength) private var cadEdgeStrength = 0.7
  @AppStorage(StudioPreferenceKey.cadRoughness) private var cadRoughness = 0.5
  @AppStorage(StudioPreferenceKey.cadMetallic) private var cadMetallic = 0.0
  @AppStorage(StudioPreferenceKey.cadKeyLightIntensity) private var cadKeyLightIntensity = 3_000.0
  @AppStorage(StudioPreferenceKey.cadFillLightIntensity) private var cadFillLightIntensity = 1_200.0
  @AppStorage(StudioPreferenceKey.cadRimLightIntensity) private var cadRimLightIntensity = 900.0
  @AppStorage(StudioPreferenceKey.cadShowsTelemetry) private var cadShowsTelemetry = false

  @State private var workspaceLocationError: String?

  public init() {}

  public var body: some View {
    TabView(selection: selectedTabBinding) {
      workspacePage
        .tabItem { Label("Workspace", systemImage: "folder") }
        .tag(StudioSettingsTab.workspace)
      navigationPage
        .tabItem { Label("Navigation", systemImage: "computermouse") }
        .tag(StudioSettingsTab.navigation)
      appearancePage
        .tabItem { Label("Appearance", systemImage: "paintpalette") }
        .tag(StudioSettingsTab.appearance)
      renderingPage
        .tabItem { Label("CAD Renderer", systemImage: "cube.transparent") }
        .tag(StudioSettingsTab.rendering)
    }
    .frame(width: 720, height: 700)
    .background(StudioPalette.canvas)
    .preferredColorScheme(.dark)
    .alert(
      "Workspace Location Could Not Be Changed",
      isPresented: Binding(
        get: { workspaceLocationError != nil },
        set: { if !$0 { workspaceLocationError = nil } }
      )
    ) {
      Button("OK", role: .cancel) { workspaceLocationError = nil }
    } message: {
      Text(workspaceLocationError ?? "Unknown error")
    }
  }

  private var workspacePage: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        StudioSectionHeader(
          title: "Project Workspace",
          detail: "Choose where new Anima Studio project folders are created by default.",
          systemImage: "folder.badge.gearshape"
        )

        VStack(alignment: .leading, spacing: 10) {
          Text("Default project location")
            .font(.caption.weight(.semibold))
            .foregroundStyle(StudioPalette.muted)
          HStack(spacing: 10) {
            Image(systemName: "folder.fill")
              .foregroundStyle(StudioPalette.accent)
            Text(workspaceLocation.workspaceRootURL.path)
              .font(.system(.body, design: .monospaced))
              .lineLimit(2)
              .textSelection(.enabled)
            Spacer(minLength: 8)
            Button("Change…") { chooseWorkspaceLocation() }
              .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: false))
          }
          .padding(12)
          .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 9))

          Text(
            "New Project, Open Project, and Save As begin in this folder. Existing projects keep their own security-scoped access."
          )
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)

          HStack {
            Button("Reveal in Finder", systemImage: "arrow.forward.square") {
              revealWorkspaceLocation()
            }
            .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: false))
            Spacer()
            Button("Restore ~/Documents/AnimaStudio") {
              workspaceLocation.restoreDefaultWorkspaceRoot()
              workspaceRootPath = ""
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioPalette.muted)
          }
        }
        .studioCardSurface()

        VStack(alignment: .leading, spacing: 12) {
          StudioSectionHeader(
            title: "Interface Layout",
            detail: "Choose how new workspace sessions present browsers, inspectors, and tools.",
            systemImage: "macwindow.on.rectangle"
          )
          Picker("Default Studio mode", selection: defaultLayoutPresetBinding) {
            ForEach(StudioLayoutPreset.allCases) { preset in
              Label(preset.title, systemImage: preset.systemImage).tag(preset)
            }
          }
          .pickerStyle(.segmented)
          Text(
            "Floating keeps spatial canvases full-size. Docked reserves space for structured work. Canvas hides panels until the pointer reaches an edge."
          )
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
          Toggle(
            "Push panels to the outer edge",
            isOn: Binding(
              get: { StudioLayoutState.shared.panelsOnOuterEdge },
              set: { StudioLayoutState.shared.panelsOnOuterEdge = $0 }
            )
          )
          .toggleStyle(.switch)
          Text("Keeps the panel margin while moving the icon rail inboard.")
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
        .studioCardSurface()

        VStack(alignment: .leading, spacing: 8) {
          Label("Plain project folders", systemImage: "checkmark.seal.fill")
            .foregroundStyle(StudioPalette.hardware)
          Text(
            "Each project remains a browsable folder containing project.json, characters, scenes, editor metadata, and portable assets."
          )
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
        }
        .studioCardSurface()
      }
      .padding(22)
    }
  }

  private var navigationPage: some View {
    MouseNavigationSettingsView(
      profile: profileBinding,
      customRotateDrag: rotateDragBinding,
      customPanDrag: panDragBinding,
      customPreciseZoomDrag: preciseZoomDragBinding,
      orbitSpeed: orbitSpeedBinding,
      panSpeed: panSpeedBinding,
      zoomSpeed: zoomSpeedBinding,
      reversesWheelZoom: $reversesWheelZoom,
      showsDismissButton: false
    )
  }

  private var appearancePage: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        StudioSectionHeader(
          title: "Viewport Appearance",
          detail: "These operator preferences apply to every project on this Mac.",
          systemImage: "paintpalette"
        )
        settingsPicker("Theme", selection: appearanceBinding, values: PreviewAppearance.allCases) {
          $0.title
        }
        settingsPicker(
          "Render style", selection: renderStyleBinding, values: ViewportRenderStyle.allCases
        ) {
          $0.title
        }
        settingsPicker(
          "Lighting", selection: lightingPresetBinding, values: ViewportLightingPreset.allCases
        ) {
          $0.title
        }
        settingsPicker(
          "Material finish", selection: materialFinishBinding,
          values: ViewportMaterialFinish.allCases
        ) {
          $0.title
        }
        settingsPicker(
          "Reflections", selection: reflectionModeBinding, values: ViewportReflectionMode.allCases
        ) {
          $0.title
        }
        settingsPicker(
          "Studio environment", selection: environmentPresetBinding,
          values: ViewportEnvironmentPreset.allCases
        ) { $0.title }
        VStack(alignment: .leading, spacing: 8) {
          LabeledContent(
            "Lighting intensity",
            value: lightingIntensity.formatted(.number.precision(.fractionLength(2)))
          )
          Slider(value: $lightingIntensity, in: 0.1...3)
          LabeledContent("Environment rotation", value: "\(Int(environmentRotationDegrees))°")
          Slider(value: $environmentRotationDegrees, in: 0...360)
        }
        .studioCardSurface()
        settingsPicker(
          "Render quality", selection: renderQualityBinding,
          values: ViewportRenderQuality.allCases
        ) { $0.title }
        Toggle("Cast viewport shadows", isOn: $showsShadows)
          .toggleStyle(.switch)
          .studioCardSurface()
      }
      .padding(22)
    }
  }

  private var renderingPage: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        StudioSectionHeader(
          title: "CAD Rendering",
          detail:
            "Every backend consumes the same Open CASCADE STEP/XDE geometry, hierarchy, colors, faces, and feature edges.",
          systemImage: "cube.transparent"
        )
        VStack(alignment: .leading, spacing: 12) {
          Picker("Render engine", selection: cadRenderBackendBinding) {
            ForEach(CADRenderBackend.allCases) { backend in
              Text(backend.title).tag(backend)
            }
          }
          LabeledContent("Assigned role", value: cadRenderBackendBinding.wrappedValue.role)
          Text(cadRenderBackendBinding.wrappedValue.detail)
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
          Text(
            cadRenderBackendBinding.wrappedValue.supportsNativeStudioInteraction
              ? "RealityKit keeps selection, mate placement, manipulators, audio, video, and spatial tools active."
              : "This is a STEP visualization surface. Switch to RealityKit for direct rig editing and media tools."
          )
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
          LabeledContent("Geometry kernel", value: "Open CASCADE \(CADGeometryKernel.version)")
          Toggle("Show performance telemetry", isOn: $cadShowsTelemetry)
            .toggleStyle(.switch)
        }
        .studioCardSurface()

        VStack(alignment: .leading, spacing: 12) {
          Picker("Coordinated theme", selection: $cadThemeName) {
            ForEach(CADViewportTheme.all) { theme in Text(theme.name).tag(theme.name) }
          }
          Toggle("Preserve STEP/XDE colors", isOn: $cadPreservesImportedColors)
            .toggleStyle(.switch)
          Toggle("Show exact B-Rep feature edges", isOn: $cadShowsFeatureEdges)
            .toggleStyle(.switch)
          settingSlider("Edge strength", value: $cadEdgeStrength, range: 0...1)
            .disabled(!cadShowsFeatureEdges)
          settingSlider("Surface roughness", value: $cadRoughness, range: 0...1)
          settingSlider("Surface metallic", value: $cadMetallic, range: 0...1)
        }
        .studioCardSurface()

        VStack(alignment: .leading, spacing: 12) {
          settingSlider("Key light", value: $cadKeyLightIntensity, range: 0...8_000)
          settingSlider("Fill light", value: $cadFillLightIntensity, range: 0...8_000)
          settingSlider("Rim light", value: $cadRimLightIntensity, range: 0...8_000)
          Text(
            "These renderer-neutral values map to the closest native material and light model in each backend."
          )
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
        }
        .studioCardSurface()
      }
      .padding(22)
    }
  }

  private var cadRenderBackendBinding: Binding<CADRenderBackend> {
    Binding(
      get: { CADRenderBackend(rawValue: cadRenderBackendRawValue) ?? .realityKit },
      set: { cadRenderBackendRawValue = $0.rawValue }
    )
  }

  private func settingSlider(
    _ title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      LabeledContent(
        title, value: value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
      Slider(value: value, in: range)
    }
  }

  private var workspaceLocation: WorkspaceLocationPreference {
    WorkspaceLocationPreference()
  }

  private var selectedTabBinding: Binding<StudioSettingsTab> {
    Binding(
      get: { StudioSettingsTab(rawValue: selectedTabRawValue) ?? .workspace },
      set: { selectedTabRawValue = $0.rawValue }
    )
  }

  private var defaultLayoutPresetBinding: Binding<StudioLayoutPreset> {
    Binding(
      get: { StudioLayoutPreset(rawValue: defaultLayoutPresetRawValue) ?? .floating },
      set: { defaultLayoutPresetRawValue = $0.rawValue }
    )
  }

  @MainActor
  private func chooseWorkspaceLocation() {
    guard let rootURL = workspaceLocation.chooseWorkspaceRoot() else { return }
    workspaceRootPath = rootURL.standardizedFileURL.path
    do {
      try workspaceLocation.ensureWorkspaceRootExists()
    } catch {
      workspaceLocationError = error.localizedDescription
    }
  }

  private func revealWorkspaceLocation() {
    do {
      let url = try workspaceLocation.ensureWorkspaceRootExists()
      NSWorkspace.shared.activateFileViewerSelecting([url])
    } catch {
      workspaceLocationError = error.localizedDescription
    }
  }

  private func settingsPicker<Value: Hashable & Identifiable>(
    _ title: String,
    selection: Binding<Value>,
    values: [Value],
    label: @escaping (Value) -> String
  ) -> some View {
    HStack {
      Text(title)
      Spacer()
      Picker(title, selection: selection) {
        ForEach(values) { value in Text(label(value)).tag(value) }
      }
      .labelsHidden()
      .frame(width: 240)
    }
    .studioCardSurface()
  }

  private var profile: PreviewNavigationProfile {
    PreviewNavigationProfile(rawValue: profileRawValue) ?? .default
  }

  private var rotateDrag: NavigationDragBinding {
    NavigationDragBinding(rawValue: rotateDragRawValue) ?? .rightMouse
  }

  private var panDrag: NavigationDragBinding {
    NavigationDragBinding(rawValue: panDragRawValue) ?? .middleMouse
  }

  private var preciseZoomDrag: NavigationDragBinding {
    NavigationDragBinding(rawValue: preciseZoomDragRawValue) ?? .shiftMiddleMouse
  }

  private var profileBinding: Binding<PreviewNavigationProfile> {
    Binding(get: { profile }, set: { profileRawValue = $0.rawValue })
  }

  private var rotateDragBinding: Binding<NavigationDragBinding> {
    Binding(
      get: { rotateDrag },
      set: { newValue in
        let previous = rotateDrag
        if newValue == panDrag { panDragRawValue = previous.rawValue }
        if newValue == preciseZoomDrag { preciseZoomDragRawValue = previous.rawValue }
        rotateDragRawValue = newValue.rawValue
      }
    )
  }

  private var panDragBinding: Binding<NavigationDragBinding> {
    Binding(
      get: { panDrag },
      set: { newValue in
        let previous = panDrag
        if newValue == rotateDrag { rotateDragRawValue = previous.rawValue }
        if newValue == preciseZoomDrag { preciseZoomDragRawValue = previous.rawValue }
        panDragRawValue = newValue.rawValue
      }
    )
  }

  private var preciseZoomDragBinding: Binding<NavigationDragBinding> {
    Binding(
      get: { preciseZoomDrag },
      set: { newValue in
        let previous = preciseZoomDrag
        if newValue == rotateDrag { rotateDragRawValue = previous.rawValue }
        if newValue == panDrag { panDragRawValue = previous.rawValue }
        preciseZoomDragRawValue = newValue.rawValue
      }
    )
  }

  private var orbitSpeedBinding: Binding<PreviewNavigationSpeed> {
    rawBinding($orbitSpeedRawValue, fallback: .standard)
  }

  private var panSpeedBinding: Binding<PreviewNavigationSpeed> {
    rawBinding($panSpeedRawValue, fallback: .standard)
  }

  private var zoomSpeedBinding: Binding<PreviewNavigationSpeed> {
    rawBinding($zoomSpeedRawValue, fallback: .reduced)
  }

  private var appearanceBinding: Binding<PreviewAppearance> {
    rawBinding($appearanceRawValue, fallback: .midnight)
  }

  private var renderStyleBinding: Binding<ViewportRenderStyle> {
    rawBinding($renderStyleRawValue, fallback: .shaded)
  }

  private var lightingPresetBinding: Binding<ViewportLightingPreset> {
    rawBinding($lightingPresetRawValue, fallback: .balanced)
  }

  private var materialFinishBinding: Binding<ViewportMaterialFinish> {
    rawBinding($materialFinishRawValue, fallback: .satin)
  }

  private var reflectionModeBinding: Binding<ViewportReflectionMode> {
    rawBinding($reflectionModeRawValue, fallback: .subtle)
  }

  private var environmentPresetBinding: Binding<ViewportEnvironmentPreset> {
    rawBinding($environmentPresetRawValue, fallback: .softbox)
  }

  private var renderQualityBinding: Binding<ViewportRenderQuality> {
    rawBinding($renderQualityRawValue, fallback: .standard)
  }

  private func rawBinding<Value: RawRepresentable>(
    _ rawValue: Binding<String>,
    fallback: Value
  ) -> Binding<Value> where Value.RawValue == String {
    Binding(
      get: { Value(rawValue: rawValue.wrappedValue) ?? fallback },
      set: { rawValue.wrappedValue = $0.rawValue }
    )
  }
}
