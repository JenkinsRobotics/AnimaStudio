import AnimaEvaluation
import AnimaModel
import AppKit
import Foundation

/// Renderer-facing appearance override for Studio's semantic proxy bodies.
///
/// This is intentionally viewport presentation state rather than AnimaModel rig
/// data. Character editor metadata persists it beside the canonical rig.
public struct PreviewPartAppearance: Equatable, Sendable {
  public static let maximumProxyFilletRadiusMeters = 0.275

  public var red: Double
  public var green: Double
  public var blue: Double
  public var opacity: Double
  public var isVisible: Bool
  public var finish: ViewportMaterialFinish
  /// View-only corner radius for Studio's generated box proxy.
  ///
  /// This does not change the AnimaCore part or its solve geometry. Imported
  /// models keep their authored geometry and ignore this value.
  public var proxyFilletRadiusMeters: Double

  public init(
    red: Double,
    green: Double,
    blue: Double,
    opacity: Double = 1,
    isVisible: Bool = true,
    finish: ViewportMaterialFinish = .satin,
    proxyFilletRadiusMeters: Double = 0
  ) {
    self.red = red.clamped(to: 0...1)
    self.green = green.clamped(to: 0...1)
    self.blue = blue.clamped(to: 0...1)
    self.opacity = opacity.clamped(to: 0...1)
    self.isVisible = isVisible
    self.finish = finish
    self.proxyFilletRadiusMeters = proxyFilletRadiusMeters.clamped(
      to: 0...Self.maximumProxyFilletRadiusMeters
    )
  }

  public init?(
    hexRGB: String,
    opacity: Double = 1,
    isVisible: Bool = true,
    finish: ViewportMaterialFinish = .satin,
    proxyFilletRadiusMeters: Double = 0
  ) {
    let normalized =
      hexRGB
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "#", with: "")
    guard normalized.count == 6, let value = UInt64(normalized, radix: 16) else {
      return nil
    }
    self.init(
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255,
      opacity: opacity,
      isVisible: isVisible,
      finish: finish,
      proxyFilletRadiusMeters: proxyFilletRadiusMeters
    )
  }

  public var hexRGB: String {
    String(
      format: "#%02X%02X%02X",
      Int((red * 255).rounded()),
      Int((green * 255).rounded()),
      Int((blue * 255).rounded())
    )
  }

  public static func defaultAppearance(for kind: RigPrimitiveKind) -> Self {
    switch kind {
    case .locator:
      Self(red: 0.95, green: 0.74, blue: 0.18)
    case .box, .cylinder, .sphere:
      Self(red: 0.22, green: 0.73, blue: 0.68)
    }
  }

  var nsColor: NSColor {
    NSColor(
      calibratedRed: red,
      green: green,
      blue: blue,
      alpha: 1
    )
  }
}

extension Comparable {
  fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
