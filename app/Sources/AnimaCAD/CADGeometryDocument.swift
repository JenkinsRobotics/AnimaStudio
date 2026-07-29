import AnimaCADShim
import Foundation
import simd

public struct CADFace: Identifiable, Sendable {
  public let id: Int
  public let positions: [SIMD3<Float>]
  public let normals: [SIMD3<Float>]
  public let indices: [UInt32]
  public let color: SIMD4<Float>
  public let assemblyNode: Int
}

public struct CADEdge: Identifiable, Sendable {
  public let id: Int
  public let points: [SIMD3<Float>]
  public let assemblyNode: Int
}

public struct CADAssemblyNode: Identifiable, Sendable {
  public let id: Int
  public let name: String
  public let parentIndex: Int?
  public let transform: simd_double4x4
}

public struct CADImportMetrics: Sendable, Equatable {
  public let readMilliseconds: Double
  public let transferMilliseconds: Double
  public let triangulationMilliseconds: Double
  public let maximumToleranceMeters: Double

  public var totalMilliseconds: Double {
    readMilliseconds + transferMilliseconds + triangulationMilliseconds
  }
}

public struct CADGeometryDocument: Sendable {
  public let identity: UUID
  public let sourceURLs: [URL]
  public let faces: [CADFace]
  public let edges: [CADEdge]
  public let nodes: [CADAssemblyNode]
  public let metrics: CADImportMetrics
  public let renderGeometry: CADRenderGeometry

  public var sourceURL: URL? { sourceURLs.first }
  public var triangleCount: Int { renderGeometry.triangleCount }

  public init(
    sourceURLs: [URL],
    faces: [CADFace],
    edges: [CADEdge],
    nodes: [CADAssemblyNode],
    metrics: CADImportMetrics
  ) {
    identity = UUID()
    self.sourceURLs = sourceURLs
    self.faces = faces
    self.edges = edges
    self.nodes = nodes
    self.metrics = metrics
    renderGeometry = CADRenderGeometry(faces: faces, edges: edges)
  }

  public static func loadSTEP(
    _ url: URL,
    unitScaleToMeters: Double = 0.001,
    linearDeflectionMeters: Double = 0.0002,
    angularDeflectionRadians: Double = 0.35
  ) throws -> Self {
    let raw = anima_cad_load_step(
      url.path, linearDeflectionMeters, angularDeflectionRadians)
    defer { anima_cad_free_document(raw) }
    // The kernel emits meters assuming a millimeter source (× 0.001). Re-scale
    // to the real source unit: mm → 1.0 (unchanged), cm → 10, inch → 25.4.
    return try decode(raw, sourceURL: url, extraScale: unitScaleToMeters / 0.001)
  }

  public static func makeTestDocument(
    linearDeflectionMeters: Double = 0.0002,
    angularDeflectionRadians: Double = 0.35
  ) throws -> Self {
    let raw = anima_cad_make_test_document(
      linearDeflectionMeters, angularDeflectionRadians)
    defer { anima_cad_free_document(raw) }
    return try decode(raw, sourceURL: nil)
  }

  public static func merging(_ documents: [Self]) throws -> Self {
    guard !documents.isEmpty else { throw CADGeometryImportError.emptyGeometry }
    var faces: [CADFace] = []
    var edges: [CADEdge] = []
    var nodes: [CADAssemblyNode] = []
    var sourceURLs: [URL] = []
    var read = 0.0
    var transfer = 0.0
    var triangulation = 0.0
    var maximumTolerance = 0.0
    for document in documents {
      let nodeOffset = nodes.count
      sourceURLs.append(contentsOf: document.sourceURLs)
      nodes.append(
        contentsOf: document.nodes.map { node in
          CADAssemblyNode(
            id: nodeOffset + node.id,
            name: node.name,
            parentIndex: node.parentIndex.map { nodeOffset + $0 },
            transform: node.transform
          )
        })
      let faceOffset = faces.count
      faces.append(
        contentsOf: document.faces.enumerated().map { index, face in
          CADFace(
            id: faceOffset + index,
            positions: face.positions,
            normals: face.normals,
            indices: face.indices,
            color: face.color,
            assemblyNode: face.assemblyNode >= 0 ? nodeOffset + face.assemblyNode : -1
          )
        })
      let edgeOffset = edges.count
      edges.append(
        contentsOf: document.edges.enumerated().map { index, edge in
          CADEdge(
            id: edgeOffset + index,
            points: edge.points,
            assemblyNode: edge.assemblyNode >= 0 ? nodeOffset + edge.assemblyNode : -1
          )
        })
      read += document.metrics.readMilliseconds
      transfer += document.metrics.transferMilliseconds
      triangulation += document.metrics.triangulationMilliseconds
      maximumTolerance = max(maximumTolerance, document.metrics.maximumToleranceMeters)
    }
    return Self(
      sourceURLs: sourceURLs,
      faces: faces,
      edges: edges,
      nodes: nodes,
      metrics: CADImportMetrics(
        readMilliseconds: read,
        transferMilliseconds: transfer,
        triangulationMilliseconds: triangulation,
        maximumToleranceMeters: maximumTolerance
      )
    )
  }

  private static func decode(_ raw: ACDocument, sourceURL: URL?, extraScale: Double = 1) throws
    -> Self
  {
    if let error = raw.error_message {
      throw CADGeometryImportError.kernel(String(cString: error))
    }
    guard raw.vertex_count > 0, let positions = raw.positions, let normals = raw.normals,
      let indices = raw.indices
    else { throw CADGeometryImportError.emptyGeometry }

    let scale = Float(extraScale)

    var faces: [CADFace] = []
    if let ranges = raw.faces {
      for index in 0..<Int(raw.face_count) {
        let range = ranges[index]
        let vertexOffset = Int(range.vertex_offset)
        let vertexCount = Int(range.vertex_count)
        let indexOffset = Int(range.index_offset)
        let indexCount = Int(range.index_count)
        let localPositions = (0..<vertexCount).map { vertex in
          let base = (vertexOffset + vertex) * 3
          return SIMD3(positions[base], positions[base + 1], positions[base + 2]) * scale
        }
        let localNormals = (0..<vertexCount).map { vertex in
          let base = (vertexOffset + vertex) * 3
          return SIMD3(normals[base], normals[base + 1], normals[base + 2])
        }
        let localIndices = (0..<indexCount).map {
          indices[indexOffset + $0] - UInt32(vertexOffset)
        }
        faces.append(
          CADFace(
            id: Int(range.topology_index),
            positions: localPositions,
            normals: localNormals,
            indices: localIndices,
            color: SIMD4(range.color.0, range.color.1, range.color.2, range.color.3),
            assemblyNode: Int(range.assembly_node)
          ))
      }
    }

    var edges: [CADEdge] = []
    if let ranges = raw.edges, let points = raw.edge_points {
      for index in 0..<Int(raw.edge_count) {
        let range = ranges[index]
        edges.append(
          CADEdge(
            id: Int(range.topology_index),
            points: (0..<Int(range.point_count)).map { item in
              let base = (Int(range.point_offset) + item) * 3
              return SIMD3(points[base], points[base + 1], points[base + 2]) * scale
            },
            assemblyNode: Int(range.assembly_node)
          ))
      }
    }

    let nodes: [CADAssemblyNode] = (0..<Int(raw.node_count)).compactMap { index in
      guard let node = raw.nodes?[index], let name = node.name else { return nil }
      let values = withUnsafeBytes(of: node.transform) {
        Array($0.bindMemory(to: Double.self))
      }
      let matrix = simd_double4x4(
        SIMD4(values[0], values[1], values[2], values[3]),
        SIMD4(values[4], values[5], values[6], values[7]),
        SIMD4(values[8], values[9], values[10], values[11]),
        SIMD4(
          values[12] * 0.001 * extraScale, values[13] * 0.001 * extraScale,
          values[14] * 0.001 * extraScale, values[15])
      )
      return CADAssemblyNode(
        id: index,
        name: String(cString: name),
        parentIndex: node.parent_index >= 0 ? Int(node.parent_index) : nil,
        transform: matrix
      )
    }

    return Self(
      sourceURLs: sourceURL.map { [$0] } ?? [],
      faces: faces,
      edges: edges,
      nodes: nodes,
      metrics: CADImportMetrics(
        readMilliseconds: raw.read_seconds * 1_000,
        transferMilliseconds: raw.transfer_seconds * 1_000,
        triangulationMilliseconds: raw.triangulation_seconds * 1_000,
        maximumToleranceMeters: raw.maximum_tolerance_m
      )
    )
  }
}

public enum CADGeometryImportError: LocalizedError, Equatable {
  case kernel(String)
  case emptyGeometry

  public var errorDescription: String? {
    switch self {
    case .kernel(let message): message
    case .emptyGeometry: "The CAD importer returned no triangles."
    }
  }
}
