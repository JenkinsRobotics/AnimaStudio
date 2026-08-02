import AetherKernel
import CoreGraphics
import simd

public enum CADViewportFeatureKind: String, Sendable {
  case face
  case edge
  case vertex
  case axis
}

/// Renderer-neutral connector frame inferred from exact Open CASCADE topology.
///
/// The position and axes remain in the owning Part's local geometry space.
/// AnimaCore performs mate alignment and solving; this type only describes the
/// operator's geometric pick.
public struct CADViewportFeaturePick: Equatable, Sendable {
  public let partID: Int
  public let nodeName: String
  public let topologyID: Int
  public let kind: CADViewportFeatureKind
  public let positionMeters: SIMD3<Double>
  public let primaryAxis: SIMD3<Double>
  public let secondaryAxis: SIMD3<Double>
  public let screenPoint: CADNormalizedViewportPoint
  /// Screen-space directions for the connector's local X/Y/Z decal.
  /// X is the secondary axis; Z is the primary axis; Y = Z × X.
  public let screenXAxis: SIMD2<Double>
  public let screenYAxis: SIMD2<Double>
  public let screenZAxis: SIMD2<Double>

  public init(
    partID: Int,
    nodeName: String,
    topologyID: Int,
    kind: CADViewportFeatureKind,
    positionMeters: SIMD3<Double>,
    primaryAxis: SIMD3<Double>,
    secondaryAxis: SIMD3<Double>,
    screenPoint: CADNormalizedViewportPoint,
    screenXAxis: SIMD2<Double> = SIMD2(1, 0),
    screenYAxis: SIMD2<Double> = SIMD2(0, -1),
    screenZAxis: SIMD2<Double> = SIMD2(0.707_106_781_186_547_6, 0.707_106_781_186_547_6)
  ) {
    self.partID = partID
    self.nodeName = nodeName
    self.topologyID = topologyID
    self.kind = kind
    self.positionMeters = positionMeters
    self.primaryAxis = primaryAxis
    self.secondaryAxis = secondaryAxis
    self.screenPoint = screenPoint
    self.screenXAxis = screenXAxis
    self.screenYAxis = screenYAxis
    self.screenZAxis = screenZAxis
  }
}

enum CADMetalFeaturePicker {
  private struct SurfaceHit {
    let partID: Int
    let faceID: Int
    let localPoint: SIMD3<Float>
    let localNormal: SIMD3<Float>
    let transform: simd_float4x4
  }

  static func feature(
    at point: CGPoint,
    viewportSize: CGSize,
    document: CADGeometryDocument,
    viewProjection: simd_float4x4,
    hiddenPartIDs: Set<Int>,
    partTransforms: [CADPartTransformPresentation]
  ) -> CADViewportFeaturePick? {
    guard
      let hit = surfaceHit(
        at: point,
        viewportSize: viewportSize,
        geometry: document.renderGeometry,
        viewProjection: viewProjection,
        hiddenPartIDs: hiddenPartIDs,
        partTransforms: partTransforms
      )
    else { return nil }

    let nodeIndex = hit.partID - 1
    let nodeName =
      document.nodes.indices.contains(nodeIndex)
      ? document.nodes[nodeIndex].name
      : "Part \(hit.partID)"
    let query = SIMD2<Double>(
      point.x / max(viewportSize.width, 1),
      1 - point.y / max(viewportSize.height, 1)
    )
    let pixelScale = SIMD2<Double>(
      max(viewportSize.width, 1),
      max(viewportSize.height, 1)
    )
    // Discrete candidate snapping, ported from the OCCT Mate Lab: the
    // cursor selects the nearest explicit candidate node (face center,
    // circle center, edge midpoint, vertex) within its pixel threshold —
    // never an arbitrary continuous point under the cursor.
    let candidates = CADConnectorCandidateEngine.candidates(
      nodeIndex: nodeIndex,
      hitFaceID: hit.faceID,
      hitNormal: hit.localNormal,
      document: document)
    return pick(
      from: candidates, hit: hit, at: point, viewportSize: viewportSize,
      document: document, viewProjection: viewProjection)
  }

  private static func pick(
    from candidates: [CADConnectorCandidate],
    hit: SurfaceHit,
    at point: CGPoint,
    viewportSize: CGSize,
    document: CADGeometryDocument,
    viewProjection: simd_float4x4
  ) -> CADViewportFeaturePick? {
    let nodeIndex = hit.partID - 1
    let nodeName =
      document.nodes.indices.contains(nodeIndex)
      ? document.nodes[nodeIndex].name
      : "Part \(hit.partID)"
    let query = SIMD2<Double>(
      point.x / max(viewportSize.width, 1),
      1 - point.y / max(viewportSize.height, 1)
    )
    let pixelScale = SIMD2<Double>(
      max(viewportSize.width, 1),
      max(viewportSize.height, 1)
    )

    var nearest: (distance: Double, candidate: CADConnectorCandidate)?
    for candidate in candidates {
      guard
        let projected = project(
          candidate.origin, transform: hit.transform, viewProjection: viewProjection)
      else { continue }
      let distance = pixelDistance(projected, query, pixelScale: pixelScale)
      guard distance <= snapThresholdPixels(for: candidate.kind) else { continue }
      if nearest == nil || distance < nearest!.distance {
        nearest = (distance, candidate)
      }
    }

    let normal = normalized(hit.localNormal, fallback: SIMD3<Float>(0, 0, 1))
    if let nearest {
      let candidate = nearest.candidate
      return makePick(
        partID: hit.partID, nodeName: nodeName, topologyID: candidate.topologyID,
        kind: pickKind(for: candidate.kind), position: candidate.origin,
        primary: candidate.zAxis, secondary: candidate.xAxis,
        transform: hit.transform, viewProjection: viewProjection)
    }

    // No candidate within threshold: the hovered face itself, framed by its
    // normal at its center, remains the fallback pick.
    let center =
      candidates.first(where: { $0.kind == .faceCenter })?.origin ?? hit.localPoint
    return makePick(
      partID: hit.partID, nodeName: nodeName, topologyID: hit.faceID,
      kind: .face, position: center, primary: normal,
      secondary: stableSecondary(for: normal), transform: hit.transform,
      viewProjection: viewProjection)
  }

  /// One hover evaluation: a single surface raycast produces BOTH the
  /// snapped pick and the full illumination candidate set. Hover runs per
  /// mouse event over dense assemblies, so the triangle raycast must not be
  /// paid twice (it was — and read as dropped frames next to the Mate Lab).
  static func hoverResult(
    at point: CGPoint,
    viewportSize: CGSize,
    document: CADGeometryDocument,
    viewProjection: simd_float4x4,
    hiddenPartIDs: Set<Int>,
    partTransforms: [CADPartTransformPresentation]
  ) -> (pick: CADViewportFeaturePick?, partID: Int, candidates: [CADConnectorCandidate])? {
    guard
      let hit = surfaceHit(
        at: point,
        viewportSize: viewportSize,
        geometry: document.renderGeometry,
        viewProjection: viewProjection,
        hiddenPartIDs: hiddenPartIDs,
        partTransforms: partTransforms
      )
    else { return nil }
    return hoverResult(
      hit: hit, at: point, viewportSize: viewportSize,
      document: document, viewProjection: viewProjection)
  }

  /// GPU-pick entry: the ID buffer already answered "which part/face" — no
  /// CPU geometry walk happens here. The face's tessellation supplies the
  /// local frame the raycast used to provide.
  static func hoverResult(
    pickedPartID: Int,
    pickedFaceID: Int,
    at point: CGPoint,
    viewportSize: CGSize,
    document: CADGeometryDocument,
    viewProjection: simd_float4x4,
    partTransforms: [CADPartTransformPresentation]
  ) -> (pick: CADViewportFeaturePick?, partID: Int, candidates: [CADConnectorCandidate])? {
    guard
      let hit = hit(
        partID: pickedPartID, faceID: pickedFaceID,
        document: document, partTransforms: partTransforms)
    else { return nil }
    return hoverResult(
      hit: hit, at: point, viewportSize: viewportSize,
      document: document, viewProjection: viewProjection)
  }

  private static func hoverResult(
    hit: SurfaceHit,
    at point: CGPoint,
    viewportSize: CGSize,
    document: CADGeometryDocument,
    viewProjection: simd_float4x4
  ) -> (pick: CADViewportFeaturePick?, partID: Int, candidates: [CADConnectorCandidate])? {
    let candidates = CADConnectorCandidateEngine.candidates(
      nodeIndex: hit.partID - 1,
      hitFaceID: hit.faceID,
      hitNormal: hit.localNormal,
      document: document)
    let pick = pick(
      from: candidates, hit: hit, at: point, viewportSize: viewportSize,
      document: document, viewProjection: viewProjection)
    return (pick, hit.partID, candidates)
  }

  private static func hit(
    partID: Int,
    faceID: Int,
    document: CADGeometryDocument,
    partTransforms: [CADPartTransformPresentation]
  ) -> SurfaceHit? {
    let nodeIndex = partID - 1
    guard
      let face = document.faces.first(where: {
        $0.id == faceID && $0.assemblyNode == nodeIndex
      }), !face.positions.isEmpty
    else { return nil }
    let center = face.positions.reduce(.zero, +) / Float(face.positions.count)
    let normalSum = face.normals.reduce(SIMD3<Float>.zero, +)
    let normal =
      simd_length_squared(normalSum) > 0.000_001
      ? simd_normalize(normalSum)
      : SIMD3<Float>(0, 0, 1)
    let transform =
      partTransforms.first(where: { $0.partID == partID })?.matrix
      ?? matrix_identity_float4x4
    return SurfaceHit(
      partID: partID, faceID: faceID, localPoint: center,
      localNormal: normal, transform: transform)
  }

  private static func snapThresholdPixels(for kind: CADConnectorCandidateKind) -> Double {
    switch kind {
    case .vertex: 10
    case .circleCenter: 12
    case .edgeMidpoint: 10
    case .faceCenter: 14
    }
  }

  private static func pickKind(for kind: CADConnectorCandidateKind) -> CADViewportFeatureKind {
    switch kind {
    case .faceCenter: .face
    case .edgeMidpoint: .edge
    case .vertex: .vertex
    case .circleCenter: .axis
    }
  }

  private static func surfaceHit(
    at point: CGPoint,
    viewportSize: CGSize,
    geometry: CADRenderGeometry,
    viewProjection: simd_float4x4,
    hiddenPartIDs: Set<Int>,
    partTransforms: [CADPartTransformPresentation]
  ) -> SurfaceHit? {
    guard viewportSize.width > 0, viewportSize.height > 0 else { return nil }
    let ndc = SIMD2<Float>(
      Float(point.x / viewportSize.width) * 2 - 1,
      Float(point.y / viewportSize.height) * 2 - 1)
    let inverseViewProjection = simd_inverse(viewProjection)
    guard
      let rayNear = unproject(SIMD3(ndc.x, ndc.y, 0), inverse: inverseViewProjection),
      let rayFar = unproject(SIMD3(ndc.x, ndc.y, 1), inverse: inverseViewProjection)
    else { return nil }
    let rayDirection = simd_normalize(rayFar - rayNear)
    let transforms = Dictionary(
      uniqueKeysWithValues: partTransforms.map { (UInt32(clamping: $0.partID), $0.matrix) })
    var localRays:
      [UInt32: (origin: SIMD3<Float>, direction: SIMD3<Float>, transform: simd_float4x4)] = [:]
    var nearestDistance = Float.greatestFiniteMagnitude
    var nearest: SurfaceHit?

    for triangle in 0..<(geometry.indices.count / 3) {
      let offset = triangle * 3
      let i0 = Int(geometry.indices[offset])
      let i1 = Int(geometry.indices[offset + 1])
      let i2 = Int(geometry.indices[offset + 2])
      guard
        i0 < geometry.positions.count, i1 < geometry.positions.count,
        i2 < geometry.positions.count, i0 < geometry.partIDs.count,
        i0 < geometry.faceIDs.count
      else { continue }
      let rawPartID = geometry.partIDs[i0]
      guard rawPartID > 0, !hiddenPartIDs.contains(Int(rawPartID)) else { continue }
      let localRay: (origin: SIMD3<Float>, direction: SIMD3<Float>, transform: simd_float4x4)
      if let cached = localRays[rawPartID] {
        localRay = cached
      } else {
        let transform = transforms[rawPartID] ?? matrix_identity_float4x4
        let inverse = simd_inverse(transform)
        let localOrigin = transformedPoint(rayNear, by: inverse)
        let localTarget = transformedPoint(rayNear + rayDirection, by: inverse)
        localRay = (
          localOrigin,
          normalized(localTarget - localOrigin, fallback: rayDirection),
          transform
        )
        localRays[rawPartID] = localRay
      }
      guard
        let distance = intersectionDistance(
          rayOrigin: localRay.origin, rayDirection: localRay.direction,
          v0: geometry.positions[i0], v1: geometry.positions[i1], v2: geometry.positions[i2])
      else { continue }
      let localPoint = localRay.origin + localRay.direction * distance
      let worldPoint = transformedPoint(localPoint, by: localRay.transform)
      let worldDistance = simd_length(worldPoint - rayNear)
      guard worldDistance < nearestDistance else { continue }
      let triangleNormal = normalized(
        simd_cross(
          geometry.positions[i1] - geometry.positions[i0],
          geometry.positions[i2] - geometry.positions[i0]),
        fallback: geometry.normals.indices.contains(i0)
          ? geometry.normals[i0] : SIMD3<Float>(0, 0, 1))
      nearestDistance = worldDistance
      nearest = SurfaceHit(
        partID: Int(rawPartID), faceID: Int(geometry.faceIDs[i0]),
        localPoint: localPoint, localNormal: triangleNormal, transform: localRay.transform)
    }
    return nearest
  }

  private static func makePick(
    partID: Int,
    nodeName: String,
    topologyID: Int,
    kind: CADViewportFeatureKind,
    position: SIMD3<Float>,
    primary: SIMD3<Float>,
    secondary: SIMD3<Float>,
    transform: simd_float4x4,
    viewProjection: simd_float4x4
  ) -> CADViewportFeaturePick? {
    guard let screen = project(position, transform: transform, viewProjection: viewProjection)
    else { return nil }
    let normalizedPrimary = normalized(primary, fallback: SIMD3<Float>(0, 0, 1))
    let normalizedSecondary = normalized(secondary, fallback: SIMD3<Float>(1, 0, 0))
    let normalizedTertiary = normalized(
      simd_cross(normalizedPrimary, normalizedSecondary),
      fallback: SIMD3<Float>(0, 1, 0)
    )
    return CADViewportFeaturePick(
      partID: partID,
      nodeName: nodeName,
      topologyID: topologyID,
      kind: kind,
      positionMeters: SIMD3<Double>(position),
      primaryAxis: SIMD3<Double>(normalizedPrimary),
      secondaryAxis: SIMD3<Double>(normalizedSecondary),
      screenPoint: CADNormalizedViewportPoint(x: screen.x, y: screen.y),
      screenXAxis: screenDirection(
        from: position,
        along: normalizedSecondary,
        transform: transform,
        viewProjection: viewProjection,
        fallback: SIMD2(1, 0)
      ),
      screenYAxis: screenDirection(
        from: position,
        along: normalizedTertiary,
        transform: transform,
        viewProjection: viewProjection,
        fallback: SIMD2(0, -1)
      ),
      screenZAxis: screenDirection(
        from: position,
        along: normalizedPrimary,
        transform: transform,
        viewProjection: viewProjection,
        fallback: SIMD2(0.707_106_781_186_547_6, 0.707_106_781_186_547_6)
      )
    )
  }

  private static func screenDirection(
    from position: SIMD3<Float>,
    along axis: SIMD3<Float>,
    transform: simd_float4x4,
    viewProjection: simd_float4x4,
    fallback: SIMD2<Double>
  ) -> SIMD2<Double> {
    let worldStart = transformedPoint(position, by: transform)
    let worldEnd = transformedPoint(position + axis, by: transform)
    guard
      let start = projectedPoint(worldStart, viewProjection: viewProjection),
      let end = projectedPoint(worldEnd, viewProjection: viewProjection)
    else { return fallback }
    let delta = end - start
    let length = simd_length(delta)
    return length > 0.000_001 ? delta / length : fallback
  }

  private static func projectedPoint(
    _ world: SIMD3<Float>,
    viewProjection: simd_float4x4
  ) -> SIMD2<Double>? {
    let clip = viewProjection * SIMD4(world, 1)
    guard clip.w > 0.000_001 else { return nil }
    return SIMD2(
      Double((clip.x / clip.w + 1) * 0.5),
      Double((1 - clip.y / clip.w) * 0.5)
    )
  }

  private static func project(
    _ point: SIMD3<Float>,
    transform: simd_float4x4,
    viewProjection: simd_float4x4
  ) -> SIMD2<Double>? {
    let world = transformedPoint(point, by: transform)
    guard
      let value = CADViewportProjection.project(
        worldPosition: world, viewProjection: viewProjection)
    else { return nil }
    return SIMD2(value.x, value.y)
  }

  private static func pixelDistance(
    _ lhs: SIMD2<Double>,
    _ rhs: SIMD2<Double>,
    pixelScale: SIMD2<Double>
  ) -> Double {
    simd_length((lhs - rhs) * pixelScale)
  }

  private static func nearestPoint(
    to point: SIMD2<Double>,
    onSegmentFrom start: SIMD2<Double>,
    to end: SIMD2<Double>,
    pixelScale: SIMD2<Double>
  ) -> (distance: Double, fraction: Double) {
    let pixelStart = start * pixelScale
    let pixelEnd = end * pixelScale
    let pixelPoint = point * pixelScale
    let delta = pixelEnd - pixelStart
    let denominator = simd_length_squared(delta)
    let fraction =
      denominator > 0
      ? min(max(simd_dot(pixelPoint - pixelStart, delta) / denominator, 0), 1)
      : 0
    return (simd_distance(pixelPoint, pixelStart + delta * fraction), fraction)
  }

  private static func stableSecondary(for primary: SIMD3<Float>) -> SIMD3<Float> {
    let seed =
      abs(primary.x) < 0.82
      ? SIMD3<Float>(1, 0, 0)
      : SIMD3<Float>(0, 1, 0)
    return normalized(seed - primary * simd_dot(seed, primary), fallback: SIMD3<Float>(0, 0, 1))
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length > 0.000_001 && length.isFinite ? value / length : fallback
  }

  private static func unproject(
    _ point: SIMD3<Float>,
    inverse: simd_float4x4
  ) -> SIMD3<Float>? {
    let homogeneous = inverse * SIMD4(point, 1)
    guard abs(homogeneous.w) > 0.000_001 else { return nil }
    let result = SIMD3(homogeneous.x, homogeneous.y, homogeneous.z) / homogeneous.w
    return result.x.isFinite && result.y.isFinite && result.z.isFinite ? result : nil
  }

  private static func transformedPoint(
    _ point: SIMD3<Float>,
    by transform: simd_float4x4
  ) -> SIMD3<Float> {
    let homogeneous = transform * SIMD4(point, 1)
    guard abs(homogeneous.w) > 0.000_001 else {
      return SIMD3(homogeneous.x, homogeneous.y, homogeneous.z)
    }
    return SIMD3(homogeneous.x, homogeneous.y, homogeneous.z) / homogeneous.w
  }

  private static func intersectionDistance(
    rayOrigin: SIMD3<Float>,
    rayDirection: SIMD3<Float>,
    v0: SIMD3<Float>,
    v1: SIMD3<Float>,
    v2: SIMD3<Float>
  ) -> Float? {
    let edge1 = v1 - v0
    let edge2 = v2 - v0
    let perpendicular = simd_cross(rayDirection, edge2)
    let determinant = simd_dot(edge1, perpendicular)
    guard abs(determinant) > 0.000_000_1 else { return nil }
    let inverse = 1 / determinant
    let offset = rayOrigin - v0
    let u = inverse * simd_dot(offset, perpendicular)
    guard u >= 0, u <= 1 else { return nil }
    let cross = simd_cross(offset, edge1)
    let v = inverse * simd_dot(rayDirection, cross)
    guard v >= 0, u + v <= 1 else { return nil }
    let distance = inverse * simd_dot(edge2, cross)
    return distance > 0.000_001 ? distance : nil
  }
}
