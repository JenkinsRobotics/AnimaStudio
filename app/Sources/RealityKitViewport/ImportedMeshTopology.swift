import Foundation
import simd

/// Renderer-neutral triangle geometry extracted from an imported asset.
/// Positions are expressed in the selected model node's local coordinate
/// space and in metres.
public struct ImportedMeshGeometry: Equatable, Sendable {
  public let name: String
  public let positions: [SIMD3<Float>]
  public let indices: [UInt32]

  public init(name: String, positions: [SIMD3<Float>], indices: [UInt32]) {
    self.name = name
    self.positions = positions
    self.indices = indices
  }
}

public struct ImportedMeshFace: Equatable, Sendable {
  public let id: String
  public let triangles: [[SIMD3<Float>]]
  public let center: SIMD3<Float>
  public let normal: SIMD3<Float>
  public let tangent: SIMD3<Float>
}

public struct ImportedMeshEdge: Equatable, Sendable {
  public let id: String
  public let points: [SIMD3<Float>]
  public let center: SIMD3<Float>
  public let direction: SIMD3<Float>
  public let normal: SIMD3<Float>
}

public struct ImportedMeshCorner: Equatable, Sendable {
  public let id: String
  public let position: SIMD3<Float>
  public let normal: SIMD3<Float>
}

/// A pragmatic CAD-selection projection of a triangle mesh. It deliberately
/// stops short of claiming B-rep/CAD-kernel semantics: faces are connected
/// coplanar triangle islands, edges are boundary or sharp-normal polylines,
/// and corners are feature-graph vertices where at least three edges meet.
public struct ImportedMeshTopology: Equatable, Sendable {
  public let faces: [ImportedMeshFace]
  public let edges: [ImportedMeshEdge]
  public let corners: [ImportedMeshCorner]
  public let boundsExtent: Float

  public init(
    faces: [ImportedMeshFace],
    edges: [ImportedMeshEdge],
    corners: [ImportedMeshCorner],
    boundsExtent: Float
  ) {
    self.faces = faces
    self.edges = edges
    self.corners = corners
    self.boundsExtent = boundsExtent
  }
}

public enum ImportedMeshTopologyBuilder {
  public struct Options: Equatable, Sendable {
    public var coplanarAngleDegrees: Float
    public var featureEdgeAngleDegrees: Float

    public init(
      coplanarAngleDegrees: Float = 2,
      featureEdgeAngleDegrees: Float = 30
    ) {
      self.coplanarAngleDegrees = coplanarAngleDegrees
      self.featureEdgeAngleDegrees = featureEdgeAngleDegrees
    }
  }

  public static func build(
    geometries: [ImportedMeshGeometry],
    options: Options = Options()
  ) -> ImportedMeshTopology {
    var faces: [ImportedMeshFace] = []
    var edges: [ImportedMeshEdge] = []
    var corners: [ImportedMeshCorner] = []
    var maximumExtent: Float = 0

    for (meshIndex, geometry) in geometries.enumerated() {
      let mesh = buildMesh(geometry, options: options)
      maximumExtent = max(maximumExtent, mesh.extent)
      faces.append(
        contentsOf: mesh.faces.enumerated().map { index, face in
          ImportedMeshFace(
            id: "mesh-\(meshIndex)-face-\(index)",
            triangles: face.triangles,
            center: face.center,
            normal: face.normal,
            tangent: face.tangent
          )
        })
      edges.append(
        contentsOf: mesh.edges.enumerated().map { index, edge in
          ImportedMeshEdge(
            id: "mesh-\(meshIndex)-edge-\(index)",
            points: edge.points,
            center: edge.center,
            direction: edge.direction,
            normal: edge.normal
          )
        })
      corners.append(
        contentsOf: mesh.corners.enumerated().map { index, corner in
          ImportedMeshCorner(
            id: "mesh-\(meshIndex)-corner-\(index)",
            position: corner.position,
            normal: corner.normal
          )
        })
    }

    return ImportedMeshTopology(
      faces: faces,
      edges: edges,
      corners: corners,
      boundsExtent: maximumExtent
    )
  }

  private struct Triangle {
    let vertices: SIMD3<Int>
    let normal: SIMD3<Float>
  }

  private struct VertexKey: Hashable {
    let x: Int64
    let y: Int64
    let z: Int64
  }

  private struct EdgeKey: Hashable, Comparable {
    let low: Int
    let high: Int

    init(_ first: Int, _ second: Int) {
      low = min(first, second)
      high = max(first, second)
    }

    static func < (lhs: EdgeKey, rhs: EdgeKey) -> Bool {
      lhs.low == rhs.low ? lhs.high < rhs.high : lhs.low < rhs.low
    }
  }

  private struct MeshFace {
    let triangles: [[SIMD3<Float>]]
    let center: SIMD3<Float>
    let normal: SIMD3<Float>
    let tangent: SIMD3<Float>
  }

  private struct MeshEdge {
    let points: [SIMD3<Float>]
    let center: SIMD3<Float>
    let direction: SIMD3<Float>
    let normal: SIMD3<Float>
  }

  private struct MeshCorner {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
  }

  private struct MeshResult {
    let faces: [MeshFace]
    let edges: [MeshEdge]
    let corners: [MeshCorner]
    let extent: Float
  }

  private static func buildMesh(
    _ geometry: ImportedMeshGeometry,
    options: Options
  ) -> MeshResult {
    guard !geometry.positions.isEmpty, geometry.indices.count >= 3 else {
      return MeshResult(faces: [], edges: [], corners: [], extent: 0)
    }

    let minimum = geometry.positions.reduce(SIMD3<Float>(repeating: .greatestFiniteMagnitude)) {
      simd_min($0, $1)
    }
    let maximum = geometry.positions.reduce(SIMD3<Float>(repeating: -.greatestFiniteMagnitude)) {
      simd_max($0, $1)
    }
    let diagonal = simd_length(maximum - minimum)
    let weldTolerance = max(diagonal * 0.000_001, 0.000_000_1)
    let planeTolerance = max(diagonal * 0.000_01, 0.000_001)

    var weldedPositions: [SIMD3<Float>] = []
    var weldedIndexByKey: [VertexKey: Int] = [:]
    var originalToWelded = Array(repeating: -1, count: geometry.positions.count)
    for (index, position) in geometry.positions.enumerated() {
      let key = VertexKey(
        x: Int64((position.x / weldTolerance).rounded()),
        y: Int64((position.y / weldTolerance).rounded()),
        z: Int64((position.z / weldTolerance).rounded())
      )
      if let existing = weldedIndexByKey[key] {
        originalToWelded[index] = existing
      } else {
        let welded = weldedPositions.count
        weldedPositions.append(position)
        weldedIndexByKey[key] = welded
        originalToWelded[index] = welded
      }
    }

    var triangles: [Triangle] = []
    for offset in stride(from: 0, to: geometry.indices.count - 2, by: 3) {
      let raw = [
        Int(geometry.indices[offset]), Int(geometry.indices[offset + 1]),
        Int(geometry.indices[offset + 2]),
      ]
      guard raw.allSatisfy({ geometry.positions.indices.contains($0) }) else { continue }
      let welded = raw.map { originalToWelded[$0] }
      guard Set(welded).count == 3 else { continue }
      let a = weldedPositions[welded[0]]
      let b = weldedPositions[welded[1]]
      let c = weldedPositions[welded[2]]
      let cross = simd_cross(b - a, c - a)
      let length = simd_length(cross)
      guard length.isFinite, length > 0.000_000_01 else { continue }
      triangles.append(
        Triangle(
          vertices: SIMD3(welded[0], welded[1], welded[2]),
          normal: cross / length
        ))
    }
    guard !triangles.isEmpty else {
      return MeshResult(faces: [], edges: [], corners: [], extent: diagonal)
    }

    var triangleIndicesByEdge: [EdgeKey: [Int]] = [:]
    for (triangleIndex, triangle) in triangles.enumerated() {
      for edge in triangleEdges(triangle.vertices) {
        triangleIndicesByEdge[edge, default: []].append(triangleIndex)
      }
    }

    let coplanarCosine = cos(options.coplanarAngleDegrees * .pi / 180)
    var coplanarNeighbors = Array(repeating: [Int](), count: triangles.count)
    for adjacent in triangleIndicesByEdge.values where adjacent.count == 2 {
      let first = adjacent[0]
      let second = adjacent[1]
      let firstTriangle = triangles[first]
      let secondTriangle = triangles[second]
      let firstPoint = weldedPositions[firstTriangle.vertices.x]
      let secondPoint = weldedPositions[secondTriangle.vertices.x]
      let normalsAgree = simd_dot(firstTriangle.normal, secondTriangle.normal) >= coplanarCosine
      let planesAgree =
        abs(simd_dot(firstTriangle.normal, secondPoint - firstPoint)) <= planeTolerance
      if normalsAgree && planesAgree {
        coplanarNeighbors[first].append(second)
        coplanarNeighbors[second].append(first)
      }
    }

    var visitedTriangles = Set<Int>()
    var faceGroups: [[Int]] = []
    for start in triangles.indices where !visitedTriangles.contains(start) {
      var group: [Int] = []
      var queue = [start]
      visitedTriangles.insert(start)
      while let current = queue.popLast() {
        group.append(current)
        for neighbor in coplanarNeighbors[current] where !visitedTriangles.contains(neighbor) {
          visitedTriangles.insert(neighbor)
          queue.append(neighbor)
        }
      }
      faceGroups.append(group.sorted())
    }

    let faces = faceGroups.map { group -> MeshFace in
      let trianglePoints = group.map { triangleIndex in
        let triangle = triangles[triangleIndex]
        return [
          weldedPositions[triangle.vertices.x],
          weldedPositions[triangle.vertices.y],
          weldedPositions[triangle.vertices.z],
        ]
      }
      let flattened = trianglePoints.flatMap { $0 }
      let center = flattened.reduce(SIMD3<Float>(repeating: 0), +) / Float(flattened.count)
      let normal = normalized(
        group.reduce(SIMD3<Float>(repeating: 0)) { $0 + triangles[$1].normal },
        fallback: triangles[group[0]].normal
      )
      let first = trianglePoints[0]
      let tangent = normalized(
        (first[1] - first[0]) - normal * simd_dot(first[1] - first[0], normal),
        fallback: perpendicular(to: normal)
      )
      return MeshFace(
        triangles: trianglePoints,
        center: center,
        normal: normal,
        tangent: tangent
      )
    }

    let featureCosine = cos(options.featureEdgeAngleDegrees * .pi / 180)
    let featureKeys = triangleIndicesByEdge.keys.filter { edge in
      guard let adjacent = triangleIndicesByEdge[edge] else { return false }
      guard adjacent.count == 2 else { return true }
      return simd_dot(triangles[adjacent[0]].normal, triangles[adjacent[1]].normal)
        < featureCosine
    }.sorted()

    var featureEdgesByVertex: [Int: [EdgeKey]] = [:]
    for edge in featureKeys {
      featureEdgesByVertex[edge.low, default: []].append(edge)
      featureEdgesByVertex[edge.high, default: []].append(edge)
    }
    for key in featureEdgesByVertex.keys {
      featureEdgesByVertex[key]?.sort()
    }

    var visitedEdges = Set<EdgeKey>()
    var polylines: [[Int]] = []
    let starts = featureEdgesByVertex.keys.filter { featureEdgesByVertex[$0]?.count != 2 }.sorted()
    for start in starts {
      for edge in featureEdgesByVertex[start] ?? [] where !visitedEdges.contains(edge) {
        polylines.append(
          tracePolyline(
            startingAt: start,
            edge: edge,
            adjacency: featureEdgesByVertex,
            visited: &visitedEdges
          ))
      }
    }
    for edge in featureKeys where !visitedEdges.contains(edge) {
      polylines.append(
        tracePolyline(
          startingAt: edge.low,
          edge: edge,
          adjacency: featureEdgesByVertex,
          visited: &visitedEdges
        ))
    }

    let meshEdges = polylines.compactMap { vertexIndices -> MeshEdge? in
      let points = vertexIndices.map { weldedPositions[$0] }
      guard points.count >= 2 else { return nil }
      let center = points.reduce(SIMD3<Float>(repeating: 0), +) / Float(points.count)
      let direction = normalized(points.last! - points.first!, fallback: SIMD3(1, 0, 0))
      let incidentNormals = Set(
        zip(vertexIndices, vertexIndices.dropFirst()).flatMap { first, second in
          triangleIndicesByEdge[EdgeKey(first, second)] ?? []
        }
      ).map { triangles[$0].normal }
      let normal = normalized(
        incidentNormals.reduce(SIMD3<Float>(repeating: 0), +),
        fallback: perpendicular(to: direction)
      )
      return MeshEdge(points: points, center: center, direction: direction, normal: normal)
    }

    let meshCorners = featureEdgesByVertex.keys.sorted().compactMap { vertex -> MeshCorner? in
      guard let incidentEdges = featureEdgesByVertex[vertex], incidentEdges.count >= 3 else {
        return nil
      }
      let triangleIndices = Set(incidentEdges.flatMap { triangleIndicesByEdge[$0] ?? [] })
      let normal = normalized(
        triangleIndices.reduce(SIMD3<Float>(repeating: 0)) { $0 + triangles[$1].normal },
        fallback: SIMD3(0, 1, 0)
      )
      return MeshCorner(position: weldedPositions[vertex], normal: normal)
    }

    return MeshResult(
      faces: faces,
      edges: meshEdges,
      corners: meshCorners,
      extent: max(maximum.x - minimum.x, maximum.y - minimum.y, maximum.z - minimum.z)
    )
  }

  private static func triangleEdges(_ vertices: SIMD3<Int>) -> [EdgeKey] {
    [
      EdgeKey(vertices.x, vertices.y), EdgeKey(vertices.y, vertices.z),
      EdgeKey(vertices.z, vertices.x),
    ]
  }

  private static func tracePolyline(
    startingAt start: Int,
    edge firstEdge: EdgeKey,
    adjacency: [Int: [EdgeKey]],
    visited: inout Set<EdgeKey>
  ) -> [Int] {
    var points = [start]
    var currentVertex = start
    var currentEdge = firstEdge
    while !visited.contains(currentEdge) {
      visited.insert(currentEdge)
      let nextVertex = currentEdge.low == currentVertex ? currentEdge.high : currentEdge.low
      points.append(nextVertex)
      guard adjacency[nextVertex]?.count == 2,
        let nextEdge = adjacency[nextVertex]?.first(where: { !visited.contains($0) })
      else { break }
      currentVertex = nextVertex
      currentEdge = nextEdge
    }
    return points
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    guard length.isFinite, length > 0.000_001 else { return fallback }
    return value / length
  }

  private static func perpendicular(to normal: SIMD3<Float>) -> SIMD3<Float> {
    let reference = abs(normal.x) < 0.8 ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
    return normalized(simd_cross(normal, reference), fallback: SIMD3(0, 0, 1))
  }
}

/// Process-lifetime cache keyed by asset identity. A modified file gets a new
/// key, while camera movement, selection, and scene rebuilds reuse the costly
/// topology projection.
actor ImportedMeshTopologyCache {
  static let shared = ImportedMeshTopologyCache()

  private var values: [String: ImportedMeshTopology] = [:]

  func topology(
    key: String,
    geometries: [ImportedMeshGeometry]
  ) async -> ImportedMeshTopology {
    if let cached = values[key] { return cached }
    let topology = await Task.detached(priority: .userInitiated) {
      ImportedMeshTopologyBuilder.build(geometries: geometries)
    }.value
    values[key] = topology
    return topology
  }
}
