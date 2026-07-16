import Foundation
import ModelIO
import RealityKit

public enum RealityKitModelLoadingError: Error, Equatable, Sendable {
  case unsupportedFileType(String)
  case emptyAsset(String)
  case missingPositions(String)
  case missingTriangles(String)
  case modelNodeNotFound(String)
}

extension RealityKitModelLoadingError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .unsupportedFileType(let fileExtension):
      "The .\(fileExtension) model format is not supported by this importer."
    case .emptyAsset(let filename):
      "\(filename) does not contain any mesh geometry."
    case .missingPositions(let meshName):
      "The mesh ‘\(meshName)’ does not contain readable vertex positions."
    case .missingTriangles(let meshName):
      "The mesh ‘\(meshName)’ does not contain triangle indices."
    case .modelNodeNotFound(let path):
      "The model node ‘\(path)’ was not found in the imported file."
    }
  }
}

@MainActor
public enum RealityKitModelLoader {
  public static let nativeFileExtensions: Set<String> = [
    "usd", "usda", "usdc", "usdz", "reality",
  ]
  public static let modelIOFileExtensions: Set<String> = ["stl", "obj"]

  public static func load(
    contentsOf url: URL,
    unitScaleToMeters: Double = 1,
    modelNode: String? = nil
  ) async throws -> Entity {
    let fileExtension = url.pathExtension.lowercased()
    let root: Entity
    if nativeFileExtensions.contains(fileExtension) {
      root = try await Entity(contentsOf: url)
    } else if modelIOFileExtensions.contains(fileExtension) {
      let meshes = try await Task.detached(priority: .userInitiated) {
        try ModelIOImporter.load(url: url, unitScaleToMeters: unitScaleToMeters)
      }.value
      root = try makeEntity(from: meshes, name: url.deletingPathExtension().lastPathComponent)
    } else {
      throw RealityKitModelLoadingError.unsupportedFileType(fileExtension)
    }

    guard let modelNode, !modelNode.isEmpty else { return root }
    guard let selected = entity(at: modelNode, in: root) else {
      throw RealityKitModelLoadingError.modelNodeNotFound(modelNode)
    }
    return selected.clone(recursive: true)
  }

  private static func makeEntity(from meshes: [ImportedMesh], name: String) throws -> Entity {
    let root = Entity()
    root.name = name
    let material = PhysicallyBasedMaterial()
    for imported in meshes {
      var descriptor = MeshDescriptor(name: imported.name)
      descriptor.positions = MeshBuffers.Positions(imported.positions)
      if imported.normals.count == imported.positions.count {
        descriptor.normals = MeshBuffers.Normals(imported.normals)
      }
      if imported.textureCoordinates.count == imported.positions.count {
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(
          imported.textureCoordinates
        )
      }
      descriptor.primitives = .triangles(imported.indices)
      let mesh = try MeshResource.generate(from: [descriptor])
      let entity = ModelEntity(mesh: mesh, materials: [material])
      entity.name = imported.name
      root.addChild(entity)
    }
    return root
  }

  private static func entity(at path: String, in root: Entity) -> Entity? {
    var components = path.split(separator: "/").map(String.init)
    if components.first == root.name { components.removeFirst() }
    var current = root
    for component in components {
      guard let next = current.children.first(where: { $0.name == component }) else {
        return nil
      }
      current = next
    }
    return current
  }
}

private struct ImportedMesh: Sendable {
  let name: String
  let positions: [SIMD3<Float>]
  let normals: [SIMD3<Float>]
  let textureCoordinates: [SIMD2<Float>]
  let indices: [UInt32]
}

private enum ModelIOImporter {
  static func load(url: URL, unitScaleToMeters: Double) throws -> [ImportedMesh] {
    let asset = MDLAsset(url: url)
    asset.loadTextures()
    let meshes = asset.childObjects(of: MDLMesh.self).compactMap { $0 as? MDLMesh }
    guard !meshes.isEmpty else {
      throw RealityKitModelLoadingError.emptyAsset(url.lastPathComponent)
    }
    return try meshes.enumerated().map { index, mesh in
      let name = mesh.name.isEmpty ? "Mesh \(index + 1)" : mesh.name
      if mesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributeNormal) == nil {
        mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.5)
      }
      guard
        let positions = vectors3(
          mesh.vertexAttributeData(
            forAttributeNamed: MDLVertexAttributePosition,
            as: .float3
          ),
          count: mesh.vertexCount
        )
      else {
        throw RealityKitModelLoadingError.missingPositions(name)
      }
      let scale = Float(unitScaleToMeters)
      let scaledPositions = positions.map { $0 * scale }
      let normals =
        vectors3(
          mesh.vertexAttributeData(
            forAttributeNamed: MDLVertexAttributeNormal,
            as: .float3
          ),
          count: mesh.vertexCount
        ) ?? []
      let textureCoordinates =
        vectors2(
          mesh.vertexAttributeData(
            forAttributeNamed: MDLVertexAttributeTextureCoordinate,
            as: .float2
          ),
          count: mesh.vertexCount
        ) ?? []
      let indices = triangleIndices(mesh)
      guard !indices.isEmpty else {
        throw RealityKitModelLoadingError.missingTriangles(name)
      }
      return ImportedMesh(
        name: name,
        positions: scaledPositions,
        normals: normals,
        textureCoordinates: textureCoordinates,
        indices: indices
      )
    }
  }

  private static func vectors3(
    _ data: MDLVertexAttributeData?,
    count: Int
  ) -> [SIMD3<Float>]? {
    guard let data else { return nil }
    return (0..<count).map { index in
      let values = data.dataStart.advanced(by: index * data.stride)
        .assumingMemoryBound(to: Float.self)
      return SIMD3(values[0], values[1], values[2])
    }
  }

  private static func vectors2(
    _ data: MDLVertexAttributeData?,
    count: Int
  ) -> [SIMD2<Float>]? {
    guard let data else { return nil }
    return (0..<count).map { index in
      let values = data.dataStart.advanced(by: index * data.stride)
        .assumingMemoryBound(to: Float.self)
      return SIMD2(values[0], values[1])
    }
  }

  private static func triangleIndices(_ mesh: MDLMesh) -> [UInt32] {
    guard let submeshes = mesh.submeshes as? [MDLSubmesh] else { return [] }
    return submeshes.flatMap { submesh -> [UInt32] in
      guard submesh.geometryType == .triangles else { return [] }
      let bytes = submesh.indexBuffer.map().bytes
      switch submesh.indexType {
      case .invalid:
        return []
      case .uInt8:
        let values = bytes.assumingMemoryBound(to: UInt8.self)
        return (0..<submesh.indexCount).map { UInt32(values[$0]) }
      case .uInt16:
        let values = bytes.assumingMemoryBound(to: UInt16.self)
        return (0..<submesh.indexCount).map { UInt32(values[$0]) }
      case .uInt32:
        let values = bytes.assumingMemoryBound(to: UInt32.self)
        return (0..<submesh.indexCount).map { values[$0] }
      @unknown default:
        return []
      }
    }
  }
}
