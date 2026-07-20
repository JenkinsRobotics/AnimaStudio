// CAD picking — cast a ray from the click into the scene and find the nearest
// B-Rep face. Pure math (no RealityKit) so it can be self-tested headlessly.
import CoreGraphics
import GeomKit
import Observation
import simd

struct PickRay {
  var origin: SIMD3<Float>
  var direction: SIMD3<Float>   // normalized

  func point(at t: Float) -> SIMD3<Float> { origin + direction * t }
}

enum Picking {
  /// Ray through a viewport point for a camera looking from `position` at `target`.
  static func cameraRay(point: CGPoint, viewport: CGSize, position: SIMD3<Float>,
    target: SIMD3<Float>, fovDegrees: Float = 60) -> PickRay
  {
    let forward = simd_normalize(target - position)
    var right = simd_cross(forward, SIMD3<Float>(0, 1, 0))
    right = simd_length_squared(right) < 1e-8 ? [1, 0, 0] : simd_normalize(right)
    let up = simd_cross(right, forward)

    let aspect = Float(max(viewport.width, 1) / max(viewport.height, 1))
    let tanHalf = tan(fovDegrees * .pi / 360)
    // Viewport point → normalized device coords (y flipped: screen grows downward).
    let ndcX = Float(2 * point.x / max(viewport.width, 1) - 1) * aspect * tanHalf
    let ndcY = Float(1 - 2 * point.y / max(viewport.height, 1)) * tanHalf

    return PickRay(origin: position,
      direction: simd_normalize(forward + right * ndcX + up * ndcY))
  }

  /// Möller–Trumbore. Returns the hit distance along the ray, or nil.
  static func rayTriangle(_ ray: PickRay, _ a: SIMD3<Float>, _ b: SIMD3<Float>,
    _ c: SIMD3<Float>) -> Float?
  {
    let edge1 = b - a
    let edge2 = c - a
    let h = simd_cross(ray.direction, edge2)
    let det = simd_dot(edge1, h)
    guard abs(det) > 1e-9 else { return nil }        // ray parallel to the triangle
    let invDet = 1 / det
    let s = ray.origin - a
    let u = invDet * simd_dot(s, h)
    guard u >= -1e-6, u <= 1 + 1e-6 else { return nil }
    let q = simd_cross(s, edge1)
    let v = invDet * simd_dot(ray.direction, q)
    guard v >= -1e-6, u + v <= 1 + 1e-6 else { return nil }
    let t = invDet * simd_dot(edge2, q)
    return t > 1e-6 ? t : nil                        // ignore hits behind the origin
  }

  /// Transform a ray into another space (direction ignores translation).
  static func transform(_ ray: PickRay, by matrix: simd_float4x4) -> PickRay {
    let origin = matrix * SIMD4<Float>(ray.origin, 1)
    let direction = matrix * SIMD4<Float>(ray.direction, 0)
    return PickRay(
      origin: SIMD3(origin.x, origin.y, origin.z),
      direction: simd_normalize(SIMD3(direction.x, direction.y, direction.z)))
  }

  /// Nearest face hit by the ray, searching the given index range (whole mesh if nil).
  static func pickFace(ray: PickRay, geometry: RenderGeometry, indexRange: Range<Int>? = nil)
    -> (face: UInt32, distance: Float)?
  {
    let range = indexRange ?? 0..<geometry.indices.count
    guard range.lowerBound >= 0, range.upperBound <= geometry.indices.count else { return nil }

    var best: (face: UInt32, distance: Float)?
    var index = range.lowerBound
    while index + 2 < range.upperBound {
      let i0 = Int(geometry.indices[index])
      let i1 = Int(geometry.indices[index + 1])
      let i2 = Int(geometry.indices[index + 2])
      index += 3
      guard i0 < geometry.positions.count, i1 < geometry.positions.count,
        i2 < geometry.positions.count
      else { continue }
      guard let hit = rayTriangle(
        ray, geometry.positions[i0], geometry.positions[i1], geometry.positions[i2])
      else { continue }
      if best == nil || hit < best!.distance {
        let face = i0 < geometry.faceIDs.count ? geometry.faceIDs[i0] : 0
        best = (face, hit)
      }
    }
    return best
  }

  /// Nearest face across all parts, accounting for the container normalization
  /// and each part's live rig pose.
  static func pick(ray: PickRay, geometry: RenderGeometry, container: simd_float4x4,
    pose: [Int: simd_float4x4]) -> (face: UInt32, node: Int, distance: Float)?
  {
    var best: (face: UInt32, node: Int, distance: Float)?
    for batch in geometry.batches {
      let world = container * (pose[batch.assemblyNode] ?? matrix_identity_float4x4)
      let local = transform(ray, by: world.inverse)
      guard let hit = pickFace(ray: local, geometry: geometry, indexRange: batch.indexRange)
      else { continue }
      if best == nil || hit.distance < best!.distance {
        best = (hit.face, batch.assemblyNode, hit.distance)
      }
    }
    return best
  }

  /// The renderer normalizes the model to unit radius at the origin; picking has
  /// to undo the same transform.
  static func containerMatrix(for geometry: RenderGeometry) -> simd_float4x4 {
    let radius = max(geometry.bounds.diagonal / 2, 0.0001)
    let scale = 1 / radius
    var m = matrix_identity_float4x4
    m.columns.0.x = scale
    m.columns.1.y = scale
    m.columns.2.z = scale
    let offset = -geometry.bounds.center * scale
    m.columns.3 = SIMD4(offset, 1)
    return m
  }
}

/// Selection granularity, CAD-style: one click picks a face, a double click
/// promotes to the whole body (and opens the move controls).
enum SelectionLevel { case face, body }

@MainActor @Observable final class SelectionModel {
  static let shared = SelectionModel()

  var level: SelectionLevel = .face
  var faceID: UInt32?
  var assemblyNode: Int?
  var partID: PartID?
  /// Where the move gizmo is anchored, in viewport coordinates.
  var gizmoPoint: CGPoint?

  var hasSelection: Bool { assemblyNode != nil }
  var showsMoveControls: Bool { level == .body && assemblyNode != nil }

  /// Single click — pick one face.
  func selectFace(_ face: UInt32, node: Int, part: PartID?, at point: CGPoint) {
    level = .face
    faceID = face
    assemblyNode = node
    partID = part
    gizmoPoint = point
  }

  /// Double click — promote to the whole body and show the move controls.
  func selectBody(node: Int, part: PartID?, at point: CGPoint) {
    level = .body
    faceID = nil
    assemblyNode = node
    partID = part
    gizmoPoint = point
  }

  func clear() {
    level = .face
    faceID = nil
    assemblyNode = nil
    partID = nil
    gizmoPoint = nil
  }

  /// True when this face should be drawn highlighted.
  func highlights(face: UInt32, node: Int) -> Bool {
    guard assemblyNode == node else { return false }
    switch level {
    case .body: return true
    case .face: return faceID == face
    }
  }
}
