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

  // Bright, flat, near-shadowless — showroom/marketing. Light bg, subtle edges.
  static let showroom = CADTheme(
    name: "Showroom",
    roughness: 0.35, metallic: 0.1, edgeStrength: 0.0, neutralColor: [0.85, 0.87, 0.9, 1],
    background: [0.42, 0.45, 0.5],
    selectedFace: .systemOrange, selectedEdge: .systemBlue,
    edge: NSColor(red: 0.4, green: 0.42, blue: 0.46, alpha: 1),
    key: .init(color: [1, 1, 1], intensity: 6_000, from: [0.4, 1.0, 0.7]),
    fill: .init(color: [1, 1, 1], intensity: 5_000, from: [-0.8, 0.4, 0.5]),
    rim: .init(color: [1, 1, 1], intensity: 3_000, from: [0.0, 0.4, -0.9]))

  // Flat even matte, thick outlines — engineering-drawing / inspection feel.
  static let technical = CADTheme(
    name: "Technical Matte",
    roughness: 0.95, metallic: 0.0, edgeStrength: 1.0, neutralColor: [0.62, 0.66, 0.70, 1],
    background: [0.20, 0.21, 0.22],
    selectedFace: .systemGreen, selectedEdge: .systemYellow,
    edge: NSColor(red: 0.05, green: 0.06, blue: 0.07, alpha: 1),
    key: .init(color: [0.85, 0.9, 1.0], intensity: 2_600, from: [0.2, 0.9, 0.3]),
    fill: .init(color: [0.85, 0.9, 1.0], intensity: 2_500, from: [-0.9, 0.6, 0.4]),
    rim: .init(color: [0.85, 0.9, 1.0], intensity: 2_400, from: [-0.3, 0.4, -0.9]))

  // Warm, dramatic single-key — deep shadows, dark bg. Hero/presentation shot.
  static let workshop = CADTheme(
    name: "Warm Workshop",
    roughness: 0.5, metallic: 0.2, edgeStrength: 0.5, neutralColor: [0.78, 0.72, 0.6, 1],
    background: [0.07, 0.06, 0.05],
    selectedFace: .systemTeal, selectedEdge: .systemOrange,
    edge: NSColor(red: 0.22, green: 0.15, blue: 0.09, alpha: 1),
    key: .init(color: [1.0, 0.78, 0.45], intensity: 4_500, from: [0.7, 0.7, 0.5]),
    fill: .init(color: [0.35, 0.5, 0.9], intensity: 500, from: [-0.8, 0.1, 0.3]),
    rim: .init(color: [1.0, 0.85, 0.6], intensity: 2_400, from: [0.2, 0.5, -0.9]))

  static let all: [CADTheme] = [.studioBlue, .showroom, .technical, .workshop]
}
