import SwiftUI

enum StudioPalette {
  static let canvas = Color(red: 0.105, green: 0.105, blue: 0.125)
  static let chrome = Color(red: 0.15, green: 0.15, blue: 0.18)
  static let panel = Color(red: 0.22, green: 0.23, blue: 0.26)
  static let panelInset = Color(red: 0.16, green: 0.17, blue: 0.19)
  static let field = Color(red: 0.12, green: 0.13, blue: 0.15)
  static let accent = Color(red: 0.12, green: 0.58, blue: 0.90)
  static let muted = Color.white.opacity(0.62)
  static let border = Color.white.opacity(0.10)
}

enum StudioMetrics {
  static let modeBarHeight: CGFloat = 43
  static let toolBarHeight: CGFloat = 47
  static let panelHeaderHeight: CGFloat = 38
  static let panelCornerRadius: CGFloat = 16
  static let panelPadding: CGFloat = 14
  static let fieldHeight: CGFloat = 30
  static let controlCornerRadius: CGFloat = 7
  static let navigatorWidth: CGFloat = 290
  static let inspectorWidth: CGFloat = 320
}

extension View {
  func studioPanelSurface() -> some View {
    background(StudioPalette.panel)
      .clipShape(RoundedRectangle(cornerRadius: StudioMetrics.panelCornerRadius))
      .overlay {
        RoundedRectangle(cornerRadius: StudioMetrics.panelCornerRadius)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
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
        .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 7))
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
      .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 7))
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

struct StudioPrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.callout.weight(.semibold))
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12)
      .frame(minHeight: 32)
      .foregroundStyle(.white)
      .background(
        StudioPalette.accent.opacity(configuration.isPressed ? 0.72 : 1),
        in: RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
      )
  }
}
