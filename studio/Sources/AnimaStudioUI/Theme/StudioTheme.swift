import SwiftUI

enum StudioPalette {
  private static var profile: StudioDesignProfile { StudioDesignRuntime.shared.profile }

  static var canvas: Color { profile.canvas.color }
  static var documentChrome: Color { profile.documentChrome.color }
  static var chrome: Color { profile.chrome.color }
  static var ribbonChrome: Color { profile.ribbonChrome.color }
  static var panel: Color { profile.panel.color }
  static var panelInset: Color { profile.panelInset.color }
  static var field: Color { profile.field.color }
  static var accent: Color { profile.accent.color }
  static var sourceModel: Color { profile.sourceModel.color }
  static var semanticPart: Color { profile.semanticPart.color }
  static var joint: Color { profile.joint.color }
  static var hardware: Color { profile.hardware.color }
  static var muted: Color { Color.white.opacity(profile.mutedOpacity) }
  static var border: Color { Color.white.opacity(profile.borderOpacity) }
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
