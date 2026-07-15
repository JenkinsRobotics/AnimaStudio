import AnimaCore
import AppKit
import RealityKitViewport
import SwiftUI

enum ComponentInspectorTab: String, CaseIterable, Identifiable {
  case properties
  case appearance

  var id: Self { self }

  var title: String {
    switch self {
    case .properties: "Properties"
    case .appearance: "Appearance"
    }
  }

  var systemImage: String {
    switch self {
    case .properties: "slider.horizontal.3"
    case .appearance: "paintpalette"
    }
  }
}

private enum ComponentAppearanceMode: String, CaseIterable, Identifiable {
  case palette
  case mixer

  var id: Self { self }

  var title: String { rawValue.capitalized }
}

struct ComponentAppearanceEditor: View {
  @Bindable var workspace: StudioWorkspaceModel
  let part: RigPartDefinition

  @State private var mode = ComponentAppearanceMode.palette

  var body: some View {
    Section("Appearance") {
      Picker("Color Editor", selection: $mode) {
        ForEach(ComponentAppearanceMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)

      switch mode {
      case .palette:
        paletteGrid
      case .mixer:
        mixer
      }
    }

    Section("Color") {
      HStack(spacing: 10) {
        RoundedRectangle(cornerRadius: 5)
          .fill(displayColor)
          .frame(width: 48, height: 30)
          .overlay {
            RoundedRectangle(cornerRadius: 5)
              .stroke(StudioPalette.border, lineWidth: 1)
          }
        ComponentHexColorField(appearance: appearanceBinding)
      }
      LabeledContent(
        "RGB",
        value: "\(redByte)   \(greenByte)   \(blueByte)"
      )
      .font(.system(.caption, design: .monospaced))
    }

    Section("Body") {
      Toggle("Visible", isOn: visibilityBinding)
      VStack(alignment: .leading, spacing: 5) {
        HStack {
          Text("Opacity")
          Spacer()
          Text("\(Int((appearance.opacity * 100).rounded()))%")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(StudioPalette.muted)
        }
        Slider(value: opacityBinding, in: 0.05...1)
      }
      LabeledContent("Tessellation Quality", value: "Automatic")
      Text("Proxy primitives use RealityKit's generated inspection geometry.")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      Button("Reset Appearance", systemImage: "arrow.counterclockwise") {
        workspace.resetComponentAppearance(id: part.id)
      }
      .buttonStyle(StudioButtonStyle(role: .secondary, density: .compact))
    }

    Section("Persistence") {
      Label(
        "This override is kept for the current Studio session. Project-file persistence arrives with the document layer.",
        systemImage: "info.circle"
      )
      .font(.caption)
      .foregroundStyle(StudioPalette.muted)
    }
  }

  private var paletteGrid: some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8),
      spacing: 4
    ) {
      ForEach(Self.paletteHex, id: \.self) { hex in
        Button {
          applyHex(hex)
        } label: {
          ZStack {
            RoundedRectangle(cornerRadius: 3)
              .fill(color(for: hex))
              .aspectRatio(1, contentMode: .fit)
            if appearance.hexRGB == hex {
              Image(systemName: "checkmark")
                .font(.caption2.weight(.black))
                .foregroundStyle(contrastColor(for: hex))
            }
          }
        }
        .buttonStyle(.plain)
        .help(hex)
        .accessibilityLabel("Set component color to \(hex)")
        .accessibilityValue(appearance.hexRGB == hex ? "Selected" : "")
      }
    }
    .padding(.vertical, 3)
  }

  private var mixer: some View {
    VStack(spacing: 9) {
      ColorPicker("Body Color", selection: colorBinding, supportsOpacity: false)
      channelRow("R", color: .red, keyPath: \.red)
      channelRow("G", color: .green, keyPath: \.green)
      channelRow("B", color: .blue, keyPath: \.blue)
    }
  }

  private func channelRow(
    _ title: String,
    color: Color,
    keyPath: WritableKeyPath<PreviewPartAppearance, Double>
  ) -> some View {
    HStack(spacing: 7) {
      Text(title)
        .font(.caption.weight(.bold))
        .foregroundStyle(color)
        .frame(width: 12)
      Slider(value: channelBinding(keyPath), in: 0...1)
      Text("\(Int((appearance[keyPath: keyPath] * 255).rounded()))")
        .font(.system(.caption, design: .monospaced))
        .frame(width: 28, alignment: .trailing)
    }
  }

  private var appearance: PreviewPartAppearance {
    workspace.componentAppearance(for: part.id) ?? .defaultAppearance(for: part.primitiveKind)
  }

  private var appearanceBinding: Binding<PreviewPartAppearance> {
    Binding(
      get: { appearance },
      set: { workspace.setComponentAppearance(id: part.id, to: $0) }
    )
  }

  private var colorBinding: Binding<Color> {
    Binding(
      get: { displayColor },
      set: { color in
        let source = NSColor(color)
        let resolved = source.usingColorSpace(.sRGB) ?? source
        var updated = appearance
        updated.red = Double(resolved.redComponent)
        updated.green = Double(resolved.greenComponent)
        updated.blue = Double(resolved.blueComponent)
        workspace.setComponentAppearance(id: part.id, to: updated)
      }
    )
  }

  private var visibilityBinding: Binding<Bool> {
    Binding(
      get: { appearance.isVisible },
      set: { isVisible in
        var updated = appearance
        updated.isVisible = isVisible
        workspace.setComponentAppearance(id: part.id, to: updated)
      }
    )
  }

  private var opacityBinding: Binding<Double> {
    Binding(
      get: { appearance.opacity },
      set: { opacity in
        var updated = appearance
        updated.opacity = opacity
        workspace.setComponentAppearance(id: part.id, to: updated)
      }
    )
  }

  private func channelBinding(
    _ keyPath: WritableKeyPath<PreviewPartAppearance, Double>
  ) -> Binding<Double> {
    Binding(
      get: { appearance[keyPath: keyPath] },
      set: { value in
        var updated = appearance
        updated[keyPath: keyPath] = value
        workspace.setComponentAppearance(id: part.id, to: updated)
      }
    )
  }

  private var displayColor: Color {
    Color(red: appearance.red, green: appearance.green, blue: appearance.blue)
  }

  private var redByte: Int { Int((appearance.red * 255).rounded()) }
  private var greenByte: Int { Int((appearance.green * 255).rounded()) }
  private var blueByte: Int { Int((appearance.blue * 255).rounded()) }

  private func applyHex(_ hex: String) {
    guard
      let color = PreviewPartAppearance(
        hexRGB: hex,
        opacity: appearance.opacity,
        isVisible: appearance.isVisible
      )
    else { return }
    workspace.setComponentAppearance(id: part.id, to: color)
  }

  private func color(for hex: String) -> Color {
    guard let value = PreviewPartAppearance(hexRGB: hex) else { return .clear }
    return Color(red: value.red, green: value.green, blue: value.blue)
  }

  private func contrastColor(for hex: String) -> Color {
    guard let value = PreviewPartAppearance(hexRGB: hex) else { return .white }
    let luminance = 0.2126 * value.red + 0.7152 * value.green + 0.0722 * value.blue
    return luminance > 0.55 ? .black : .white
  }

  private static let paletteHex = [
    "#202124", "#FFFFFF", "#D9E2EC", "#9FB3C8", "#486581", "#243B53", "#102A43", "#7B8794",
    "#F7CAC9", "#F28B82", "#EA4335", "#C5221F", "#FAD2CF", "#F6AEA9", "#D93025", "#A50E0E",
    "#FCE8B2", "#FDD663", "#F9AB00", "#E37400", "#FFF475", "#FBC02D", "#F29900", "#B06000",
    "#CCFF90", "#81C995", "#34A853", "#188038", "#A7FFEB", "#35B9AD", "#00897B", "#00695C",
    "#CBF0F8", "#8AB4F8", "#4285F4", "#185ABC", "#D7AEFB", "#A970FF", "#8430CE", "#5B1A91",
  ]
}

private struct ComponentHexColorField: View {
  @Binding var appearance: PreviewPartAppearance
  @State private var draft: String
  @FocusState private var isFocused: Bool

  init(appearance: Binding<PreviewPartAppearance>) {
    _appearance = appearance
    _draft = State(initialValue: appearance.wrappedValue.hexRGB)
  }

  var body: some View {
    TextField("#RRGGBB", text: $draft)
      .textFieldStyle(.roundedBorder)
      .font(.system(.callout, design: .monospaced))
      .focused($isFocused)
      .onSubmit(commit)
      .onChange(of: isFocused) { _, focused in
        if !focused { commit() }
      }
      .onChange(of: appearance.hexRGB) { _, hex in
        if !isFocused { draft = hex }
      }
      .accessibilityLabel("Hex color")
  }

  private func commit() {
    guard
      let updated = PreviewPartAppearance(
        hexRGB: draft,
        opacity: appearance.opacity,
        isVisible: appearance.isVisible
      )
    else {
      draft = appearance.hexRGB
      return
    }
    appearance = updated
    draft = updated.hexRGB
  }
}
