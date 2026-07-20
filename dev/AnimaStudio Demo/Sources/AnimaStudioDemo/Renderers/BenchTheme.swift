import AppKit
import SwiftUI

struct BenchTheme: Codable, Identifiable, Hashable {
  struct Light: Codable, Hashable {
    var color: SIMD3<Float>
    var intensity: Float
    var directionFrom: SIMD3<Float>
  }

  let name: String
  var roughness: Float
  var metallic: Float
  var edgeStrength: Float
  var neutralColor: SIMD4<Float>
  var overrideColor: SIMD4<Float>?
  var background: SIMD3<Float>
  var edgeColor: SIMD3<Float>
  var selectionColor: SIMD3<Float>
  var edgeSelectionColor: SIMD3<Float>
  var key: Light
  var fill: Light
  var rim: Light

  var id: String { name }

  var backgroundNSColor: NSColor {
    NSColor(
      srgbRed: CGFloat(background.x), green: CGFloat(background.y), blue: CGFloat(background.z),
      alpha: 1)
  }

  var backgroundColor: Color { Color(nsColor: backgroundNSColor) }

  func displayColor(for importedColor: SIMD4<Float>) -> SIMD4<Float> {
    overrideColor ?? importedColor
  }

  var panelColor: Color {
    Color(
      red: Double(background.x) * 0.62,
      green: Double(background.y) * 0.62,
      blue: Double(background.z) * 0.62)
  }

  static func named(_ name: String?) -> BenchTheme {
    all.first { $0.name == name } ?? .studioBlue
  }

  var isCustomized: Bool { self != Self.named(name) }

  static let studioBlue = BenchTheme(
    name: "Studio Blue",
    roughness: 0.50, metallic: 0.0, edgeStrength: 0.70,
    neutralColor: [0.72, 0.74, 0.78, 1], overrideColor: nil,
    background: [0.16, 0.17, 0.19],
    edgeColor: [0.16, 0.18, 0.22], selectionColor: [1.0, 0.48, 0.0],
    edgeSelectionColor: [0.0, 0.72, 0.72],
    key: .init(color: [1, 1, 1], intensity: 3_000, directionFrom: [0.5, 0.9, 0.6]),
    fill: .init(color: [0.75, 0.82, 1.0], intensity: 1_200, directionFrom: [-0.7, 0.3, 0.4]),
    rim: .init(color: [1, 1, 1], intensity: 900, directionFrom: [0.1, 0.5, -0.8]))

  static let showroom = BenchTheme(
    name: "Showroom",
    roughness: 0.35, metallic: 0.10, edgeStrength: 0.0,
    neutralColor: [0.82, 0.84, 0.87, 1], overrideColor: nil,
    background: [0.36, 0.38, 0.42],
    edgeColor: [0.30, 0.32, 0.36], selectionColor: [1.0, 0.48, 0.0],
    edgeSelectionColor: [0.1, 0.48, 1.0],
    key: .init(color: [1, 1, 1], intensity: 4_200, directionFrom: [0.4, 1.0, 0.7]),
    fill: .init(color: [0.9, 0.93, 1.0], intensity: 2_400, directionFrom: [-0.8, 0.4, 0.5]),
    rim: .init(color: [1, 1, 1], intensity: 1_400, directionFrom: [0.0, 0.4, -0.9]))

  static let technical = BenchTheme(
    name: "Technical Matte",
    roughness: 0.95, metallic: 0.0, edgeStrength: 1.0,
    neutralColor: [0.70, 0.72, 0.74, 1], overrideColor: nil,
    background: [0.22, 0.23, 0.24],
    edgeColor: [0.12, 0.13, 0.14], selectionColor: [0.2, 0.78, 0.35],
    edgeSelectionColor: [1.0, 0.82, 0.0],
    key: .init(color: [1, 1, 1], intensity: 2_200, directionFrom: [0.3, 0.9, 0.5]),
    fill: .init(color: [1, 1, 1], intensity: 2_000, directionFrom: [-0.6, 0.5, 0.5]),
    rim: .init(color: [0.9, 0.9, 0.9], intensity: 1_400, directionFrom: [-0.2, 0.3, -0.8]))

  static let workshop = BenchTheme(
    name: "Warm Workshop",
    roughness: 0.50, metallic: 0.20, edgeStrength: 0.50,
    neutralColor: [0.74, 0.72, 0.68, 1], overrideColor: nil,
    background: [0.09, 0.08, 0.07],
    edgeColor: [0.20, 0.16, 0.12], selectionColor: [0.0, 0.72, 0.72],
    edgeSelectionColor: [1.0, 0.48, 0.0],
    key: .init(color: [1.0, 0.9, 0.72], intensity: 3_400, directionFrom: [0.6, 0.8, 0.5]),
    fill: .init(color: [0.6, 0.7, 0.9], intensity: 800, directionFrom: [-0.8, 0.2, 0.3]),
    rim: .init(color: [1.0, 0.95, 0.85], intensity: 1_600, directionFrom: [0.2, 0.6, -0.9]))

  static let solidWorks = BenchTheme(
    name: "SolidWorks",
    roughness: 0.45, metallic: 0.35, edgeStrength: 0.60,
    neutralColor: [0.60, 0.62, 0.66, 1], overrideColor: [0.55, 0.58, 0.63, 1],
    background: [0.22, 0.28, 0.38], edgeColor: [0.10, 0.11, 0.13],
    selectionColor: [0.10, 0.48, 1.0], edgeSelectionColor: [0.0, 0.78, 0.95],
    key: .init(color: [1, 1, 1], intensity: 4_000, directionFrom: [0.4, 0.9, 0.6]),
    fill: .init(color: [0.9, 0.94, 1.0], intensity: 2_600, directionFrom: [-0.7, 0.4, 0.5]),
    rim: .init(color: [1, 1, 1], intensity: 1_600, directionFrom: [0.1, 0.4, -0.9]))

  static let onshape = BenchTheme(
    name: "Onshape",
    roughness: 0.55, metallic: 0.10, edgeStrength: 0.35,
    neutralColor: [0.70, 0.74, 0.80, 1], overrideColor: [0.66, 0.71, 0.78, 1],
    background: [0.86, 0.88, 0.90], edgeColor: [0.35, 0.38, 0.42],
    selectionColor: [1.0, 0.48, 0.0], edgeSelectionColor: [0.10, 0.48, 1.0],
    key: .init(color: [1, 1, 1], intensity: 5_500, directionFrom: [0.3, 1.0, 0.6]),
    fill: .init(color: [1, 1, 1], intensity: 4_500, directionFrom: [-0.7, 0.5, 0.5]),
    rim: .init(color: [1, 1, 1], intensity: 2_500, directionFrom: [0.0, 0.3, -0.9]))

  static let fusion360 = BenchTheme(
    name: "Fusion 360",
    roughness: 0.40, metallic: 0.25, edgeStrength: 0.40,
    neutralColor: [0.66, 0.64, 0.62, 1], overrideColor: [0.68, 0.66, 0.63, 1],
    background: [0.14, 0.15, 0.17], edgeColor: [0.12, 0.12, 0.13],
    selectionColor: [0.10, 0.48, 1.0], edgeSelectionColor: [1.0, 0.48, 0.0],
    key: .init(color: [1.0, 0.98, 0.94], intensity: 4_200, directionFrom: [0.5, 0.9, 0.7]),
    fill: .init(color: [0.85, 0.9, 1.0], intensity: 2_200, directionFrom: [-0.7, 0.3, 0.4]),
    rim: .init(color: [1, 1, 1], intensity: 1_800, directionFrom: [0.2, 0.5, -0.9]))

  static let blueprint = BenchTheme(
    name: "Blueprint",
    roughness: 0.90, metallic: 0.0, edgeStrength: 1.0,
    neutralColor: [0.80, 0.86, 0.95, 1], overrideColor: [0.42, 0.55, 0.78, 1],
    background: [0.05, 0.10, 0.24], edgeColor: [0.75, 0.90, 1.0],
    selectionColor: [0.0, 0.72, 0.72], edgeSelectionColor: [1.0, 1.0, 1.0],
    key: .init(color: [0.8, 0.88, 1.0], intensity: 2_400, directionFrom: [0.3, 0.9, 0.4]),
    fill: .init(color: [0.6, 0.72, 1.0], intensity: 2_200, directionFrom: [-0.8, 0.5, 0.5]),
    rim: .init(color: [0.9, 0.95, 1.0], intensity: 2_000, directionFrom: [-0.2, 0.4, -0.9]))

  static let clay = BenchTheme(
    name: "Clay",
    roughness: 1.0, metallic: 0.0, edgeStrength: 0.0,
    neutralColor: [0.82, 0.68, 0.60, 1], overrideColor: [0.82, 0.66, 0.58, 1],
    background: [0.24, 0.23, 0.22], edgeColor: [0.50, 0.40, 0.35],
    selectionColor: [0.0, 0.72, 0.72], edgeSelectionColor: [0.10, 0.48, 1.0],
    key: .init(color: [1.0, 0.97, 0.92], intensity: 3_400, directionFrom: [0.4, 0.9, 0.6]),
    fill: .init(color: [1.0, 0.95, 0.9], intensity: 2_400, directionFrom: [-0.7, 0.4, 0.5]),
    rim: .init(color: [1, 1, 1], intensity: 1_400, directionFrom: [0.1, 0.4, -0.9]))

  static let midnight = BenchTheme(
    name: "Midnight Glow",
    roughness: 0.40, metallic: 0.50, edgeStrength: 0.90,
    neutralColor: [0.20, 0.22, 0.26, 1], overrideColor: [0.18, 0.20, 0.24, 1],
    background: [0.02, 0.02, 0.03], edgeColor: [0.20, 0.90, 1.0],
    selectionColor: [1.0, 0.20, 0.65], edgeSelectionColor: [0.35, 1.0, 0.75],
    key: .init(color: [0.7, 0.85, 1.0], intensity: 3_000, directionFrom: [0.5, 0.8, 0.6]),
    fill: .init(color: [0.9, 0.5, 1.0], intensity: 1_400, directionFrom: [-0.8, 0.2, 0.4]),
    rim: .init(color: [0.4, 1.0, 0.9], intensity: 2_600, directionFrom: [0.1, 0.5, -0.9]))

  static let all: [BenchTheme] = [
    .studioBlue, .showroom, .technical, .workshop, .solidWorks,
    .onshape, .fusion360, .blueprint, .clay, .midnight,
  ]
}
