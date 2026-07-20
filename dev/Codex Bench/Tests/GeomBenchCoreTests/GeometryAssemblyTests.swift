import Foundation
import Testing
import simd

@testable import GeomBenchApp
@testable import GeomBenchCore

@Test func mergingDocumentsRemapsTopologyAndAggregatesMetrics() throws {
  let transform = matrix_identity_double4x4
  let first = GeometryDocument(
    sourceURLs: [URL(fileURLWithPath: "/tmp/a.step")],
    faces: [
      BenchFace(
        id: 4, positions: [[0, 0, 0], [1, 0, 0], [0, 1, 0]],
        normals: Array(repeating: [0, 0, 1], count: 3), indices: [0, 1, 2],
        color: [1, 0, 0, 1], assemblyNode: 0)
    ],
    edges: [BenchEdge(id: 8, points: [[0, 0, 0], [1, 0, 0]], assemblyNode: 0)],
    nodes: [AssemblyNode(id: 0, name: "A", parentIndex: nil, transform: transform)],
    metrics: ImportMetrics(
      readMilliseconds: 1, transferMilliseconds: 2, triangulationMilliseconds: 3,
      maximumToleranceMetres: 0.001))
  let second = GeometryDocument(
    sourceURLs: [URL(fileURLWithPath: "/tmp/b.step")],
    faces: [
      BenchFace(
        id: 4, positions: [[0, 0, 1], [1, 0, 1], [0, 1, 1]],
        normals: Array(repeating: [0, 0, 1], count: 3), indices: [0, 1, 2],
        color: [0, 1, 0, 1], assemblyNode: 0)
    ],
    edges: [BenchEdge(id: 8, points: [[0, 0, 1], [1, 0, 1]], assemblyNode: 0)],
    nodes: [AssemblyNode(id: 0, name: "B", parentIndex: nil, transform: transform)],
    metrics: ImportMetrics(
      readMilliseconds: 4, transferMilliseconds: 5, triangulationMilliseconds: 6,
      maximumToleranceMetres: 0.002))

  let merged = try GeometryDocument.merging([first, second])

  #expect(merged.sourceURLs.map(\.lastPathComponent) == ["a.step", "b.step"])
  #expect(merged.faces.map(\.id) == [0, 1])
  #expect(merged.faces.map(\.assemblyNode) == [0, 1])
  #expect(merged.edges.map(\.id) == [0, 1])
  #expect(merged.edges.map(\.assemblyNode) == [0, 1])
  #expect(merged.nodes.map(\.id) == [0, 1])
  #expect(merged.triangleCount == 2)
  #expect(merged.metrics.totalMilliseconds == 21)
  #expect(merged.metrics.maximumToleranceMetres == 0.002)
}

@Test func renderProjectionBatchesByRigidPartAndMaterialWithoutLosingTopology() {
  let faces = [
    BenchFace(
      id: 20, positions: [[0, 0, 0], [1, 0, 0], [0, 1, 0]],
      normals: Array(repeating: [0, 0, 1], count: 3), indices: [0, 1, 2],
      color: [1, 0, 0, 1], assemblyNode: 0),
    BenchFace(
      id: 21, positions: [[0, 0, 1], [1, 0, 1], [0, 1, 1]],
      normals: Array(repeating: [0, 0, 1], count: 3), indices: [0, 1, 2],
      color: [1, 0, 0, 1], assemblyNode: 0),
    BenchFace(
      id: 30, positions: [[2, 0, 0], [3, 0, 0], [2, 1, 0]],
      normals: Array(repeating: [0, 0, 1], count: 3), indices: [0, 1, 2],
      color: [0, 0.5, 1, 1], assemblyNode: 1),
  ]
  let edges = [
    BenchEdge(id: 1, points: [[0, 0, 0], [1, 0, 0], [1, 1, 0]], assemblyNode: 0)
  ]

  let projection = RenderGeometry(faces: faces, edges: edges)

  #expect(projection.vertexCount == 9)
  #expect(projection.triangleCount == 3)
  #expect(projection.edgeSegmentCount == 2)
  #expect(projection.batches.count == 2)
  #expect(projection.batches[0].faceIDs == [20, 21])
  #expect(projection.batches[0].indexRange.count == 6)
  #expect(projection.batches[1].assemblyNode == 1)
  #expect(projection.faceIDs == [20, 20, 20, 21, 21, 21, 30, 30, 30])
  #expect(projection.partIDs == [1, 1, 1, 1, 1, 1, 2, 2, 2])
  #expect(projection.bounds.minimum == [0, 0, 0])
  #expect(projection.bounds.maximum == [3, 1, 1])
  #expect(projection.edgePositions(maximumSegments: 1).count == 2)
  #expect(projection.edgePositions(maximumSegments: 0).isEmpty)
}

@Test func webPayloadUsesOneCompactBinaryBlockAndCarriesBatchMetadata() throws {
  let document = GeometryDocument(
    sourceURLs: [],
    faces: [
      BenchFace(
        id: 7, positions: [[0, 0, 0], [1, 0, 0], [0, 1, 0]],
        normals: Array(repeating: [0, 0, 1], count: 3), indices: [0, 1, 2],
        color: [0.25, 0.5, 0.75, 1], assemblyNode: 0)
    ],
    edges: [BenchEdge(id: 2, points: [[0, 0, 0], [1, 0, 0]], assemblyNode: 0)],
    nodes: [
      AssemblyNode(id: 0, name: "Part", parentIndex: nil, transform: matrix_identity_double4x4)
    ],
    metrics: ImportMetrics(
      readMilliseconds: 0, transferMilliseconds: 0, triangulationMilliseconds: 0,
      maximumToleranceMetres: 0))

  let payload = WebGeometryPayload(document: document)
  let bytes = try #require(Data(base64Encoded: payload.data))

  #expect(payload.formatVersion == 1)
  #expect(payload.vertexCount == 3)
  #expect(payload.indexCount == 3)
  #expect(payload.edgeVertexCount == 2)
  #expect(payload.batches.count == 1)
  #expect(bytes.count == 3 * 28 + 3 * 4 + 2 * 12)
}
