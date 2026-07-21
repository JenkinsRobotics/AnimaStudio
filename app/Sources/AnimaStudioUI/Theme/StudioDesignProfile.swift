import AppKit
import Foundation
import SwiftUI

struct StudioColorToken: Codable, Equatable, Sendable {
  var red: Double
  var green: Double
  var blue: Double
  var opacity: Double

  init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
    self.red = red
    self.green = green
    self.blue = blue
    self.opacity = opacity
  }

  init(color: Color) {
    let source = NSColor(color)
    let resolved = source.usingColorSpace(.sRGB) ?? source
    red = Double(resolved.redComponent)
    green = Double(resolved.greenComponent)
    blue = Double(resolved.blueComponent)
    opacity = Double(resolved.alphaComponent)
  }

  var color: Color {
    Color(red: red, green: green, blue: blue, opacity: opacity)
  }

  func clamped() -> Self {
    Self(
      red: red.clamped(to: 0...1),
      green: green.clamped(to: 0...1),
      blue: blue.clamped(to: 0...1),
      opacity: opacity.clamped(to: 0...1)
    )
  }
}

struct StudioDesignProfile: Codable, Equatable, Sendable {
  var canvas: StudioColorToken
  var documentChrome: StudioColorToken
  var chrome: StudioColorToken
  var ribbonChrome: StudioColorToken
  var panel: StudioColorToken
  var panelInset: StudioColorToken
  var field: StudioColorToken
  var accent: StudioColorToken
  var sourceModel: StudioColorToken
  var semanticPart: StudioColorToken
  var joint: StudioColorToken
  var hardware: StudioColorToken
  var mutedOpacity: Double
  var borderOpacity: Double

  var documentBarHeight: Double
  var compactRibbonHeight: Double
  var fullRibbonHeight: Double
  var panelHeaderHeight: Double
  var panelCornerRadius: Double
  var panelPadding: Double
  var fieldHeight: Double
  var controlCornerRadius: Double
  var navigatorWidth: Double
  var inspectorWidth: Double
  var agentWidth: Double

  static let standard = Self(
    // Shared with the accepted CodexUI/AnimaStudio Demo visual language.
    // Keeping the production palette here means every real workspace inherits
    // the same canvas, chrome, panel, and control hierarchy automatically.
    canvas: .init(red: 14 / 255, green: 16 / 255, blue: 19 / 255),
    documentChrome: .init(red: 23 / 255, green: 26 / 255, blue: 32 / 255),
    chrome: .init(red: 23 / 255, green: 26 / 255, blue: 32 / 255),
    ribbonChrome: .init(red: 23 / 255, green: 26 / 255, blue: 32 / 255),
    panel: .init(red: 23 / 255, green: 26 / 255, blue: 32 / 255),
    panelInset: .init(red: 30 / 255, green: 34 / 255, blue: 42 / 255),
    field: .init(red: 15 / 255, green: 18 / 255, blue: 22 / 255),
    accent: .init(red: 76 / 255, green: 157 / 255, blue: 1),
    sourceModel: .init(red: 76 / 255, green: 157 / 255, blue: 1),
    semanticPart: .init(red: 54 / 255, green: 214 / 255, blue: 195 / 255),
    joint: .init(red: 139 / 255, green: 135 / 255, blue: 1),
    hardware: .init(red: 255 / 255, green: 138 / 255, blue: 61 / 255),
    mutedOpacity: 0.64,
    borderOpacity: 0.07,
    documentBarHeight: 54,
    compactRibbonHeight: 48,
    fullRibbonHeight: 88,
    panelHeaderHeight: 42,
    panelCornerRadius: 10,
    panelPadding: 12,
    fieldHeight: 29,
    controlCornerRadius: 7,
    navigatorWidth: 246,
    inspectorWidth: 286,
    agentWidth: 360
  )

  static let compact: Self = {
    var profile = standard
    profile.documentBarHeight = 48
    profile.compactRibbonHeight = 44
    profile.fullRibbonHeight = 78
    profile.panelHeaderHeight = 38
    profile.panelCornerRadius = 8
    profile.panelPadding = 9
    profile.fieldHeight = 27
    profile.controlCornerRadius = 6
    profile.navigatorWidth = 260
    profile.inspectorWidth = 290
    profile.agentWidth = 330
    return profile
  }()

  static let highContrast: Self = {
    var profile = standard
    profile.canvas = .init(red: 6 / 255, green: 9 / 255, blue: 15 / 255)
    profile.documentChrome = .init(red: 13 / 255, green: 18 / 255, blue: 27 / 255)
    profile.chrome = .init(red: 13 / 255, green: 18 / 255, blue: 27 / 255)
    profile.ribbonChrome = .init(red: 13 / 255, green: 18 / 255, blue: 27 / 255)
    profile.panel = .init(red: 21 / 255, green: 28 / 255, blue: 40 / 255)
    profile.panelInset = .init(red: 28 / 255, green: 38 / 255, blue: 54 / 255)
    profile.field = .init(red: 8 / 255, green: 12 / 255, blue: 19 / 255)
    profile.accent = .init(red: 76 / 255, green: 157 / 255, blue: 1)
    profile.mutedOpacity = 0.78
    profile.borderOpacity = 0.24
    return profile
  }()

  func clamped() -> Self {
    var profile = self
    profile.canvas = canvas.clamped()
    profile.documentChrome = documentChrome.clamped()
    profile.chrome = chrome.clamped()
    profile.ribbonChrome = ribbonChrome.clamped()
    profile.panel = panel.clamped()
    profile.panelInset = panelInset.clamped()
    profile.field = field.clamped()
    profile.accent = accent.clamped()
    profile.sourceModel = sourceModel.clamped()
    profile.semanticPart = semanticPart.clamped()
    profile.joint = joint.clamped()
    profile.hardware = hardware.clamped()
    profile.mutedOpacity = mutedOpacity.clamped(to: 0.35...1)
    profile.borderOpacity = borderOpacity.clamped(to: 0.04...0.50)
    profile.documentBarHeight = documentBarHeight.clamped(to: 30...64)
    profile.compactRibbonHeight = compactRibbonHeight.clamped(to: 44...72)
    profile.fullRibbonHeight = fullRibbonHeight.clamped(to: 72...150)
    profile.panelHeaderHeight = panelHeaderHeight.clamped(to: 32...56)
    profile.panelCornerRadius = panelCornerRadius.clamped(to: 0...28)
    profile.panelPadding = panelPadding.clamped(to: 8...24)
    profile.fieldHeight = fieldHeight.clamped(to: 26...44)
    profile.controlCornerRadius = controlCornerRadius.clamped(to: 0...16)
    profile.navigatorWidth = navigatorWidth.clamped(to: 240...420)
    profile.inspectorWidth = inspectorWidth.clamped(to: 270...460)
    profile.agentWidth = agentWidth.clamped(to: 320...480)
    return profile
  }
}

enum StudioDesignPreset: String, CaseIterable, Identifiable, Sendable {
  case standard
  case compact
  case highContrast

  var id: Self { self }

  var title: String {
    switch self {
    case .standard: "Standard"
    case .compact: "Compact"
    case .highContrast: "High Contrast"
    }
  }

  var profile: StudioDesignProfile {
    switch self {
    case .standard: .standard
    case .compact: .compact
    case .highContrast: .highContrast
    }
  }
}

enum StudioDesignPersistence {
  // v2 adopts the shared CodexUI/AnimaStudio Demo palette and compact chrome.
  static let defaultsKey = "studioDesignProfile.v2"

  static func load(from defaults: UserDefaults = .standard) -> StudioDesignProfile {
    guard let data = defaults.data(forKey: defaultsKey),
      let profile = try? decode(data)
    else {
      return .standard
    }
    return profile
  }

  static func save(
    _ profile: StudioDesignProfile,
    to defaults: UserDefaults = .standard
  ) {
    guard let data = try? encode(profile.clamped()) else { return }
    defaults.set(data, forKey: defaultsKey)
  }

  static func reset(_ defaults: UserDefaults = .standard) {
    defaults.removeObject(forKey: defaultsKey)
  }

  static func encode(_ profile: StudioDesignProfile) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(profile.clamped())
  }

  static func decode(_ data: Data) throws -> StudioDesignProfile {
    try JSONDecoder().decode(StudioDesignProfile.self, from: data).clamped()
  }
}

final class StudioDesignRuntime: @unchecked Sendable {
  static let shared = StudioDesignRuntime()

  private let lock = NSLock()
  private var storedProfile = StudioDesignProfile.standard

  private init() {}

  var profile: StudioDesignProfile {
    lock.lock()
    defer { lock.unlock() }
    return storedProfile
  }

  func apply(_ profile: StudioDesignProfile) {
    lock.lock()
    storedProfile = profile.clamped()
    lock.unlock()
  }
}

extension Comparable {
  fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
