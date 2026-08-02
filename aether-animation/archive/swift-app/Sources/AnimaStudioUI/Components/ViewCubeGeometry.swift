import CoreGraphics
import RealityKitViewport
import simd

enum ViewCubeFace: String, CaseIterable {
  case front
  case back
  case right
  case left
  case top
  case bottom

  var title: String { rawValue.capitalized }

  var normal: SIMD3<Float> {
    switch self {
    case .front: SIMD3<Float>(0, 0, 1)
    case .back: SIMD3<Float>(0, 0, -1)
    case .right: SIMD3<Float>(1, 0, 0)
    case .left: SIMD3<Float>(-1, 0, 0)
    case .top: SIMD3<Float>(0, 1, 0)
    case .bottom: SIMD3<Float>(0, -1, 0)
    }
  }

  var labelRightDirection: SIMD3<Float> {
    switch self {
    case .front, .top, .bottom: SIMD3<Float>(1, 0, 0)
    case .back: SIMD3<Float>(-1, 0, 0)
    case .right: SIMD3<Float>(0, 0, -1)
    case .left: SIMD3<Float>(0, 0, 1)
    }
  }

  var labelUpDirection: SIMD3<Float> {
    simd_cross(normal, labelRightDirection)
  }

  var vertices: [SIMD3<Float>] {
    switch self {
    case .front:
      [point(-1, -1, 1), point(1, -1, 1), point(1, 1, 1), point(-1, 1, 1)]
    case .back:
      [point(1, -1, -1), point(-1, -1, -1), point(-1, 1, -1), point(1, 1, -1)]
    case .right:
      [point(1, -1, 1), point(1, -1, -1), point(1, 1, -1), point(1, 1, 1)]
    case .left:
      [point(-1, -1, -1), point(-1, -1, 1), point(-1, 1, 1), point(-1, 1, -1)]
    case .top:
      [point(-1, 1, 1), point(1, 1, 1), point(1, 1, -1), point(-1, 1, -1)]
    case .bottom:
      [point(-1, -1, -1), point(1, -1, -1), point(1, -1, 1), point(-1, -1, 1)]
    }
  }

  private func point(_ x: Float, _ y: Float, _ z: Float) -> SIMD3<Float> {
    SIMD3<Float>(x, y, z)
  }
}

struct ProjectedViewCubeFace {
  let face: ViewCubeFace
  let worldVertices: [SIMD3<Float>]
  let points: [CGPoint]
  let depth: Float

  var center: CGPoint {
    let total = points.reduce(CGPoint.zero) { partial, point in
      CGPoint(x: partial.x + point.x, y: partial.y + point.y)
    }
    return CGPoint(x: total.x / CGFloat(points.count), y: total.y / CGFloat(points.count))
  }
}

enum ViewCubeAxis: CaseIterable {
  case x
  case y
  case z

  var title: String {
    switch self {
    case .x: "X"
    case .y: "Y"
    case .z: "Z"
    }
  }

  var direction: SIMD3<Float> {
    switch self {
    case .x: SIMD3<Float>(1, 0, 0)
    case .y: SIMD3<Float>(0, 1, 0)
    case .z: SIMD3<Float>(0, 0, 1)
    }
  }
}

struct ProjectedViewCubeAxis {
  let axis: ViewCubeAxis
  let origin: CGPoint
  let endpoint: CGPoint
}

struct ViewCubeLabelProjection {
  let transform: CGAffineTransform
  let localBounds: CGRect
  let projectedArea: CGFloat

  var determinant: CGFloat {
    transform.a * transform.d - transform.b * transform.c
  }
}

enum ViewCubeHitKind: Equatable {
  case face(ViewCubeFace)
  case edge
  case corner
}

enum ViewCubeHighlight {
  case face([CGPoint])
  case edge(start: CGPoint, end: CGPoint)
  case corner(CGPoint)
}

struct ViewCubeHitTarget {
  let direction: PreviewCameraDirection
  let kind: ViewCubeHitKind
  let highlight: ViewCubeHighlight
}

enum ViewCubeGeometry {
  static func projectedFaces(
    in size: CGSize,
    orientation: PreviewCameraOrientation
  ) -> [ProjectedViewCubeFace] {
    let basis = cameraBasis(for: orientation)
    let scale = min(size.width, size.height) * 0.28

    return ViewCubeFace.allCases
      .filter { simd_dot($0.normal, orientation.direction.vector) > 0.001 }
      .map { face in
        let projected = face.vertices.map { vertex in
          project(vertex, in: size, basis: basis, scale: scale)
        }
        let depth =
          face.vertices
          .map { simd_dot($0, orientation.direction.vector) }
          .reduce(0, +) / Float(face.vertices.count)
        return ProjectedViewCubeFace(
          face: face,
          worldVertices: face.vertices,
          points: projected,
          depth: depth
        )
      }
      .sorted { $0.depth < $1.depth }
  }

  static func projectedAxes(
    in size: CGSize,
    orientation: PreviewCameraOrientation
  ) -> [ProjectedViewCubeAxis] {
    let basis = cameraBasis(for: orientation)
    let scale = min(size.width, size.height) * 0.28
    let worldOrigin = SIMD3<Float>(repeating: -1.15)
    let axisLength: Float = 2.35
    let origin = project(worldOrigin, in: size, basis: basis, scale: scale)

    return ViewCubeAxis.allCases.map { axis in
      ProjectedViewCubeAxis(
        axis: axis,
        origin: origin,
        endpoint: project(
          worldOrigin + axis.direction * axisLength,
          in: size,
          basis: basis,
          scale: scale
        )
      )
    }
  }

  static func hitDirection(
    at location: CGPoint,
    in size: CGSize,
    orientation: PreviewCameraOrientation
  ) -> PreviewCameraDirection? {
    hitTarget(at: location, in: size, orientation: orientation)?.direction
  }

  static func hitTarget(
    at location: CGPoint,
    in size: CGSize,
    orientation: PreviewCameraOrientation
  ) -> ViewCubeHitTarget? {
    let faces = projectedFaces(in: size, orientation: orientation)
    let vertices = uniqueVertices(from: faces)

    if let closestVertex = vertices.min(by: {
      distanceSquared(location, $0.point) < distanceSquared(location, $1.point)
    }), distanceSquared(location, closestVertex.point) <= 100 {
      return ViewCubeHitTarget(
        direction: direction(for: closestVertex.world),
        kind: .corner,
        highlight: .corner(closestVertex.point)
      )
    }

    let edges = uniqueEdges(from: faces)
    if let closestEdge = edges.min(by: {
      distanceSquared(location, toSegmentFrom: $0.start, to: $0.end)
        < distanceSquared(location, toSegmentFrom: $1.start, to: $1.end)
    }), distanceSquared(location, toSegmentFrom: closestEdge.start, to: closestEdge.end) <= 49 {
      return ViewCubeHitTarget(
        direction: direction(for: closestEdge.worldMidpoint),
        kind: .edge,
        highlight: .edge(start: closestEdge.start, end: closestEdge.end)
      )
    }

    for face in faces.reversed() where contains(location, polygon: face.points) {
      return ViewCubeHitTarget(
        direction: direction(for: face.face.normal),
        kind: .face(face.face),
        highlight: .face(face.points)
      )
    }
    return nil
  }

  static func labelProjection(
    for face: ProjectedViewCubeFace,
    orientation: PreviewCameraOrientation,
    labelSize: CGSize
  ) -> ViewCubeLabelProjection? {
    guard labelSize.width > 0, labelSize.height > 0 else { return nil }

    let facing = simd_dot(face.face.normal, orientation.direction.vector)
    let projectedArea = abs(polygonArea(face.points))
    guard facing >= minimumLabelFacing, projectedArea >= minimumLabelArea else {
      return nil
    }

    guard
      var right = projectedSpan(
        of: face,
        along: face.face.labelRightDirection
      ),
      var down = projectedSpan(
        of: face,
        along: -face.face.labelUpDirection
      )
    else { return nil }

    let rightLength = hypot(right.x, right.y)
    let downLength = hypot(down.x, down.y)
    guard rightLength > 0.05, downLength > 0.05 else { return nil }

    // Keep the printed decal's baseline readable without detaching it from the
    // face. A simultaneous 180-degree flip preserves the face plane and avoids
    // upside-down labels; the determinant correction prevents mirroring.
    if right.x < -0.001 || (abs(right.x) <= 0.001 && right.y > 0) {
      right = CGPoint(x: -right.x, y: -right.y)
      down = CGPoint(x: -down.x, y: -down.y)
    }
    if cross(right, down) < 0 {
      down = CGPoint(x: -down.x, y: -down.y)
    }

    let horizontalSpan = CGPoint(
      x: right.x * labelWidthFraction,
      y: right.y * labelWidthFraction
    )
    let verticalSpan = CGPoint(
      x: down.x * labelHeightFraction,
      y: down.y * labelHeightFraction
    )
    let origin = CGPoint(
      x: face.center.x - horizontalSpan.x / 2 - verticalSpan.x / 2,
      y: face.center.y - horizontalSpan.y / 2 - verticalSpan.y / 2
    )
    let transform = CGAffineTransform(
      a: horizontalSpan.x / labelSize.width,
      b: horizontalSpan.y / labelSize.width,
      c: verticalSpan.x / labelSize.height,
      d: verticalSpan.y / labelSize.height,
      tx: origin.x,
      ty: origin.y
    )
    return ViewCubeLabelProjection(
      transform: transform,
      localBounds: CGRect(origin: .zero, size: labelSize),
      projectedArea: projectedArea
    )
  }

  static func headOnFace(
    for orientation: PreviewCameraOrientation
  ) -> ViewCubeFace? {
    ViewCubeFace.allCases
      .map { ($0, simd_dot($0.normal, orientation.direction.vector)) }
      .max(by: { $0.1 < $1.1 })
      .flatMap { $0.1 >= headOnFacing ? $0.0 : nil }
  }

  private static func cameraBasis(
    for orientation: PreviewCameraOrientation
  ) -> (right: SIMD3<Float>, up: SIMD3<Float>) {
    let cameraDirection = orientation.direction.vector
    let forward = -simd_normalize(cameraDirection)
    var right = simd_cross(forward, SIMD3<Float>(0, 1, 0))
    if simd_length_squared(right) < 0.0001 {
      right = SIMD3<Float>(1, 0, 0)
    } else {
      right = simd_normalize(right)
    }
    var up = simd_normalize(simd_cross(right, forward))
    if abs(orientation.rollRadians) > 0.0001 {
      let roll = simd_quatf(angle: orientation.rollRadians, axis: forward)
      right = roll.act(right)
      up = roll.act(up)
    }
    return (right, up)
  }

  private static func projectedSpan(
    of face: ProjectedViewCubeFace,
    along direction: SIMD3<Float>
  ) -> CGPoint? {
    let desiredDifference = direction * 2
    for firstIndex in face.worldVertices.indices {
      for secondIndex in face.worldVertices.indices where secondIndex != firstIndex {
        let difference = face.worldVertices[secondIndex] - face.worldVertices[firstIndex]
        guard simd_length_squared(difference - desiredDifference) < 0.0001 else {
          continue
        }
        return CGPoint(
          x: face.points[secondIndex].x - face.points[firstIndex].x,
          y: face.points[secondIndex].y - face.points[firstIndex].y
        )
      }
    }
    return nil
  }

  private static func polygonArea(_ points: [CGPoint]) -> CGFloat {
    guard points.count >= 3 else { return 0 }
    return points.indices.reduce(0) { total, index in
      let next = (index + 1) % points.count
      return total + points[index].x * points[next].y - points[next].x * points[index].y
    } / 2
  }

  private static func cross(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
    first.x * second.y - first.y * second.x
  }

  private static let minimumLabelFacing: Float = 0.16
  private static let minimumLabelArea: CGFloat = 80
  private static let headOnFacing: Float = 0.985
  private static let labelWidthFraction: CGFloat = 0.58
  private static let labelHeightFraction: CGFloat = 0.25

  private static func direction(for vector: SIMD3<Float>) -> PreviewCameraDirection {
    PreviewCameraDirection(x: vector.x, y: vector.y, z: vector.z)
  }

  private static func project(
    _ point: SIMD3<Float>,
    in size: CGSize,
    basis: (right: SIMD3<Float>, up: SIMD3<Float>),
    scale: CGFloat
  ) -> CGPoint {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    return CGPoint(
      x: center.x + CGFloat(simd_dot(point, basis.right)) * scale,
      y: center.y - CGFloat(simd_dot(point, basis.up)) * scale
    )
  }

  private static func uniqueVertices(
    from faces: [ProjectedViewCubeFace]
  ) -> [(world: SIMD3<Float>, point: CGPoint)] {
    var result: [(SIMD3<Float>, CGPoint)] = []
    for face in faces {
      for (world, point) in zip(face.worldVertices, face.points)
      where !result.contains(where: { $0.0 == world }) {
        result.append((world, point))
      }
    }
    return result
  }

  private static func uniqueEdges(
    from faces: [ProjectedViewCubeFace]
  ) -> [(start: CGPoint, end: CGPoint, worldMidpoint: SIMD3<Float>)] {
    var seen: Set<String> = []
    var result: [(CGPoint, CGPoint, SIMD3<Float>)] = []
    for face in faces {
      for index in face.points.indices {
        let next = (index + 1) % face.points.count
        let firstWorld = face.worldVertices[index]
        let secondWorld = face.worldVertices[next]
        let key = edgeKey(firstWorld, secondWorld)
        guard seen.insert(key).inserted else { continue }
        result.append(
          (
            face.points[index],
            face.points[next],
            (firstWorld + secondWorld) / 2
          )
        )
      }
    }
    return result
  }

  private static func edgeKey(_ first: SIMD3<Float>, _ second: SIMD3<Float>) -> String {
    let firstKey = "\(Int(first.x)),\(Int(first.y)),\(Int(first.z))"
    let secondKey = "\(Int(second.x)),\(Int(second.y)),\(Int(second.z))"
    return [firstKey, secondKey].sorted().joined(separator: "|")
  }

  private static func contains(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
    guard polygon.count >= 3 else { return false }
    var isInside = false
    var previous = polygon[polygon.count - 1]
    for current in polygon {
      let crosses =
        (current.y > point.y) != (previous.y > point.y)
        && point.x
          < (previous.x - current.x) * (point.y - current.y)
          / (previous.y - current.y) + current.x
      if crosses { isInside.toggle() }
      previous = current
    }
    return isInside
  }

  private static func distanceSquared(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
    let deltaX = first.x - second.x
    let deltaY = first.y - second.y
    return deltaX * deltaX + deltaY * deltaY
  }

  private static func distanceSquared(
    _ point: CGPoint,
    toSegmentFrom start: CGPoint,
    to end: CGPoint
  ) -> CGFloat {
    let deltaX = end.x - start.x
    let deltaY = end.y - start.y
    let lengthSquared = deltaX * deltaX + deltaY * deltaY
    guard lengthSquared > 0 else { return distanceSquared(point, start) }
    let projection = min(
      max(((point.x - start.x) * deltaX + (point.y - start.y) * deltaY) / lengthSquared, 0),
      1
    )
    return distanceSquared(
      point,
      CGPoint(x: start.x + projection * deltaX, y: start.y + projection * deltaY)
    )
  }
}
