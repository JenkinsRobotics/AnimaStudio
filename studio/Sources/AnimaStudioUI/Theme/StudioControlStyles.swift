import SwiftUI

enum StudioButtonRole: Sendable {
  case primary
  case secondary
  case quiet
  case destructive
}

enum StudioControlDensity: Sendable {
  case compact
  case regular

  var minimumHeight: CGFloat {
    switch self {
    case .compact: 26
    case .regular: 32
    }
  }
}

/// The canonical button treatment for Studio-owned controls.
struct StudioButtonStyle: ButtonStyle {
  var role: StudioButtonRole = .primary
  var density: StudioControlDensity = .regular
  var expandsHorizontally = true

  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.callout.weight(role == .quiet ? .medium : .semibold))
      .lineLimit(1)
      .padding(.horizontal, density == .compact ? 9 : 12)
      .frame(
        maxWidth: expandsHorizontally ? .infinity : nil,
        minHeight: density.minimumHeight
      )
      .foregroundStyle(foregroundColor)
      .background(backgroundColor(isPressed: configuration.isPressed), in: controlShape)
      .overlay {
        controlShape
          .stroke(borderColor, lineWidth: role == .quiet ? 0 : 1)
      }
      .opacity(isEnabled ? 1 : 0.42)
      .contentShape(controlShape)
  }

  private var controlShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
  }

  private var foregroundColor: Color {
    switch role {
    case .primary, .destructive: .white
    case .secondary: .white.opacity(0.88)
    case .quiet: StudioPalette.muted
    }
  }

  private func backgroundColor(isPressed: Bool) -> Color {
    let pressedOpacity = isPressed ? 0.72 : 1.0
    return switch role {
    case .primary: StudioPalette.accent.opacity(pressedOpacity)
    case .secondary: StudioPalette.panelInset.opacity(pressedOpacity)
    case .quiet:
      isPressed ? StudioPalette.panelInset : .clear
    case .destructive: Color.red.opacity(isPressed ? 0.68 : 0.82)
    }
  }

  private var borderColor: Color {
    switch role {
    case .primary: StudioPalette.accent.opacity(0.85)
    case .secondary: StudioPalette.border
    case .quiet: .clear
    case .destructive: Color.red.opacity(0.88)
    }
  }
}

/// Retains the existing call site while routing it through the canonical style.
typealias StudioPrimaryButtonStyle = StudioButtonStyle

struct StudioIconButtonStyle: ButtonStyle {
  var isSelected = false

  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.callout.weight(.semibold))
      .foregroundStyle(isSelected ? .white : StudioPalette.muted)
      .frame(width: 30, height: 30)
      .background(
        isSelected
          ? StudioPalette.accent.opacity(configuration.isPressed ? 0.58 : 0.82)
          : StudioPalette.panelInset.opacity(configuration.isPressed ? 0.74 : 1),
        in: RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
      )
      .overlay {
        RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
      .opacity(isEnabled ? 1 : 0.42)
      .contentShape(Rectangle())
  }
}

struct StudioSectionHeader: View {
  let title: String
  let detail: String
  var systemImage: String?

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 9) {
      if let systemImage {
        Image(systemName: systemImage)
          .foregroundStyle(StudioPalette.accent)
      }
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline)
        Text(detail)
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }
      Spacer(minLength: 12)
    }
  }
}

/// Canonical chrome for docked panels and auxiliary window content.
struct StudioPanelHeader<Trailing: View>: View {
  let title: String
  let detail: String
  let systemImage: String
  @ViewBuilder let trailing: () -> Trailing

  init(
    title: String,
    detail: String,
    systemImage: String,
    @ViewBuilder trailing: @escaping () -> Trailing
  ) {
    self.title = title
    self.detail = detail
    self.systemImage = systemImage
    self.trailing = trailing
  }

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: systemImage)
        .foregroundStyle(StudioPalette.accent)
      VStack(alignment: .leading, spacing: 1) {
        Text(title.uppercased())
          .font(.caption.weight(.bold))
          .tracking(0.8)
        Text(detail)
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
      }
      Spacer(minLength: 8)
      trailing()
    }
    .padding(.horizontal, 14)
    .frame(height: 52)
    .background(StudioPalette.chrome)
  }
}

extension StudioPanelHeader where Trailing == EmptyView {
  init(title: String, detail: String, systemImage: String) {
    self.init(title: title, detail: detail, systemImage: systemImage) {
      EmptyView()
    }
  }
}

extension View {
  func studioCardSurface() -> some View {
    padding(StudioMetrics.panelPadding)
      .background(
        StudioPalette.panel,
        in: RoundedRectangle(cornerRadius: StudioMetrics.panelCornerRadius)
      )
      .overlay {
        RoundedRectangle(cornerRadius: StudioMetrics.panelCornerRadius)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
  }

  func studioPopupSurface() -> some View {
    padding(12)
      .background(
        StudioPalette.panel,
        in: RoundedRectangle(cornerRadius: StudioMetrics.panelCornerRadius)
      )
      .overlay {
        RoundedRectangle(cornerRadius: StudioMetrics.panelCornerRadius)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
  }
}
