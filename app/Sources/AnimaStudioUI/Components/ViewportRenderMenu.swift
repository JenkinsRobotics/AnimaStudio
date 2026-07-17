import RealityKitViewport
import SwiftUI

struct ViewportRenderMenu: View {
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
  @Binding var lightingIntensity: Double
  @Binding var environmentPreset: ViewportEnvironmentPreset
  @Binding var environmentRotationDegrees: Double
  @Binding var renderQuality: ViewportRenderQuality
  @Binding var navigationProfile: PreviewNavigationProfile
  @Binding var customRotateDrag: NavigationDragBinding
  @Binding var customPanDrag: NavigationDragBinding
  @Binding var customPreciseZoomDrag: NavigationDragBinding
  @Binding var orbitSpeed: PreviewNavigationSpeed
  @Binding var panSpeed: PreviewNavigationSpeed
  @Binding var zoomSpeed: PreviewNavigationSpeed
  @Binding var reversesWheelZoom: Bool
  let canFrameSelection: Bool
  let frameSelection: () -> Void
  @State private var showsEnvironmentSettings = false
  @State private var showsSaveViewPrompt = false
  @State private var newViewName = ""

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

        Button("Previous View", systemImage: "arrow.uturn.backward") {
          workspace.restorePreviousCameraView()
        }
        .disabled(workspace.previousCameraState == nil)

        Menu("Named Views", systemImage: "bookmark") {
          ForEach(workspace.namedCameraViews) { view in
            Button(view.name) { workspace.restoreNamedCameraView(id: view.id) }
          }
          if !workspace.namedCameraViews.isEmpty { Divider() }
          Button("Save Current View…", systemImage: "plus") {
            newViewName = "View \(workspace.namedCameraViews.count + 1)"
            showsSaveViewPrompt = true
          }
          if !workspace.namedCameraViews.isEmpty {
            Menu("Delete Named View") {
              ForEach(workspace.namedCameraViews) { view in
                Button(view.name, role: .destructive) {
                  workspace.deleteNamedCameraView(id: view.id)
                }
              }
            }
          }
        }
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

        Picker("Material Finish", selection: $materialFinish) {
          ForEach(ViewportMaterialFinish.allCases) { finish in
            Text(finish.title).tag(finish)
          }
        }
        .disabled(renderStyle != .shaded && renderStyle != .shadedWithEdges)

        Picker("Reflections", selection: $reflectionMode) {
          ForEach(ViewportReflectionMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .disabled(renderStyle != .shaded && renderStyle != .shadedWithEdges)

        Toggle("Cast Shadows", systemImage: "shadow", isOn: $showsShadows)

        Picker("Edges", selection: $edgeDisplay) {
          ForEach(ViewportEdgeDisplay.allCases) { display in
            Label(display.title, systemImage: display.systemImage)
              .tag(display)
          }
        }
        .disabled(renderStyle == .wireframe)

        Toggle("Show Grid", systemImage: "grid", isOn: $showsGrid)

        Toggle(
          "Section View",
          systemImage: "square.split.diagonal",
          isOn: sectionEnabledBinding
        )

        Toggle(
          "View in High Quality",
          systemImage: "sparkles",
          isOn: highQualityBinding
        )
      }

      Section("Viewport Appearance") {
        Picker("Appearance", selection: $appearance) {
          ForEach(PreviewAppearance.allCases) { appearance in
            Text(appearance.title).tag(appearance)
          }
        }
        Button("Environment & Background…", systemImage: "mountain.2") {
          showsEnvironmentSettings = true
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

          Picker("Precise Zoom", selection: $customPreciseZoomDrag) {
            ForEach(NavigationDragBinding.allCases) { binding in
              Text(binding.title).tag(binding)
            }
          }
        }

        Menu("Navigation Speed", systemImage: "gauge.with.dots.needle.33percent") {
          Picker("Orbit Speed", selection: $orbitSpeed) {
            speedChoices
          }
          Picker("Pan Speed", selection: $panSpeed) {
            speedChoices
          }
          Picker("Zoom Speed", selection: $zoomSpeed) {
            speedChoices
          }
        }

        Toggle("Reverse Wheel Zoom", isOn: $reversesWheelZoom)

        Label("Select · Left Click", systemImage: "cursorarrow.click")
        Label(
          "Orbit · \(navigationProfile.summary(customMapping: CustomNavigationMapping(rotateDrag: customRotateDrag, panDrag: customPanDrag, preciseZoomDrag: customPreciseZoomDrag)).orbit)",
          systemImage: "rotate.3d"
        )
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
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .help("Camera and render options")
    .accessibilityLabel("Camera and render options")
    .popover(isPresented: $showsEnvironmentSettings) {
      ViewportEnvironmentSettingsView(
        background: viewportBackgroundBinding,
        sectionPlane: viewportSectionBinding,
        lightingIntensity: $lightingIntensity,
        environmentPreset: $environmentPreset,
        environmentRotationDegrees: $environmentRotationDegrees
      )
    }
    .alert("Save Named View", isPresented: $showsSaveViewPrompt) {
      TextField("View name", text: $newViewName)
      Button("Cancel", role: .cancel) {}
      Button("Save") { workspace.saveNamedCameraView(name: newViewName) }
    } message: {
      Text("Save the current camera orientation, target, distance, and projection.")
    }
  }

  private static let fieldOfViewPresets: [Float] = [30, 45, 60, 75, 90]

  private var viewportBackgroundBinding: Binding<ViewportBackgroundSettings> {
    Binding(
      get: { workspace.viewportBackground },
      set: { workspace.setViewportBackground($0) }
    )
  }

  private var viewportSectionBinding: Binding<ViewportSectionPlane> {
    Binding(
      get: { workspace.viewportSectionPlane },
      set: { workspace.setViewportSectionPlane($0) }
    )
  }

  private var sectionEnabledBinding: Binding<Bool> {
    Binding(
      get: { workspace.viewportSectionPlane.isEnabled },
      set: { value in
        var section = workspace.viewportSectionPlane
        section.isEnabled = value
        workspace.setViewportSectionPlane(section)
      }
    )
  }

  private var highQualityBinding: Binding<Bool> {
    Binding(
      get: { renderQuality == .high },
      set: { renderQuality = $0 ? .high : .standard }
    )
  }

  @ViewBuilder
  private var speedChoices: some View {
    ForEach(PreviewNavigationSpeed.allCases) { speed in
      Text(speed.title).tag(speed)
    }
  }
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
