import AppKit
import GeomBenchCore
import SwiftUI

struct BenchSettingsView: View {
  @Bindable var session: BenchSession

  var body: some View {
    TabView {
      RendererSettingsView(session: session)
        .tabItem { Label("Renderer", systemImage: "cube.transparent") }
      AppearanceSettingsView(session: session)
        .tabItem { Label("Appearance", systemImage: "paintpalette") }
      MaterialEdgeSettingsView(session: session)
        .tabItem { Label("Materials & Edges", systemImage: "square.3.layers.3d") }
      LightingSettingsView(session: session)
        .tabItem { Label("Lighting", systemImage: "light.max") }
    }
    .frame(width: 820, height: 610)
    .padding(.top, 8)
  }
}

private struct RendererSettingsView: View {
  @Bindable var session: BenchSession

  var body: some View {
    HSplitView {
      List(selection: selection) {
        Section("RENDER ENGINES") {
          ForEach(PipelineID.allCases) { pipeline in
            rendererRow(pipeline)
              .tag(pipeline)
          }
        }
      }
      .listStyle(.sidebar)
      .frame(minWidth: 310, idealWidth: 330, maxWidth: 370)

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          settingsHeader(
            "Render Engine",
            subtitle: "Choose the geometry-to-viewport pipeline used by Codex Bench.")
          engineSummary
          configurationCard
          capabilityCard
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private var selection: Binding<PipelineID?> {
    Binding(
      get: { session.pipeline },
      set: { value in
        guard let value, session.capability(for: value)?.available == true else { return }
        session.switchPipeline(value)
      })
  }

  private func rendererRow(_ pipeline: PipelineID) -> some View {
    let capability = session.capability(for: pipeline)
    return HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 7)
          .fill(pipeline == session.pipeline ? Color.accentColor : Color.secondary.opacity(0.15))
        Text("P\(pipeline.rawValue)")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .foregroundStyle(pipeline == session.pipeline ? .white : .secondary)
      }
      .frame(width: 34, height: 28)
      VStack(alignment: .leading, spacing: 2) {
        Text(pipeline.shortName).lineLimit(2)
        Text(pipeline.role.label)
          .font(.caption2).foregroundStyle(.secondary)
      }
      Spacer(minLength: 4)
      Image(
        systemName: capability?.available == true
          ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
      )
      .foregroundStyle(capability?.available == true ? .green : .orange)
      .help(capability?.reason ?? "Capability status unavailable")
    }
    .padding(.vertical, 3)
    .opacity(capability?.available == true ? 1 : 0.55)
  }

  private var engineSummary: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "cube.transparent")
        .font(.system(size: 30)).foregroundStyle(.tint)
        .frame(width: 54, height: 54)
        .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 5) {
        Text("P\(session.pipeline.rawValue) · \(session.pipeline.comparisonName)")
          .font(.title3.weight(.semibold))
        Text(session.pipeline.detail)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var configurationCard: some View {
    SettingsCard("Architecture", systemImage: "point.3.connected.trianglepath.dotted") {
      settingsValue("Geometry kernel", "Open CASCADE Technology")
      settingsValue("Renderer", rendererName)
      settingsValue("Assigned role", session.pipeline.role.label)
      settingsValue("Process model", "Native in-process")
      settingsValue(
        "Input",
        session.pipeline.supportedFilenameExtensions.map { $0.uppercased() }.joined(
          separator: " · "))
      settingsValue("B-Rep topology", session.pipeline.preservesBRep ? "Preserved" : "Mesh only")
      Text(session.pipeline.role.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var capabilityCard: some View {
    let capability = session.capability(for: session.pipeline)
    return SettingsCard("Availability", systemImage: "checkmark.seal") {
      HStack(alignment: .top, spacing: 10) {
        Image(
          systemName: capability?.available == true
            ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        )
        .foregroundStyle(capability?.available == true ? .green : .orange)
        VStack(alignment: .leading, spacing: 3) {
          Text(capability?.available == true ? "Ready" : "Unavailable").fontWeight(.semibold)
          Text(capability?.reason ?? "Capability status unavailable")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
    }
  }

  private var rendererName: String {
    switch session.pipeline {
    case .occtRealityKit: "Apple RealityKit"
    case .occtMetalKit: "Apple MetalKit"
    case .threeJSWebGPU:
      session.rendererBackend.map { "Three.js via \($0) and Apple WebKit" }
        ?? "Three.js WebGPU probing via Apple WebKit"
    case .openCascadeWebGPU:
      session.rendererBackend.map { "\($0) via Apple WebKit" }
        ?? "Raw WebGPU probing via Apple WebKit"
    }
  }
}

private struct AppearanceSettingsView: View {
  @Bindable var session: BenchSession

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        settingsHeader(
          "Appearance",
          subtitle: "Start from a coordinated preset, then tune the shared renderer theme.")

        SettingsCard("Theme Preset", systemImage: "paintpalette.fill") {
          HStack {
            Picker("Preset", selection: presetBinding) {
              ForEach(BenchTheme.all) { theme in Text(theme.name).tag(theme.name) }
            }
            .frame(maxWidth: 280)
            Spacer()
            if session.theme.isCustomized {
              Text("CUSTOM").font(.caption2.weight(.bold)).foregroundStyle(.orange)
              Button("Reset Preset") { session.resetTheme() }
            }
          }
          ThemeSwatchStrip(theme: session.theme)
        }

        SettingsCard("Scene Colors", systemImage: "circle.lefthalf.filled") {
          settingsColorRow("Viewport background", binding: color3(\.background))
          settingsColorRow("Unspecified model color", binding: color4(\.neutralColor))
          settingsColorRow("Face selection", binding: color3(\.selectionColor))
        }

        SettingsCard("Imported Model Colors", systemImage: "shippingbox") {
          Toggle("Preserve colors from STEP/XDE", isOn: preserveImportedColors)
          Text("Turn this off to apply one diagnostic color to every imported face.")
            .font(.caption).foregroundStyle(.secondary)
          settingsColorRow("Model override", binding: overrideColor)
            .disabled(session.theme.overrideColor == nil)
        }
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var presetBinding: Binding<String> {
    Binding(
      get: { session.theme.name },
      set: { session.setTheme(BenchTheme.named($0)) })
  }

  private var preserveImportedColors: Binding<Bool> {
    Binding(
      get: { session.theme.overrideColor == nil },
      set: { preserve in
        session.updateTheme {
          $0.overrideColor = preserve ? nil : $0.neutralColor
        }
      })
  }

  private var overrideColor: Binding<Color> {
    Binding(
      get: { color(session.theme.overrideColor ?? session.theme.neutralColor) },
      set: { value in
        let rgba = rgba(value)
        session.updateTheme { $0.overrideColor = rgba }
      })
  }

  private func color3(_ path: WritableKeyPath<BenchTheme, SIMD3<Float>>) -> Binding<Color> {
    Binding(
      get: { color(session.theme[keyPath: path]) },
      set: { value in
        let rgb = rgb(value)
        session.updateTheme { $0[keyPath: path] = rgb }
      })
  }

  private func color4(_ path: WritableKeyPath<BenchTheme, SIMD4<Float>>) -> Binding<Color> {
    Binding(
      get: { color(session.theme[keyPath: path]) },
      set: { value in
        let rgba = rgba(value)
        session.updateTheme { $0[keyPath: path] = rgba }
      })
  }
}

private struct MaterialEdgeSettingsView: View {
  @Bindable var session: BenchSession

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        settingsHeader(
          "Materials & Edges",
          subtitle: "Configure the common surface finish and CAD feature treatment.")

        SettingsCard("Surface Material", systemImage: "circle.hexagongrid.fill") {
          settingsSlider("Roughness", value: float(\.roughness), range: 0...1)
          settingsSlider("Metallic", value: float(\.metallic), range: 0...1)
          HStack(spacing: 12) {
            MaterialPreview(theme: session.theme)
            Text(
              "These renderer-neutral values are mapped into each backend's closest native material model."
            )
            .font(.caption).foregroundStyle(.secondary)
          }
        }

        SettingsCard("Feature Edges", systemImage: "square.dashed") {
          Toggle("Show B-Rep feature edges", isOn: edgesEnabled)
          settingsSlider("Edge strength", value: float(\.edgeStrength), range: 0...1)
            .disabled(session.theme.edgeStrength <= 0)
          settingsColorRow("Edge color", binding: color3(\.edgeColor))
          settingsColorRow("Selected edge", binding: color3(\.edgeSelectionColor))
        }
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var edgesEnabled: Binding<Bool> {
    Binding(
      get: { session.theme.edgeStrength > 0.02 },
      set: { enabled in session.updateTheme { $0.edgeStrength = enabled ? 0.7 : 0 } })
  }

  private func float(_ path: WritableKeyPath<BenchTheme, Float>) -> Binding<Double> {
    Binding(
      get: { Double(session.theme[keyPath: path]) },
      set: { value in session.updateTheme { $0[keyPath: path] = Float(value) } })
  }

  private func color3(_ path: WritableKeyPath<BenchTheme, SIMD3<Float>>) -> Binding<Color> {
    Binding(
      get: { color(session.theme[keyPath: path]) },
      set: { value in
        let rgb = rgb(value)
        session.updateTheme { $0[keyPath: path] = rgb }
      })
  }
}

private struct LightingSettingsView: View {
  @Bindable var session: BenchSession

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        settingsHeader(
          "Lighting", subtitle: "Balance the common key, fill, and rim rig used by every renderer.")
        Text(
          "Intensity is normalized by each backend so the visual relationship remains comparable."
        )
        .font(.caption).foregroundStyle(.secondary)

        lightCard("Key Light", role: "Defines the primary form and shadow direction.", path: \.key)
        lightCard("Fill Light", role: "Controls contrast on the unlit side.", path: \.fill)
        lightCard("Rim Light", role: "Separates the silhouette from the background.", path: \.rim)
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func lightCard(
    _ title: String, role: String, path: WritableKeyPath<BenchTheme, BenchTheme.Light>
  ) -> some View {
    SettingsCard(title, systemImage: "light.max") {
      Text(role).font(.caption).foregroundStyle(.secondary)
      settingsColorRow("Color", binding: lightColor(path))
      settingsSlider("Relative intensity", value: lightIntensity(path), range: 0...8_000)
    }
  }

  private func lightColor(
    _ path: WritableKeyPath<BenchTheme, BenchTheme.Light>
  ) -> Binding<Color> {
    Binding(
      get: { color(session.theme[keyPath: path].color) },
      set: { value in
        let rgb = rgb(value)
        session.updateTheme { $0[keyPath: path].color = rgb }
      })
  }

  private func lightIntensity(
    _ path: WritableKeyPath<BenchTheme, BenchTheme.Light>
  ) -> Binding<Double> {
    Binding(
      get: { Double(session.theme[keyPath: path].intensity) },
      set: { value in session.updateTheme { $0[keyPath: path].intensity = Float(value) } })
  }
}

private struct SettingsCard<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder let content: Content

  init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.systemImage = systemImage
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 13) {
      Label(title, systemImage: systemImage).font(.headline)
      Divider()
      content
    }
    .padding(16)
    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.35)))
  }
}

private struct ThemeSwatchStrip: View {
  let theme: BenchTheme

  var body: some View {
    HStack(spacing: 0) {
      swatch(theme.background)
      swatch(SIMD3(theme.neutralColor.x, theme.neutralColor.y, theme.neutralColor.z))
      swatch(theme.edgeColor)
      swatch(theme.selectionColor)
      swatch(theme.key.color)
      swatch(theme.fill.color)
      swatch(theme.rim.color)
    }
    .frame(height: 28)
    .clipShape(RoundedRectangle(cornerRadius: 7))
    .overlay(RoundedRectangle(cornerRadius: 7).stroke(.separator.opacity(0.5)))
  }

  private func swatch(_ value: SIMD3<Float>) -> some View {
    Rectangle().fill(color(value)).frame(maxWidth: .infinity)
  }
}

private struct MaterialPreview: View {
  let theme: BenchTheme

  var body: some View {
    Circle()
      .fill(
        RadialGradient(
          colors: [
            color(theme.overrideColor ?? theme.neutralColor).opacity(0.95),
            color(theme.overrideColor ?? theme.neutralColor).opacity(0.55),
            .black.opacity(Double(theme.roughness) * 0.55),
          ], center: .topLeading, startRadius: 3, endRadius: 52)
      )
      .overlay(Circle().stroke(color(theme.edgeColor).opacity(0.8), lineWidth: 1))
      .frame(width: 72, height: 72)
      .shadow(color: .white.opacity(Double(theme.metallic) * 0.18), radius: 8, x: -3, y: -3)
  }
}

private func settingsHeader(_ title: String, subtitle: String) -> some View {
  VStack(alignment: .leading, spacing: 5) {
    Text(title).font(.title2.weight(.semibold))
    Text(subtitle).foregroundStyle(.secondary)
  }
}

private func settingsValue(_ label: String, _ value: String) -> some View {
  HStack(alignment: .firstTextBaseline) {
    Text(label).foregroundStyle(.secondary)
    Spacer()
    Text(value).multilineTextAlignment(.trailing)
  }
}

private func settingsColorRow(_ label: String, binding: Binding<Color>) -> some View {
  HStack {
    Text(label)
    Spacer()
    ColorPicker(label, selection: binding, supportsOpacity: false).labelsHidden()
  }
}

private func settingsSlider(
  _ label: String, value: Binding<Double>, range: ClosedRange<Double>
) -> some View {
  HStack(spacing: 12) {
    Text(label).frame(width: 118, alignment: .leading)
    Slider(value: value, in: range)
    Text(
      value.wrappedValue.formatted(
        .number.precision(.fractionLength(range.upperBound > 10 ? 0 : 2)))
    )
    .monospacedDigit()
    .frame(width: 56, alignment: .trailing)
  }
}

private func color(_ value: SIMD3<Float>) -> Color {
  Color(red: Double(value.x), green: Double(value.y), blue: Double(value.z))
}

private func color(_ value: SIMD4<Float>) -> Color {
  Color(
    red: Double(value.x), green: Double(value.y), blue: Double(value.z), opacity: Double(value.w))
}

private func rgb(_ value: Color) -> SIMD3<Float> {
  let color = NSColor(value).usingColorSpace(.sRGB) ?? NSColor(value)
  return [Float(color.redComponent), Float(color.greenComponent), Float(color.blueComponent)]
}

private func rgba(_ value: Color) -> SIMD4<Float> {
  let color = NSColor(value).usingColorSpace(.sRGB) ?? NSColor(value)
  return [
    Float(color.redComponent), Float(color.greenComponent), Float(color.blueComponent),
    Float(color.alphaComponent),
  ]
}
