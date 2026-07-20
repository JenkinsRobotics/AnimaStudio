// Settings design system, adopted from the Codex Bench settings: page title +
// description, section cards with icon badges, labelled sliders with numeric
// readouts, colour rows, a theme swatch strip, and a material preview sphere.
import AppKit
import SwiftUI

struct SettingsPage<Content: View>: View {
  let title: String
  var subtitle: String? = nil
  @ViewBuilder var content: () -> Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title).font(.system(size: 19, weight: .semibold))
          if let subtitle {
            Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(.bottom, 2)
        content()
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct SettingsSection<Content: View>: View {
  let title: String
  var icon: String
  var footnote: String? = nil
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: icon).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
        Text(title).font(.system(size: 12.5, weight: .semibold))
        Spacer()
      }
      .padding(.horizontal, 14).padding(.vertical, 10)
      Divider()
      VStack(alignment: .leading, spacing: 12) {
        content()
        if let footnote {
          Text(footnote).font(.system(size: 10)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(14)
    }
    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(Color.primary.opacity(0.09), lineWidth: 1))
  }
}

struct SettingsSlider: View {
  let label: String
  @Binding var value: Double
  var range: ClosedRange<Double> = 0...1
  var format: String = "%.2f"

  var body: some View {
    HStack(spacing: 12) {
      Text(label).font(.system(size: 12)).frame(width: 118, alignment: .leading)
      Slider(value: $value, in: range)
      Text(String(format: format, value))
        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
        .frame(width: 54, alignment: .trailing)
    }
  }
}

struct SettingsColorRow: View {
  let label: String
  @Binding var color: Color
  var body: some View {
    HStack {
      Text(label).font(.system(size: 12))
      Spacer()
      ColorPicker("", selection: $color, supportsOpacity: false).labelsHidden()
    }
  }
}

struct SettingsLabeledRow<Trailing: View>: View {
  let label: String
  @ViewBuilder var trailing: () -> Trailing
  var body: some View {
    HStack {
      Text(label).font(.system(size: 12))
      Spacer()
      trailing()
    }
  }
}

/// The theme's palette at a glance — background, model, edges, selection, lights.
struct ThemeSwatchStrip: View {
  let theme: BenchTheme
  var body: some View {
    HStack(spacing: 2) {
      ForEach(Array(swatches.enumerated()), id: \.offset) { _, color in
        Rectangle().fill(color).frame(height: 26)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
  }

  private var swatches: [Color] {
    [
      color3(theme.background),
      color4(theme.overrideColor ?? theme.neutralColor),
      color3(theme.edgeColor),
      color3(theme.selectionColor),
      color3(theme.key.color),
      color3(theme.fill.color),
      color3(theme.rim.color),
    ]
  }
}

/// Approximate preview of the shared roughness/metallic surface values.
struct MaterialPreviewSphere: View {
  var roughness: Double
  var metallic: Double
  var size: CGFloat = 62

  var body: some View {
    Circle()
      .fill(
        RadialGradient(
          colors: [
            Color.white.opacity(0.95 - roughness * 0.55),
            Color(white: 0.55 - metallic * 0.2),
            Color(white: 0.12),
          ],
          center: UnitPoint(x: 0.34, y: 0.28),
          startRadius: 1,
          endRadius: size * (0.55 + roughness * 0.5)))
      .frame(width: size, height: size)
      .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
  }
}

// MARK: - Color <-> SIMD helpers (shared by the settings pages)

func color3(_ v: SIMD3<Float>) -> Color {
  Color(red: Double(v.x), green: Double(v.y), blue: Double(v.z))
}

func color4(_ v: SIMD4<Float>) -> Color {
  Color(red: Double(v.x), green: Double(v.y), blue: Double(v.z))
}

func simd3(_ c: Color) -> SIMD3<Float> {
  let n = NSColor(c).usingColorSpace(.sRGB) ?? .white
  return SIMD3(Float(n.redComponent), Float(n.greenComponent), Float(n.blueComponent))
}
