import AppKit
import SwiftUI

public struct ViewportColor: Equatable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double

  public init(red: Double, green: Double, blue: Double) {
    self.red = min(max(red, 0), 1)
    self.green = min(max(green, 0), 1)
    self.blue = min(max(blue, 0), 1)
  }

  public init(_ color: NSColor) {
    let color = color.usingColorSpace(.sRGB) ?? color
    self.init(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
  }

  public var nsColor: NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
  }

  public var color: Color { Color(nsColor: nsColor) }
}

public enum ViewportBackgroundMode: String, CaseIterable, Identifiable, Sendable {
  case preset
  case solid
  case gradient

  public var id: String { rawValue }
  public var title: String { rawValue.capitalized }
}

public struct ViewportBackgroundSettings: Equatable, Sendable {
  public var mode: ViewportBackgroundMode
  public var preset: PreviewAppearance
  public var primary: ViewportColor
  public var secondary: ViewportColor

  public init(
    mode: ViewportBackgroundMode = .preset,
    preset: PreviewAppearance = .midnight,
    primary: ViewportColor = ViewportColor(red: 0.035, green: 0.05, blue: 0.095),
    secondary: ViewportColor = ViewportColor(red: 0.12, green: 0.18, blue: 0.30)
  ) {
    self.mode = mode
    self.preset = preset
    self.primary = primary
    self.secondary = secondary
  }

  public var palette: PreviewAppearance { preset }

  @ViewBuilder public var background: some View {
    switch mode {
    case .preset:
      preset.backgroundColor
    case .solid:
      primary.color
    case .gradient:
      LinearGradient(
        colors: [primary.color, secondary.color],
        startPoint: .top,
        endPoint: .bottom
      )
    }
  }
}

public enum ViewportEnvironmentPreset: String, CaseIterable, Identifiable, Sendable {
  case softbox
  case rim
  case warmStage

  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .softbox: "Neutral Softbox"
    case .rim: "Cool Rim Studio"
    case .warmStage: "Warm Stage"
    }
  }
}

public enum ViewportRenderQuality: String, CaseIterable, Identifiable, Sendable {
  case standard
  case high

  public var id: String { rawValue }
  public var title: String { self == .high ? "High (4× MSAA)" : "Standard" }
}

public enum ViewportSectionAxis: String, CaseIterable, Identifiable, Sendable {
  case x
  case y
  case z

  public var id: String { rawValue }
  public var title: String { rawValue.uppercased() }
}

public struct ViewportSectionPlane: Equatable, Sendable {
  public var isEnabled: Bool
  public var axis: ViewportSectionAxis
  public var positionMeters: Double

  public init(
    isEnabled: Bool = false,
    axis: ViewportSectionAxis = .x,
    positionMeters: Double = 0
  ) {
    self.isEnabled = isEnabled
    self.axis = axis
    self.positionMeters = positionMeters
  }
}
