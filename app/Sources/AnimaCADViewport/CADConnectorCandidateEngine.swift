import AnimaCAD
import simd

/// The discrete snap-candidate taxonomy, ported faithfully from the OCCT
/// Mate Lab (`dev/OCCTMateLab/src/occt.worker.ts`): every hoverable feature
/// resolves to an explicit candidate with an exact connector frame — never
/// an arbitrary point under the cursor.
public enum CADConnectorCandidateKind: String, Sendable {
  case faceCenter
  case edgeMidpoint
  case vertex
  case circleCenter
}

/// One snappable connector candidate in the owning Part's local geometry
/// space. `zAxis` is the primary axis (surface normal / circle axis) and
/// `xAxis` the secondary, matching the engine's connector-frame convention.
public struct CADConnectorCandidate: Equatable, Sendable {
  public let id: String
  public let topologyID: Int
  public let kind: CADConnectorCandidateKind
  public let label: String
  public let origin: SIMD3<Float>
  public let zAxis: SIMD3<Float>
  public let xAxis: SIMD3<Float>
}

/// Enumerates the complete candidate set for a hovered face/node, mirroring
/// the Mate Lab's `topologyForFace`: face center, circular-edge centers with
/// exact circle-axis frames, edge midpoints, and edge endpoints, deduped by
/// kind and origin. Pure geometry — no screen projection, so it is directly
/// unit-testable against imported documents.
public enum CADConnectorCandidateEngine {
  /// Circle detection: a closed polyline sampled densely enough that its
  /// endpoints meet within a fraction of its extent (same rule the picker
  /// used, kept as the single source of truth here).
  static func circleCenter(of edge: CADEdge) -> (center: SIMD3<Float>, axis: SIMD3<Float>)? {
    guard edge.points.count >= 8,
      let first = edge.points.first,
      let last = edge.points.last
    else { return nil }
    let extent = edge.points.reduce(Float.zero) { partial, value in
      max(partial, simd_length(value - first))
    }
    guard extent > 0, simd_distance(first, last) <= extent * 0.08 else { return nil }
    // A closed polyline duplicates its first point at the end; averaging it
    // twice biases the centroid off the true circle center.
    let ring =
      simd_distance(first, last) < extent * 0.001
      ? Array(edge.points.dropLast())
      : edge.points
    let center = ring.reduce(SIMD3<Float>.zero, +) / Float(ring.count)
    let radialA = edge.points[0] - center
    let radialB = edge.points[edge.points.count / 4] - center
    let cross = simd_cross(radialA, radialB)
    guard simd_length_squared(cross) > 0.000_000_1 else { return nil }
    return (center, simd_normalize(cross))
  }

  /// The point halfway along a polyline by arc length — the discrete
  /// midpoint candidate, not "wherever the cursor is on the edge".
  static func arcMidpoint(of points: [SIMD3<Float>]) -> (point: SIMD3<Float>, tangent: SIMD3<Float>)? {
    guard points.count > 1 else { return nil }
    var lengths: [Float] = [0]
    for index in 1..<points.count {
      lengths.append(lengths[index - 1] + simd_distance(points[index - 1], points[index]))
    }
    guard let total = lengths.last, total > 0 else { return nil }
    let half = total / 2
    for index in 1..<points.count where lengths[index] >= half {
      let segment = lengths[index] - lengths[index - 1]
      let fraction = segment > 0 ? (half - lengths[index - 1]) / segment : 0
      let point = simd_mix(
        points[index - 1], points[index], SIMD3<Float>(repeating: fraction))
      let tangent = points[index] - points[index - 1]
      guard simd_length_squared(tangent) > 0 else { continue }
      return (point, simd_normalize(tangent))
    }
    return nil
  }

  public static func candidates(
    nodeIndex: Int,
    hitFaceID: Int,
    hitNormal: SIMD3<Float>,
    document: CADGeometryDocument
  ) -> [CADConnectorCandidate] {
    var results: [CADConnectorCandidate] = []
    let normal = normalizedOrFallback(hitNormal, fallback: SIMD3(0, 0, 1))

    // Face center of the hovered face (area proxy: vertex centroid, which
    // matches the shim's tessellation density closely enough for snapping).
    if let face = document.faces.first(where: {
      $0.id == hitFaceID && $0.assemblyNode == nodeIndex
    }), !face.positions.isEmpty {
      let center = face.positions.reduce(.zero, +) / Float(face.positions.count)
      push(
        CADConnectorCandidate(
          id: "face-\(hitFaceID)-center",
          topologyID: hitFaceID,
          kind: .faceCenter,
          label: "Face center",
          origin: center,
          zAxis: normal,
          xAxis: stableSecondary(for: normal)),
        into: &results)
    }

    for edge in document.edges where edge.assemblyNode == nodeIndex && edge.points.count > 1 {
      if let circle = circleCenter(of: edge) {
        push(
          CADConnectorCandidate(
            id: "edge-\(edge.id)-circle",
            topologyID: edge.id,
            kind: .circleCenter,
            label: "Circle center",
            origin: circle.center,
            zAxis: circle.axis,
            xAxis: stableSecondary(for: circle.axis)),
          into: &results)
        // A closed circle has no meaningful endpoints; its midpoint is
        // just another rim point, so the circle contributes only its center.
        continue
      }
      if let midpoint = arcMidpoint(of: edge.points) {
        push(
          CADConnectorCandidate(
            id: "edge-\(edge.id)-midpoint",
            topologyID: edge.id,
            kind: .edgeMidpoint,
            label: "Edge midpoint",
            origin: midpoint.point,
            zAxis: normal,
            xAxis: midpoint.tangent),
          into: &results)
      }
      for (suffix, endpoint) in [("a", edge.points.first), ("b", edge.points.last)] {
        guard let endpoint else { continue }
        push(
          CADConnectorCandidate(
            id: "edge-\(edge.id)-vertex-\(suffix)",
            topologyID: edge.id,
            kind: .vertex,
            label: "Vertex",
            origin: endpoint,
            zAxis: normal,
            xAxis: stableSecondary(for: normal)),
          into: &results)
      }
    }
    return results
  }

  /// The Mate Lab's epsilon dedup: coincident candidates of one kind (shared
  /// corners between edges, most commonly) collapse to a single node. Every
  /// stored frame is orthonormalized (the lab's `orthogonalFrame`): x is
  /// projected off z so the connector basis is always valid.
  private static func push(
    _ candidate: CADConnectorCandidate, into results: inout [CADConnectorCandidate]
  ) {
    let duplicate = results.contains { existing in
      existing.kind == candidate.kind
        && simd_distance(existing.origin, candidate.origin) < 0.000_001
    }
    guard !duplicate else { return }
    let z = normalizedOrFallback(candidate.zAxis, fallback: SIMD3(0, 0, 1))
    var x = candidate.xAxis - z * simd_dot(candidate.xAxis, z)
    if simd_length_squared(x) < 0.000_001 { x = stableSecondary(for: z) }
    x = simd_normalize(x)
    results.append(
      CADConnectorCandidate(
        id: candidate.id, topologyID: candidate.topologyID, kind: candidate.kind,
        label: candidate.label, origin: candidate.origin, zAxis: z, xAxis: x))
  }

  static func stableSecondary(for primary: SIMD3<Float>) -> SIMD3<Float> {
    let reference: SIMD3<Float> =
      abs(primary.y) < 0.9 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)
    let secondary = simd_cross(reference, primary)
    return normalizedOrFallback(secondary, fallback: SIMD3(1, 0, 0))
  }

  static func normalizedOrFallback(
    _ vector: SIMD3<Float>, fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    simd_length_squared(vector) > 0.000_001 ? simd_normalize(vector) : fallback
  }
}
