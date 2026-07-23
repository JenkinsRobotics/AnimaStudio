// Mac preferences (⌘,) — Codex-Bench-style pages: title + description, section
// cards with icon badges, labelled sliders with readouts, and colour rows.
import SwiftUI

struct SettingsWindow: View {
  var body: some View {
    TabView {
      RendererSettings().tabItem { Label("Renderer", systemImage: "cube.transparent") }
      SceneAppearanceSettings().tabItem { Label("Appearance", systemImage: "paintpalette") }
      MaterialEdgeSettings().tabItem { Label("Materials & Edges", systemImage: "square.3.layers.3d") }
      LightingSettings().tabItem { Label("Lighting", systemImage: "light.max") }
      LayoutSettings().tabItem { Label("Layout", systemImage: "rectangle.split.3x1") }
      NavigationSettings().tabItem { Label("Navigation", systemImage: "cursorarrow.motionlines") }
      InterfaceSettings().tabItem { Label("UI", systemImage: "sidebar.squares.left") }
    }
    .frame(width: 620, height: 570)
  }
}

// MARK: - Renderer

struct RendererSettings: View {
  @Bindable private var render = RenderState.shared

  var body: some View {
    SettingsPage(title: "Renderer",
      subtitle: "Choose the backend that draws the viewport, and how finely imported CAD is tessellated.") {
      SettingsSection(title: "Render Engine", icon: "cube.transparent") {
        SettingsLabeledRow(label: "Engine") {
          Picker("", selection: $render.engine) {
            ForEach(RenderEngine.allCases) { engine in
              Text(engine.available ? engine.rawValue : "\(engine.rawValue) — unavailable").tag(engine)
            }
          }
          .labelsHidden().frame(width: 190)
        }
        Text(render.engine.subtitle).font(.system(size: 10.5)).foregroundStyle(.secondary)
        if !render.engine.available {
          Label("Not available on this device — the viewport falls back to Metal.",
            systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 10.5)).foregroundStyle(.orange)
        }
      }

      SettingsSection(title: "Import Quality", icon: "square.grid.3x3",
        footnote: "Lower deflection means a finer mesh and a slower import. Applies to the next import.") {
        SettingsSlider(label: "Tessellation", value: $render.deflectionMillimetres,
          range: 0.02...1.0, format: "%.2f mm")
      }

      SettingsSection(title: "Viewport Overlays", icon: "move.3d") {
        Toggle("Show character origin axes", isOn: $render.showOrigin).font(.system(size: 12))
        Toggle("Show orientation view cube", isOn: $render.showViewCube).font(.system(size: 12))
        Toggle("Pin the performance HUD to the corner", isOn: $render.pinPerformance)
          .font(.system(size: 12))
      }
    }
  }
}

// MARK: - Appearance (scene)

struct SceneAppearanceSettings: View {
  @Bindable private var render = RenderState.shared

  var body: some View {
    SettingsPage(title: "Appearance",
      subtitle: "Start from a coordinated preset, then tune the shared renderer theme.") {
      SettingsSection(title: "Theme Preset", icon: "paintpalette") {
        SettingsLabeledRow(label: "Preset") {
          Picker("", selection: presetBinding) {
            ForEach(BenchTheme.all) { Text($0.name).tag($0.name) }
          }
          .labelsHidden().frame(width: 190)
        }
        ThemeSwatchStrip(theme: render.theme)
        if render.theme.isCustomized {
          HStack {
            Text("Customized").font(.system(size: 10.5)).foregroundStyle(.secondary)
            Spacer()
            Button("Reset preset") { render.theme = .named(render.theme.name) }
              .controlSize(.small)
          }
        }
      }

      SettingsSection(title: "Scene Colors", icon: "circle.lefthalf.filled") {
        SettingsColorRow(label: "Viewport background", color: bind(\.background))
        SettingsColorRow(label: "Unspecified model color", color: neutralBinding)
        SettingsColorRow(label: "Face selection", color: bind(\.selectionColor))
      }

      SettingsSection(title: "Imported Model Colors", icon: "cube",
        footnote: "Turn this off to apply one diagnostic color to every imported face.") {
        Toggle("Preserve colors from STEP/XDE", isOn: preserveBinding).font(.system(size: 12))
        SettingsColorRow(label: "Model override", color: overrideBinding)
          .disabled(render.theme.overrideColor == nil)
      }
    }
  }

  private var presetBinding: Binding<String> {
    Binding(get: { render.theme.name }, set: { render.theme = .named($0) })
  }

  private var preserveBinding: Binding<Bool> {
    Binding(
      get: { render.theme.overrideColor == nil },
      set: { render.theme.overrideColor = $0 ? nil : render.theme.neutralColor })
  }

  private var neutralBinding: Binding<Color> {
    Binding(get: { color4(render.theme.neutralColor) },
      set: { c in let s = simd3(c); render.theme.neutralColor = SIMD4(s.x, s.y, s.z, 1) })
  }

  private var overrideBinding: Binding<Color> {
    Binding(
      get: { color4(render.theme.overrideColor ?? render.theme.neutralColor) },
      set: { c in let s = simd3(c); render.theme.overrideColor = SIMD4(s.x, s.y, s.z, 1) })
  }

  private func bind(_ key: WritableKeyPath<BenchTheme, SIMD3<Float>>) -> Binding<Color> {
    Binding(get: { color3(render.theme[keyPath: key]) },
      set: { render.theme[keyPath: key] = simd3($0) })
  }
}

// MARK: - Materials & Edges

struct MaterialEdgeSettings: View {
  @Bindable private var render = RenderState.shared

  var body: some View {
    SettingsPage(title: "Materials & Edges",
      subtitle: "Configure the common surface finish and CAD feature-edge treatment.") {
      SettingsSection(title: "Surface Material", icon: "circle.dashed") {
        SettingsSlider(label: "Roughness", value: float(\.roughness))
        SettingsSlider(label: "Metallic", value: float(\.metallic))
        HStack(alignment: .center, spacing: 14) {
          MaterialPreviewSphere(
            roughness: Double(render.theme.roughness), metallic: Double(render.theme.metallic))
          Text("These renderer-neutral values are mapped into each backend's closest native material model.")
            .font(.system(size: 10.5)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      SettingsSection(title: "Feature Edges", icon: "square.dashed") {
        Toggle("Show B-Rep feature edges", isOn: edgesBinding).font(.system(size: 12))
        SettingsSlider(label: "Edge strength", value: float(\.edgeStrength))
        SettingsColorRow(label: "Edge color", color: bind(\.edgeColor))
        SettingsColorRow(label: "Selected edge", color: bind(\.edgeSelectionColor))
      }
    }
  }

  private var edgesBinding: Binding<Bool> {
    Binding(get: { render.theme.edgeStrength > 0 },
      set: { render.theme.edgeStrength = $0 ? 0.7 : 0 })
  }

  private func float(_ key: WritableKeyPath<BenchTheme, Float>) -> Binding<Double> {
    Binding(get: { Double(render.theme[keyPath: key]) },
      set: { render.theme[keyPath: key] = Float($0) })
  }

  private func bind(_ key: WritableKeyPath<BenchTheme, SIMD3<Float>>) -> Binding<Color> {
    Binding(get: { color3(render.theme[keyPath: key]) },
      set: { render.theme[keyPath: key] = simd3($0) })
  }
}

// MARK: - Lighting

struct LightingSettings: View {
  @Bindable private var render = RenderState.shared

  var body: some View {
    SettingsPage(title: "Lighting",
      subtitle: "Balance the common key, fill, and rim rig used by every renderer. Intensity is normalized by each backend so the visual relationship stays comparable.") {
      light("Key Light", "Defines the primary form and shadow direction.", \.key)
      light("Fill Light", "Controls contrast on the unlit side.", \.fill)
      light("Rim Light", "Separates the silhouette from the background.", \.rim)
    }
  }

  private func light(_ title: String, _ detail: String,
    _ key: WritableKeyPath<BenchTheme, BenchTheme.Light>) -> some View
  {
    SettingsSection(title: title, icon: "light.max") {
      Text(detail).font(.system(size: 10.5)).foregroundStyle(.secondary)
      SettingsColorRow(label: "Color", color: Binding(
        get: { color3(render.theme[keyPath: key].color) },
        set: { render.theme[keyPath: key].color = simd3($0) }))
      SettingsSlider(label: "Relative intensity", value: Binding(
        get: { Double(render.theme[keyPath: key].intensity) },
        set: { render.theme[keyPath: key].intensity = Float($0) }),
        range: 0...8000, format: "%.0f")
    }
  }
}

// MARK: - Layout

struct LayoutSettings: View {
  @Bindable private var layout = LayoutState.shared

  var body: some View {
    SettingsPage(title: "Layout",
      subtitle: "The Studio layout preset controls every panel at once. Fine-tune individual panels below.") {
      SettingsSection(title: "Studio Layout", icon: "rectangle.split.3x1",
        footnote: "Matches the layout button at the right of the toolbar.") {
        Picker("", selection: presetBinding) {
          ForEach(LayoutPreset.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented).labelsHidden()
        Toggle("Push panels to the outer edge", isOn: $layout.panelsOnOuterEdge)
          .font(.system(size: 12))
      }

      SettingsSection(title: "Panels", icon: "sidebar.leading") {
        SettingsLabeledRow(label: "Browser (left)") {
          Picker("", selection: leftBinding) {
            Text("Docked").tag("docked"); Text("Floating").tag("floating"); Text("Hidden").tag("hidden")
          }.labelsHidden().frame(width: 150)
        }
        SettingsLabeledRow(label: "Inspector (right)") {
          Picker("", selection: rightBinding) {
            Text("Docked").tag("docked"); Text("Floating").tag("floating")
            Text("Auto").tag("auto"); Text("Hidden").tag("hidden")
          }.labelsHidden().frame(width: 150)
        }
        SettingsLabeledRow(label: "Tool ribbon") {
          Picker("", selection: ribbonBinding) {
            Text("Docked").tag("docked"); Text("Floating").tag("floating")
          }.labelsHidden().frame(width: 150)
        }
      }
    }
  }

  private func animate(_ change: @escaping () -> Void) {
    withAnimation(.spring(response: 0.34, dampingFraction: 0.86), change)
  }

  private var presetBinding: Binding<LayoutPreset> {
    Binding(get: { layout.detectedPreset ?? .floating }, set: { p in animate { layout.apply(p) } })
  }

  private var leftBinding: Binding<String> {
    Binding(
      get: { !layout.showLeft ? "hidden" : (layout.leftDocked ? "docked" : "floating") },
      set: { v in
        animate {
          switch v {
          case "hidden": layout.showLeft = false
          case "docked": layout.showLeft = true; layout.leftDocked = true
          default: layout.showLeft = true; layout.leftDocked = false
          }
        }
      })
  }

  private var rightBinding: Binding<String> {
    Binding(
      get: {
        if !layout.showRight { return "hidden" }
        return layout.rightDocked ? "docked" : (layout.rightPinned ? "floating" : "auto")
      },
      set: { v in
        animate {
          switch v {
          case "hidden": layout.showRight = false
          case "docked": layout.showRight = true; layout.rightDocked = true
          case "floating": layout.showRight = true; layout.rightDocked = false; layout.rightPinned = true
          default: layout.showRight = true; layout.rightDocked = false; layout.rightPinned = false
          }
        }
      })
  }

  private var ribbonBinding: Binding<String> {
    Binding(get: { layout.ribbonDocked ? "docked" : "floating" },
      set: { v in animate { layout.ribbonDocked = (v == "docked") } })
  }
}

// MARK: - Navigation

struct NavigationSettings: View {
  @Bindable private var nav = NavState.shared

  var body: some View {
    SettingsPage(title: "Navigation",
      subtitle: "Mouse and trackpad behaviour in the 3D viewport. 1.00× matches the Onshape defaults.") {
      SettingsSection(title: "Sensitivity", icon: "cursorarrow.motionlines") {
        SettingsSlider(label: "Orbit", value: $nav.orbitSpeed, range: 0.25...3, format: "%.2f×")
        SettingsSlider(label: "Pan", value: $nav.panSpeed, range: 0.25...3, format: "%.2f×")
        SettingsSlider(label: "Zoom", value: $nav.zoomSpeed, range: 0.25...3, format: "%.2f×")
      }

      SettingsSection(title: "Invert", icon: "arrow.left.arrow.right") {
        Toggle("Orbit horizontal", isOn: $nav.invertOrbitX).font(.system(size: 12))
        Toggle("Orbit vertical", isOn: $nav.invertOrbitY).font(.system(size: 12))
        Toggle("Zoom direction", isOn: $nav.invertZoom).font(.system(size: 12))
      }

      SettingsSection(title: "Mouse & Trackpad", icon: "magicmouse",
        footnote: "Button mapping follows the Onshape scheme.") {
        mapping("Rotate", "Left- or right-drag")
        mapping("Pan", "Middle-drag")
        mapping("Zoom", "Scroll / pinch")
        mapping("Fit to view", "Double middle-click")
        mapping("Select", "Left-click (no drag)")
      }
    }
  }

  private func mapping(_ action: String, _ gesture: String) -> some View {
    HStack {
      Text(action).font(.system(size: 12))
      Spacer()
      Text(gesture).font(.system(size: 11)).foregroundStyle(.secondary)
    }
  }
}

// MARK: - Interface

struct InterfaceSettings: View {
  @Bindable private var theme = ThemeState.shared
  @Bindable private var ribbon = RibbonSettings.shared
  @Bindable private var layout = LayoutState.shared
  @State private var units = "Millimeters"
  @State private var autosave = true
  @State private var fps = 24.0

  var body: some View {
    SettingsPage(title: "Interface",
      subtitle: "App chrome, tool presentation, and project defaults.") {
      SettingsSection(title: "Theme", icon: "circle.lefthalf.filled",
        footnote: "System follows macOS. The same tokens drive every panel, so light and dark stay consistent.") {
        Picker("", selection: $theme.appearance) {
          ForEach(Appearance.allCases) { mode in Label(mode.label, systemImage: mode.icon).tag(mode) }
        }
        .pickerStyle(.segmented).labelsHidden()
        HStack(spacing: 14) {
          ForEach(AccentTheme.allCases) { accent in
            Button {
              withAnimation(.easeInOut(duration: 0.15)) { theme.accent = accent }
            } label: {
              Circle().fill(accent.swatch).frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.primary.opacity(theme.accent == accent ? 0.85 : 0), lineWidth: 2).padding(-3))
                .overlay(Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                  .foregroundStyle(.white).opacity(theme.accent == accent ? 1 : 0))
            }
            .buttonStyle(.plain).help(accent.label)
          }
          Spacer()
        }
      }

      SettingsSection(title: "Chrome", icon: "macwindow") {
        Toggle("Show status bar", isOn: $layout.showStatusBar).font(.system(size: 12))
        Toggle("Dev: show layout zones", isOn: $layout.showZones).font(.system(size: 12))
      }

      SettingsSection(title: "Sidebars", icon: "sidebar.squares.left",
        footnote: "The tool sidebar (top), workspace sidebar (left), and view sidebar (right). Panels toggle from their rail, stack, and can be dragged off to float.") {
        SettingsLabeledRow(label: "Layout mode") {
          Picker("", selection: Binding(
            get: { layout.detectedPreset ?? .floating },
            set: { layout.apply($0) })) {
            ForEach(LayoutPreset.allCases) { Label($0.label, systemImage: $0.icon).tag($0) }
          }
          .labelsHidden().frame(width: 170)
        }
        Toggle("Push panels to the outer edge", isOn: $layout.panelsOnOuterEdge)
          .font(.system(size: 12))
        SettingsLabeledRow(label: "Tool density") {
          Picker("", selection: $ribbon.density) {
            ForEach(ToolDensity.allCases) { Text($0.rawValue).tag($0) }
          }
          .pickerStyle(.segmented).labelsHidden().frame(width: 210)
        }
        SettingsLabeledRow(label: "Tool popup") {
          Picker("", selection: $ribbon.popupStyle) {
            ForEach(ToolPopupStyle.allCases) { Text($0.rawValue).tag($0) }
          }
          .pickerStyle(.segmented).labelsHidden().frame(width: 150)
        }
      }

      SettingsSection(title: "Project", icon: "folder") {
        SettingsLabeledRow(label: "Units") {
          Picker("", selection: $units) {
            ForEach(["Millimeters", "Centimeters", "Inches"], id: \.self) { Text($0).tag($0) }
          }.labelsHidden().frame(width: 150)
        }
        Toggle("Autosave", isOn: $autosave).font(.system(size: 12))
        SettingsSlider(label: "Frame rate", value: $fps, range: 12...60, format: "%.0f fps")
      }
    }
  }
}
