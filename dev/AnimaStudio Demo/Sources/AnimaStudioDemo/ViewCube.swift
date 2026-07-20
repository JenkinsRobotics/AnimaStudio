// Orientation cube for the 3D viewport, built the same way the AnimaStudio app
// does it: project the cube's vertices orthographically, keep only camera-facing
// faces, depth-sort them, and hit-test with point-in-polygon. That gives correct
// occlusion and accurate clicks (stacked rotation3DEffect views give neither).
import CoreGraphics
import SwiftUI
import simd

enum ViewCubeFace: String, CaseIterable {
  case front, back, right, left, top, bottom

  var title: String { rawValue.uppercased() }

  var normal: SIMD3<Float> {
    switch self {
    case .front: return [0, 0, 1]
    case .back: return [0, 0, -1]
    case .right: return [1, 0, 0]
    case .left: return [-1, 0, 0]
    case .top: return [0, 1, 0]
    case .bottom: return [0, -1, 0]
    }
  }

  /// Camera orbit angles that look straight at this face.
  var cameraAngles: (yaw: Float, pitch: Float) {
    switch self {
    case .front: return (0, 0)
    case .back: return (.pi, 0)
    case .right: return (.pi / 2, 0)
    case .left: return (-.pi / 2, 0)
    case .top: return (0, 1.5)
    case .bottom: return (0, -1.5)
    }
  }

  var vertices: [SIMD3<Float>] {
    switch self {
    case .front: return [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]]
    case .back: return [[1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1]]
    case .right: return [[1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1]]
    case .left: return [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]]
    case .top: return [[-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1]]
    case .bottom: return [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]]
    }
  }
}

struct ProjectedCubeFace {
  let face: ViewCubeFace
  let points: [CGPoint]
  let depth: Float

  var center: CGPoint {
    let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
    return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
  }
}

enum ViewCubeGeometry {
  /// Screen basis for an orthographic view along `direction` (origin → camera).
  static func basis(_ direction: SIMD3<Float>) -> (right: SIMD3<Float>, up: SIMD3<Float>) {
    let forward = -simd_normalize(direction)
    var right = simd_cross(forward, SIMD3<Float>(0, 1, 0))
    right = simd_length_squared(right) < 0.0001 ? [1, 0, 0] : simd_normalize(right)
    let up = simd_normalize(simd_cross(right, forward))
    return (right, up)
  }

  static func project(_ point: SIMD3<Float>, in size: CGSize,
    basis: (right: SIMD3<Float>, up: SIMD3<Float>), scale: CGFloat) -> CGPoint
  {
    CGPoint(
      x: size.width / 2 + CGFloat(simd_dot(point, basis.right)) * scale,
      y: size.height / 2 - CGFloat(simd_dot(point, basis.up)) * scale)
  }

  /// Camera-facing faces only, back-to-front so painting order is correct.
  static func faces(in size: CGSize, direction: SIMD3<Float>) -> [ProjectedCubeFace] {
    let b = basis(direction)
    let scale = min(size.width, size.height) * 0.30
    return ViewCubeFace.allCases
      .filter { simd_dot($0.normal, direction) > 0.001 }
      .map { face in
        ProjectedCubeFace(
          face: face,
          points: face.vertices.map { project($0, in: size, basis: b, scale: scale) },
          depth: face.vertices.map { simd_dot($0, direction) }.reduce(0, +)
            / Float(face.vertices.count))
      }
      .sorted { $0.depth < $1.depth }
  }

  /// Topmost visible face under a point (searched front-to-back).
  static func face(at point: CGPoint, in size: CGSize, direction: SIMD3<Float>) -> ViewCubeFace? {
    faces(in: size, direction: direction).reversed()
      .first { contains(point, polygon: $0.points) }?.face
  }

  static func contains(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
    guard polygon.count >= 3 else { return false }
    var inside = false
    var previous = polygon[polygon.count - 1]
    for current in polygon {
      let crosses = (current.y > point.y) != (previous.y > point.y)
        && point.x < (previous.x - current.x) * (point.y - current.y)
          / (previous.y - current.y) + current.x
      if crosses { inside.toggle() }
      previous = current
    }
    return inside
  }
}

struct ViewCube: View {
  var yaw: Float
  var pitch: Float
  var size: CGFloat = 72
  var onSelect: (Float, Float) -> Void = { _, _ in }

  @State private var hovered: ViewCubeFace?

  /// Matches PartViewport.orbitDir — direction from the target toward the camera.
  private var direction: SIMD3<Float> {
    SIMD3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
  }

  var body: some View {
    VStack(spacing: 7) {
      Canvas { context, canvasSize in
        for projected in ViewCubeGeometry.faces(in: canvasSize, direction: direction) {
          var path = Path()
          path.move(to: projected.points[0])
          for point in projected.points.dropFirst() { path.addLine(to: point) }
          path.closeSubpath()

          let isHovered = hovered == projected.face
          context.fill(path, with: .color(fill(projected.face, hovered: isHovered)))
          context.stroke(path,
            with: .color(isHovered ? UI.accent : UI.stroke.opacity(0.9)),
            lineWidth: isHovered ? 1.6 : 1)

          let label = context.resolve(
            Text(projected.face.title)
              .font(.system(size: 7.5, weight: .bold))
              .foregroundStyle(isHovered ? UI.accent : UI.text2))
          context.draw(label, at: projected.center)
        }

        drawAxes(context, canvasSize)
      }
      .frame(width: size, height: size)
      .contentShape(Rectangle())
      .onContinuousHover { phase in
        switch phase {
        case .active(let point):
          hovered = ViewCubeGeometry.face(
            at: point, in: CGSize(width: size, height: size), direction: direction)
        case .ended:
          hovered = nil
        }
      }
      .onTapGesture { location in
        guard let face = ViewCubeGeometry.face(
          at: location, in: CGSize(width: size, height: size), direction: direction)
        else { return }
        let angles = face.cameraAngles
        withAnimation(.easeInOut(duration: 0.28)) { onSelect(angles.yaw, angles.pitch) }
      }

      Button { withAnimation(.easeInOut(duration: 0.28)) { onSelect(0.7, 0.42) } } label: {
        Text("ISO").font(.system(size: 8, weight: .bold)).tracking(0.6)
          .foregroundStyle(UI.text2)
          .padding(.horizontal, 9).padding(.vertical, 3)
          .background(UI.panelHi, in: Capsule())
          .overlay(Capsule().stroke(UI.stroke, lineWidth: 1))
      }
      .buttonStyle(.plain).help("Isometric view")
    }
  }

  /// The colored XYZ triad, projected with the same basis as the cube so it
  /// turns with the view. X red · Y green · Z blue, letters at each tip.
  private func drawAxes(_ context: GraphicsContext, _ canvasSize: CGSize) {
    let basis = ViewCubeGeometry.basis(direction)
    let scale = min(canvasSize.width, canvasSize.height) * 0.30
    let origin = ViewCubeGeometry.project([0, 0, 0], in: canvasSize, basis: basis, scale: scale)
    let axes: [(SIMD3<Float>, Color, String)] = [
      ([1, 0, 0], .red, "X"), ([0, 1, 0], .green, "Y"), ([0, 0, 1], .blue, "Z"),
    ]
    // Paint far-to-near so the nearer axis overlaps the farther one.
    for (vec, color, letter) in axes.sorted(by: {
      simd_dot($0.0, direction) < simd_dot($1.0, direction)
    }) {
      let tip = ViewCubeGeometry.project(vec * 1.55, in: canvasSize, basis: basis, scale: scale)
      var line = Path()
      line.move(to: origin)
      line.addLine(to: tip)
      context.stroke(line, with: .color(color), lineWidth: 1.8)
      context.fill(
        Path(ellipseIn: CGRect(x: tip.x - 5.5, y: tip.y - 5.5, width: 11, height: 11)),
        with: .color(color))
      context.draw(
        context.resolve(Text(letter).font(.system(size: 7, weight: .heavy))
          .foregroundStyle(.white)),
        at: tip)
    }
  }

  /// Simple directional shading so the cube reads as a solid.
  private func fill(_ face: ViewCubeFace, hovered: Bool) -> Color {
    if hovered { return UI.accent.opacity(0.34) }
    let light = simd_normalize(SIMD3<Float>(0.4, 0.9, 0.5))
    let lambert = max(simd_dot(face.normal, light), 0)
    return UI.panelHi.opacity(0.72 + Double(lambert) * 0.22)
  }
}
