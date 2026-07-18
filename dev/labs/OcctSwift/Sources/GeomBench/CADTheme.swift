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
  /// If set, EVERY face uses this color (ignoring the file's CAD colors) —
  /// how SolidWorks/Onshape/etc. impose their signature material look. nil =
  /// keep the STEP file's real per-face colors.
  let overrideColor: SIMD4<Float>?

  /// The face color to actually render for a given file color, honoring the
  /// theme's override.
  func faceColor(fileColor: SIMD4<Float>) -> SIMD4<Float> { overrideColor ?? fileColor }

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
  // ---- Original four (keep the CAD file's real colors) --------------------

  // The approved look (blue enclosure render). Warm key + cool fill + rim.
  static let studioBlue = CADTheme(
    name: "Studio Blue",
    roughness: 0.5, metallic: 0.0, edgeStrength: 0.7, neutralColor: [0.72, 0.74, 0.78, 1],
    overrideColor: nil, background: [0.16, 0.17, 0.19],
    selectedFace: .systemOrange, selectedEdge: .systemTeal,
    edge: NSColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1),
    key: .init(color: [1, 1, 1], intensity: 3_000, from: [0.5, 0.9, 0.6]),
    fill: .init(color: [0.75, 0.82, 1.0], intensity: 1_200, from: [-0.7, 0.3, 0.4]),
    rim: .init(color: [1, 1, 1], intensity: 900, from: [0.1, 0.5, -0.8]))

  static let showroom = CADTheme(
    name: "Showroom",
    roughness: 0.35, metallic: 0.1, edgeStrength: 0.0, neutralColor: [0.85, 0.87, 0.9, 1],
    overrideColor: nil, background: [0.42, 0.45, 0.5],
    selectedFace: .systemOrange, selectedEdge: .systemBlue,
    edge: NSColor(red: 0.4, green: 0.42, blue: 0.46, alpha: 1),
    key: .init(color: [1, 1, 1], intensity: 6_000, from: [0.4, 1.0, 0.7]),
    fill: .init(color: [1, 1, 1], intensity: 5_000, from: [-0.8, 0.4, 0.5]),
    rim: .init(color: [1, 1, 1], intensity: 3_000, from: [0.0, 0.4, -0.9]))

  static let technical = CADTheme(
    name: "Technical Matte",
    roughness: 0.95, metallic: 0.0, edgeStrength: 1.0, neutralColor: [0.62, 0.66, 0.70, 1],
    overrideColor: nil, background: [0.20, 0.21, 0.22],
    selectedFace: .systemGreen, selectedEdge: .systemYellow,
    edge: NSColor(red: 0.05, green: 0.06, blue: 0.07, alpha: 1),
    key: .init(color: [0.85, 0.9, 1.0], intensity: 2_600, from: [0.2, 0.9, 0.3]),
    fill: .init(color: [0.85, 0.9, 1.0], intensity: 2_500, from: [-0.9, 0.6, 0.4]),
    rim: .init(color: [0.85, 0.9, 1.0], intensity: 2_400, from: [-0.3, 0.4, -0.9]))

  static let workshop = CADTheme(
    name: "Warm Workshop",
    roughness: 0.5, metallic: 0.2, edgeStrength: 0.5, neutralColor: [0.78, 0.72, 0.6, 1],
    overrideColor: nil, background: [0.07, 0.06, 0.05],
    selectedFace: .systemTeal, selectedEdge: .systemOrange,
    edge: NSColor(red: 0.22, green: 0.15, blue: 0.09, alpha: 1),
    key: .init(color: [1.0, 0.78, 0.45], intensity: 4_500, from: [0.7, 0.7, 0.5]),
    fill: .init(color: [0.35, 0.5, 0.9], intensity: 500, from: [-0.8, 0.1, 0.3]),
    rim: .init(color: [1.0, 0.85, 0.6], intensity: 2_400, from: [0.2, 0.5, -0.9]))

  // ---- CAD-app styles (override the whole part to their signature look) ----

  // SolidWorks: steel-gray parts, medium edges, blue-gray gradient bg.
  static let solidworks = CADTheme(
    name: "SolidWorks",
    roughness: 0.45, metallic: 0.35, edgeStrength: 0.6, neutralColor: [0.6, 0.62, 0.66, 1],
    overrideColor: [0.55, 0.58, 0.63, 1], background: [0.22, 0.28, 0.38],
    selectedFace: .systemBlue, selectedEdge: .systemCyan,
    edge: NSColor(red: 0.1, green: 0.11, blue: 0.13, alpha: 1),
    key: .init(color: [1, 1, 1], intensity: 4_000, from: [0.4, 0.9, 0.6]),
    fill: .init(color: [0.9, 0.94, 1.0], intensity: 2_600, from: [-0.7, 0.4, 0.5]),
    rim: .init(color: [1, 1, 1], intensity: 1_600, from: [0.1, 0.4, -0.9]))

  // Onshape: light gray-blue parts, subtle edges, near-white studio bg.
  static let onshape = CADTheme(
    name: "Onshape",
    roughness: 0.55, metallic: 0.1, edgeStrength: 0.35, neutralColor: [0.7, 0.74, 0.8, 1],
    overrideColor: [0.66, 0.71, 0.78, 1], background: [0.86, 0.88, 0.9],
    selectedFace: .systemOrange, selectedEdge: .systemBlue,
    edge: NSColor(red: 0.35, green: 0.38, blue: 0.42, alpha: 1),
    key: .init(color: [1, 1, 1], intensity: 5_500, from: [0.3, 1.0, 0.6]),
    fill: .init(color: [1, 1, 1], intensity: 4_500, from: [-0.7, 0.5, 0.5]),
    rim: .init(color: [1, 1, 1], intensity: 2_500, from: [0.0, 0.3, -0.9]))

  // Fusion 360: warm neutral gray, dark gradient bg, soft edges.
  static let fusion = CADTheme(
    name: "Fusion 360",
    roughness: 0.4, metallic: 0.25, edgeStrength: 0.4, neutralColor: [0.66, 0.64, 0.62, 1],
    overrideColor: [0.68, 0.66, 0.63, 1], background: [0.14, 0.15, 0.17],
    selectedFace: .systemBlue, selectedEdge: .systemOrange,
    edge: NSColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1),
    key: .init(color: [1.0, 0.98, 0.94], intensity: 4_200, from: [0.5, 0.9, 0.7]),
    fill: .init(color: [0.85, 0.9, 1.0], intensity: 2_200, from: [-0.7, 0.3, 0.4]),
    rim: .init(color: [1, 1, 1], intensity: 1_800, from: [0.2, 0.5, -0.9]))

  // Blueprint: pale part, deep blue bg, bright cyan/white edges — drawing look.
  static let blueprint = CADTheme(
    name: "Blueprint",
    roughness: 0.9, metallic: 0.0, edgeStrength: 1.0, neutralColor: [0.8, 0.86, 0.95, 1],
    overrideColor: [0.42, 0.55, 0.78, 1], background: [0.05, 0.1, 0.24],
    selectedFace: .systemTeal, selectedEdge: .white,
    edge: NSColor(red: 0.75, green: 0.9, blue: 1.0, alpha: 1),
    key: .init(color: [0.8, 0.88, 1.0], intensity: 2_400, from: [0.3, 0.9, 0.4]),
    fill: .init(color: [0.6, 0.72, 1.0], intensity: 2_200, from: [-0.8, 0.5, 0.5]),
    rim: .init(color: [0.9, 0.95, 1.0], intensity: 2_000, from: [-0.2, 0.4, -0.9]))

  // Clay: uniform matte terracotta, no edges — sculpt/shape-study look.
  static let clay = CADTheme(
    name: "Clay",
    roughness: 1.0, metallic: 0.0, edgeStrength: 0.0, neutralColor: [0.82, 0.68, 0.6, 1],
    overrideColor: [0.82, 0.66, 0.58, 1], background: [0.24, 0.23, 0.22],
    selectedFace: .systemTeal, selectedEdge: .systemBlue,
    edge: NSColor(red: 0.5, green: 0.4, blue: 0.35, alpha: 1),
    key: .init(color: [1.0, 0.97, 0.92], intensity: 3_400, from: [0.4, 0.9, 0.6]),
    fill: .init(color: [1.0, 0.95, 0.9], intensity: 2_400, from: [-0.7, 0.4, 0.5]),
    rim: .init(color: [1, 1, 1], intensity: 1_400, from: [0.1, 0.4, -0.9]))

  // Midnight: dark charcoal part, glowing cyan edges, black bg — dramatic.
  static let midnight = CADTheme(
    name: "Midnight Glow",
    roughness: 0.4, metallic: 0.5, edgeStrength: 0.9, neutralColor: [0.2, 0.22, 0.26, 1],
    overrideColor: [0.18, 0.2, 0.24, 1], background: [0.02, 0.02, 0.03],
    selectedFace: .systemPink, selectedEdge: .systemMint,
    edge: NSColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1),
    key: .init(color: [0.7, 0.85, 1.0], intensity: 3_000, from: [0.5, 0.8, 0.6]),
    fill: .init(color: [0.9, 0.5, 1.0], intensity: 1_400, from: [-0.8, 0.2, 0.4]),
    rim: .init(color: [0.4, 1.0, 0.9], intensity: 2_600, from: [0.1, 0.5, -0.9]))

  static let all: [CADTheme] = [
    .studioBlue, .showroom, .technical, .workshop,
    .solidworks, .onshape, .fusion, .blueprint, .clay, .midnight,
  ]
}
