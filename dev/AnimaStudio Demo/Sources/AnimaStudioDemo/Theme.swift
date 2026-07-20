// Theme state — light/dark + accent, the single source of truth the design
// tokens read from. @Observable so any view that touches a UI.* token in its
// body re-renders when appearance or accent changes.
import AppKit
import Metal
import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
  case system, light, dark
  var id: String { rawValue }
  var label: String { rawValue.capitalized }
  var icon: String {
    switch self {
    case .system: return "circle.lefthalf.filled"
    case .light: return "sun.max"
    case .dark: return "moon"
    }
  }
}

enum AccentTheme: String, CaseIterable, Identifiable {
  case blue, teal, indigo, orange, graphite
  var id: String { rawValue }
  var label: String { rawValue.capitalized }
  func color(dark: Bool) -> Color {
    switch self {
    case .blue: return Color(hex: dark ? 0x4C9DFF : 0x2E6BF6)
    case .teal: return Color(hex: dark ? 0x36D6C3 : 0x11A594)
    case .indigo: return Color(hex: dark ? 0x8B87FF : 0x5B54E0)
    case .orange: return Color(hex: dark ? 0xFF9A4D : 0xEC6D1F)
    case .graphite: return Color(hex: dark ? 0x9AA3AE : 0x5B6270)
    }
  }
  var swatch: Color { color(dark: true) }
}

@Observable final class ThemeState {
  static let shared = ThemeState()

  var appearance: Appearance = .dark
  var accent: AccentTheme = .blue

  var isDark: Bool {
    switch appearance {
    case .dark: return true
    case .light: return false
    case .system:
      return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
  }

  var resolvedScheme: ColorScheme? {
    switch appearance {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }

  /// Quick toggle for the top-bar sun/moon button.
  func toggleLightDark() {
    appearance = isDark ? .light : .dark
  }
}

// Render settings — the selectable render engine + import tessellation quality.
enum RenderEngine: String, CaseIterable, Identifiable {
  case realityKit = "RealityKit"
  case metal = "Metal"
  case rayTraced = "Ray Traced"
  case webGPU = "WebGPU"
  case threeJS = "Three.js"
  var id: String { rawValue }
  var available: Bool {
    // Ray tracing needs Apple-Silicon hardware RT; the rest are always wired.
    self == .rayTraced ? (MTLCreateSystemDefaultDevice()?.supportsRaytracing ?? false) : true
  }
  var subtitle: String {
    switch self {
    case .realityKit: return "Apple RealityKit · native Metal (default)"
    case .metal: return "Custom MetalKit renderer — raw buffers"
    case .rayTraced: return "Metal hardware ray tracing — traced shadows (Apple Silicon)"
    case .webGPU: return "navigator.gpu · WGSL in a WKWebView (portable)"
    case .threeJS: return "Three.js on WebGPU in a WKWebView (portable)"
    }
  }
}

@Observable final class RenderState {
  static let shared = RenderState()
  var engine: RenderEngine = .realityKit
  var deflectionMillimetres: Double = 0.2   // tessellation quality (lower = finer)
  var theme: BenchTheme = .studioBlue       // shading/lighting/color/edges/selection — shared by every engine
  var pinPerformance = false                // pinned live-stats HUD in the viewport corner
}

// Navigation preferences — speed/scale + invert, adjustable in Settings.
@Observable final class NavState {
  static let shared = NavState()
  var orbitSpeed: Double = 1.0
  var panSpeed: Double = 1.0
  var zoomSpeed: Double = 1.0
  var invertOrbitX = false
  var invertOrbitY = false
  var invertZoom = false
}
