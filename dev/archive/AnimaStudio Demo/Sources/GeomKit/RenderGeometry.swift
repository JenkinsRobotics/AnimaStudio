import Foundation
import simd

/// Renderer-ready projection of one imported B-Rep document.
///
/// The Open CASCADE-facing model intentionally keeps exact face and edge
/// records. Renderers should consume this compact projection instead of each
/// independently flattening thousands of faces. Batches preserve rigid-part,
/// material, and topology identity while keeping GPU buffers contiguous.
public struct RenderGeometry: Sendable {
  public let positions: [SIMD3<Float>]
  public let normals: [SIMD3<Float>]
  public let colors: [SIMD4<UInt8>]
  public let faceIDs: [UInt32]
  public let partIDs: [UInt32]
  public let indices: [UInt32]
  public let edgePositions: [SIMD3<Float>]
  public let batches: [RenderBatch]
  public let bounds: RenderBounds

  public var vertexCount: Int { positions.count }
  public var triangleCount: Int { indices.count / 3 }
  public var edgeSegmentCount: Int { edgePositions.count / 2 }
  public var partCount: Int { Set(batches.map(\.assemblyNode)).count }

  /// Evenly samples complete line segments for renderers whose scene layer
  /// cannot sustain the full CAD edge set. The source topology remains intact
  /// in `GeometryDocument.edges`; this is presentation-only budgeting.
  public func edgePositions(maximumSegments: Int) -> [SIMD3<Float>] {
    guard maximumSegments > 0, edgeSegmentCount > maximumSegments else {
      return maximumSegments > 0 ? edgePositions : []
    }
    let step = Double(edgeSegmentCount) / Double(maximumSegments)
    var result: [SIMD3<Float>] = []
    result.reserveCapacity(maximumSegments * 2)
    for sample in 0..<maximumSegments {
      let segment = min(Int(Double(sample) * step), edgeSegmentCount - 1)
      result.append(edgePositions[segment * 2])
      result.append(edgePositions[segment * 2 + 1])
    }
    return result
  }

  public init(faces: [BenchFace], edges: [BenchEdge]) {
    struct BatchKey: Hashable {
      let assemblyNode: Int
      let rgba: UInt32
    }

    var keyOrder: [BatchKey] = []
    var faceIndicesByKey: [BatchKey: [Int]] = [:]
    for (faceIndex, face) in faces.enumerated() {
      let key = BatchKey(assemblyNode: face.assemblyNode, rgba: Self.pack(face.color))
      if faceIndicesByKey[key] == nil { keyOrder.append(key) }
      faceIndicesByKey[key, default: []].append(faceIndex)
    }

    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var colors: [SIMD4<UInt8>] = []
    var faceIDs: [UInt32] = []
    var partIDs: [UInt32] = []
    var indices: [UInt32] = []
    var batches: [RenderBatch] = []
    positions.reserveCapacity(faces.reduce(0) { $0 + $1.positions.count })
    normals.reserveCapacity(positions.capacity)
    colors.reserveCapacity(positions.capacity)
    faceIDs.reserveCapacity(positions.capacity)
    partIDs.reserveCapacity(positions.capacity)
    indices.reserveCapacity(faces.reduce(0) { $0 + $1.indices.count })

    var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

    for key in keyOrder {
      let vertexStart = positions.count
      let indexStart = indices.count
      var topologyIDs: [Int] = []
      let color = Self.unpack(key.rgba)
      for faceIndex in faceIndicesByKey[key] ?? [] {
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
        RenderBatch(
          assemblyNode: key.assemblyNode,
          materialColor: color,
          vertexRange: vertexStart..<positions.count,
          indexRange: indexStart..<indices.count,
          faceIDs: topologyIDs))
    }

    var edgePositions: [SIMD3<Float>] = []
    edgePositions.reserveCapacity(edges.reduce(0) { $0 + max($1.points.count - 1, 0) * 2 })
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
    self.bounds = positions.isEmpty ? .empty : RenderBounds(minimum: minimum, maximum: maximum)
  }

  private static func pack(_ color: SIMD4<Float>) -> UInt32 {
    let rgba = SIMD4<UInt8>(
      quantize(color.x), quantize(color.y), quantize(color.z), quantize(color.w))
    return UInt32(rgba.x) | UInt32(rgba.y) << 8 | UInt32(rgba.z) << 16 | UInt32(rgba.w) << 24
  }

  private static func unpack(_ value: UInt32) -> SIMD4<UInt8> {
    SIMD4(
      UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff),
      UInt8((value >> 24) & 0xff))
  }

  private static func quantize(_ value: Float) -> UInt8 {
    UInt8(clamping: Int((min(max(value, 0), 1) * 255).rounded()))
  }
}

public struct RenderBatch: Sendable, Equatable {
  public let assemblyNode: Int
  public let materialColor: SIMD4<UInt8>
  public let vertexRange: Range<Int>
  public let indexRange: Range<Int>
  public let faceIDs: [Int]
}

public struct RenderBounds: Sendable, Equatable {
  public let minimum: SIMD3<Float>
  public let maximum: SIMD3<Float>

  public static let empty = RenderBounds(minimum: .zero, maximum: .zero)
  public var center: SIMD3<Float> { (minimum + maximum) * 0.5 }
  public var diagonal: Float { simd_length(maximum - minimum) }
}
