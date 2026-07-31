import SwiftUI
import simd

enum CADGizmoInteraction {
  static let viewportCoordinateSpace = "CADTransformGizmoViewport"

  /// Project a pointer delta onto the actual displayed local-axis direction.
  static func axisDragPoints(
    _ translation: CGSize,
    projectedAxis: SIMD2<Double>
  ) -> Double {
    let length = simd_length(projectedAxis)
    guard length > 0.000_1 else { return 0 }
    let unit = projectedAxis / length
    return SIMD2(Double(translation.width), Double(translation.height)).dot(unit)
  }

  /// Resolve a pointer delta into two non-orthogonal projected axis
  /// coefficients. Perspective can make local orthogonal axes non-perpendicular
  /// on screen, so two independent dot products are not sufficient.
  static func planeDragPoints(
    _ translation: CGSize,
    firstAxis: SIMD2<Double>,
    secondAxis: SIMD2<Double>
  ) -> SIMD2<Double> {
    let firstLength = simd_length(firstAxis)
    let secondLength = simd_length(secondAxis)
    guard firstLength > 0.000_1, secondLength > 0.000_1 else { return .zero }
    let first = firstAxis / firstLength
    let second = secondAxis / secondLength
    let determinant = first.x * second.y - first.y * second.x
    let delta = SIMD2(Double(translation.width), Double(translation.height))
    guard abs(determinant) > 0.025 else {
      return SIMD2(delta.dot(first), delta.dot(second))
    }
    return SIMD2(
      (delta.x * second.y - delta.y * second.x) / determinant,
      (first.x * delta.y - first.y * delta.x) / determinant)
  }

  static func rotationRadians(
    start: CGPoint,
    current: CGPoint,
    center: CGPoint,
    orientationSign: Double
  ) -> Double {
    let startAngle = atan2(
      Double(start.y - center.y),
      Double(start.x - center.x))
    let currentAngle = atan2(
      Double(current.y - center.y),
      Double(current.x - center.x))
    var delta = currentAngle - startAngle
    if delta > .pi { delta -= 2 * .pi }
    if delta < -.pi { delta += 2 * .pi }
    return delta * (orientationSign < 0 ? -1 : 1)
  }
}

struct CADGizmoProjectedGeometry: Equatable {
  static let side: CGFloat = 232
  static let center = CGPoint(x: side * 0.5, y: side * 0.5)
  static let targetAxisLength: Double = 72

  let xAxis: SIMD2<Double>
  let yAxis: SIMD2<Double>
  let zAxis: SIMD2<Double>

  init(projectedFrame: CADProjectedLocalFrame, viewportSize: CGSize) {
    let origin = projectedFrame.origin
    func viewportVector(_ endpoint: CADNormalizedViewportPoint) -> SIMD2<Double> {
      SIMD2(
        (endpoint.x - origin.x) * Double(viewportSize.width),
        (endpoint.y - origin.y) * Double(viewportSize.height))
    }
    let rawX = viewportVector(projectedFrame.xAxis)
    let rawY = viewportVector(projectedFrame.yAxis)
    let rawZ = viewportVector(projectedFrame.zAxis)
    let longest = max(
      max(simd_length(rawX), simd_length(rawY)),
      max(simd_length(rawZ), 0.000_1))
    let scale = Self.targetAxisLength / longest
    xAxis = rawX * scale
    yAxis = rawY * scale
    zAxis = rawZ * scale
  }

  func vector(_ axis: CADTransformAxis) -> SIMD2<Double> {
    switch axis {
    case .x: xAxis
    case .y: yAxis
    case .z: zAxis
    }
  }

  func planeAxes(_ plane: CADTransformPlane) -> (
    first: CADTransformAxis, second: CADTransformAxis
  ) {
    switch plane {
    case .xy: (.x, .y)
    case .yz: (.y, .z)
    case .zx: (.z, .x)
    }
  }

  func rotationAxes(_ axis: CADTransformAxis) -> (
    first: CADTransformAxis, second: CADTransformAxis
  ) {
    switch axis {
    case .x: (.y, .z)
    case .y: (.z, .x)
    case .z: (.x, .y)
    }
  }

  func rotationOrientationSign(_ axis: CADTransformAxis) -> Double {
    let axes = rotationAxes(axis)
    let first = vector(axes.first)
    let second = vector(axes.second)
    let determinant = first.x * second.y - first.y * second.x
    return determinant < 0 ? -1 : 1
  }
}

enum CADTransformPlane: String, CaseIterable, Sendable {
  case xy
  case yz
  case zx
}

extension SIMD2<Double> {
  fileprivate init(_ point: CGPoint) {
    self.init(Double(point.x), Double(point.y))
  }

  fileprivate func dot(_ other: SIMD2<Double>) -> Double {
    x * other.x + y * other.y
  }

  fileprivate var point: CGPoint { CGPoint(x: x, y: y) }
}

enum CADDirectManipulation {
  /// Moves a transform parallel to the camera plane. AppKit reports positive Y
  /// upward, so the screen delta maps directly to the camera's corrected up
  /// vector. Keeping the starting transform fixed prevents incremental drift.
  static func translated(
    _ transform: CADPartRestTransform,
    screenTranslation: CGSize,
    viewportHeightPoints: Double,
    cameraPosition: SIMD3<Float>,
    cameraTarget: SIMD3<Float>,
    cameraUp: SIMD3<Float>,
    verticalFieldOfViewRadians: Double = 45 * .pi / 180
  ) -> CADPartRestTransform {
    let forwardValue = cameraTarget - cameraPosition
    guard simd_length(forwardValue) > 0.000_001 else { return transform }
    let forward = simd_normalize(forwardValue)
    let rightValue = simd_cross(forward, cameraUp)
    guard simd_length(rightValue) > 0.000_001 else { return transform }
    let right = simd_normalize(rightValue)
    let up = simd_normalize(simd_cross(right, forward))
    let origin = SIMD3<Float>(
      Float(transform.positionMeters[0]),
      Float(transform.positionMeters[1]),
      Float(transform.positionMeters[2]))
    let depth = max(Double(simd_dot(origin - cameraPosition, forward)), 0.001)
    let metersPerPoint =
      2 * depth * tan(verticalFieldOfViewRadians * 0.5) / max(viewportHeightPoints, 1)
    let offset =
      SIMD3<Double>(right) * (Double(screenTranslation.width) * metersPerPoint)
      + SIMD3<Double>(up) * (Double(screenTranslation.height) * metersPerPoint)
    var result = transform
    result.positionMeters[0] += offset.x
    result.positionMeters[1] += offset.y
    result.positionMeters[2] += offset.z
    return result
  }
}

/// Renderer-independent direct-manipulation surface. The GPU adapters draw the
/// selected frame and transformed mesh; this overlay owns hit testing and turns
/// pointer deltas into edits of AnimaCore's part rest transform.
struct CADTransformGizmoOverlay: View {
  let transform: CADPartRestTransform
  let projectedFrame: CADProjectedLocalFrame
  let viewportSize: CGSize
  let label: String
  let isEnabled: Bool
  let metersPerPoint: Double
  let onChange: @MainActor @Sendable (CADPartRestTransform) -> Void

  var body: some View {
    let geometry = CADGizmoProjectedGeometry(
      projectedFrame: projectedFrame,
      viewportSize: viewportSize)
    ZStack {
      planeHandle(.xy, geometry: geometry, color: .yellow)
      planeHandle(.yz, geometry: geometry, color: .cyan)
      planeHandle(.zx, geometry: geometry, color: .purple)

      rotationHandle(.x, geometry: geometry, color: .red)
      rotationHandle(.y, geometry: geometry, color: .green)
      rotationHandle(.z, geometry: geometry, color: .blue)

      translationHandle(.x, geometry: geometry, color: .red)
      translationHandle(.y, geometry: geometry, color: .green)
      translationHandle(.z, geometry: geometry, color: .blue)

      Circle()
        .fill(.ultraThickMaterial)
        .frame(width: 24, height: 24)
        .overlay {
          Image(systemName: isEnabled ? "move.3d" : "lock.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(isEnabled ? .primary : .secondary)
        }
        .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
    }
    .frame(width: CADGizmoProjectedGeometry.side, height: CADGizmoProjectedGeometry.side)
    .overlay(alignment: .bottom) {
      Text(isEnabled ? label : "\(label) · fixed")
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThickMaterial, in: Capsule())
        .offset(y: 8)
    }
    .accessibilityElement(children: .contain)
  }

  private func translationHandle(
    _ axis: CADTransformAxis,
    geometry: CADGizmoProjectedGeometry,
    color: Color
  ) -> some View {
    CADGizmoAxisHandle(
      transform: transform,
      axis: axis,
      geometry: geometry,
      subjectLabel: label,
      isEnabled: isEnabled,
      metersPerPoint: metersPerPoint,
      color: color,
      onChange: onChange
    )
  }

  private func rotationHandle(
    _ axis: CADTransformAxis,
    geometry: CADGizmoProjectedGeometry,
    color: Color
  ) -> some View {
    CADGizmoRotationHandle(
      transform: transform,
      axis: axis,
      geometry: geometry,
      subjectLabel: label,
      isEnabled: isEnabled,
      color: color,
      onChange: onChange
    )
  }

  private func planeHandle(
    _ plane: CADTransformPlane,
    geometry: CADGizmoProjectedGeometry,
    color: Color
  ) -> some View {
    CADGizmoPlaneHandle(
      transform: transform,
      plane: plane,
      geometry: geometry,
      subjectLabel: label,
      isEnabled: isEnabled,
      metersPerPoint: metersPerPoint,
      color: color,
      onChange: onChange
    )
  }
}

private struct CADGizmoAxisHandle: View {
  let transform: CADPartRestTransform
  let axis: CADTransformAxis
  let geometry: CADGizmoProjectedGeometry
  let subjectLabel: String
  let isEnabled: Bool
  let metersPerPoint: Double
  let color: Color
  let onChange: @MainActor @Sendable (CADPartRestTransform) -> Void

  @State private var dragStart: CADPartRestTransform?

  var body: some View {
    let vector = geometry.vector(axis)
    let path = axisPath(vector)
    ZStack {
      path
        .stroke(.black.opacity(0.35), style: StrokeStyle(lineWidth: 7, lineCap: .round))
      path
        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
      arrowhead(vector)
        .fill(color)
      path
        .stroke(color.opacity(0.001), style: StrokeStyle(lineWidth: 20, lineCap: .round))
        .gesture(isEnabled ? dragGesture : nil)
    }
    .frame(width: CADGizmoProjectedGeometry.side, height: CADGizmoProjectedGeometry.side)
    .opacity(isEnabled ? 1 : 0.38)
    .accessibilityElement()
    .accessibilityLabel("Translate \(axis.rawValue.uppercased())")
    .accessibilityHint(isEnabled ? "Drag to edit \(subjectLabel)" : "\(subjectLabel) is fixed")
  }

  private func axisPath(_ vector: SIMD2<Double>) -> Path {
    Path { path in
      let length = simd_length(vector)
      guard length > 5 else { return }
      let unit = vector / length
      path.move(to: (SIMD2(CADGizmoProjectedGeometry.center) + unit * 10).point)
      path.addLine(to: (SIMD2(CADGizmoProjectedGeometry.center) + vector).point)
    }
  }

  private func arrowhead(_ vector: SIMD2<Double>) -> Path {
    Path { path in
      let length = simd_length(vector)
      guard length > 5 else { return }
      let unit = vector / length
      let perpendicular = SIMD2(-unit.y, unit.x)
      let tip = SIMD2(CADGizmoProjectedGeometry.center) + vector
      path.move(to: tip.point)
      path.addLine(to: (tip - unit * 15 + perpendicular * 7).point)
      path.addLine(to: (tip - unit * 15 - perpendicular * 7).point)
      path.closeSubpath()
    }
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 1)
      .onChanged { value in
        let start = dragStart ?? transform
        if dragStart == nil { dragStart = start }
        let points = CADGizmoInteraction.axisDragPoints(
          value.translation,
          projectedAxis: geometry.vector(axis))
        onChange(start.translated(localAxis: axis, distanceMeters: points * metersPerPoint))
      }
      .onEnded { _ in dragStart = nil }
  }
}

private struct CADGizmoPlaneHandle: View {
  let transform: CADPartRestTransform
  let plane: CADTransformPlane
  let geometry: CADGizmoProjectedGeometry
  let subjectLabel: String
  let isEnabled: Bool
  let metersPerPoint: Double
  let color: Color
  let onChange: @MainActor @Sendable (CADPartRestTransform) -> Void

  @State private var dragStart: CADPartRestTransform?

  var body: some View {
    let path = planePath
    ZStack {
      path.fill(color.opacity(0.20))
      path.stroke(color.opacity(0.8), lineWidth: 1.5)
      path
        .fill(color.opacity(0.001))
        .gesture(isEnabled ? dragGesture : nil)
    }
    .frame(width: CADGizmoProjectedGeometry.side, height: CADGizmoProjectedGeometry.side)
    .opacity(isEnabled ? 1 : 0.28)
    .accessibilityElement()
    .accessibilityLabel("Translate \(plane.rawValue.uppercased()) plane")
    .accessibilityHint(isEnabled ? "Drag to edit \(subjectLabel)" : "\(subjectLabel) is fixed")
  }

  private var planePath: Path {
    let axes = geometry.planeAxes(plane)
    let first = geometry.vector(axes.first)
    let second = geometry.vector(axes.second)
    let center = SIMD2(CADGizmoProjectedGeometry.center)
    return Path { path in
      guard simd_length(first) > 8, simd_length(second) > 8 else { return }
      path.move(to: (center + first * 0.18 + second * 0.18).point)
      path.addLine(to: (center + first * 0.48 + second * 0.18).point)
      path.addLine(to: (center + first * 0.48 + second * 0.48).point)
      path.addLine(to: (center + first * 0.18 + second * 0.48).point)
      path.closeSubpath()
    }
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 1)
      .onChanged { value in
        let start = dragStart ?? transform
        if dragStart == nil { dragStart = start }
        let axes = geometry.planeAxes(plane)
        let points = CADGizmoInteraction.planeDragPoints(
          value.translation,
          firstAxis: geometry.vector(axes.first),
          secondAxis: geometry.vector(axes.second))
        let firstMoved = start.translated(
          localAxis: axes.first,
          distanceMeters: points.x * metersPerPoint)
        onChange(
          firstMoved.translated(
            localAxis: axes.second,
            distanceMeters: points.y * metersPerPoint))
      }
      .onEnded { _ in dragStart = nil }
  }
}

private struct CADGizmoRotationHandle: View {
  let transform: CADPartRestTransform
  let axis: CADTransformAxis
  let geometry: CADGizmoProjectedGeometry
  let subjectLabel: String
  let isEnabled: Bool
  let color: Color
  let onChange: @MainActor @Sendable (CADPartRestTransform) -> Void

  @State private var dragStart: CADPartRestTransform?

  var body: some View {
    let path = ringPath
    ZStack {
      path.stroke(.black.opacity(0.32), lineWidth: 6)
      path.stroke(color.opacity(0.9), lineWidth: 3)
      path
        .stroke(color.opacity(0.001), lineWidth: 18)
        .gesture(isEnabled ? dragGesture : nil)
    }
    .frame(width: CADGizmoProjectedGeometry.side, height: CADGizmoProjectedGeometry.side)
    .opacity(isEnabled ? 1 : 0.28)
    .accessibilityElement()
    .accessibilityLabel("Rotate \(axis.rawValue.uppercased())")
    .accessibilityHint(isEnabled ? "Drag to edit \(subjectLabel)" : "\(subjectLabel) is fixed")
  }

  private var ringPath: Path {
    let axes = geometry.rotationAxes(axis)
    let first = geometry.vector(axes.first) * 0.82
    let second = geometry.vector(axes.second) * 0.82
    let center = SIMD2(CADGizmoProjectedGeometry.center)
    return Path { path in
      guard simd_length(first) > 5, simd_length(second) > 5 else { return }
      for step in 0...64 {
        let angle = Double(step) / 64 * 2 * .pi
        let point = center + first * cos(angle) + second * sin(angle)
        if step == 0 {
          path.move(to: point.point)
        } else {
          path.addLine(to: point.point)
        }
      }
    }
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 1)
      .onChanged { value in
        let start = dragStart ?? transform
        if dragStart == nil { dragStart = start }
        let radians = CADGizmoInteraction.rotationRadians(
          start: value.startLocation,
          current: value.location,
          center: CADGizmoProjectedGeometry.center,
          orientationSign: geometry.rotationOrientationSign(axis))
        onChange(start.rotated(localAxis: axis, angleRadians: radians))
      }
      .onEnded { _ in dragStart = nil }
  }
}
