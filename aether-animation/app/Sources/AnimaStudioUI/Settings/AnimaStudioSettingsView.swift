import AetherKernel
import AnimaCADViewport
import AppKit
import RealityKitViewport
import SwiftUI

public struct AnimaStudioSettingsView: View {
  @AppStorage(StudioPreferenceKey.appAppearanceMode) private var appAppearanceModeRawValue =
    StudioAppearanceMode.dark.rawValue
  @AppStorage(StudioPreferenceKey.settingsSelectedTab) private var selectedTabRawValue =
    StudioSettingsTab.workspace.rawValue
  @AppStorage(StudioPreferenceKey.workspaceRootPath) private var workspaceRootPath = ""
  @AppStorage(StudioPreferenceKey.defaultLayoutPreset) private var defaultLayoutPresetRawValue =
    StudioLayoutPreset.floating.rawValue
  @AppStorage(StudioPreferenceKey.showsStatusBar) private var showsStatusBar = true
  @AppStorage(StudioPreferenceKey.projectDefaultImportUnit) private var defaultImportUnitRawValue =
    ModelImportUnit.millimeters.rawValue
  @AppStorage(StudioPreferenceKey.projectAutosavesAfterImport) private var autosavesAfterImport =
    true
  @AppStorage(StudioPreferenceKey.projectDefaultFrameRate) private var defaultFrameRate = 30.0
  @AppStorage(StudioPreferenceKey.viewportShowsViewCube) private var showsViewCube = true
  @AppStorage(StudioPreferenceKey.viewportShowsOrigin) private var showsOrigin = true
  @AppStorage(StudioPreferenceKey.showsNodesWorkspaceTab) private var showsNodesWorkspaceTab =
    StudioWorkspaceTabDefaults.showsNodes
  @AppStorage(StudioPreferenceKey.showsDesignWorkspaceTab) private var showsDesignWorkspaceTab =
    StudioWorkspaceTabDefaults.showsDesign
  @AppStorage(StudioPreferenceKey.showsUIDevWorkspaceTab) private var showsUIDevWorkspaceTab =
    StudioWorkspaceTabDefaults.showsUIDev
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
    CADRenderBackend.defaultBackend.rawValue
  @AppStorage(StudioPreferenceKey.cadThemeName) private var cadThemeName =
    CADThemePreferences.defaultTheme.name
  @AppStorage(StudioPreferenceKey.cadPreservesImportedColors) private
    var cadPreservesImportedColors = true
  @AppStorage(StudioPreferenceKey.cadShowsFeatureEdges) private var cadShowsFeatureEdges = true
  @AppStorage(StudioPreferenceKey.cadEdgeStrength) private var cadEdgeStrength =
    Double(CADThemePreferences.defaultTheme.edgeStrength)
  @AppStorage(StudioPreferenceKey.cadAmbientStrength) private var cadAmbientStrength =
    Double(CADThemePreferences.defaultTheme.ambientStrength)
  @AppStorage(StudioPreferenceKey.cadShadowStrength) private var cadShadowStrength =
    Double(CADThemePreferences.defaultTheme.shadowStrength)
  @AppStorage(StudioPreferenceKey.cadRoughness) private var cadRoughness =
    Double(CADThemePreferences.defaultTheme.roughness)
  @AppStorage(StudioPreferenceKey.cadMetallic) private var cadMetallic =
    Double(CADThemePreferences.defaultTheme.metallic)
  @AppStorage(StudioPreferenceKey.cadKeyLightIntensity) private var cadKeyLightIntensity =
    Double(CADThemePreferences.defaultTheme.key.intensity)
  @AppStorage(StudioPreferenceKey.cadFillLightIntensity) private var cadFillLightIntensity =
    Double(CADThemePreferences.defaultTheme.fill.intensity)
  @AppStorage(StudioPreferenceKey.cadRimLightIntensity) private var cadRimLightIntensity =
    Double(CADThemePreferences.defaultTheme.rim.intensity)
  @AppStorage(StudioPreferenceKey.cadShowsTelemetry) private var cadShowsTelemetry = false
  @AppStorage(StudioPreferenceKey.cadShowsFloorGrid) private var cadShowsFloorGrid = true
  @AppStorage(StudioPreferenceKey.cadFloorGridSpacingMeters) private
    var cadFloorGridSpacingMeters = 0.1
  @AppStorage(StudioPreferenceKey.cadFloorGridExtentMultiplier) private
    var cadFloorGridExtentMultiplier = 4.0
  @AppStorage(StudioPreferenceKey.cadFloorGridMajorLineInterval) private
    var cadFloorGridMajorLineInterval = 5
  @AppStorage(StudioPreferenceKey.cadFloorGridOpacity) private var cadFloorGridOpacity = 0.24
  // Per-color theme overrides imported from the demo settings (empty = use the
  // named theme's color; resolved in CADViewportTheme.applyingOverrides).
  @AppStorage(StudioPreferenceKey.cadEdgeColorHex) private var cadEdgeColorHex = ""
  @AppStorage(StudioPreferenceKey.cadSelectedEdgeColorHex) private var cadSelectedEdgeColorHex = ""
  @AppStorage(StudioPreferenceKey.cadBackgroundColorHex) private var cadBackgroundColorHex = ""
  @AppStorage(StudioPreferenceKey.cadFaceSelectionColorHex) private
    var cadFaceSelectionColorHex = ""
  @AppStorage(StudioPreferenceKey.cadNeutralColorHex) private var cadNeutralColorHex = ""
  @AppStorage(StudioPreferenceKey.cadKeyLightColorHex) private var cadKeyLightColorHex = ""
  @AppStorage(StudioPreferenceKey.cadFillLightColorHex) private var cadFillLightColorHex = ""
  @AppStorage(StudioPreferenceKey.cadRimLightColorHex) private var cadRimLightColorHex = ""

  @State private var workspaceLocationError: String?
  @State private var designProfile = StudioDesignPersistence.load()

  public init() {}

  public var body: some View {
    NavigationSplitView {
      List(selection: selectedTabOptionalBinding) {
        ForEach(StudioSettingsGroup.allCases) { group in
          Section(group.rawValue) {
            ForEach(StudioSettingsTab.allCases.filter { $0.group == group }) { tab in
              Label(tab.title, systemImage: tab.systemImage)
                .tag(tab)
                .help(tab.detail)
            }
          }
        }
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 230)
    } detail: {
      selectedPage
    }
    .navigationSplitViewStyle(.balanced)
    .frame(width: 850, height: 700)
    .background(StudioPalette.canvas)
    .preferredColorScheme(StudioAppearanceMode.current.colorScheme)
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

  @ViewBuilder
  private var selectedPage: some View {
    switch selectedTabBinding.wrappedValue {
    case .workspace: workspacePage
    case .renderer: renderingPage
    case .appearance: appearancePage
    case .materialsAndEdges: materialsAndEdgesPage
    case .lighting: lightingPage
    case .layout: layoutPage
    case .navigation: navigationPage
    case .interface: interfacePage
    case .developer: developerPage
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
            title: "Authoring Defaults",
            detail: "Defaults for newly imported assets and newly created animation clips.",
            systemImage: "slider.horizontal.3"
          )
          Picker("Unitless model units", selection: defaultImportUnitBinding) {
            ForEach(ModelImportUnit.allCases) { unit in
              Text(unit.label).tag(unit)
            }
          }
          Toggle("Autosave after import", isOn: $autosavesAfterImport)
            .toggleStyle(.switch)
          VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Default frame rate", value: "\(Int(defaultFrameRate)) fps")
            Slider(value: $defaultFrameRate, in: 12...60, step: 1)
          }
          Text(
            "STL and OBJ are unitless. The import review sheet still lets the operator override this choice per file."
          )
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
          title: "Appearance",
          detail:
            "Coordinate the viewport background, imported colors, reflections, and environment.",
          systemImage: "paintpalette"
        )
        settingsPicker("Theme", selection: appearanceBinding, values: PreviewAppearance.allCases) {
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
          LabeledContent("Environment rotation", value: "\(Int(environmentRotationDegrees))°")
          Slider(value: $environmentRotationDegrees, in: 0...360)
        }
        .studioCardSurface()
        VStack(alignment: .leading, spacing: 12) {
          Picker("Coordinated CAD theme", selection: cadThemeSelection) {
            ForEach(CADViewportTheme.all) { theme in Text(theme.name).tag(theme.name) }
          }
          Toggle("Preserve STEP/XDE colors", isOn: $cadPreservesImportedColors)
            .toggleStyle(.switch)
          Text("Turn imported colors off to use the coordinated diagnostic material instead.")
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
        .studioCardSurface()
        VStack(alignment: .leading, spacing: 12) {
          Text("SCENE COLORS")
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(StudioPalette.muted)
          themeColorRow(
            "Viewport background", $cadBackgroundColorHex, default: currentCADTheme.background
          )
          themeColorRow(
            "Unspecified model color", $cadNeutralColorHex,
            default: SIMD3(
              currentCADTheme.neutralColor.x, currentCADTheme.neutralColor.y,
              currentCADTheme.neutralColor.z
            )
          )
          themeColorRow(
            "Face selection", $cadFaceSelectionColorHex, default: currentCADTheme.selectionColor
          )
        }
        .studioCardSurface()
      }
      .padding(22)
    }
  }

  private var renderingPage: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        StudioSectionHeader(
          title: "Renderer",
          detail:
            "Every backend consumes the same Open CASCADE STEP/XDE geometry, hierarchy, colors, faces, and feature edges.",
          systemImage: "cube.transparent"
        )
        VStack(alignment: .leading, spacing: 12) {
          Picker("Render engine", selection: cadRenderBackendBinding) {
            ForEach(CADRenderBackend.selectable) { backend in
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
          Toggle("Show orientation ViewCube", isOn: $showsViewCube)
            .toggleStyle(.switch)
          Toggle("Show character origin axes", isOn: $showsOrigin)
            .toggleStyle(.switch)
        }
        .studioCardSurface()

        VStack(alignment: .leading, spacing: 12) {
          Text("3D FLOOR GRID")
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(StudioPalette.muted)
          Toggle("Show world-space floor grid", isOn: $cadShowsFloorGrid)
            .toggleStyle(.switch)
          settingSlider(
            "Minor spacing (meters)",
            value: $cadFloorGridSpacingMeters,
            range: 0.001...1
          )
          .disabled(!cadShowsFloorGrid)
          settingSlider(
            "Extent relative to model",
            value: $cadFloorGridExtentMultiplier,
            range: 1.5...20
          )
          .disabled(!cadShowsFloorGrid)
          Stepper(
            "Major line every \(cadFloorGridMajorLineInterval) minor lines",
            value: $cadFloorGridMajorLineInterval,
            in: 2...20
          )
          .disabled(!cadShowsFloorGrid)
          settingSlider(
            "Grid opacity",
            value: $cadFloorGridOpacity,
            range: 0.02...0.9
          )
          .disabled(!cadShowsFloorGrid)
          Text(
            "One presentation setting drives the Assets preview, MetalKit CAD viewport, and Three.js/WebGPU viewport. Reference planes remain independently selectable."
          )
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
        }
        .studioCardSurface()

        settingsPicker(
          "Render style", selection: renderStyleBinding, values: ViewportRenderStyle.allCases
        ) { $0.title }
        settingsPicker(
          "Render quality", selection: renderQualityBinding,
          values: ViewportRenderQuality.allCases
        ) { $0.title }
      }
      .padding(22)
    }
  }

  private var materialsAndEdgesPage: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        StudioSectionHeader(
          title: "Materials & Edges",
          detail: "Configure the common surface finish and exact CAD feature-edge treatment.",
          systemImage: "square.3.layers.3d"
        )
        settingsPicker(
          "Material finish", selection: materialFinishBinding,
          values: ViewportMaterialFinish.allCases
        ) { $0.title }
        VStack(alignment: .leading, spacing: 12) {
          settingSlider("Surface roughness", value: $cadRoughness, range: 0...1)
          settingSlider("Surface metallic", value: $cadMetallic, range: 0...1)
          Text("Renderer-neutral values map to each backend's closest native material model.")
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
        .studioCardSurface()
        VStack(alignment: .leading, spacing: 12) {
          Toggle("Show exact B-Rep feature edges", isOn: $cadShowsFeatureEdges)
            .toggleStyle(.switch)
          settingSlider("Edge definition", value: $cadEdgeStrength, range: 0...1)
            .disabled(!cadShowsFeatureEdges)
          themeColorRow("Edge color", $cadEdgeColorHex, default: currentCADTheme.edgeColor)
          themeColorRow(
            "Selected edge", $cadSelectedEdgeColorHex, default: currentCADTheme.edgeSelectionColor
          )
        }
        .studioCardSurface()
      }
      .padding(22)
    }
  }

  private var lightingPage: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        StudioSectionHeader(
          title: "Lighting",
          detail: "Balance the interactive viewport and the renderer-neutral CAD light rig.",
          systemImage: "light.max"
        )
        settingsPicker(
          "Viewport preset", selection: lightingPresetBinding,
          values: ViewportLightingPreset.allCases
        ) { $0.title }
        VStack(alignment: .leading, spacing: 12) {
          settingSlider("Viewport intensity", value: $lightingIntensity, range: 0.1...3)
          Toggle("Cast viewport shadows", isOn: $showsShadows)
            .toggleStyle(.switch)
        }
        .studioCardSurface()
        VStack(alignment: .leading, spacing: 12) {
          settingSlider("Ambient light", value: $cadAmbientStrength, range: 0...0.55)
          settingSlider("Contact shadows", value: $cadShadowStrength, range: 0...1)
          Text(
            "Contact shadows use an interactive soft depth pass. Offline path tracing remains a future render/export mode."
          )
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
          settingSlider("Key light", value: $cadKeyLightIntensity, range: 0...8_000)
          themeColorRow("Key light color", $cadKeyLightColorHex, default: currentCADTheme.key.color)
          settingSlider("Fill light", value: $cadFillLightIntensity, range: 0...8_000)
          themeColorRow(
            "Fill light color", $cadFillLightColorHex, default: currentCADTheme.fill.color
          )
          settingSlider("Rim light", value: $cadRimLightIntensity, range: 0...8_000)
          themeColorRow("Rim light color", $cadRimLightColorHex, default: currentCADTheme.rim.color)
          Text("The relationship is normalized into each renderer's closest native light model.")
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
        .studioCardSurface()
      }
      .padding(22)
    }
  }

  private var layoutPage: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        StudioSectionHeader(
          title: "Layout",
          detail: "Control the app-global Studio mode and panel relationship.",
          systemImage: "rectangle.split.3x1"
        )
        VStack(alignment: .leading, spacing: 12) {
          Picker("Default Studio mode", selection: defaultLayoutPresetBinding) {
            ForEach(StudioLayoutPreset.allCases) { preset in
              Label(preset.title, systemImage: preset.systemImage).tag(preset)
            }
          }
          .pickerStyle(.segmented)
          Text("The selected default is applied to new workspace sessions.")
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
        .studioCardSurface()
        VStack(alignment: .leading, spacing: 12) {
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
      }
      .padding(22)
    }
  }

  private var interfacePage: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        StudioSectionHeader(
          title: "UI",
          detail: "App chrome, tool presentation, status, and shared design tokens.",
          systemImage: "sidebar.squares.left"
        )
        VStack(alignment: .leading, spacing: 12) {
          Picker("Appearance", selection: appearanceModeBinding) {
            ForEach(StudioAppearanceMode.allCases) { mode in
              Label(mode.title, systemImage: mode.systemImage).tag(mode)
            }
          }
          .pickerStyle(.segmented)
          Text("Dark is the default; Light and System adapt every panel to the chosen appearance.")
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
        .studioCardSurface()
        VStack(alignment: .leading, spacing: 12) {
          Picker("Design preset", selection: designPresetBinding) {
            ForEach(StudioDesignPreset.allCases) { preset in Text(preset.title).tag(preset) }
          }
          .pickerStyle(.segmented)
          ColorPicker("Accent color", selection: accentColorBinding, supportsOpacity: false)
          Text("The shared profile updates panels, ribbons, fields, and semantic chrome together.")
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
        .studioCardSurface()
        VStack(alignment: .leading, spacing: 12) {
          Picker("Tool density", selection: toolDensityBinding) {
            ForEach(StudioToolDensity.allCases) { density in
              Label(density.rawValue, systemImage: density.systemImage).tag(density)
            }
          }
          .pickerStyle(.segmented)
          Picker("Floating chrome", selection: chromeShapeBinding) {
            ForEach(StudioChromeShape.allCases) { shape in
              Label(shape.rawValue, systemImage: shape.systemImage).tag(shape)
            }
          }
          .pickerStyle(.segmented)
          Toggle("Show workspace status bar", isOn: $showsStatusBar)
            .toggleStyle(.switch)
        }
        .studioCardSurface()
      }
      .padding(22)
    }
  }

  private var developerPage: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        StudioSectionHeader(
          title: "Developer",
          detail:
            "Diagnostics and optional development surfaces. These controls never change project data.",
          systemImage: "hammer"
        )
        VStack(alignment: .leading, spacing: 12) {
          Toggle(
            "Show live layout zones",
            isOn: Binding(
              get: { StudioLayoutState.shared.showsLayoutZones },
              set: { StudioLayoutState.shared.showsLayoutZones = $0 }
            )
          )
          .toggleStyle(.switch)
          Text("Draws the content-safe visible zone and all four shell edges over the center view.")
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
        .studioCardSurface()
        VStack(alignment: .leading, spacing: 12) {
          Text("WORKSPACE TABS")
            .font(.caption2.weight(.bold))
            .foregroundStyle(StudioPalette.muted)
          Toggle("Nodes", isOn: $showsNodesWorkspaceTab).toggleStyle(.switch)
          Toggle("Design sandbox", isOn: $showsDesignWorkspaceTab).toggleStyle(.switch)
          Toggle("UI Dev", isOn: $showsUIDevWorkspaceTab).toggleStyle(.switch)
          Text("Hiding a tab does not remove its implementation or saved content.")
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
      get: {
        (CADRenderBackend(rawValue: cadRenderBackendRawValue) ?? .defaultBackend)
          .selectableOrDefault
      },
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

  /// The named theme, used to seed a color override control with the preset's
  /// value until the operator picks a custom color.
  private var currentCADTheme: CADViewportTheme { CADViewportTheme.named(cadThemeName) }

  private var cadThemeSelection: Binding<String> {
    Binding(
      get: { cadThemeName },
      set: { CADThemePreferences.applyPreset(named: $0) }
    )
  }

  /// A labelled color override row: shows `default` (the theme color) until the
  /// hex string is set, then persists the picked color as hex.
  private func themeColorRow(
    _ label: String, _ hex: Binding<String>, default themeDefault: SIMD3<Float>
  ) -> some View {
    HStack {
      Text(label).font(.system(size: 12))
      Spacer()
      ColorPicker(
        "", selection: hex.cadColor(themeDefault: themeDefault), supportsOpacity: false
      )
      .labelsHidden()
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

  private var selectedTabOptionalBinding: Binding<StudioSettingsTab?> {
    Binding(
      get: { selectedTabBinding.wrappedValue },
      set: { if let value = $0 { selectedTabBinding.wrappedValue = value } }
    )
  }

  private var defaultLayoutPresetBinding: Binding<StudioLayoutPreset> {
    Binding(
      get: { StudioLayoutPreset(rawValue: defaultLayoutPresetRawValue) ?? .floating },
      set: { defaultLayoutPresetRawValue = $0.rawValue }
    )
  }

  private var defaultImportUnitBinding: Binding<ModelImportUnit> {
    rawBinding($defaultImportUnitRawValue, fallback: .millimeters)
  }

  private var appearanceModeBinding: Binding<StudioAppearanceMode> {
    Binding(
      get: { StudioAppearanceMode(rawValue: appAppearanceModeRawValue) ?? .dark },
      set: {
        appAppearanceModeRawValue = $0.rawValue
        $0.apply()
      }
    )
  }

  private var toolDensityBinding: Binding<StudioToolDensity> {
    Binding(
      get: { StudioToolSettings.shared.density },
      set: { StudioToolSettings.shared.density = $0 }
    )
  }

  private var chromeShapeBinding: Binding<StudioChromeShape> {
    Binding(
      get: { StudioToolSettings.shared.chromeShape },
      set: { StudioToolSettings.shared.chromeShape = $0 }
    )
  }

  private var designPresetBinding: Binding<StudioDesignPreset> {
    Binding(
      get: {
        StudioDesignPreset.allCases.first(where: { $0.profile == designProfile }) ?? .standard
      },
      set: { applyDesignProfile($0.profile) }
    )
  }

  private var accentColorBinding: Binding<Color> {
    Binding(
      get: { designProfile.accent.color },
      set: { color in
        var updated = designProfile
        updated.accent = StudioColorToken(color: color)
        applyDesignProfile(updated)
      }
    )
  }

  private func applyDesignProfile(_ profile: StudioDesignProfile) {
    let applied = profile.clamped()
    designProfile = applied
    StudioDesignRuntime.shared.apply(applied)
    StudioDesignPersistence.save(applied)
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
