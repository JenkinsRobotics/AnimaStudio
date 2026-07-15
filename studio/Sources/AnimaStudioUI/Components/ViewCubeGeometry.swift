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

enum ViewCubeGeometry {
  static func projectedFaces(
    in size: CGSize,
    orientation: PreviewCameraOrientation
  ) -> [ProjectedViewCubeFace] {
    let basis = cameraBasis(for: orientation.direction.vector)
    let scale = min(size.width, size.height) * 0.28
    let center = CGPoint(x: size.width / 2, y: size.height / 2)

    return ViewCubeFace.allCases
      .filter { simd_dot($0.normal, orientation.direction.vector) > 0.001 }
      .map { face in
        let projected = face.vertices.map { vertex in
          CGPoint(
            x: center.x + CGFloat(simd_dot(vertex, basis.right)) * scale,
            y: center.y - CGFloat(simd_dot(vertex, basis.up)) * scale
          )
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

  static func hitDirection(
    at location: CGPoint,
    in size: CGSize,
    orientation: PreviewCameraOrientation
  ) -> PreviewCameraDirection? {
    let faces = projectedFaces(in: size, orientation: orientation)
    let vertices = uniqueVertices(from: faces)

    if let closestVertex = vertices.min(by: {
      distanceSquared(location, $0.point) < distanceSquared(location, $1.point)
    }), distanceSquared(location, closestVertex.point) <= 100 {
      return direction(for: closestVertex.world)
    }

    let edges = uniqueEdges(from: faces)
    if let closestEdge = edges.min(by: {
      distanceSquared(location, toSegmentFrom: $0.start, to: $0.end)
        < distanceSquared(location, toSegmentFrom: $1.start, to: $1.end)
    }), distanceSquared(location, toSegmentFrom: closestEdge.start, to: closestEdge.end) <= 49 {
      return direction(for: closestEdge.worldMidpoint)
    }

    for face in faces.reversed() where contains(location, polygon: face.points) {
      return direction(for: face.face.normal)
    }
    return nil
  }

  private static func cameraBasis(
    for cameraDirection: SIMD3<Float>
  ) -> (right: SIMD3<Float>, up: SIMD3<Float>) {
    let forward = -simd_normalize(cameraDirection)
    var right = simd_cross(forward, SIMD3<Float>(0, 1, 0))
    if simd_length_squared(right) < 0.0001 {
      right = SIMD3<Float>(1, 0, 0)
    } else {
      right = simd_normalize(right)
    }
    return (right, simd_normalize(simd_cross(right, forward)))
  }

  private static func direction(for vector: SIMD3<Float>) -> PreviewCameraDirection {
    PreviewCameraDirection(x: vector.x, y: vector.y, z: vector.z)
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
