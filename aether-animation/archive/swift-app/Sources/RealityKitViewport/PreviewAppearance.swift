import AppKit
import SwiftUI

public enum PreviewAppearance: String, CaseIterable, Identifiable, Sendable {
  case midnight
  case graphite
  case cadLight
  case blueprint

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .midnight: "Midnight"
    case .graphite: "Graphite"
    case .cadLight: "CAD Light"
    case .blueprint: "Blueprint"
    }
  }

  public var systemImage: String {
    switch self {
    case .midnight: "moon.stars.fill"
    case .graphite: "circle.lefthalf.filled"
    case .cadLight: "sun.max.fill"
    case .blueprint: "square.grid.3x3.fill"
    }
  }

  public var backgroundColor: Color {
    Color(nsColor: backgroundNSColor)
  }

  public var swatchColor: Color {
    switch self {
    case .midnight: Color(red: 0.08, green: 0.11, blue: 0.20)
    case .graphite: Color(red: 0.24, green: 0.25, blue: 0.28)
    case .cadLight: Color(red: 0.78, green: 0.81, blue: 0.84)
    case .blueprint: Color(red: 0.04, green: 0.24, blue: 0.38)
    }
  }

  var backgroundNSColor: NSColor {
    switch self {
    case .midnight: NSColor(red: 0.035, green: 0.05, blue: 0.095, alpha: 1)
    case .graphite: NSColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1)
    case .cadLight: NSColor(red: 0.78, green: 0.81, blue: 0.84, alpha: 1)
    case .blueprint: NSColor(red: 0.025, green: 0.16, blue: 0.27, alpha: 1)
    }
  }

  var minorGridColor: NSColor {
    switch self {
    case .midnight: NSColor(white: 0.58, alpha: 0.18)
    case .graphite: NSColor(white: 0.72, alpha: 0.19)
    case .cadLight: NSColor(white: 0.16, alpha: 0.16)
    case .blueprint: NSColor(red: 0.15, green: 0.66, blue: 0.82, alpha: 0.20)
    }
  }

  var majorGridColor: NSColor {
    switch self {
    case .midnight: NSColor(red: 0.27, green: 0.50, blue: 0.78, alpha: 0.42)
    case .graphite: NSColor(white: 0.78, alpha: 0.34)
    case .cadLight: NSColor(white: 0.12, alpha: 0.34)
    case .blueprint: NSColor(red: 0.18, green: 0.78, blue: 0.94, alpha: 0.46)
    }
  }

  var lightIntensity: Float {
    self == .cadLight ? 16_000 : 12_000
  }
}
