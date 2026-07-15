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
    canvas: .init(red: 0.105, green: 0.105, blue: 0.125),
    documentChrome: .init(red: 0.115, green: 0.115, blue: 0.135),
    chrome: .init(red: 0.15, green: 0.15, blue: 0.18),
    ribbonChrome: .init(red: 0.18, green: 0.185, blue: 0.21),
    panel: .init(red: 0.22, green: 0.23, blue: 0.26),
    panelInset: .init(red: 0.16, green: 0.17, blue: 0.19),
    field: .init(red: 0.12, green: 0.13, blue: 0.15),
    accent: .init(red: 0.12, green: 0.58, blue: 0.90),
    sourceModel: .init(red: 0.25, green: 0.62, blue: 0.96),
    semanticPart: .init(red: 0.23, green: 0.76, blue: 0.68),
    joint: .init(red: 0.72, green: 0.45, blue: 0.96),
    hardware: .init(red: 0.96, green: 0.58, blue: 0.24),
    mutedOpacity: 0.62,
    borderOpacity: 0.10,
    documentBarHeight: 34,
    compactRibbonHeight: 53,
    fullRibbonHeight: 112,
    panelHeaderHeight: 38,
    panelCornerRadius: 16,
    panelPadding: 14,
    fieldHeight: 30,
    controlCornerRadius: 7,
    navigatorWidth: 290,
    inspectorWidth: 320,
    agentWidth: 360
  )

  static let compact: Self = {
    var profile = standard
    profile.compactRibbonHeight = 47
    profile.fullRibbonHeight = 102
    profile.panelHeaderHeight = 34
    profile.panelCornerRadius = 12
    profile.panelPadding = 10
    profile.fieldHeight = 27
    profile.controlCornerRadius = 6
    profile.navigatorWidth = 260
    profile.inspectorWidth = 290
    profile.agentWidth = 330
    return profile
  }()

  static let highContrast: Self = {
    var profile = standard
    profile.canvas = .init(red: 0.055, green: 0.06, blue: 0.075)
    profile.chrome = .init(red: 0.105, green: 0.115, blue: 0.14)
    profile.ribbonChrome = .init(red: 0.14, green: 0.15, blue: 0.18)
    profile.panel = .init(red: 0.18, green: 0.195, blue: 0.23)
    profile.panelInset = .init(red: 0.09, green: 0.10, blue: 0.125)
    profile.field = .init(red: 0.045, green: 0.05, blue: 0.065)
    profile.accent = .init(red: 0.10, green: 0.68, blue: 1)
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
    profile.documentBarHeight = documentBarHeight.clamped(to: 30...48)
    profile.compactRibbonHeight = compactRibbonHeight.clamped(to: 44...72)
    profile.fullRibbonHeight = fullRibbonHeight.clamped(to: 92...150)
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
  static let defaultsKey = "studioDesignProfile.v1"

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
