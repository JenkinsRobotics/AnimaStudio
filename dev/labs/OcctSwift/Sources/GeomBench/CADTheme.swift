// CAD Themes — selectable render looks, switchable like the engine backends.
// Each theme is a full preset: surface finish + three-point lighting +
// background + selection colors. The presets capture the distinct looks the
// different benches used, so any of them can drive any RealityKit-based view.
// Single source of truth; ports to Anima Studio's viewport unchanged.
import AppKit
import RealityKit
import SwiftUI
import simd

struct CADTheme: Identifiable, Hashable {
  let name: String
  var id: String { name }

  static func == (lhs: CADTheme, rhs: CADTheme) -> Bool { lhs.name == rhs.name }
  func hash(into hasher: inout Hasher) { hasher.combine(name) }

  // Surface
  let roughness: Float
  let metallic: Float
  /// Edge prominence: 0 = no outlines, 1 = thick dark edges. Drives edge tube
  /// radius and darkness — a per-theme "level" for the outlined/cartoon look.
  let edgeStrength: Float
  /// Neutral fallback when a STEP file assigns no face color.
  let neutralColor: SIMD4<Float>

  // Environment
  let background: SIMD3<Float>

  // Selection
  let selectedFace: NSColor
  let selectedEdge: NSColor
  let edge: NSColor

  // Three-point lighting: (color, intensity, direction-from)
  struct Light: Equatable {
    let color: SIMD3<Float>
    let intensity: Float
    let from: SIMD3<Float>
  }
  let key: Light
  let fill: Light
  let rim: Light

  @MainActor
  func surfaceMaterial(baseColor: SIMD4<Float>) -> PhysicallyBasedMaterial {
    var material = PhysicallyBasedMaterial()
    material.baseColor = .init(
      tint: NSColor(
        red: CGFloat(baseColor.x), green: CGFloat(baseColor.y),
        blue: CGFloat(baseColor.z), alpha: CGFloat(baseColor.w)))
    material.roughness = .init(floatLiteral: roughness)
    material.metallic = .init(floatLiteral: metallic)
    return material
  }

  @MainActor
  func addLighting(to content: some RealityViewContentProtocol) {
    for light in [key, fill, rim] {
      let entity = Entity()
      entity.name = "themeLight"
      entity.components.set(
        DirectionalLightComponent(
          color: NSColor(
            red: CGFloat(light.color.x), green: CGFloat(light.color.y),
            blue: CGFloat(light.color.z), alpha: 1),
          intensity: light.intensity))
      entity.look(at: .zero, from: light.from, relativeTo: nil)
      content.add(entity)
    }
  }

  var backgroundNSColor: NSColor {
    NSColor(
      red: CGFloat(background.x), green: CGFloat(background.y),
      blue: CGFloat(background.z), alpha: 1)
  }

  /// The dark edge color as RGB, for the GPU-buffer edge tubes.
  var edgeColorRGB: SIMD3<Float> {
    let c = edge.usingColorSpace(.deviceRGB) ?? edge
    return SIMD3<Float>(Float(c.redComponent), Float(c.greenComponent), Float(c.blueComponent))
  }
}

extension CADTheme {
  // The approved look (blue enclosure render). Warm key + cool fill + rim,
  // matte 0.5, charcoal background.
  static let studioBlue = CADTheme(
    name: "Studio Blue",
    roughness: 0.5, metallic: 0.0, edgeStrength: 0.7, neutralColor: [0.72, 0.74, 0.78, 1],
    background: [0.16, 0.17, 0.19],
    selectedFace: .systemOrange, selectedEdge: .systemTeal,
    edge: NSColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1),
    key: .init(color: [1, 1, 1], intensity: 3_000, from: [0.5, 0.9, 0.6]),
    fill: .init(color: [0.75, 0.82, 1.0], intensity: 1_200, from: [-0.7, 0.3, 0.4]),
    rim: .init(color: [1, 1, 1], intensity: 900, from: [0.1, 0.5, -0.8]))

  // Clean, bright, whiter light + lighter background — showroom/marketing feel.
  static let showroom = CADTheme(
    name: "Showroom",
    roughness: 0.42, metallic: 0.05, edgeStrength: 0.25, neutralColor: [0.82, 0.84, 0.87, 1],
    background: [0.36, 0.38, 0.42],
    selectedFace: .systemOrange, selectedEdge: .systemBlue,
    edge: NSColor(red: 0.3, green: 0.32, blue: 0.36, alpha: 1),
    key: .init(color: [1, 1, 1], intensity: 4_200, from: [0.4, 1.0, 0.7]),
    fill: .init(color: [0.9, 0.93, 1.0], intensity: 2_400, from: [-0.8, 0.4, 0.5]),
    rim: .init(color: [1, 1, 1], intensity: 1_400, from: [0.0, 0.4, -0.9]))

  // Flat, even, matte — engineering-drawing / inspection feel, gray bg.
  static let technical = CADTheme(
    name: "Technical Matte",
    roughness: 0.85, metallic: 0.0, edgeStrength: 1.0, neutralColor: [0.70, 0.72, 0.74, 1],
    background: [0.22, 0.23, 0.24],
    selectedFace: .systemGreen, selectedEdge: .systemYellow,
    edge: NSColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 1),
    key: .init(color: [1, 1, 1], intensity: 2_200, from: [0.3, 0.9, 0.5]),
    fill: .init(color: [1, 1, 1], intensity: 2_000, from: [-0.6, 0.5, 0.5]),
    rim: .init(color: [0.9, 0.9, 0.9], intensity: 1_400, from: [-0.2, 0.3, -0.8]))

  // Warm, dramatic — darker background, amber key. Presentation/hero shot.
  static let workshop = CADTheme(
    name: "Warm Workshop",
    roughness: 0.55, metallic: 0.12, edgeStrength: 0.5, neutralColor: [0.74, 0.72, 0.68, 1],
    background: [0.09, 0.08, 0.07],
    selectedFace: .systemTeal, selectedEdge: .systemOrange,
    edge: NSColor(red: 0.2, green: 0.16, blue: 0.12, alpha: 1),
    key: .init(color: [1.0, 0.9, 0.72], intensity: 3_400, from: [0.6, 0.8, 0.5]),
    fill: .init(color: [0.6, 0.7, 0.9], intensity: 800, from: [-0.8, 0.2, 0.3]),
    rim: .init(color: [1.0, 0.95, 0.85], intensity: 1_600, from: [0.2, 0.6, -0.9]))

  static let all: [CADTheme] = [.studioBlue, .showroom, .technical, .workshop]
}
