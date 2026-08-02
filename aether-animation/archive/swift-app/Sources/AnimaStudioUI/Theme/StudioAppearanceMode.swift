import AppKit
import SwiftUI

/// The app-wide light/dark appearance. Default is Dark (the pro-tool norm);
/// Light and System are opt-in. Applied to `NSApplication.appearance` so both
/// the adaptive StudioPalette colors and native controls follow the choice.
enum StudioAppearanceMode: String, CaseIterable, Identifiable, Sendable {
  case system
  case light
  case dark

  var id: Self { self }

  var title: String {
    switch self {
    case .system: "System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var systemImage: String {
    switch self {
    case .system: "circle.lefthalf.filled"
    case .light: "sun.max"
    case .dark: "moon"
    }
  }

  /// SwiftUI scheme; nil = follow the parent/system.
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }

  /// nil = follow the macOS system appearance.
  var nsAppearance: NSAppearance? {
    switch self {
    case .system: nil
    case .light: NSAppearance(named: .aqua)
    case .dark: NSAppearance(named: .darkAqua)
    }
  }

  static var current: StudioAppearanceMode {
    let raw = UserDefaults.standard.string(forKey: StudioPreferenceKey.appAppearanceMode)
    return StudioAppearanceMode(rawValue: raw ?? "") ?? .dark
  }

  /// Apply app-wide. Call at launch and whenever the setting changes.
  func apply() {
    NSApplication.shared.appearance = nsAppearance
  }

  static func applyCurrent() {
    current.apply()
  }
}
