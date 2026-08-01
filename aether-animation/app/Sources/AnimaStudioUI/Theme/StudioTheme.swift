import AppKit
import SwiftUI

enum StudioPanelSurfaceMode {
  case docked
  case floating
}

private struct StudioPanelSurfaceModeKey: EnvironmentKey {
  static let defaultValue = StudioPanelSurfaceMode.floating
}

extension EnvironmentValues {
  var studioPanelSurfaceMode: StudioPanelSurfaceMode {
    get { self[StudioPanelSurfaceModeKey.self] }
    set { self[StudioPanelSurfaceModeKey.self] = newValue }
  }
}

enum StudioPalette {
  private static var profile: StudioDesignProfile { StudioDesignRuntime.shared.profile }
  private static var lightProfile: StudioDesignProfile { .standardLight }

  // Structural surfaces resolve per appearance: dark from the (user-editable)
  // profile, light from the fixed light profile. Semantic/accent colors are
  // vivid on both grounds and stay from the active profile (so a custom accent
  // still applies in both modes).
  static var canvas: Color { dynamic(profile.canvas.color, lightProfile.canvas.color) }
  static var documentChrome: Color {
    dynamic(profile.documentChrome.color, lightProfile.documentChrome.color)
  }
  static var chrome: Color { dynamic(profile.chrome.color, lightProfile.chrome.color) }
  static var ribbonChrome: Color {
    dynamic(profile.ribbonChrome.color, lightProfile.ribbonChrome.color)
  }
  static var panel: Color { dynamic(profile.panel.color, lightProfile.panel.color) }
  static var panelInset: Color {
    dynamic(profile.panelInset.color, lightProfile.panelInset.color)
  }
  static var field: Color { dynamic(profile.field.color, lightProfile.field.color) }
  static var accent: Color { profile.accent.color }
  static var sourceModel: Color { profile.sourceModel.color }
  static var semanticPart: Color { profile.semanticPart.color }
  static var joint: Color { profile.joint.color }
  static var hardware: Color { profile.hardware.color }
  /// Primary text/icon ink on adaptive surfaces: near-white on dark, near-black
  /// on light. Use instead of a literal `Color.white` for chrome that sits on a
  /// panel/canvas (a literal white goes invisible in light mode). Text/icons on
  /// the accent color should stay `.white` (accent is dark enough in both modes).
  static var ink: Color { dynamic(.white, Color(red: 0.10, green: 0.11, blue: 0.13)) }

  // Ink flips: white-on-dark, black-on-light.
  static var muted: Color {
    dynamic(
      Color.white.opacity(profile.mutedOpacity),
      Color.black.opacity(lightProfile.mutedOpacity))
  }
  static var border: Color {
    dynamic(
      Color.white.opacity(profile.borderOpacity), Color.black.opacity(lightProfile.borderOpacity))
  }

  /// A color that resolves to `dark` under a dark appearance and `light`
  /// otherwise, so every surface adapts automatically without views observing
  /// the color scheme.
  static func dynamic(_ dark: Color, _ light: Color) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(isDark ? dark : light)
      })
  }
}

enum StudioMetrics {
  private static var profile: StudioDesignProfile { StudioDesignRuntime.shared.profile }

  static var documentBarHeight: CGFloat { profile.documentBarHeight }
  static let workspaceTabBarHeight: CGFloat = 51
  static var compactRibbonHeight: CGFloat { profile.compactRibbonHeight }
  static var rigCreationRibbonHeight: CGFloat { profile.fullRibbonHeight }
  static var panelHeaderHeight: CGFloat { profile.panelHeaderHeight }
  static var panelCornerRadius: CGFloat { profile.panelCornerRadius }
  static var panelPadding: CGFloat { profile.panelPadding }
  static var fieldHeight: CGFloat { profile.fieldHeight }
  static var controlCornerRadius: CGFloat { profile.controlCornerRadius }
  static var navigatorWidth: CGFloat { profile.navigatorWidth }
  static var inspectorWidth: CGFloat { profile.inspectorWidth }
  static var agentWidth: CGFloat { profile.agentWidth }
}

extension View {
  func studioPanelSurface() -> some View {
    modifier(StudioPanelSurfaceModifier())
  }
}

private struct StudioPanelSurfaceModifier: ViewModifier {
  @Environment(\.studioPanelSurfaceMode) private var mode

  func body(content: Content) -> some View {
    let floating = mode == .floating
    let radius = floating ? StudioMetrics.panelCornerRadius : 0
    content
      .background(StudioPalette.panel)
      .clipShape(RoundedRectangle(cornerRadius: radius))
      .overlay {
        RoundedRectangle(cornerRadius: radius)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
      .shadow(color: .black.opacity(floating ? 0.30 : 0), radius: 14, y: 6)
  }
}

struct StudioTextFieldRow: View {
  let title: String
  @Binding var text: String
  var placeholder = ""
  var help: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      StudioFieldLabel(title: title, help: help)
      TextField(placeholder, text: $text)
        .textFieldStyle(.plain)
        .padding(.horizontal, 9)
        .frame(height: StudioMetrics.fieldHeight)
        .background(
          StudioPalette.field,
          in: RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
        )
        .overlay {
          RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
            .stroke(StudioPalette.border, lineWidth: 1)
        }
        .accessibilityLabel(title)
    }
  }
}

struct StudioPickerRow<Value: Hashable, Choices: View>: View {
  let title: String
  @Binding var selection: Value
  var help: String?
  @ViewBuilder let choices: () -> Choices

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      StudioFieldLabel(title: title, help: help)
      Picker(title, selection: $selection, content: choices)
        .labelsHidden()
        .pickerStyle(.segmented)
        .accessibilityLabel(title)
    }
  }
}

struct StudioReadoutRow: View {
  let title: String
  let value: String
  var unit: String?
  var help: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      StudioFieldLabel(title: title, help: help)
      HStack(spacing: 7) {
        Text(value)
          .font(.system(.body, design: .monospaced))
          .textSelection(.enabled)
        Spacer(minLength: 8)
        if let unit {
          Text(unit)
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
      }
      .padding(.horizontal, 9)
      .frame(maxWidth: .infinity, minHeight: StudioMetrics.fieldHeight, alignment: .leading)
      .background(
        StudioPalette.panelInset,
        in: RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
      )
      .overlay {
        RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(title)
      .accessibilityValue(unit.map { "\(value) \($0)" } ?? value)
    }
  }
}

struct StudioNumberFieldRow: View {
  let title: String
  @Binding var value: Double
  var unit: String?
  var help: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      StudioFieldLabel(title: title, help: help)
      HStack(spacing: 7) {
        TextField(title, value: $value, format: .number.precision(.fractionLength(0...3)))
          .textFieldStyle(.plain)
          .font(.system(.body, design: .monospaced))
        if let unit {
          Text(unit)
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
      }
      .padding(.horizontal, 9)
      .frame(height: StudioMetrics.fieldHeight)
      .background(
        StudioPalette.field,
        in: RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
      )
      .overlay {
        RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
      .accessibilityLabel(title)
    }
  }
}

struct StudioFieldLabel: View {
  let title: String
  var help: String?

  var body: some View {
    HStack(spacing: 5) {
      Text(title)
        .font(.caption.weight(.medium))
        .foregroundStyle(StudioPalette.muted)
      if let help {
        Image(systemName: "questionmark.circle")
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
          .help(help)
      }
    }
  }
}

struct StudioSearchField: View {
  let prompt: String
  @Binding var text: String

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(StudioPalette.muted)
      TextField(prompt, text: $text)
        .textFieldStyle(.plain)
      if !text.isEmpty {
        Button("Clear filter", systemImage: "xmark.circle.fill") {
          text = ""
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(StudioPalette.muted)
      }
    }
    .padding(.horizontal, 9)
    .frame(height: StudioMetrics.fieldHeight)
    .background(
      StudioPalette.field,
      in: RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
    )
    .overlay {
      RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .accessibilityLabel(prompt)
  }
}
