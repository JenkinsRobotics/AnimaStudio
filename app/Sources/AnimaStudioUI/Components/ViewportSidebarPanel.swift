import RealityKitViewport
import SwiftUI

private let viewportSidebarFieldOfViewPresets: [Float] = [30, 45, 60, 75, 90]

enum ViewportControlID: String, Hashable, Sendable {
  case viewCube
  case home
  case display
  case mouseSettings
  case cameraHelp
  case visualization
  case performance
}

enum ViewportControlPlacement {
  static let viewportHUD: [ViewportControlID] = [.viewCube, .home]
  static let viewSidebar: [ViewportControlID] = [.display, .mouseSettings, .cameraHelp]
  static let environmentSidebar: [ViewportControlID] = [.visualization]
  static let performanceSidebar: [ViewportControlID] = [.performance]
}

/// The single production control contract for viewport presentation.
///
/// The viewport keeps only spatial controls (ViewCube + Home). Everything
/// that configures camera, display, environment, material, or navigation is
/// projected through this one right-sidebar surface.
struct ConsolidatedViewportSidebarBindings {
  let workspace: StudioWorkspaceModel
  let projection: Binding<PreviewCameraProjection>
  let renderStyle: Binding<ViewportRenderStyle>
  let edgeDisplay: Binding<ViewportEdgeDisplay>
  let lightingPreset: Binding<ViewportLightingPreset>
  let materialFinish: Binding<ViewportMaterialFinish>
  let reflectionMode: Binding<ViewportReflectionMode>
  let showsShadows: Binding<Bool>
  let showsGrid: Binding<Bool>
  let appearance: Binding<PreviewAppearance>
  let fieldOfViewDegrees: Binding<Float>
  let lightingIntensity: Binding<Double>
  let environmentPreset: Binding<ViewportEnvironmentPreset>
  let environmentRotationDegrees: Binding<Double>
  let renderQuality: Binding<ViewportRenderQuality>
  let navigationProfile: Binding<PreviewNavigationProfile>
  let customRotateDrag: Binding<NavigationDragBinding>
  let customPanDrag: Binding<NavigationDragBinding>
  let customPreciseZoomDrag: Binding<NavigationDragBinding>
  let orbitSpeed: Binding<PreviewNavigationSpeed>
  let panSpeed: Binding<PreviewNavigationSpeed>
  let zoomSpeed: Binding<PreviewNavigationSpeed>
  let reversesWheelZoom: Binding<Bool>
  let showsPerformanceHUD: Binding<Bool>
  let openMouseSettings: () -> Void
}

struct ConsolidatedViewportSidebarPanel<Inspector: View>: View {
  let tab: StudioViewSidebarTab
  let viewport: ConsolidatedViewportSidebarBindings
  @ViewBuilder let inspector: Inspector

  @Environment(\.studioPanelSurfaceMode) private var surfaceMode
  @State private var showsCameraHelp = false
  @State private var showsSaveViewPrompt = false
  @State private var newViewName = ""

  private var state: StudioViewSidebarState { .shared }

  var body: some View {
    if tab == .inspector {
      inspector
    } else {
      VStack(alignment: .leading, spacing: 0) {
        WorkspacePanelHeader(title: tab.rawValue, systemImage: tab.systemImage)
        switch tab {
        case .view:
          scrollable(viewControls)
        case .environment:
          visualizationControls
        case .appearance:
          scrollable(appearanceControls)
        case .performance:
          scrollable(performanceControls)
        case .inspector:
          EmptyView()
        }
        if surfaceMode == .docked { Spacer(minLength: 0) }
      }
      .studioPanelSurface()
      .alert("Save Named View", isPresented: $showsSaveViewPrompt) {
        TextField("View name", text: $newViewName)
        Button("Cancel", role: .cancel) {}
        Button("Save") { viewport.workspace.saveNamedCameraView(name: newViewName) }
      } message: {
        Text("Save the current camera orientation, target, distance, and projection.")
      }
    }
  }

  private func scrollable<Content: View>(_ content: Content) -> some View {
    ScrollView {
      content
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var viewControls: some View {
    VStack(alignment: .leading, spacing: 11) {
      Text("CAMERA").studioViewportSidebarCaption()
      Picker("Projection", selection: viewport.projection) {
        ForEach(PreviewCameraProjection.allCases) { projection in
          Text(projection.title).tag(projection)
        }
      }
      .controlSize(.small)

      Picker("Field of view", selection: viewport.fieldOfViewDegrees) {
        ForEach(viewportSidebarFieldOfViewPresets, id: \.self) { degrees in
          Text("\(Int(degrees))°").tag(degrees)
        }
      }
      .controlSize(.small)
      .disabled(viewport.projection.wrappedValue == .orthographic)

      HStack(spacing: 5) {
        sidebarButton("Frame selection", systemImage: "viewfinder") {
          viewport.workspace.frameSelection()
        }
        .disabled(!viewport.workspace.canFrameSelection)

        sidebarButton("Previous view", systemImage: "arrow.uturn.backward") {
          viewport.workspace.restorePreviousCameraView()
        }
        .disabled(viewport.workspace.previousCameraState == nil)

        Menu {
          ForEach(viewport.workspace.namedCameraViews) { view in
            Button(view.name) { viewport.workspace.restoreNamedCameraView(id: view.id) }
          }
          if !viewport.workspace.namedCameraViews.isEmpty { Divider() }
          Button("Save Current View…", systemImage: "plus") {
            newViewName = "View \(viewport.workspace.namedCameraViews.count + 1)"
            showsSaveViewPrompt = true
          }
          if !viewport.workspace.namedCameraViews.isEmpty {
            Menu("Delete Named View", systemImage: "trash") {
              ForEach(viewport.workspace.namedCameraViews) { view in
                Button(view.name, role: .destructive) {
                  viewport.workspace.deleteNamedCameraView(id: view.id)
                }
              }
            }
          }
        } label: {
          Image(systemName: "bookmark")
            .frame(width: 32, height: 28)
            .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 7))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Named views")
      }

      Divider()
      Text("DISPLAY").studioViewportSidebarCaption()
      Picker("Surface", selection: viewport.renderStyle) {
        ForEach(ViewportRenderStyle.allCases) { style in
          Label(style.title, systemImage: style.systemImage).tag(style)
        }
      }
      .controlSize(.small)

      Picker("Edges", selection: viewport.edgeDisplay) {
        ForEach(ViewportEdgeDisplay.allCases) { display in
          Label(display.title, systemImage: display.systemImage).tag(display)
        }
      }
      .controlSize(.small)
      .disabled(viewport.renderStyle.wrappedValue == .wireframe)

      Toggle("Grid", isOn: viewport.showsGrid)
      Toggle("Section view", isOn: sectionEnabledBinding)
      Toggle("High quality", isOn: highQualityBinding)
      Toggle(
        "Origin",
        isOn: Binding(get: { state.showsOrigin }, set: { state.showsOrigin = $0 })
      )
      .controlSize(.small)

      Divider()
      Text("CAMERA NAVIGATION").studioViewportSidebarCaption()
      HStack(spacing: 4) {
        ForEach(StudioCameraNavigationMode.allCases) { mode in
          Button {
            state.selectNavigation(mode)
          } label: {
            Image(systemName: mode.systemImage)
              .frame(width: 32, height: 28)
              .background(
                state.navigationMode == mode ? StudioPalette.accent : StudioPalette.panelInset,
                in: RoundedRectangle(cornerRadius: 7)
              )
          }
          .buttonStyle(.plain)
          .help("\(mode.rawValue) camera")
        }
      }

      Picker("Mouse profile", selection: viewport.navigationProfile) {
        ForEach(PreviewNavigationProfile.allCases) { profile in
          Text(profile.displayName).tag(profile)
        }
      }
      .controlSize(.small)

      if viewport.navigationProfile.wrappedValue == .custom {
        Picker("Rotate", selection: viewport.customRotateDrag) {
          ForEach(NavigationDragBinding.allCases) { binding in
            Text(binding.title).tag(binding)
          }
        }
        Picker("Pan", selection: viewport.customPanDrag) {
          ForEach(NavigationDragBinding.allCases) { binding in
            Text(binding.title).tag(binding)
          }
        }
        Picker("Precise zoom", selection: viewport.customPreciseZoomDrag) {
          ForEach(NavigationDragBinding.allCases) { binding in
            Text(binding.title).tag(binding)
          }
        }
        .controlSize(.small)
      }

      Menu("Navigation speed", systemImage: "gauge.with.dots.needle.33percent") {
        Picker("Orbit", selection: viewport.orbitSpeed) { speedChoices }
        Picker("Pan", selection: viewport.panSpeed) { speedChoices }
        Picker("Zoom", selection: viewport.zoomSpeed) { speedChoices }
      }
      .controlSize(.small)

      Toggle("Reverse wheel zoom", isOn: viewport.reversesWheelZoom)
        .controlSize(.small)

      Button("Mouse Settings…", systemImage: "computermouse") {
        viewport.openMouseSettings()
      }
      .buttonStyle(.bordered)
      .controlSize(.small)

      DisclosureGroup("Camera Help", isExpanded: $showsCameraHelp) {
        VStack(alignment: .leading, spacing: 5) {
          ForEach(navigationInstructions, id: \.self) { instruction in
            Text(instruction)
          }
          Text("Scroll or pinch — zoom")
          Text("Click geometry — select")
          Text("Escape — clear selection")
        }
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
        .padding(.top, 5)
      }
      .font(.caption.weight(.semibold))
    }
  }

  private var visualizationControls: some View {
    ViewportVisualizationPanel(
      workspace: viewport.workspace,
      lightingIntensity: viewport.lightingIntensity,
      environmentPreset: viewport.environmentPreset,
      environmentRotationDegrees: viewport.environmentRotationDegrees,
      renderSettings: ViewportVisualizationRenderBindings(
        lightingPreset: viewport.lightingPreset,
        materialFinish: viewport.materialFinish,
        reflectionMode: viewport.reflectionMode,
        showsShadows: viewport.showsShadows
      ),
      presentation: .sidebar,
      initialTab: .environment
    )
  }

  private var appearanceControls: some View {
    VStack(alignment: .leading, spacing: 11) {
      Text("VIEWPORT THEME").studioViewportSidebarCaption()
      Picker("Theme", selection: viewport.appearance) {
        ForEach(PreviewAppearance.allCases) { appearance in
          Text(appearance.title).tag(appearance)
        }
      }
      .controlSize(.small)

      Toggle(
        "Keep imported colors",
        isOn: Binding(
          get: { state.keepsImportedColors },
          set: { state.keepsImportedColors = $0 }
        )
      )
      Text("PREVIEW OPACITY").studioViewportSidebarCaption()
      Slider(value: Binding(get: { state.opacity }, set: { state.opacity = $0 }), in: 0.2...1)
    }
    .controlSize(.small)
  }

  private var performanceControls: some View {
    VStack(alignment: .leading, spacing: 11) {
      Text("VIEWPORT HUD").studioViewportSidebarCaption()
      Toggle("Show engine frame status", isOn: viewport.showsPerformanceHUD)
        .controlSize(.small)
      Text(
        "The runtime card stays at bottom-right, clear of the center-view switcher and any open View panels."
      )
      .font(.caption)
      .foregroundStyle(StudioPalette.muted)

      Divider()
      Text("LIVE STATUS").studioViewportSidebarCaption()
      LabeledContent("Engine", value: viewport.workspace.animaCoreStatusLabel)
      LabeledContent(
        "Evaluated frame",
        value: viewport.workspace.engineEvaluationTimeSeconds.map {
          String(format: "%.3f s", $0)
        } ?? "Waiting"
      )
    }
    .controlSize(.small)
  }

  private var sectionEnabledBinding: Binding<Bool> {
    Binding(
      get: { viewport.workspace.viewportSectionPlane.isEnabled },
      set: { value in
        var section = viewport.workspace.viewportSectionPlane
        section.isEnabled = value
        viewport.workspace.setViewportSectionPlane(section)
      }
    )
  }

  private var highQualityBinding: Binding<Bool> {
    Binding(
      get: { viewport.renderQuality.wrappedValue == .high },
      set: { viewport.renderQuality.wrappedValue = $0 ? .high : .standard }
    )
  }

  private var navigationInstructions: [String] {
    switch viewport.navigationProfile.wrappedValue {
    case .onshape:
      ["Right-drag — orbit / tilt", "Middle-drag — pan"]
    case .default, .solidWorks:
      [
        "Middle-drag — orbit / tilt",
        "Option + middle-drag — pan",
        "Shift + middle-drag — precise zoom",
      ]
    case .fusion360:
      ["Shift + middle-drag — orbit / tilt", "Middle-drag — pan"]
    case .custom:
      [
        "\(viewport.customRotateDrag.wrappedValue.title) — orbit / tilt",
        "\(viewport.customPanDrag.wrappedValue.title) — pan",
        "\(viewport.customPreciseZoomDrag.wrappedValue.title) — precise zoom",
      ]
    }
  }

  private var speedChoices: some View {
    ForEach(PreviewNavigationSpeed.allCases) { speed in
      Text(speed.title).tag(speed)
    }
  }

  private func sidebarButton(
    _ title: String,
    systemImage: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .frame(width: 32, height: 28)
        .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(.plain)
    .help(title)
    .accessibilityLabel(title)
  }
}

extension View {
  fileprivate func studioViewportSidebarCaption() -> some View {
    font(.system(size: 9.5, weight: .semibold))
      .tracking(0.6)
      .foregroundStyle(StudioPalette.muted)
  }
}
