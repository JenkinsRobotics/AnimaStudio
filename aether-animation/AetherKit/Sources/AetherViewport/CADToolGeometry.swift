import simd

/// In-world tools are REAL 3D geometry drawn by every renderer
/// (CONVENTIONS.md). This module owns the tool geometry itself —
/// transform-gizmo arrows/rings/plane tabs, mate-connector triads, and
/// snap-node stars — as renderer-neutral line lists that Metal and WebGPU
/// both consume. Renderers upload these vertices; they never rebuild the
/// shapes.
public struct CADToolVertex: Equatable, Sendable {
  public var position: SIMD4<Float>
  public var color: SIMD4<Float>

  public init(position: SIMD4<Float>, color: SIMD4<Float>) {
    self.position = position
    self.color = color
  }
}

/// The transform tool as REAL world-space geometry: translate arrows,
/// rotation rings, and plane tabs at the subject's frame, sized so the
/// longest arm projects to the same pixels as the overlay's gesture zones.
public struct CADGizmoPresentation: Equatable, Sendable {
  public var origin: SIMD3<Float>
  public var xAxis: SIMD3<Float>
  public var yAxis: SIMD3<Float>
  public var zAxis: SIMD3<Float>
  public var armLengthMeters: Float
  public var isEnabled: Bool

  public init(
    origin: SIMD3<Float>, xAxis: SIMD3<Float>, yAxis: SIMD3<Float>,
    zAxis: SIMD3<Float>, armLengthMeters: Float, isEnabled: Bool
  ) {
    self.origin = origin
    self.xAxis = xAxis
    self.yAxis = yAxis
    self.zAxis = zAxis
    self.armLengthMeters = armLengthMeters
    self.isEnabled = isEnabled
  }
}

/// A mate-connector frame drawn as real world-space triad geometry. The
/// origin/axes are part-local; the renderer applies the part's transform so
/// the triad stays glued to its component through drags and camera moves.
public struct CADConnectorMarker: Equatable, Sendable {
  public var partID: Int
  public var origin: SIMD3<Float>
  public var xAxis: SIMD3<Float>
  public var zAxis: SIMD3<Float>
  public var isSelected: Bool
  /// A small illuminated snap node (candidate) rather than a full triad.
  public var isNode: Bool

  public init(
    partID: Int, origin: SIMD3<Float>, xAxis: SIMD3<Float>,
    zAxis: SIMD3<Float>, isSelected: Bool, isNode: Bool = false
  ) {
    self.partID = partID
    self.origin = origin
    self.xAxis = xAxis
    self.zAxis = zAxis
    self.isSelected = isSelected
    self.isNode = isNode
  }
}

public enum CADToolGeometry {

  /// Gizmo line list: three arrows with barbed heads, three rotation
  /// rings, and three plane tabs. Colors carry the enabled/disabled
  /// policy so every renderer shows the identical tool.
  public static func gizmoLineVertices(
    _ gizmo: CADGizmoPresentation
  ) -> [CADToolVertex] {
    let arm = max(gizmo.armLengthMeters, 0.000_1)
    let origin = gizmo.origin
    let axes = [gizmo.xAxis, gizmo.yAxis, gizmo.zAxis]
    let axisColors: [SIMD4<Float>] =
      gizmo.isEnabled
      ? [SIMD4(0.95, 0.26, 0.21, 1), SIMD4(0.30, 0.85, 0.39, 1), SIMD4(0.25, 0.55, 1.0, 1)]
      : [SIMD4(0.62, 0.62, 0.66, 0.7), SIMD4(0.62, 0.62, 0.66, 0.7), SIMD4(0.62, 0.62, 0.66, 0.7)]
    let planeColors: [SIMD4<Float>] =
      gizmo.isEnabled
      ? [SIMD4(0.95, 0.83, 0.20, 0.9), SIMD4(0.25, 0.85, 0.90, 0.9), SIMD4(0.72, 0.42, 0.95, 0.9)]
      : [SIMD4(0.62, 0.62, 0.66, 0.5), SIMD4(0.62, 0.62, 0.66, 0.5), SIMD4(0.62, 0.62, 0.66, 0.5)]
    var vertices: [CADToolVertex] = []

    for (index, axis) in axes.enumerated() {
      let color = axisColors[index]
      let tip = origin + axis * arm
      appendLine(from: origin, to: tip, color: color, into: &vertices)
      // Arrowhead: four short barbs angled back from the tip.
      let side = axes[(index + 1) % 3]
      let up = axes[(index + 2) % 3]
      let back = tip - axis * arm * 0.14
      for direction in [side, -side, up, -up] {
        appendLine(
          from: tip, to: back + direction * arm * 0.05, color: color, into: &vertices)
      }
      // Rotation ring around this axis, in the plane of the other two arms.
      let first = axes[(index + 1) % 3]
      let second = axes[(index + 2) % 3]
      let radius = arm * 0.82
      var previous: SIMD3<Float>?
      for step in 0...48 {
        let angle = Float(step) / 48 * 2 * .pi
        let point = origin + first * (cos(angle) * radius) + second * (sin(angle) * radius)
        if let previous {
          appendLine(from: previous, to: point, color: color, into: &vertices)
        }
        previous = point
      }
    }

    // Plane tabs: small parallelograms between each axis pair (XY, YZ, ZX).
    let planes = [(0, 1), (1, 2), (2, 0)]
    for (index, pair) in planes.enumerated() {
      let a = axes[pair.0]
      let b = axes[pair.1]
      let color = planeColors[index]
      let near: Float = 0.32
      let far: Float = 0.55
      let corners = [
        origin + a * (arm * near) + b * (arm * near),
        origin + a * (arm * far) + b * (arm * near),
        origin + a * (arm * far) + b * (arm * far),
        origin + a * (arm * near) + b * (arm * far),
      ]
      for cornerIndex in 0..<4 {
        appendLine(
          from: corners[cornerIndex], to: corners[(cornerIndex + 1) % 4],
          color: color, into: &vertices)
      }
    }
    return vertices
  }

  /// Connector triads and snap-node stars, world-space: part-local frames
  /// carried through each part's current transform so tools track drags
  /// exactly like the model.
  public static func connectorMarkerLineVertices(
    markers: [CADConnectorMarker],
    transformsByPartID: [Int: simd_float4x4],
    axisLength: Float
  ) -> [CADToolVertex] {
    var vertices: [CADToolVertex] = []
    for marker in markers {
      let transform = transformsByPartID[marker.partID] ?? matrix_identity_float4x4
      func world(_ v: SIMD3<Float>) -> SIMD3<Float> {
        let p = transform * SIMD4(v, 1)
        return SIMD3(p.x, p.y, p.z)
      }
      func rotated(_ v: SIMD3<Float>) -> SIMD3<Float> {
        let p = transform * SIMD4(v, 0)
        return SIMD3(p.x, p.y, p.z)
      }
      let origin = world(marker.origin)
      var z = rotated(marker.zAxis)
      if simd_length_squared(z) < 0.000_001 { z = SIMD3(0, 0, 1) }
      z = simd_normalize(z)
      var x = rotated(marker.xAxis)
      x -= z * simd_dot(x, z)
      if simd_length_squared(x) < 0.000_001 {
        x = abs(z.y) < 0.9 ? simd_cross(SIMD3(0, 1, 0), z) : simd_cross(SIMD3(1, 0, 0), z)
      }
      x = simd_normalize(x)
      let y = simd_cross(z, x)
      if marker.isNode {
        // Candidate node: a small neutral star, visibly snappable but
        // subordinate to the full triad of the active pick.
        let nodeLength = axisLength * 0.3
        let nodeColor = SIMD4<Float>(0.20, 0.82, 1.0, 0.9)
        appendLine(
          from: origin - x * nodeLength, to: origin + x * nodeLength,
          color: nodeColor, into: &vertices)
        appendLine(
          from: origin - y * nodeLength, to: origin + y * nodeLength,
          color: nodeColor, into: &vertices)
        appendLine(
          from: origin - z * nodeLength, to: origin + z * nodeLength,
          color: nodeColor, into: &vertices)
        continue
      }
      let emphasis: Float = marker.isSelected ? 1.3 : 1
      appendLine(
        from: origin, to: origin + x * axisLength * emphasis,
        color: SIMD4(0.95, 0.26, 0.21, 1), into: &vertices)
      appendLine(
        from: origin, to: origin + y * axisLength * emphasis,
        color: SIMD4(0.30, 0.85, 0.39, 1), into: &vertices)
      appendLine(
        from: origin, to: origin + z * axisLength * 1.4 * emphasis,
        color: SIMD4(0.25, 0.55, 1.0, 1), into: &vertices)
    }
    return vertices
  }

  private static func appendLine(
    from start: SIMD3<Float>,
    to end: SIMD3<Float>,
    color: SIMD4<Float>,
    into vertices: inout [CADToolVertex]
  ) {
    vertices.append(CADToolVertex(position: SIMD4(start, 1), color: color))
    vertices.append(CADToolVertex(position: SIMD4(end, 1), color: color))
  }
}
