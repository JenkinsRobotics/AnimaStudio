import AnimaCADViewport
import AppKit
import SwiftUI

/// Owns the persisted values that turn a named CAD preset into one coordinated
/// environment. Choosing a preset intentionally restores all of its material,
/// edge, lighting, and color values; operators can then customize any field.
enum CADThemePreferences {
  static let defaultTheme = CADViewportTheme.defaultTheme

  static func applyPreset(
    named name: String,
    to defaults: UserDefaults = .standard
  ) {
    let theme = CADViewportTheme.named(name)
    defaults.set(theme.name, forKey: StudioPreferenceKey.cadThemeName)
    defaults.set(Double(theme.edgeStrength), forKey: StudioPreferenceKey.cadEdgeStrength)
    defaults.set(Double(theme.ambientStrength), forKey: StudioPreferenceKey.cadAmbientStrength)
    defaults.set(Double(theme.shadowStrength), forKey: StudioPreferenceKey.cadShadowStrength)
    defaults.set(Double(theme.roughness), forKey: StudioPreferenceKey.cadRoughness)
    defaults.set(Double(theme.metallic), forKey: StudioPreferenceKey.cadMetallic)
    defaults.set(Double(theme.key.intensity), forKey: StudioPreferenceKey.cadKeyLightIntensity)
    defaults.set(Double(theme.fill.intensity), forKey: StudioPreferenceKey.cadFillLightIntensity)
    defaults.set(Double(theme.rim.intensity), forKey: StudioPreferenceKey.cadRimLightIntensity)

    for key in colorOverrideKeys {
      defaults.removeObject(forKey: key)
    }
  }

  private static let colorOverrideKeys = [
    StudioPreferenceKey.cadEdgeColorHex,
    StudioPreferenceKey.cadSelectedEdgeColorHex,
    StudioPreferenceKey.cadBackgroundColorHex,
    StudioPreferenceKey.cadFaceSelectionColorHex,
    StudioPreferenceKey.cadNeutralColorHex,
    StudioPreferenceKey.cadKeyLightColorHex,
    StudioPreferenceKey.cadFillLightColorHex,
    StudioPreferenceKey.cadRimLightColorHex,
  ]
}

/// Bridges the CAD viewport theme's SIMD colors to persisted hex strings so the
/// demo's per-color settings (edge color, selected edge, scene colors, per-light
/// colors) can be imported. Each override is stored as a hex string; an empty
/// string means "use the named theme's color", so switching a control back to a
/// preset value is just clearing it. Applied on top of `CADViewportTheme.named`.
enum CADThemeColor {
  static func hexString(_ rgb: SIMD3<Float>) -> String {
    func byte(_ value: Float) -> Int { max(0, min(255, Int((value * 255).rounded()))) }
    return String(format: "#%02X%02X%02X", byte(rgb.x), byte(rgb.y), byte(rgb.z))
  }

  /// Parse "#RRGGBB" / "RRGGBB"; nil for empty/invalid → caller uses the theme.
  static func rgb(_ hex: String) -> SIMD3<Float>? {
    var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return nil }
    if text.hasPrefix("#") { text.removeFirst() }
    guard text.count == 6, let value = Int(text, radix: 16) else { return nil }
    return SIMD3(
      Float((value >> 16) & 0xFF) / 255,
      Float((value >> 8) & 0xFF) / 255,
      Float(value & 0xFF) / 255
    )
  }
}

extension Color {
  init(cadRGB rgb: SIMD3<Float>) {
    self.init(.sRGB, red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
  }

  /// sRGB components for storage. Falls back to black if the color can't be
  /// resolved into sRGB (e.g. a catalog/dynamic color).
  var cadRGB: SIMD3<Float> {
    let resolved = NSColor(self).usingColorSpace(.sRGB) ?? .black
    return SIMD3(
      Float(resolved.redComponent),
      Float(resolved.greenComponent),
      Float(resolved.blueComponent)
    )
  }
}

extension Binding where Value == String {
  /// A `Color` binding over a persisted hex string, showing `themeDefault` when
  /// the string is empty and writing the picked color back as hex.
  func cadColor(themeDefault: SIMD3<Float>) -> Binding<Color> {
    Binding<Color>(
      get: { Color(cadRGB: CADThemeColor.rgb(wrappedValue) ?? themeDefault) },
      set: { wrappedValue = CADThemeColor.hexString($0.cadRGB) }
    )
  }
}

/// Applies persisted per-color overrides on top of a named theme. Shared by the
/// settings preview and the live viewport so both agree on the resolved theme.
extension CADViewportTheme {
  func applyingOverrides(
    edgeHex: String,
    selectedEdgeHex: String,
    backgroundHex: String,
    faceSelectionHex: String,
    neutralHex: String,
    keyColorHex: String,
    fillColorHex: String,
    rimColorHex: String
  ) -> CADViewportTheme {
    var theme = self
    if let rgb = CADThemeColor.rgb(edgeHex) { theme.edgeColor = rgb }
    if let rgb = CADThemeColor.rgb(selectedEdgeHex) { theme.edgeSelectionColor = rgb }
    if let rgb = CADThemeColor.rgb(backgroundHex) { theme.background = rgb }
    if let rgb = CADThemeColor.rgb(faceSelectionHex) { theme.selectionColor = rgb }
    if let rgb = CADThemeColor.rgb(neutralHex) {
      theme.neutralColor = SIMD4(rgb.x, rgb.y, rgb.z, theme.neutralColor.w)
    }
    if let rgb = CADThemeColor.rgb(keyColorHex) { theme.key.color = rgb }
    if let rgb = CADThemeColor.rgb(fillColorHex) { theme.fill.color = rgb }
    if let rgb = CADThemeColor.rgb(rimColorHex) { theme.rim.color = rgb }
    return theme
  }
}
