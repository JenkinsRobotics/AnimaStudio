import SwiftUI

/// One application-wide visual theme. Surface, text, and semantic color values
/// intentionally follow the sibling AnimaStudio Demo design system so CodexUI
/// can compare layouts without a competing visual language.
enum PrototypeTheme: String, CaseIterable, Identifiable {
  case studio = "Studio Blue"
  case teal = "Studio Teal"
  case indigo = "Studio Indigo"
  case orangeAccent = "Studio Orange"
  case graphite = "Graphite"
  case cadLight = "CAD Light"
  case midnight = "Midnight"

  var id: String { rawValue }

  var preferredColorScheme: ColorScheme { isLight ? .light : .dark }
  var isLight: Bool { self == .cadLight }

  var canvas: Color {
    if isLight { return Color(hex: 0xF2F4F8) }
    if self == .midnight { return Color(hex: 0x06090F) }
    return Color(hex: 0x0E1013)
  }

  var panel: Color {
    if isLight { return .white }
    if self == .midnight { return Color(hex: 0x0D121B) }
    return Color(hex: 0x171A20)
  }

  var raised: Color {
    if isLight { return Color(hex: 0xEDF0F5) }
    if self == .midnight { return Color(hex: 0x151C28) }
    return Color(hex: 0x1E222A)
  }

  var toolbar: Color { panel }
  var inset: Color {
    if isLight { return Color(hex: 0xE9ECF1) }
    if self == .midnight { return Color(hex: 0x080C13) }
    return Color(hex: 0x0F1216)
  }

  var primaryText: Color { Color(hex: isLight ? 0x1A1E27 : 0xE7E9ED) }
  var secondaryText: Color { Color(hex: isLight ? 0x5B636F : 0x9AA1AB) }
  var tertiaryText: Color { Color(hex: isLight ? 0x9BA2AD : 0x646B76) }
  var iconText: Color { secondaryText }
  var line: Color { isLight ? .black.opacity(0.08) : .white.opacity(0.07) }
  var strongLine: Color { isLight ? .black.opacity(0.13) : .white.opacity(0.12) }

  var accent: Color {
    switch self {
    case .teal: Color(hex: isLight ? 0x11A594 : 0x36D6C3)
    case .indigo: Color(hex: isLight ? 0x5B54E0 : 0x8B87FF)
    case .orangeAccent: Color(hex: isLight ? 0xEC6D1F : 0xFF9A4D)
    case .graphite: Color(hex: isLight ? 0x5B6270 : 0x9AA3AE)
    case .studio, .midnight: Color(hex: isLight ? 0x2E6BF6 : 0x4C9DFF)
    case .cadLight: Color(hex: 0x2E6BF6)
    }
  }

  var controlFill: Color { raised }
  var controlHover: Color { isLight ? .black.opacity(0.06) : .white.opacity(0.07) }
  var cyan: Color { Color(hex: isLight ? 0x11A594 : 0x36D6C3) }
  var purple: Color { Color(hex: isLight ? 0x5B54E0 : 0x8B87FF) }
  var orange: Color { Color(hex: isLight ? 0xEC6D1F : 0xFF8A3D) }
  var green: Color { Color(hex: isLight ? 0x27B36A : 0x4CD07A) }
  var danger: Color { Color(hex: isLight ? 0xE5484D : 0xFF5A5F) }

  func ribbonTint(_ name: String) -> Color {
    switch name {
    case "teal": cyan
    case "purple": purple
    case "orange": orange
    case "green": green
    case "red": danger
    case "pink": Color(hex: isLight ? 0xC13B78 : 0xFF6EBA)
    case "indigo": Color(hex: isLight ? 0x5B54E0 : 0x8B87FF)
    default: accent
    }
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: 1)
  }
}

enum PrototypeDesignMetrics {
  static let panelRadius: CGFloat = 10
  static let floatingPanelRadius: CGFloat = 12
  static let controlRadius: CGFloat = 7
  static let panelHorizontalPadding: CGFloat = 12
  static let contentPadding: CGFloat = 10
}

private struct PrototypeThemeKey: EnvironmentKey {
  static let defaultValue = PrototypeTheme.studio
}

extension EnvironmentValues {
  var prototypeTheme: PrototypeTheme {
    get { self[PrototypeThemeKey.self] }
    set { self[PrototypeThemeKey.self] = newValue }
  }
}
