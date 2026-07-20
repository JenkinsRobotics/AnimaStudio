// Mac-standard preferences window (⌘,) — tabbed, native chrome, grouped forms.
import SwiftUI

struct SettingsWindow: View {
  var body: some View {
    TabView {
      AppearanceSettings()
        .tabItem { Label("Appearance", systemImage: "paintpalette") }
      RenderSettings()
        .tabItem { Label("Render", systemImage: "cube.transparent") }
      MaterialSettings()
        .tabItem { Label("Materials", systemImage: "paintpalette.fill") }
      LayoutSettings()
        .tabItem { Label("Layout", systemImage: "rectangle.split.3x1") }
      NavigationSettings()
        .tabItem { Label("Navigation", systemImage: "cursorarrow.motionlines") }
      GeneralSettings()
        .tabItem { Label("General", systemImage: "gearshape") }
    }
    .frame(width: 500, height: 400)
  }
}

struct RenderSettings: View {
  @Bindable private var render = RenderState.shared

  var body: some View {
    Form {
      Section {
        Picker("Engine", selection: $render.engine) {
          ForEach(RenderEngine.allCases) { e in
            Text(e.available ? e.rawValue : "\(e.rawValue) — soon").tag(e)
          }
        }
        Text(render.engine.subtitle).font(.caption).foregroundStyle(.secondary)
        if !render.engine.available {
          Label("Not wired yet — the viewport falls back to RealityKit.",
            systemImage: "exclamationmark.triangle.fill")
            .font(.caption).foregroundStyle(.orange)
        }
      } header: {
        Text("Render engine")
      }

      Section {
        LabeledContent("Tessellation") {
          HStack {
            Slider(value: $render.deflectionMillimetres, in: 0.02...1.0)
            Text(String(format: "%.2f mm", render.deflectionMillimetres))
              .font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
              .frame(width: 70, alignment: .trailing)
          }
        }
      } header: {
        Text("Import quality")
      } footer: {
        Text("Lower = finer mesh, slower import. Applies to the next import.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
  }
}

// Materials & lighting — theme presets plus live shading/color/edge/selection
// controls shared by every renderer (RealityKit, Metal, WebGPU, Three.js).
struct MaterialSettings: View {
  @Bindable private var render = RenderState.shared

  var body: some View {
    Form {
      Section {
        Picker("Theme", selection: presetBinding) {
          ForEach(BenchTheme.all) { Text($0.name).tag($0.name) }
        }
        if render.theme.isCustomized {
          HStack {
            Label("Customized", systemImage: "slider.horizontal.3")
              .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Reset") { render.theme = .named(render.theme.name) }
              .controlSize(.small)
          }
        }
      } header: {
        Text("Theme")
      } footer: {
        Text("Presets set shading, lighting, colors, edges, and selection at once. "
          + "Adjust anything below to make a custom variant.")
          .font(.caption).foregroundStyle(.secondary)
      }

      Section("Shading") {
        slider("Roughness", $render.theme.roughness)
        slider("Metallic", $render.theme.metallic)
        slider("Edge strength", $render.theme.edgeStrength)
      }

      Section {
        Toggle("Preserve imported STEP colors", isOn: preserveBinding)
        ColorPicker("Base", selection: color4(\.neutralColor, override: true), supportsOpacity: false)
          .disabled(render.theme.overrideColor == nil)
        ColorPicker("Background", selection: color3(\.background), supportsOpacity: false)
        ColorPicker("Edges", selection: color3(\.edgeColor), supportsOpacity: false)
        ColorPicker("Selection", selection: color3(\.selectionColor), supportsOpacity: false)
      } header: {
        Text("Colors")
      } footer: {
        Text("On: each part keeps the color from the STEP/XDE file. "
          + "Off: the Base color is applied to every part.")
          .font(.caption).foregroundStyle(.secondary)
      }

      Section("Lights") {
        lightRow("Key", \.key)
        lightRow("Fill", \.fill)
        lightRow("Rim", \.rim)
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
  }

  private var presetBinding: Binding<String> {
    Binding(get: { render.theme.name },
      set: { render.theme = .named($0) })
  }

  // Preserve = no override (renderers show each part's imported color).
  private var preserveBinding: Binding<Bool> {
    Binding(
      get: { render.theme.overrideColor == nil },
      set: { render.theme.overrideColor = $0 ? nil : render.theme.neutralColor })
  }

  private func slider(_ label: String, _ value: Binding<Float>) -> some View {
    LabeledContent(label) {
      HStack {
        Slider(value: Binding(get: { Double(value.wrappedValue) },
          set: { value.wrappedValue = Float($0) }), in: 0...1)
        Text(String(format: "%.2f", value.wrappedValue))
          .font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
          .frame(width: 44, alignment: .trailing)
      }
    }
  }

  private func lightRow(_ label: String, _ key: WritableKeyPath<BenchTheme, BenchTheme.Light>) -> some View {
    LabeledContent(label) {
      HStack {
        ColorPicker("", selection: Binding(
          get: { simdToColor3(render.theme[keyPath: key].color) },
          set: { render.theme[keyPath: key].color = colorToSimd3($0) }), supportsOpacity: false)
          .labelsHidden()
        Slider(value: Binding(
          get: { Double(render.theme[keyPath: key].intensity) },
          set: { render.theme[keyPath: key].intensity = Float($0) }), in: 0...6000)
        Text("\(Int(render.theme[keyPath: key].intensity))")
          .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
          .frame(width: 40, alignment: .trailing)
      }
    }
  }

  private func color3(_ key: WritableKeyPath<BenchTheme, SIMD3<Float>>) -> Binding<Color> {
    Binding(get: { simdToColor3(render.theme[keyPath: key]) },
      set: { render.theme[keyPath: key] = colorToSimd3($0) })
  }

  // Base color edits set `overrideColor` (what renderers actually display).
  private func color4(_ key: WritableKeyPath<BenchTheme, SIMD4<Float>>, override: Bool) -> Binding<Color> {
    Binding(
      get: {
        let v = render.theme.overrideColor ?? render.theme.neutralColor
        return Color(red: Double(v.x), green: Double(v.y), blue: Double(v.z))
      },
      set: {
        let s = colorToSimd3($0)
        render.theme.overrideColor = SIMD4<Float>(s.x, s.y, s.z, 1)
      })
  }
}

private func simdToColor3(_ v: SIMD3<Float>) -> Color {
  Color(red: Double(v.x), green: Double(v.y), blue: Double(v.z))
}
private func colorToSimd3(_ c: Color) -> SIMD3<Float> {
  let n = NSColor(c).usingColorSpace(.sRGB) ?? .white
  return SIMD3(Float(n.redComponent), Float(n.greenComponent), Float(n.blueComponent))
}

// Layout — the Studio preset plus per-panel placement for custom layouts.
// (The top-bar layout button cycles presets; this is where you fine-tune.)
struct LayoutSettings: View {
  @Bindable private var layout = LayoutState.shared

  var body: some View {
    Form {
      Section {
        Picker("Preset", selection: presetBinding) {
          ForEach(LayoutPreset.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
      } header: {
        Text("Studio layout")
      } footer: {
        Text("Same as the top-bar layout button. Adjust the panels below for a custom layout.")
          .font(.caption).foregroundStyle(.secondary)
      }

      Section("Panels") {
        Picker("Browser (left)", selection: leftBinding) {
          Text("Docked").tag("docked"); Text("Floating").tag("floating"); Text("Hidden").tag("hidden")
        }
        Picker("Inspector (right)", selection: rightBinding) {
          Text("Docked").tag("docked"); Text("Floating").tag("floating")
          Text("Auto").tag("auto"); Text("Hidden").tag("hidden")
        }
        Picker("Tool ribbon", selection: ribbonBinding) {
          Text("Docked").tag("docked"); Text("Floating").tag("floating")
        }
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
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

struct NavigationSettings: View {
  @Bindable private var nav = NavState.shared

  var body: some View {
    Form {
      Section {
        speedRow("Orbit", $nav.orbitSpeed)
        speedRow("Pan", $nav.panSpeed)
        speedRow("Zoom", $nav.zoomSpeed)
      } header: {
        Text("Sensitivity")
      } footer: {
        Text("1.0× is the Onshape default. Higher = faster.")
          .font(.caption).foregroundStyle(.secondary)
      }

      Section("Invert") {
        Toggle("Orbit horizontal", isOn: $nav.invertOrbitX)
        Toggle("Orbit vertical", isOn: $nav.invertOrbitY)
        Toggle("Zoom direction", isOn: $nav.invertZoom)
      }

      Section {
        row("Rotate", "Left- or right-drag")
        row("Pan", "Middle-drag")
        row("Zoom", "Scroll / pinch")
        row("Fit to view", "Double middle-click")
      } header: {
        Text("Mouse & trackpad")
      } footer: {
        Text("Button mapping is fixed to the Onshape scheme for now.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
  }

  func speedRow(_ label: String, _ value: Binding<Double>) -> some View {
    LabeledContent(label) {
      HStack {
        Slider(value: value, in: 0.25...3.0)
        Text(String(format: "%.2f×", value.wrappedValue))
          .font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
          .frame(width: 56, alignment: .trailing)
      }
    }
  }

  func row(_ action: String, _ gesture: String) -> some View {
    LabeledContent(action) { Text(gesture).foregroundStyle(.secondary) }
  }
}

struct AppearanceSettings: View {
  @Bindable private var theme = ThemeState.shared

  var body: some View {
    Form {
      Section {
        Picker("Appearance", selection: $theme.appearance) {
          ForEach(Appearance.allCases) { mode in
            Label(mode.label, systemImage: mode.icon).tag(mode)
          }
        }
        .pickerStyle(.segmented)
      } header: {
        Text("Theme")
      } footer: {
        Text("System follows macOS. This walkthrough is a design mockup — the "
          + "same tokens drive every panel, so light and dark stay consistent.")
          .font(.caption).foregroundStyle(.secondary)
      }

      Section("Accent") {
        HStack(spacing: 14) {
          ForEach(AccentTheme.allCases) { a in
            Button {
              withAnimation(.easeInOut(duration: 0.15)) { theme.accent = a }
            } label: {
              Circle().fill(a.swatch).frame(width: 24, height: 24)
                .overlay(
                  Circle().stroke(Color.primary.opacity(theme.accent == a ? 0.85 : 0), lineWidth: 2)
                    .padding(-3)
                )
                .overlay(
                  Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white).opacity(theme.accent == a ? 1 : 0))
            }
            .buttonStyle(.plain)
            .help(a.label)
          }
          Spacer()
        }
        .padding(.vertical, 2)
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
  }
}

struct GeneralSettings: View {
  @State private var units = "Millimeters"
  @State private var autosave = true
  @State private var fps = 24.0
  @Bindable private var ribbon = RibbonSettings.shared

  var body: some View {
    Form {
      Section("Project") {
        Picker("Units", selection: $units) {
          ForEach(["Millimeters", "Centimeters", "Inches"], id: \.self) { Text($0).tag($0) }
        }
        Toggle("Autosave", isOn: $autosave)
      }
      Section("Interface") {
        Toggle("Show status bar", isOn: Bindable(LayoutState.shared).showStatusBar)
      }
      Section {
        Picker("Tool popup", selection: $ribbon.popupStyle) {
          ForEach(ToolPopupStyle.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
      } header: {
        Text("Toolbar")
      } footer: {
        Text("How a category's tools appear when you tap its icon — a named list or an icon grid.")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("Timeline") {
        LabeledContent("Frame rate") {
          HStack {
            Slider(value: $fps, in: 12...60, step: 1).frame(width: 160)
            Text("\(Int(fps)) fps").font(.system(.body, design: .monospaced))
              .foregroundStyle(.secondary).frame(width: 56, alignment: .trailing)
          }
        }
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
  }
}
