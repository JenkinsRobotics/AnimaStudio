import AppKit
import RealityKit
import simd

public enum ViewportLightingPreset: String, CaseIterable, Identifiable, Sendable {
  case balanced
  case soft
  case bright
  case dramatic

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .balanced: "Balanced"
    case .soft: "Soft"
    case .bright: "Bright"
    case .dramatic: "High Contrast"
    }
  }

  public var systemImage: String {
    switch self {
    case .balanced: "circle.lefthalf.filled"
    case .soft: "cloud.sun.fill"
    case .bright: "sun.max.fill"
    case .dramatic: "circle.righthalf.filled"
    }
  }

  public var detail: String {
    switch self {
    case .balanced: "A neutral key light with a moderate fill"
    case .soft: "Low-contrast illumination for inspecting forms"
    case .bright: "Higher overall illumination for dark materials"
    case .dramatic: "Strong directional light with minimal fill"
    }
  }

  var configuration: ViewportLightingConfiguration {
    switch self {
    case .balanced:
      ViewportLightingConfiguration(keyMultiplier: 1, fillMultiplier: 0.28)
    case .soft:
      ViewportLightingConfiguration(keyMultiplier: 0.72, fillMultiplier: 0.55)
    case .bright:
      ViewportLightingConfiguration(keyMultiplier: 1.35, fillMultiplier: 0.48)
    case .dramatic:
      ViewportLightingConfiguration(keyMultiplier: 1.2, fillMultiplier: 0.08)
    }
  }
}

struct ViewportLightingConfiguration: Equatable {
  let keyMultiplier: Float
  let fillMultiplier: Float
}

@MainActor
enum ViewportLightingFactory {
  static let keyLightName = "viewportKeyLight"
  static let fillLightName = "viewportFillLight"

  static func makeLights(
    preset: ViewportLightingPreset,
    baseIntensity: Float
  ) -> [Entity] {
    let configuration = preset.configuration
    return [
      makeDirectionalLight(
        name: keyLightName,
        color: NSColor(calibratedRed: 1, green: 0.97, blue: 0.91, alpha: 1),
        intensity: baseIntensity * configuration.keyMultiplier,
        pitchRadians: -.pi / 4,
        yawRadians: -.pi / 4
      ),
      makeDirectionalLight(
        name: fillLightName,
        color: NSColor(calibratedRed: 0.78, green: 0.88, blue: 1, alpha: 1),
        intensity: baseIntensity * configuration.fillMultiplier,
        pitchRadians: -.pi / 6,
        yawRadians: .pi * 0.72
      ),
    ]
  }

  private static func makeDirectionalLight(
    name: String,
    color: NSColor,
    intensity: Float,
    pitchRadians: Float,
    yawRadians: Float
  ) -> Entity {
    let light = Entity(
      components: DirectionalLightComponent(color: color, intensity: intensity)
    )
    light.name = name
    let pitch = simd_quatf(angle: pitchRadians, axis: SIMD3<Float>(1, 0, 0))
    let yaw = simd_quatf(angle: yawRadians, axis: SIMD3<Float>(0, 1, 0))
    light.orientation = yaw * pitch
    return light
  }
}
