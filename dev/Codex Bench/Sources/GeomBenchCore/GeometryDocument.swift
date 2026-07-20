import Foundation
import GeomShim
import simd

public struct BenchFace: Identifiable, Sendable {
  public let id: Int
  public let positions: [SIMD3<Float>]
  public let normals: [SIMD3<Float>]
  public let indices: [UInt32]
  public let color: SIMD4<Float>
  public let assemblyNode: Int
}

public struct BenchEdge: Identifiable, Sendable {
  public let id: Int
  public let points: [SIMD3<Float>]
  public let assemblyNode: Int
}

public struct AssemblyNode: Identifiable, Sendable {
  public let id: Int
  public let name: String
  public let parentIndex: Int?
  public let transform: simd_double4x4
}

public struct ImportMetrics: Sendable, Equatable {
  public let readMilliseconds: Double
  public let transferMilliseconds: Double
  public let triangulationMilliseconds: Double
  public let maximumToleranceMetres: Double

  public var totalMilliseconds: Double {
    readMilliseconds + transferMilliseconds + triangulationMilliseconds
  }
}

public struct GeometryDocument: Sendable {
  public let identity: UUID
  public let sourceURLs: [URL]
  public let faces: [BenchFace]
  public let edges: [BenchEdge]
  public let nodes: [AssemblyNode]
  public let metrics: ImportMetrics
  public let renderGeometry: RenderGeometry

  public var sourceURL: URL? { sourceURLs.first }
  public var triangleCount: Int { faces.reduce(0) { $0 + $1.indices.count / 3 } }

  public init(
    sourceURLs: [URL], faces: [BenchFace], edges: [BenchEdge], nodes: [AssemblyNode],
    metrics: ImportMetrics
  ) {
    identity = UUID()
    self.sourceURLs = sourceURLs
    self.faces = faces
    self.edges = edges
    self.nodes = nodes
    self.metrics = metrics
    renderGeometry = RenderGeometry(faces: faces, edges: edges)
  }

  /// Joins independently imported STEP documents into one renderer workload.
  /// Geometry remains in the coordinate system supplied by each STEP file;
  /// only topology and assembly-node identifiers are remapped.
  public static func merging(_ documents: [GeometryDocument]) throws -> GeometryDocument {
    guard !documents.isEmpty else { throw GeometryImportError.emptyGeometry }

    var faces: [BenchFace] = []
    var edges: [BenchEdge] = []
    var nodes: [AssemblyNode] = []
    var sourceURLs: [URL] = []
    var readMilliseconds = 0.0
    var transferMilliseconds = 0.0
    var triangulationMilliseconds = 0.0
    var maximumToleranceMetres = 0.0

    for document in documents {
      let nodeOffset = nodes.count
      sourceURLs.append(contentsOf: document.sourceURLs)
      nodes.append(
        contentsOf: document.nodes.map { node in
          AssemblyNode(
            id: nodeOffset + node.id, name: node.name,
            parentIndex: node.parentIndex.map { nodeOffset + $0 }, transform: node.transform)
        })
      let faceOffset = faces.count
      faces.append(
        contentsOf: document.faces.enumerated().map { index, face in
          BenchFace(
            id: faceOffset + index, positions: face.positions, normals: face.normals,
            indices: face.indices, color: face.color,
            assemblyNode: face.assemblyNode >= 0 ? nodeOffset + face.assemblyNode : -1)
        })
      let edgeOffset = edges.count
      edges.append(
        contentsOf: document.edges.enumerated().map { index, edge in
          BenchEdge(
            id: edgeOffset + index, points: edge.points,
            assemblyNode: edge.assemblyNode >= 0 ? nodeOffset + edge.assemblyNode : -1)
        })
      readMilliseconds += document.metrics.readMilliseconds
      transferMilliseconds += document.metrics.transferMilliseconds
      triangulationMilliseconds += document.metrics.triangulationMilliseconds
      maximumToleranceMetres = max(
        maximumToleranceMetres, document.metrics.maximumToleranceMetres)
    }

    return GeometryDocument(
      sourceURLs: sourceURLs, faces: faces, edges: edges, nodes: nodes,
      metrics: ImportMetrics(
        readMilliseconds: readMilliseconds, transferMilliseconds: transferMilliseconds,
        triangulationMilliseconds: triangulationMilliseconds,
        maximumToleranceMetres: maximumToleranceMetres))
  }

  public static func loadSTEP(
    _ url: URL,
    linearDeflectionMetres: Double = 0.0002,
    angularDeflectionRadians: Double = 0.35
  ) throws -> GeometryDocument {
    let raw = gb_load_step_document(url.path, linearDeflectionMetres, angularDeflectionRadians)
    defer { gb_free_document(raw) }
    return try decode(raw, sourceURL: url)
  }

  public static func demo(
    linearDeflectionMetres: Double = 0.0002,
    angularDeflectionRadians: Double = 0.35
  ) throws -> GeometryDocument {
    let raw = gb_make_demo_document(linearDeflectionMetres, angularDeflectionRadians)
    defer { gb_free_document(raw) }
    return try decode(raw, sourceURL: nil)
  }

  private static func decode(_ raw: GBDocument, sourceURL: URL?) throws -> GeometryDocument {
    if let error = raw.error_message {
      throw GeometryImportError.kernel(String(cString: error))
    }
    guard raw.vertex_count > 0, let positions = raw.positions, let normals = raw.normals,
      let indices = raw.indices
    else { throw GeometryImportError.emptyGeometry }

    var faces: [BenchFace] = []
    if let ranges = raw.faces {
      for index in 0..<Int(raw.face_count) {
        let range = ranges[index]
        let vertexOffset = Int(range.vertex_offset)
        let vertexCount = Int(range.vertex_count)
        let indexOffset = Int(range.index_offset)
        let indexCount = Int(range.index_count)
        let localPositions = (0..<vertexCount).map { vertex in
          let base = (vertexOffset + vertex) * 3
          return SIMD3(positions[base], positions[base + 1], positions[base + 2])
        }
        let localNormals = (0..<vertexCount).map { vertex in
          let base = (vertexOffset + vertex) * 3
          return SIMD3(normals[base], normals[base + 1], normals[base + 2])
        }
        let localIndices = (0..<indexCount).map { item in
          indices[indexOffset + item] - UInt32(vertexOffset)
        }
        faces.append(
          BenchFace(
            id: Int(range.topology_index), positions: localPositions, normals: localNormals,
            indices: localIndices,
            color: SIMD4(range.color.0, range.color.1, range.color.2, range.color.3),
            assemblyNode: Int(range.assembly_node)))
      }
    }

    var edges: [BenchEdge] = []
    if let ranges = raw.edges, let points = raw.edge_points {
      for index in 0..<Int(raw.edge_count) {
        let range = ranges[index]
        let localPoints = (0..<Int(range.point_count)).map { item in
          let base = (Int(range.point_offset) + item) * 3
          return SIMD3(points[base], points[base + 1], points[base + 2])
        }
        edges.append(
          BenchEdge(
            id: Int(range.topology_index), points: localPoints,
            assemblyNode: Int(range.assembly_node)))
      }
    }

    let nodes: [AssemblyNode] = (0..<Int(raw.node_count)).compactMap { index in
      guard let node = raw.nodes?[index], let name = node.name else { return nil }
      let values = withUnsafeBytes(of: node.transform) { Array($0.bindMemory(to: Double.self)) }
      let matrix = simd_double4x4(
        SIMD4(values[0], values[1], values[2], values[3]),
        SIMD4(values[4], values[5], values[6], values[7]),
        SIMD4(values[8], values[9], values[10], values[11]),
        SIMD4(values[12] * 0.001, values[13] * 0.001, values[14] * 0.001, values[15]))
      return AssemblyNode(
        id: index, name: String(cString: name),
        parentIndex: node.parent_index >= 0 ? Int(node.parent_index) : nil,
        transform: matrix)
    }

    return GeometryDocument(
      sourceURLs: sourceURL.map { [$0] } ?? [], faces: faces, edges: edges, nodes: nodes,
      metrics: ImportMetrics(
        readMilliseconds: raw.read_seconds * 1000,
        transferMilliseconds: raw.transfer_seconds * 1000,
        triangulationMilliseconds: raw.triangulation_seconds * 1000,
        maximumToleranceMetres: raw.maximum_tolerance_m))
  }
}

public enum GeometryImportError: LocalizedError {
  case kernel(String)
  case emptyGeometry

  public var errorDescription: String? {
    switch self {
    case .kernel(let message): message
    case .emptyGeometry: "The importer returned no triangles."
    }
  }
}

public enum GeomKernel {
  public static var version: String { String(cString: gb_occt_version()) }
}
