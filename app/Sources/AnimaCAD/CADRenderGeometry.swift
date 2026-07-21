import Foundation
import simd

public struct CADRenderGeometry: Sendable {
  public let positions: [SIMD3<Float>]
  public let normals: [SIMD3<Float>]
  public let colors: [SIMD4<UInt8>]
  public let faceIDs: [UInt32]
  public let partIDs: [UInt32]
  public let indices: [UInt32]
  public let edgePositions: [SIMD3<Float>]
  public let batches: [CADRenderBatch]
  public let bounds: CADRenderBounds

  public var vertexCount: Int { positions.count }
  public var triangleCount: Int { indices.count / 3 }
  public var edgeSegmentCount: Int { edgePositions.count / 2 }
  public var partCount: Int { Set(batches.map(\.assemblyNode)).count }

  public init(faces: [CADFace], edges: [CADEdge]) {
    struct BatchKey: Hashable {
      let assemblyNode: Int
      let rgba: UInt32
    }
    var keyOrder: [BatchKey] = []
    var faceIndices: [BatchKey: [Int]] = [:]
    for (faceIndex, face) in faces.enumerated() {
      let key = BatchKey(assemblyNode: face.assemblyNode, rgba: Self.pack(face.color))
      if faceIndices[key] == nil { keyOrder.append(key) }
      faceIndices[key, default: []].append(faceIndex)
    }

    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var colors: [SIMD4<UInt8>] = []
    var faceIDs: [UInt32] = []
    var partIDs: [UInt32] = []
    var indices: [UInt32] = []
    var batches: [CADRenderBatch] = []
    var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

    for key in keyOrder {
      let vertexStart = positions.count
      let indexStart = indices.count
      var topologyIDs: [Int] = []
      let color = Self.unpack(key.rgba)
      for faceIndex in faceIndices[key] ?? [] {
        let face = faces[faceIndex]
        let vertexOffset = UInt32(positions.count)
        positions.append(contentsOf: face.positions)
        normals.append(contentsOf: face.normals)
        colors.append(contentsOf: repeatElement(color, count: face.positions.count))
        faceIDs.append(
          contentsOf: repeatElement(UInt32(clamping: face.id), count: face.positions.count))
        let partID = key.assemblyNode >= 0 ? UInt32(key.assemblyNode + 1) : 0
        partIDs.append(contentsOf: repeatElement(partID, count: face.positions.count))
        indices.append(contentsOf: face.indices.map { $0 + vertexOffset })
        topologyIDs.append(face.id)
        for position in face.positions {
          minimum = simd_min(minimum, position)
          maximum = simd_max(maximum, position)
        }
      }
      batches.append(
        CADRenderBatch(
          assemblyNode: key.assemblyNode,
          materialColor: color,
          vertexRange: vertexStart..<positions.count,
          indexRange: indexStart..<indices.count,
          faceIDs: topologyIDs
        ))
    }

    var edgePositions: [SIMD3<Float>] = []
    for edge in edges where edge.points.count > 1 {
      for index in 0..<(edge.points.count - 1) {
        edgePositions.append(edge.points[index])
        edgePositions.append(edge.points[index + 1])
      }
    }
    self.positions = positions
    self.normals = normals
    self.colors = colors
    self.faceIDs = faceIDs
    self.partIDs = partIDs
    self.indices = indices
    self.edgePositions = edgePositions
    self.batches = batches
    bounds = positions.isEmpty ? .empty : .init(minimum: minimum, maximum: maximum)
  }

  public func edgePositions(maximumSegments: Int) -> [SIMD3<Float>] {
    guard maximumSegments > 0, edgeSegmentCount > maximumSegments else {
      return maximumSegments > 0 ? edgePositions : []
    }
    let step = Double(edgeSegmentCount) / Double(maximumSegments)
    return (0..<maximumSegments).flatMap { sample -> [SIMD3<Float>] in
      let segment = min(Int(Double(sample) * step), edgeSegmentCount - 1)
      return [edgePositions[segment * 2], edgePositions[segment * 2 + 1]]
    }
  }

  private static func pack(_ value: SIMD4<Float>) -> UInt32 {
    let rgba = SIMD4<UInt8>(
      quantize(value.x), quantize(value.y), quantize(value.z), quantize(value.w))
    return UInt32(rgba.x) | UInt32(rgba.y) << 8 | UInt32(rgba.z) << 16 | UInt32(rgba.w) << 24
  }

  private static func unpack(_ value: UInt32) -> SIMD4<UInt8> {
    SIMD4(
      UInt8(value & 0xff), UInt8((value >> 8) & 0xff),
      UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff))
  }

  private static func quantize(_ value: Float) -> UInt8 {
    UInt8(clamping: Int((min(max(value, 0), 1) * 255).rounded()))
  }
}

public struct CADRenderBatch: Sendable, Equatable {
  public let assemblyNode: Int
  public let materialColor: SIMD4<UInt8>
  public let vertexRange: Range<Int>
  public let indexRange: Range<Int>
  public let faceIDs: [Int]
}

public struct CADRenderBounds: Sendable, Equatable {
  public let minimum: SIMD3<Float>
  public let maximum: SIMD3<Float>
  public static let empty = Self(minimum: .zero, maximum: .zero)
  public var center: SIMD3<Float> { (minimum + maximum) * 0.5 }
  public var diagonal: Float { simd_length(maximum - minimum) }
}
