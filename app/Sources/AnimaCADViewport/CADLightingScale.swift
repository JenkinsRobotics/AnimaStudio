import Foundation

/// Maps a lighting slider position onto a multiplier of a light's
/// theme-nominal intensity so every slider shares one perceptual contract:
/// far left is fully off, mid-slider is the theme's nominal value, far right
/// is 4x nominal (deliberately overexposed). The quadratic keeps the left
/// half fine-grained and lets the right half climb quickly.
public enum CADLightingScale {
  public static let maximumMultiplier: Float = 4

  /// Multiplier for slider position `t` in 0...1: `4t²`.
  public static func multiplier(position: Float) -> Float {
    let t = min(max(position, 0), 1)
    return maximumMultiplier * t * t
  }

  /// Inverse of `multiplier(position:)`, clamped to the slider range.
  public static func position(multiplier: Float) -> Float {
    let m = min(max(multiplier, 0), maximumMultiplier)
    return (m / maximumMultiplier).squareRoot()
  }

  /// Absolute intensity for a slider position against a light's nominal
  /// value. A zero/negative nominal falls back to `fallbackNominal` so the
  /// slider still spans a real range on themes that ship the light disabled.
  public static func intensity(
    position: Float, nominal: Float, fallbackNominal: Float
  ) -> Float {
    let base = nominal > .ulpOfOne ? nominal : fallbackNominal
    return base * multiplier(position: position)
  }

  /// Slider position representing an absolute intensity against a nominal.
  public static func position(
    intensity: Float, nominal: Float, fallbackNominal: Float
  ) -> Float {
    let base = nominal > .ulpOfOne ? nominal : fallbackNominal
    guard base > .ulpOfOne else { return 0 }
    return position(multiplier: intensity / base)
  }
}
