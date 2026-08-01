import AppKit
import Foundation

public struct CADViewportTheme: Codable, Identifiable, Hashable, Sendable {
  public struct Light: Codable, Hashable, Sendable {
    public var color: SIMD3<Float>
    public var intensity: Float
    public var directionFrom: SIMD3<Float>

    public init(color: SIMD3<Float>, intensity: Float, directionFrom: SIMD3<Float>) {
      self.color = color
      self.intensity = intensity
      self.directionFrom = directionFrom
    }
  }

  public let name: String
  public var roughness: Float
  public var metallic: Float
  public var edgeStrength: Float
  public var ambientStrength: Float
  public var shadowStrength: Float
  public var neutralColor: SIMD4<Float>
  public var overrideColor: SIMD4<Float>?
  public var background: SIMD3<Float>
  /// Bottom color of a vertical background gradient; `nil` keeps the flat
  /// `background` color (additive — older persisted themes decode as solid).
  public var backgroundBottom: SIMD3<Float>?
  /// Matte color of the optional solid environment floor plane.
  public var floorColor: SIMD3<Float>
  /// Per-theme environment-floor defaults: whether choosing this preset
  /// shows the Unity-style grid and/or the solid ground plane.
  public var floorGrid: Bool
  public var solidFloor: Bool
  public var edgeColor: SIMD3<Float>
  public var selectionColor: SIMD3<Float>
  public var edgeSelectionColor: SIMD3<Float>
  public var key: Light
  public var fill: Light
  public var rim: Light

  public var id: String { name }

  public init(
    name: String,
    roughness: Float,
    metallic: Float,
    edgeStrength: Float,
    neutralColor: SIMD4<Float>,
    overrideColor: SIMD4<Float>? = nil,
    background: SIMD3<Float>,
    edgeColor: SIMD3<Float>,
    selectionColor: SIMD3<Float>,
    edgeSelectionColor: SIMD3<Float>,
    key: Light,
    fill: Light,
    rim: Light,
    ambientStrength: Float = 0.30,
    shadowStrength: Float = 0.55,
    backgroundBottom: SIMD3<Float>? = nil,
    floorColor: SIMD3<Float> = SIMD3(0.36, 0.37, 0.40),
    floorGrid: Bool = true,
    solidFloor: Bool = false
  ) {
    self.name = name
    self.roughness = roughness
    self.metallic = metallic
    self.edgeStrength = edgeStrength
    self.ambientStrength = ambientStrength
    self.shadowStrength = shadowStrength
    self.neutralColor = neutralColor
    self.overrideColor = overrideColor
    self.background = background
    self.backgroundBottom = backgroundBottom
    self.floorColor = floorColor
    self.floorGrid = floorGrid
    self.solidFloor = solidFloor
    self.edgeColor = edgeColor
    self.selectionColor = selectionColor
    self.edgeSelectionColor = edgeSelectionColor
    self.key = key
    self.fill = fill
    self.rim = rim
  }

  public func displayColor(for importedColor: SIMD4<Float>) -> SIMD4<Float> {
    overrideColor ?? importedColor
  }

  public static func named(_ name: String?) -> Self {
    all.first { $0.name == name } ?? .defaultTheme
  }

  /// The coordinated CAD environment used when an operator has not selected
  /// and saved a different preset.
  public static var defaultTheme: Self { .onshape }

  private static func theme(
    _ name: String,
    roughness: Float,
    metallic: Float,
    edge: Float,
    model: SIMD4<Float>,
    override: SIMD4<Float>? = nil,
    background: SIMD3<Float>,
    edgeColor: SIMD3<Float>,
    selection: SIMD3<Float>,
    edgeSelection: SIMD3<Float>,
    key: (SIMD3<Float>, Float, SIMD3<Float>),
    fill: (SIMD3<Float>, Float, SIMD3<Float>),
    rim: (SIMD3<Float>, Float, SIMD3<Float>),
    ambient: Float = 0.30,
    shadow: Float = 0.55,
    bottom: SIMD3<Float>? = nil,
    floor: SIMD3<Float> = SIMD3(0.36, 0.37, 0.40),
    floorGrid: Bool = true,
    solidFloor: Bool = false
  ) -> Self {
    Self(
      name: name, roughness: roughness, metallic: metallic, edgeStrength: edge,
      neutralColor: model, overrideColor: override, background: background,
      edgeColor: edgeColor, selectionColor: selection, edgeSelectionColor: edgeSelection,
      key: .init(color: key.0, intensity: key.1, directionFrom: key.2),
      fill: .init(color: fill.0, intensity: fill.1, directionFrom: fill.2),
      rim: .init(color: rim.0, intensity: rim.1, directionFrom: rim.2),
      ambientStrength: ambient,
      shadowStrength: shadow,
      backgroundBottom: bottom,
      floorColor: floor,
      floorGrid: floorGrid,
      solidFloor: solidFloor
    )
  }

  /// Unity-editor-style environment: dark gradient sky, grid over a solid
  /// shadow-receiving floor — the preset that demonstrates the floor layer.
  public static let unity = theme(
    "Unity", roughness: 0.55, metallic: 0.02, edge: 0.55,
    model: [0.74, 0.75, 0.78, 1], background: [0.21, 0.22, 0.25],
    edgeColor: [0.13, 0.14, 0.16], selection: [1, 0.48, 0], edgeSelection: [0.35, 0.62, 1],
    key: ([1, 0.98, 0.94], 4_000, [0.4, 1, 0.55]),
    fill: ([0.80, 0.85, 0.95], 1_500, [-0.7, 0.35, 0.45]),
    rim: ([1, 1, 1], 900, [0.05, 0.45, -0.85]),
    ambient: 0.26,
    bottom: [0.11, 0.12, 0.14],
    floor: [0.20, 0.21, 0.23],
    floorGrid: true,
    solidFloor: true)

  public static let studioBlue = theme(
    "Studio Blue", roughness: 0.50, metallic: 0, edge: 0.70,
    model: [0.72, 0.74, 0.78, 1], background: [0.16, 0.17, 0.19],
    edgeColor: [0.16, 0.18, 0.22], selection: [1, 0.48, 0], edgeSelection: [0, 0.72, 0.72],
    key: ([1, 1, 1], 3_000, [0.5, 0.9, 0.6]),
    fill: ([0.75, 0.82, 1], 1_200, [-0.7, 0.3, 0.4]),
    rim: ([1, 1, 1], 900, [0.1, 0.5, -0.8]))

  public static let showroom = theme(
    "Showroom", roughness: 0.35, metallic: 0.10, edge: 0,
    model: [0.82, 0.84, 0.87, 1], background: [0.36, 0.38, 0.42],
    edgeColor: [0.30, 0.32, 0.36], selection: [1, 0.48, 0], edgeSelection: [0.1, 0.48, 1],
    key: ([1, 1, 1], 4_200, [0.4, 1, 0.7]),
    fill: ([0.9, 0.93, 1], 2_400, [-0.8, 0.4, 0.5]),
    rim: ([1, 1, 1], 1_400, [0, 0.4, -0.9]))

  public static let technical = theme(
    "Technical Matte", roughness: 0.95, metallic: 0, edge: 1,
    model: [0.70, 0.72, 0.74, 1], background: [0.22, 0.23, 0.24],
    edgeColor: [0.12, 0.13, 0.14], selection: [0.2, 0.78, 0.35], edgeSelection: [1, 0.82, 0],
    key: ([1, 1, 1], 2_200, [0.3, 0.9, 0.5]),
    fill: ([1, 1, 1], 2_000, [-0.6, 0.5, 0.5]),
    rim: ([0.9, 0.9, 0.9], 1_400, [-0.2, 0.3, -0.8]))

  public static let workshop = theme(
    "Warm Workshop", roughness: 0.50, metallic: 0.20, edge: 0.50,
    model: [0.74, 0.72, 0.68, 1], background: [0.09, 0.08, 0.07],
    edgeColor: [0.20, 0.16, 0.12], selection: [0, 0.72, 0.72], edgeSelection: [1, 0.48, 0],
    key: ([1, 0.9, 0.72], 3_400, [0.6, 0.8, 0.5]),
    fill: ([0.6, 0.7, 0.9], 800, [-0.8, 0.2, 0.3]),
    rim: ([1, 0.95, 0.85], 1_600, [0.2, 0.6, -0.9]))

  public static let solidWorks = theme(
    "SolidWorks", roughness: 0.45, metallic: 0.35, edge: 0.60,
    model: [0.60, 0.62, 0.66, 1], override: [0.55, 0.58, 0.63, 1],
    background: [0.22, 0.28, 0.38], edgeColor: [0.10, 0.11, 0.13],
    selection: [0.10, 0.48, 1], edgeSelection: [0, 0.78, 0.95],
    key: ([1, 1, 1], 4_000, [0.4, 0.9, 0.6]),
    fill: ([0.9, 0.94, 1], 2_600, [-0.7, 0.4, 0.5]),
    rim: ([1, 1, 1], 1_600, [0.1, 0.4, -0.9]))

  public static let onshape = theme(
    "Onshape", roughness: 0.46, metallic: 0.02, edge: 0.82,
    model: [0.52, 0.68, 0.78, 1], override: [0.52, 0.68, 0.78, 1],
    background: [0.985, 0.988, 0.992], edgeColor: [0.07, 0.10, 0.12],
    selection: [1, 0.48, 0], edgeSelection: [1, 0.48, 0],
    key: ([1, 1, 1], 4_400, [0.35, 1, 0.65]),
    fill: ([0.97, 0.99, 1], 1_650, [-0.75, 0.55, 0.45]),
    rim: ([1, 1, 1], 1_200, [0.05, 0.35, -0.9]),
    ambient: 0.24,
    shadow: 0.72)

  public static let fusion360 = theme(
    "Fusion 360", roughness: 0.40, metallic: 0.25, edge: 0.40,
    model: [0.66, 0.64, 0.62, 1], override: [0.68, 0.66, 0.63, 1],
    background: [0.14, 0.15, 0.17], edgeColor: [0.12, 0.12, 0.13],
    selection: [0.10, 0.48, 1], edgeSelection: [1, 0.48, 0],
    key: ([1, 0.98, 0.94], 4_200, [0.5, 0.9, 0.7]),
    fill: ([0.85, 0.9, 1], 2_200, [-0.7, 0.3, 0.4]),
    rim: ([1, 1, 1], 1_800, [0.2, 0.5, -0.9]))

  public static let blueprint = theme(
    "Blueprint", roughness: 0.90, metallic: 0, edge: 1,
    model: [0.80, 0.86, 0.95, 1], override: [0.42, 0.55, 0.78, 1],
    background: [0.05, 0.10, 0.24], edgeColor: [0.75, 0.90, 1],
    selection: [0, 0.72, 0.72], edgeSelection: [1, 1, 1],
    key: ([0.8, 0.88, 1], 2_400, [0.3, 0.9, 0.4]),
    fill: ([0.6, 0.72, 1], 2_200, [-0.8, 0.5, 0.5]),
    rim: ([0.9, 0.95, 1], 2_000, [-0.2, 0.4, -0.9]))

  public static let clay = theme(
    "Clay", roughness: 1, metallic: 0, edge: 0,
    model: [0.82, 0.68, 0.60, 1], override: [0.82, 0.66, 0.58, 1],
    background: [0.24, 0.23, 0.22], edgeColor: [0.50, 0.40, 0.35],
    selection: [0, 0.72, 0.72], edgeSelection: [0.10, 0.48, 1],
    key: ([1, 0.97, 0.92], 3_400, [0.4, 0.9, 0.6]),
    fill: ([1, 0.95, 0.9], 2_400, [-0.7, 0.4, 0.5]),
    rim: ([1, 1, 1], 1_400, [0.1, 0.4, -0.9]))

  public static let midnight = theme(
    "Midnight Glow", roughness: 0.40, metallic: 0.50, edge: 0.90,
    model: [0.20, 0.22, 0.26, 1], override: [0.18, 0.20, 0.24, 1],
    background: [0.02, 0.02, 0.03], edgeColor: [0.20, 0.90, 1],
    selection: [1, 0.20, 0.65], edgeSelection: [0.35, 1, 0.75],
    key: ([0.7, 0.85, 1], 3_000, [0.5, 0.8, 0.6]),
    fill: ([0.9, 0.5, 1], 1_400, [-0.8, 0.2, 0.4]),
    rim: ([0.4, 1, 0.9], 2_600, [0.1, 0.5, -0.9]))


  /// The OCCT Mate Lab's browser environment (operator-requested port,
  /// 2026-08-01): light cool-gray studio, steel-blue parts, slate edges,
  /// bright hemisphere-style lighting, cyan/orange selection accents.
  public static let mateLab = theme(
    "Mate Lab", roughness: 0.56, metallic: 0.05, edge: 0.80,
    model: [0.475, 0.663, 0.761, 1], background: [0.949, 0.961, 0.973],
    edgeColor: [0.114, 0.204, 0.259], selection: [1.0, 0.675, 0.224],
    edgeSelection: [0.20, 0.816, 1.0],
    key: ([1, 1, 1], 4_600, [0.40, 1, 0.55]),
    fill: ([0.725, 0.863, 1.0], 1_800, [-0.70, 0.35, 0.45]),
    rim: ([1, 1, 1], 800, [0.05, 0.45, -0.85]),
    ambient: 0.34,
    floor: [0.796, 0.831, 0.863],
    floorGrid: true,
    solidFloor: false)

  public static let all: [Self] = [
    .studioBlue, .showroom, .technical, .workshop, .solidWorks,
    .onshape, .fusion360, .blueprint, .clay, .midnight, .unity, .mateLab,
  ]
}
