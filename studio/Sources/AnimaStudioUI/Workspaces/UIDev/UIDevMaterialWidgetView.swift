import AppKit
import SwiftUI

enum UIDevMaterialType: String, CaseIterable, Identifiable, Sendable {
  case glossy
  case matte
  case metallic
  case glass
  case emissive

  var id: Self { self }
  var title: String { rawValue.capitalized }
}

enum UIDevMaterialChannel: String, CaseIterable, Identifiable, Sendable {
  case diffuse
  case specular
  case roughness
  case bump
  case normal
  case displacement

  var id: Self { self }
  var title: String { rawValue.capitalized }

  var defaultValue: Double {
    switch self {
    case .diffuse: 0.88
    case .specular: 0.62
    case .roughness: 0.23
    case .bump: 0.12
    case .normal: 0.50
    case .displacement: 0.03
    }
  }
}

private enum UIDevMaterialInput: String, CaseIterable, Identifiable {
  case float
  case texture

  var id: Self { self }
  var title: String { rawValue.capitalized }
}

struct UIDevMaterialWidgetView: View {
  @State private var materialName = "Gold material"
  @State private var materialType: UIDevMaterialType = .glossy
  @State private var hue = 0.12
  @State private var saturation = 0.34
  @State private var brightness = 0.69
  @State private var selectedChannel: UIDevMaterialChannel = .roughness
  @State private var enabledChannels: Set<UIDevMaterialChannel> = [
    .diffuse, .specular, .roughness, .normal,
  ]
  @State private var channelValues = Dictionary(
    uniqueKeysWithValues: UIDevMaterialChannel.allCases.map { ($0, $0.defaultValue) }
  )
  @State private var input: UIDevMaterialInput = .float
  @State private var mix = 0.03
  @State private var isLocked = false
  @State private var showHelp = false
  @State private var status = "UI-only material draft"

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ScrollView {
        VStack(spacing: 16) {
          previewAndColor
          Divider()
          channelEditor
          actionBar
        }
        .padding(14)
      }
    }
    .frame(maxWidth: 420, minHeight: 590, maxHeight: 650)
    .background(StudioPalette.panel)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Material editor prototype")
  }

  private var header: some View {
    HStack(spacing: 9) {
      Image(systemName: "circle.grid.cross")
        .foregroundStyle(StudioPalette.muted)
      Text("Brushed Metal Material")
        .font(.caption.weight(.semibold))
      Spacer()
      Button(action: previousMaterial) {
        Image(systemName: "chevron.left")
      }
      Button(action: nextMaterial) {
        Image(systemName: "chevron.right")
      }
      Button {
        isLocked.toggle()
        status = isLocked ? "Material controls locked" : "Material controls unlocked"
      } label: {
        Image(systemName: isLocked ? "lock.fill" : "lock.open")
          .foregroundStyle(isLocked ? StudioPalette.hardware : StudioPalette.muted)
      }
      .help(isLocked ? "Unlock material" : "Lock material")
    }
    .buttonStyle(.plain)
    .font(.system(size: 11, weight: .semibold))
    .padding(.horizontal, 14)
    .frame(height: 42)
    .background(StudioPalette.chrome)
  }

  private var previewAndColor: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(spacing: 10) {
        materialSphere
          .frame(width: 106, height: 106)

        TextField("Material name", text: $materialName)
          .textFieldStyle(.plain)
          .font(.caption)
          .padding(.horizontal, 9)
          .frame(height: 30)
          .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 6))

        HStack {
          Text("Type")
            .font(.caption.weight(.medium))
          Spacer()
          Picker("Type", selection: $materialType) {
            ForEach(UIDevMaterialType.allCases) { type in
              Text(type.title).tag(type)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(width: 90)
        }
      }
      .frame(width: 125)

      VStack(spacing: 13) {
        HStack(spacing: 8) {
          Circle()
            .fill(materialColor)
            .frame(width: 10, height: 10)
            .overlay { Circle().stroke(Color.white.opacity(0.65), lineWidth: 2) }
          Text("Color")
            .font(.caption.weight(.medium))
          Spacer()
          ColorPicker("Material color", selection: materialColorBinding, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 46)
        }

        colorSlider(
          value: $hue,
          text: "\(Int((hue * 360).rounded()))°",
          colors: Self.hueColors,
          label: "Hue"
        )
        colorSlider(
          value: $saturation,
          text: "\(Int((saturation * 100).rounded()))%",
          colors: [.white, Color(hue: hue, saturation: 1, brightness: brightness)],
          label: "Saturation"
        )
        colorSlider(
          value: $brightness,
          text: "\(Int((brightness * 100).rounded()))%",
          colors: [.black, Color(hue: hue, saturation: saturation, brightness: 1), .white],
          label: "Brightness"
        )
      }
      .frame(maxWidth: .infinity)
    }
    .disabled(isLocked)
  }

  private var materialSphere: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [.white, materialColor.opacity(0.92), materialColor.opacity(0.45), .black],
            center: UnitPoint(x: 0.34, y: 0.25),
            startRadius: 2,
            endRadius: 78
          )
        )
      Circle()
        .fill(
          LinearGradient(
            colors: [.white.opacity(0.72), .clear, .black.opacity(0.68)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .blendMode(.softLight)
      Ellipse()
        .fill(Color.white.opacity(0.62))
        .frame(width: 26, height: 11)
        .blur(radius: 5)
        .offset(x: -23, y: -27)
    }
    .clipShape(Circle())
    .overlay { Circle().stroke(Color.white.opacity(0.12), lineWidth: 1) }
    .shadow(color: materialColor.opacity(0.30), radius: 12, y: 5)
    .accessibilityLabel("Live material preview sphere")
  }

  private var channelEditor: some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(spacing: 3) {
        ForEach(UIDevMaterialChannel.allCases) { channel in
          channelRow(channel)
        }
      }
      .frame(width: 135)

      Divider()

      VStack(alignment: .leading, spacing: 13) {
        HStack {
          Text(selectedChannel.title)
            .font(.caption.weight(.semibold))
          Spacer()
          Picker("Input", selection: $input) {
            ForEach(UIDevMaterialInput.allCases) { source in
              Text(source.title).tag(source)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(width: 92)
        }

        if input == .texture {
          HStack(spacing: 6) {
            Image(systemName: "photo")
              .foregroundStyle(StudioPalette.accent)
            Text("Choose texture…")
              .font(.caption)
            Spacer()
          }
          .padding(.horizontal, 8)
          .frame(height: 29)
          .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 6))
        }

        valueControl(
          title: selectedChannel == .displacement ? "Distance" : "Value",
          value: channelValueBinding
        )
        valueControl(title: "Mix", value: $mix)

        Text(enabledChannels.contains(selectedChannel) ? "Channel enabled" : "Channel bypassed")
          .font(.caption2.monospaced())
          .foregroundStyle(
            enabledChannels.contains(selectedChannel)
              ? StudioPalette.semanticPart : StudioPalette.muted
          )
      }
      .frame(maxWidth: .infinity)
    }
    .disabled(isLocked)
  }

  private var actionBar: some View {
    VStack(spacing: 10) {
      Text(status)
        .font(.caption2.monospaced())
        .foregroundStyle(StudioPalette.muted)
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 8) {
        Button("Node Editor") {
          status = "Node Editor preview requested"
        }
        .buttonStyle(
          StudioButtonStyle(role: .secondary, density: .compact, expandsHorizontally: false)
        )

        Spacer()

        Button("Assignment") {
          status = "Assignment target selected"
        }
        .buttonStyle(
          StudioButtonStyle(role: .quiet, density: .compact, expandsHorizontally: false)
        )

        Button("Help") {
          showHelp.toggle()
        }
        .buttonStyle(
          StudioButtonStyle(role: .secondary, density: .compact, expandsHorizontally: false)
        )
        .popover(isPresented: $showHelp, arrowEdge: .bottom) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Material widget")
              .font(.headline)
            Text(
              "This prototype edits a UI-only draft. Renderer materials, texture assets, and saved assignments require the material document contract."
            )
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
            .fixedSize(horizontal: false, vertical: true)
          }
          .padding(14)
          .frame(width: 270)
        }
      }
    }
  }

  private func channelRow(_ channel: UIDevMaterialChannel) -> some View {
    let isSelected = selectedChannel == channel
    let isEnabled = enabledChannels.contains(channel)

    return HStack(spacing: 7) {
      Button {
        selectedChannel = channel
      } label: {
        Circle()
          .stroke(isSelected ? StudioPalette.accent : StudioPalette.muted, lineWidth: 1.5)
          .background {
            if isSelected {
              Circle().fill(StudioPalette.accent).padding(3)
            }
          }
          .frame(width: 13, height: 13)
      }
      .buttonStyle(.plain)

      Text(channel.title)
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { selectedChannel = channel }

      Button {
        if isEnabled {
          enabledChannels.remove(channel)
        } else {
          enabledChannels.insert(channel)
        }
      } label: {
        RoundedRectangle(cornerRadius: 3)
          .stroke(isEnabled ? StudioPalette.semanticPart : StudioPalette.border, lineWidth: 1.2)
          .background {
            if isEnabled {
              RoundedRectangle(cornerRadius: 3)
                .fill(StudioPalette.semanticPart)
                .padding(3)
            }
          }
          .frame(width: 14, height: 14)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(isEnabled ? "Disable" : "Enable") \(channel.title)")
    }
    .padding(.horizontal, 5)
    .frame(height: 27)
    .background(
      isSelected ? StudioPalette.accent.opacity(0.10) : Color.clear,
      in: RoundedRectangle(cornerRadius: 6)
    )
  }

  private func colorSlider(
    value: Binding<Double>,
    text: String,
    colors: [Color],
    label: String
  ) -> some View {
    HStack(spacing: 8) {
      Text(text)
        .font(.caption2.monospaced())
        .frame(width: 35, alignment: .trailing)
        .padding(.vertical, 5)
        .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 5))
      UIDevMaterialSlider(value: value, colors: colors)
        .frame(height: 18)
        .accessibilityLabel(label)
    }
  }

  private func valueControl(title: String, value: Binding<Double>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(title)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(StudioPalette.muted)
        Spacer()
        Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
          .font(.caption2.monospaced())
      }
      UIDevMaterialSlider(
        value: value,
        colors: [materialColor.opacity(0.25), materialColor, .white.opacity(0.92)]
      )
      .frame(height: 18)
    }
  }

  private var channelValueBinding: Binding<Double> {
    Binding(
      get: { channelValues[selectedChannel, default: selectedChannel.defaultValue] },
      set: { channelValues[selectedChannel] = $0 }
    )
  }

  private var materialColor: Color {
    Color(hue: hue, saturation: saturation, brightness: brightness)
  }

  private var materialColorBinding: Binding<Color> {
    Binding(
      get: { materialColor },
      set: { color in
        guard let converted = NSColor(color).usingColorSpace(.deviceRGB) else { return }
        var newHue: CGFloat = 0
        var newSaturation: CGFloat = 0
        var newBrightness: CGFloat = 0
        var alpha: CGFloat = 0
        converted.getHue(
          &newHue,
          saturation: &newSaturation,
          brightness: &newBrightness,
          alpha: &alpha
        )
        hue = Double(newHue)
        saturation = Double(newSaturation)
        brightness = Double(newBrightness)
      }
    )
  }

  private func previousMaterial() {
    materialName = "Previous material"
    status = "Previous material previewed"
  }

  private func nextMaterial() {
    materialName = "Next material"
    status = "Next material previewed"
  }

  private static let hueColors: [Color] = [
    .red, .yellow, .green, .cyan, .blue, .purple, .red,
  ]
}

private struct UIDevMaterialSlider: View {
  @Binding var value: Double
  let colors: [Color]

  var body: some View {
    GeometryReader { proxy in
      let progress = CGFloat(min(max(value, 0), 1))
      let availableWidth = max(proxy.size.width - 10, 1)

      ZStack(alignment: .leading) {
        Capsule()
          .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
          .frame(height: 8)
        Circle()
          .fill(Color.white)
          .frame(width: 12, height: 12)
          .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
          .offset(x: availableWidth * progress)
      }
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { gesture in
            value = min(max(Double(gesture.location.x / availableWidth), 0), 1)
          }
      )
    }
  }
}
