import AnimaCAD
import Foundation

struct CADWebGeometryPayload: Encodable {
  struct Batch: Encodable {
    let assemblyNode: Int
    let materialColor: [UInt8]
    let vertexStart: Int
    let vertexCount: Int
    let indexStart: Int
    let indexCount: Int
  }

  let formatVersion = 2
  let data: String
  let vertexCount: Int
  let indexCount: Int
  let edgeVertexCount: Int
  let triangles: Int
  let batches: [Batch]

  init(document: CADGeometryDocument) {
    let geometry = document.renderGeometry
    vertexCount = geometry.vertexCount
    indexCount = geometry.indices.count
    edgeVertexCount = geometry.edgePositions.count
    triangles = geometry.triangleCount
    batches = geometry.batches.map {
      Batch(
        assemblyNode: $0.assemblyNode,
        materialColor: [
          $0.materialColor.x, $0.materialColor.y, $0.materialColor.z, $0.materialColor.w,
        ],
        vertexStart: $0.vertexRange.lowerBound, vertexCount: $0.vertexRange.count,
        indexStart: $0.indexRange.lowerBound, indexCount: $0.indexRange.count)
    }
    let positionBytes = geometry.vertexCount * 3 * MemoryLayout<Float>.size
    let normalBytes = positionBytes
    let colorBytes = geometry.vertexCount * 4
    let indexBytes = geometry.indices.count * MemoryLayout<UInt32>.size
    let edgeBytes = geometry.edgePositions.count * 3 * MemoryLayout<Float>.size
    let edgePartIDBytes = geometry.edgePartIDs.count * MemoryLayout<UInt32>.size
    var payload = Data(
      count: positionBytes + normalBytes + colorBytes + indexBytes + edgeBytes + edgePartIDBytes)
    payload.withUnsafeMutableBytes { raw in
      var offset = 0
      func write(_ value: Float) {
        raw.storeBytes(of: value.bitPattern.littleEndian, toByteOffset: offset, as: UInt32.self)
        offset += 4
      }
      for value in geometry.positions {
        write(value.x)
        write(value.y)
        write(value.z)
      }
      for value in geometry.normals {
        write(value.x)
        write(value.y)
        write(value.z)
      }
      for value in geometry.colors {
        raw[offset] = value.x
        raw[offset + 1] = value.y
        raw[offset + 2] = value.z
        raw[offset + 3] = value.w
        offset += 4
      }
      for value in geometry.indices {
        raw.storeBytes(of: value.littleEndian, toByteOffset: offset, as: UInt32.self)
        offset += 4
      }
      for value in geometry.edgePositions {
        write(value.x)
        write(value.y)
        write(value.z)
      }
      for value in geometry.edgePartIDs {
        raw.storeBytes(of: value.littleEndian, toByteOffset: offset, as: UInt32.self)
        offset += 4
      }
    }
    data = payload.base64EncodedString()
  }
}

struct CADWebThemePayload: Encodable {
  struct Light: Encodable {
    let color: [Float]
    let direction: [Float]
    let intensity: Float
    init(_ value: CADViewportTheme.Light) {
      color = [value.color.x, value.color.y, value.color.z]
      direction = [value.directionFrom.x, value.directionFrom.y, value.directionFrom.z]
      intensity = value.intensity / 4_000
    }
  }
  let background: [Float]
  let backgroundBottom: [Float]?
  let floorColor: [Float]
  let edge: [Float]
  let selection: [Float]
  let roughness: Float
  let metallic: Float
  let edgeStrength: Float
  let ambientStrength: Float
  let shadowStrength: Float
  let overrideColor: [Float]?
  let key: Light
  let fill: Light
  let rim: Light

  init(theme: CADViewportTheme) {
    background = [theme.background.x, theme.background.y, theme.background.z]
    backgroundBottom = theme.backgroundBottom.map { [$0.x, $0.y, $0.z] }
    floorColor = [theme.floorColor.x, theme.floorColor.y, theme.floorColor.z]
    edge = [theme.edgeColor.x, theme.edgeColor.y, theme.edgeColor.z]
    selection = [theme.selectionColor.x, theme.selectionColor.y, theme.selectionColor.z]
    roughness = theme.roughness
    metallic = theme.metallic
    edgeStrength = theme.edgeStrength
    ambientStrength = theme.ambientStrength
    shadowStrength = theme.shadowStrength
    overrideColor = theme.overrideColor.map { [$0.x, $0.y, $0.z, $0.w] }
    key = Light(theme.key)
    fill = Light(theme.fill)
    rim = Light(theme.rim)
  }
}

struct CADWebNavigationPayload: Encodable {
  let orbit: [String]
  let pan: [String]
  let preciseZoom: [String]
  let orbitMultiplier: Float
  let panMultiplier: Float
  let zoomMultiplier: Float
  let reversesWheelZoom: Bool

  init(_ configuration: CADViewportNavigationConfiguration) {
    orbit = configuration.orbitDragBindings.sorted()
    pan = configuration.panDragBindings.sorted()
    preciseZoom = configuration.preciseZoomDragBindings.sorted()
    orbitMultiplier = configuration.orbitMultiplier
    panMultiplier = configuration.panMultiplier
    zoomMultiplier = configuration.zoomMultiplier
    reversesWheelZoom = configuration.reversesWheelZoom
  }
}
