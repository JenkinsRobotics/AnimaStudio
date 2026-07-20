// Pose evaluation — turns authored mates into a per-part world transform.
// Pure math (no SwiftUI/RealityKit) so it can be self-tested headlessly.
import GeomKit
import simd

enum RigPose {
  /// World-space delta transform per assembly node, accumulated down mate chains.
  /// Parts with no driving mate get identity (they stay where OCCT put them).
  static func evaluate(mates: [Mate], pivots: [PartID: SIMD3<Float>]) -> [PartID: simd_float4x4] {
    var mateByChild: [PartID: Mate] = [:]
    for mate in mates where mate.child != mate.parent { mateByChild[mate.child] = mate }

    var cache: [PartID: simd_float4x4] = [:]
    var visiting: Set<PartID> = []

    func delta(_ node: PartID) -> simd_float4x4 {
      if let cached = cache[node] { return cached }
      guard let mate = mateByChild[node] else { return matrix_identity_float4x4 }
      guard !visiting.contains(node) else { return matrix_identity_float4x4 }  // cycle guard
      visiting.insert(node)
      let result = delta(mate.parent) * local(mate, pivot: pivots[node] ?? .zero)
      visiting.remove(node)
      cache[node] = result
      return result
    }

    var out: [PartID: simd_float4x4] = [:]
    for child in mateByChild.keys { out[child] = delta(child) }
    return out
  }

  /// The motion a single mate contributes, about the child's pivot.
  static func local(_ mate: Mate, pivot: SIMD3<Float>) -> simd_float4x4 {
    let axis = mate.axis.vector
    switch mate.type {
    case .revolute:
      return rotation(axis: axis, degrees: Float(mate.value), about: pivot)
    case .slider:
      // Geometry is in metres; slider values are millimetres.
      return translation(axis * Float(mate.value / 1000))
    case .cylindrical:
      return rotation(axis: axis, degrees: Float(mate.value), about: pivot)
        * translation(axis * Float(mate.value / 1000))
    case .fastened, .ball, .planar:
      return matrix_identity_float4x4
    }
  }

  static func rotation(axis: SIMD3<Float>, degrees: Float, about pivot: SIMD3<Float>) -> simd_float4x4 {
    let unit = simd_length(axis) > 0 ? simd_normalize(axis) : SIMD3<Float>(0, 0, 1)
    let r = simd_float4x4(simd_quatf(angle: degrees * .pi / 180, axis: unit))
    return translation(pivot) * r * translation(-pivot)
  }

  static func translation(_ v: SIMD3<Float>) -> simd_float4x4 {
    var m = matrix_identity_float4x4
    m.columns.3 = SIMD4(v, 1)
    return m
  }

  /// Per-assembly-node centroid — the default rotation pivot for a part.
  static func pivots(for document: GeometryDocument) -> [Int: SIMD3<Float>] {
    let g = document.renderGeometry
    var sums: [Int: SIMD3<Float>] = [:]
    var counts: [Int: Int] = [:]
    for batch in g.batches where batch.assemblyNode >= 0 {
      for index in batch.vertexRange {
        sums[batch.assemblyNode, default: .zero] += g.positions[index]
        counts[batch.assemblyNode, default: 0] += 1
      }
    }
    return sums.reduce(into: [:]) { out, entry in
      out[entry.key] = entry.value / Float(max(counts[entry.key] ?? 1, 1))
    }
  }
}
