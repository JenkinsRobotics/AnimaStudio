import Foundation
import GeomKit

/// Compact bridge payload shared by the browser-hosted WebGPU pipelines.
/// Numeric arrays cross WebKit as one base64-encoded binary block rather than
/// millions of decimal JSON values. The browser creates typed-array views over
/// the decoded block without rebuilding the geometry element by element.
struct WebGeometryPayload: Encodable {
  struct Batch: Encodable {
    let assemblyNode: Int
    let materialColor: [UInt8]
    let vertexStart: Int
    let vertexCount: Int
    let indexStart: Int
    let indexCount: Int
  }

  let formatVersion = 1
  let data: String
  let vertexCount: Int
  let indexCount: Int
  let edgeVertexCount: Int
  let triangles: Int
  let batches: [Batch]

  init(document: GeometryDocument) {
    let geometry = document.renderGeometry
    vertexCount = geometry.vertexCount
    indexCount = geometry.indices.count
    edgeVertexCount = geometry.edgePositions.count
    triangles = geometry.triangleCount
    batches = geometry.batches.map { batch in
      Batch(
        assemblyNode: batch.assemblyNode,
        materialColor: [
          batch.materialColor.x, batch.materialColor.y, batch.materialColor.z,
          batch.materialColor.w,
        ],
        vertexStart: batch.vertexRange.lowerBound,
        vertexCount: batch.vertexRange.count,
        indexStart: batch.indexRange.lowerBound,
        indexCount: batch.indexRange.count)
    }

    let positionBytes = geometry.vertexCount * 3 * MemoryLayout<Float>.size
    let normalBytes = positionBytes
    let colorBytes = geometry.vertexCount * 4
    let indexBytes = geometry.indices.count * MemoryLayout<UInt32>.size
    let edgeBytes = geometry.edgePositions.count * 3 * MemoryLayout<Float>.size
    var payload = Data(count: positionBytes + normalBytes + colorBytes + indexBytes + edgeBytes)
    payload.withUnsafeMutableBytes { raw in
      var offset = 0
      func write(_ value: Float) {
        raw.storeBytes(
          of: value.bitPattern.littleEndian, toByteOffset: offset, as: UInt32.self)
        offset += 4
      }
      for position in geometry.positions {
        write(position.x)
        write(position.y)
        write(position.z)
      }
      for normal in geometry.normals {
        write(normal.x)
        write(normal.y)
        write(normal.z)
      }
      for color in geometry.colors {
        raw[offset] = color.x
        raw[offset + 1] = color.y
        raw[offset + 2] = color.z
        raw[offset + 3] = color.w
        offset += 4
      }
      for index in geometry.indices {
        raw.storeBytes(of: index.littleEndian, toByteOffset: offset, as: UInt32.self)
        offset += 4
      }
      for point in geometry.edgePositions {
        write(point.x)
        write(point.y)
        write(point.z)
      }
    }
    data = payload.base64EncodedString()
  }
}
