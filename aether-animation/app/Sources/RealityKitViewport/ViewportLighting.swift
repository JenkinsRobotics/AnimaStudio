import AppKit
import CoreGraphics
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

public enum ViewportReflectionMode: String, CaseIterable, Identifiable, Sendable {
  case off
  case subtle
  case studio

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .off: "Reflections Off"
    case .subtle: "Subtle Reflections"
    case .studio: "Studio Reflections"
    }
  }

  var intensityExponent: Float {
    switch self {
    case .off: -8
    case .subtle: -1.1
    case .studio: 0.15
    }
  }
}

@MainActor
enum ViewportLightingFactory {
  static let keyLightName = "viewportKeyLight"
  static let fillLightName = "viewportFillLight"
  static let environmentLightName = "viewportEnvironmentLight"

  private static var studioEnvironments: [ViewportEnvironmentPreset: EnvironmentResource] = [:]

  static func makeLights(
    preset: ViewportLightingPreset,
    baseIntensity: Float,
    intensityMultiplier: Float = 1,
    showsShadows: Bool = true
  ) -> [Entity] {
    let configuration = preset.configuration
    return [
      makeDirectionalLight(
        name: keyLightName,
        color: NSColor(calibratedRed: 1, green: 0.97, blue: 0.91, alpha: 1),
        intensity: baseIntensity * configuration.keyMultiplier * intensityMultiplier,
        pitchRadians: -.pi / 4,
        yawRadians: -.pi / 4,
        castsShadows: showsShadows
      ),
      makeDirectionalLight(
        name: fillLightName,
        color: NSColor(calibratedRed: 0.78, green: 0.88, blue: 1, alpha: 1),
        intensity: baseIntensity * configuration.fillMultiplier * intensityMultiplier,
        pitchRadians: -.pi / 6,
        yawRadians: .pi * 0.72,
        castsShadows: false
      ),
    ]
  }

  static func makeEnvironmentLight(
    mode: ViewportReflectionMode,
    preset: ViewportEnvironmentPreset = .softbox,
    intensityMultiplier: Float = 1,
    rotationDegrees: Float = 0
  ) async -> Entity? {
    guard mode != .off else { return nil }
    let environment: EnvironmentResource
    if let cached = studioEnvironments[preset] {
      environment = cached
    } else {
      guard let image = makeStudioEnvironmentImage(preset: preset),
        let generated = try? await EnvironmentResource(
          equirectangular: image,
          withName: "AnimaStudio-\(preset.rawValue)"
        )
      else { return nil }
      studioEnvironments[preset] = generated
      environment = generated
    }
    let entity = Entity(
      components: ImageBasedLightComponent(
        source: .single(environment),
        intensityExponent: mode.intensityExponent + log2(max(intensityMultiplier, 0.05))
      )
    )
    entity.name = environmentLightName
    entity.orientation = simd_quatf(
      angle: rotationDegrees * .pi / 180,
      axis: SIMD3<Float>(0, 1, 0)
    )
    return entity
  }

  static func applyEnvironmentReceiver(
    light: Entity?,
    to root: Entity
  ) {
    guard let light else { return }
    var stack = [root]
    while let entity = stack.popLast() {
      if entity.components[ModelComponent.self] != nil {
        entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: light))
      }
      stack.append(contentsOf: entity.children)
    }
  }

  private static func makeDirectionalLight(
    name: String,
    color: NSColor,
    intensity: Float,
    pitchRadians: Float,
    yawRadians: Float,
    castsShadows: Bool
  ) -> Entity {
    let light = Entity(
      components: DirectionalLightComponent(color: color, intensity: intensity)
    )
    light.name = name
    let pitch = simd_quatf(angle: pitchRadians, axis: SIMD3<Float>(1, 0, 0))
    let yaw = simd_quatf(angle: yawRadians, axis: SIMD3<Float>(0, 1, 0))
    light.orientation = yaw * pitch
    if castsShadows {
      light.components.set(
        DirectionalLightComponent.Shadow(
          shadowProjection: .automatic(maximumDistance: 12),
          depthBias: 1.2
        )
      )
    }
    return light
  }

  private static func makeStudioEnvironmentImage(
    preset: ViewportEnvironmentPreset
  ) -> CGImage? {
    let width = 512
    let height = 256
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else { return nil }

    let colors: CFArray =
      switch preset {
      case .softbox:
        [
          NSColor(white: 0.055, alpha: 1).cgColor,
          NSColor(red: 0.24, green: 0.30, blue: 0.38, alpha: 1).cgColor,
          NSColor(white: 0.035, alpha: 1).cgColor,
        ] as CFArray
      case .rim:
        [
          NSColor(red: 0.02, green: 0.04, blue: 0.10, alpha: 1).cgColor,
          NSColor(red: 0.10, green: 0.28, blue: 0.52, alpha: 1).cgColor,
          NSColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1).cgColor,
        ] as CFArray
      case .warmStage:
        [
          NSColor(red: 0.08, green: 0.035, blue: 0.02, alpha: 1).cgColor,
          NSColor(red: 0.40, green: 0.20, blue: 0.08, alpha: 1).cgColor,
          NSColor(red: 0.025, green: 0.02, blue: 0.02, alpha: 1).cgColor,
        ] as CFArray
      }
    if let gradient = CGGradient(
      colorsSpace: colorSpace,
      colors: colors,
      locations: [0, 0.48, 1]
    ) {
      context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: 0, y: height),
        options: []
      )
    }

    context.setFillColor(NSColor(calibratedWhite: 0.94, alpha: 1).cgColor)
    context.fill(CGRect(x: 70, y: 118, width: 96, height: 82))
    context.setFillColor(
      NSColor(calibratedRed: 0.68, green: 0.82, blue: 1, alpha: 1).cgColor
    )
    context.fill(CGRect(x: 350, y: 100, width: 64, height: 104))
    context.setFillColor(NSColor(calibratedWhite: 0.46, alpha: 1).cgColor)
    context.fill(CGRect(x: 225, y: 32, width: 84, height: 24))
    return context.makeImage()
  }
}
