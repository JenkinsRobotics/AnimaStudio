import AnimaModel
import AppKit
import RealityKit
import simd

enum MeshFeatureVisualKind: Sendable {
  case face
  case edge
  case corner
}

struct MeshFeatureComponent: Component {
  let candidate: MateConnectorCandidate
  let visualKind: MeshFeatureVisualKind
}

@MainActor
enum MeshFeatureOverlayFactory {
  static let layerName = "importedMeshFeatureLayer"

  static func make(
    partID: PartID,
    topology: ImportedMeshTopology
  ) async -> Entity {
    let layer = Entity()
    layer.name = layerName
    let extent = max(topology.boundsExtent, 0.1)
    let surfaceOffset = max(extent * 0.000_35, 0.000_02)
    let edgeRadius = min(max(extent * 0.002_2, 0.000_8), 0.008)
    let cornerRadius = min(max(extent * 0.006, 0.001_8), 0.018)

    for (index, face) in topology.faces.enumerated() {
      guard
        let entity = await makeFace(
          face,
          partID: partID,
          displayIndex: index + 1,
          surfaceOffset: surfaceOffset
        )
      else { continue }
      layer.addChild(entity)
    }

    for (index, edge) in topology.edges.enumerated() {
      let candidate = candidate(
        id: edge.id,
        partID: partID,
        displayName: "Mesh Edge \(index + 1)",
        featureKind: .edgeMidpoint,
        origin: edge.center,
        primary: edge.normal,
        secondary: edge.direction
      )
      for (segmentIndex, pair) in zip(edge.points, edge.points.dropFirst()).enumerated() {
        guard
          let segment = makeEdgeSegment(
            from: pair.0,
            to: pair.1,
            radius: edgeRadius,
            candidate: candidate,
            segmentIndex: segmentIndex
          )
        else { continue }
        layer.addChild(segment)
      }
    }

    for (index, corner) in topology.corners.enumerated() {
      let candidate = candidate(
        id: corner.id,
        partID: partID,
        displayName: "Mesh Corner \(index + 1)",
        featureKind: .corner,
        origin: corner.position,
        primary: corner.normal,
        secondary: perpendicular(to: corner.normal)
      )
      let marker = ModelEntity(
        mesh: .generateSphere(radius: cornerRadius),
        materials: [material(for: .corner, state: .idle)]
      )
      marker.name = "meshFeature|corner|\(corner.id)"
      marker.position = corner.position
      marker.components.set(MeshFeatureComponent(candidate: candidate, visualKind: .corner))
      marker.components.set(InputTargetComponent(allowedInputTypes: .indirect))
      marker.components.set(
        CollisionComponent(shapes: [.generateSphere(radius: cornerRadius * 2.4)])
      )
      layer.addChild(marker)
    }

    return layer
  }

  static func candidate(from entity: Entity) -> MateConnectorCandidate? {
    var current: Entity? = entity
    while let candidateEntity = current {
      if let feature = candidateEntity.components[MeshFeatureComponent.self] {
        return feature.candidate
      }
      current = candidateEntity.parent
    }
    return nil
  }

  static func containsFeature(_ entity: Entity) -> Bool {
    candidate(from: entity) != nil
  }

  static func applyInteraction(
    hovered: MateConnectorCandidate?,
    selected: MateConnectorCandidate?,
    pickScale: Float,
    to root: Entity
  ) {
    var stack = [root]
    while let entity = stack.popLast() {
      if let feature = entity.components[MeshFeatureComponent.self],
        var model = entity.components[ModelComponent.self]
      {
        let state: InteractionState
        if matches(feature.candidate, selected) {
          state = .selected
        } else if matches(feature.candidate, hovered) {
          state = .hovered
        } else {
          state = .idle
        }
        model.materials = [material(for: feature.visualKind, state: state)]
        entity.components.set(model)
        switch feature.visualKind {
        case .face:
          entity.scale = SIMD3(repeating: 1)
        case .edge:
          entity.scale = SIMD3(pickScale, 1, pickScale)
        case .corner:
          entity.scale = SIMD3(repeating: pickScale)
        }
      }
      stack.append(contentsOf: entity.children)
    }
  }

  private enum InteractionState {
    case idle
    case hovered
    case selected
  }

  private static func makeFace(
    _ face: ImportedMeshFace,
    partID: PartID,
    displayIndex: Int,
    surfaceOffset: Float
  ) async -> ModelEntity? {
    let positions = face.triangles.flatMap { triangle in
      triangle.map { $0 + face.normal * surfaceOffset }
    }
    guard positions.count >= 3 else { return nil }
    var descriptor = MeshDescriptor(name: face.id)
    descriptor.positions = MeshBuffers.Positions(positions)
    descriptor.normals = MeshBuffers.Normals(
      Array(repeating: face.normal, count: positions.count)
    )
    descriptor.primitives = .triangles((0..<UInt32(positions.count)).map { $0 })
    guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }
    let candidate = candidate(
      id: face.id,
      partID: partID,
      displayName: "Mesh Face \(displayIndex)",
      featureKind: .faceCenter,
      origin: face.center,
      primary: face.normal,
      secondary: face.tangent
    )
    let entity = ModelEntity(mesh: mesh, materials: [material(for: .face, state: .idle)])
    entity.name = "meshFeature|face|\(face.id)"
    entity.components.set(MeshFeatureComponent(candidate: candidate, visualKind: .face))
    entity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
    if let shape = try? await ShapeResource.generateStaticMesh(from: mesh) {
      entity.components.set(CollisionComponent(shapes: [shape]))
    } else if let shape = try? await ShapeResource.generateConvex(from: positions) {
      entity.components.set(CollisionComponent(shapes: [shape]))
    }
    return entity
  }

  private static func makeEdgeSegment(
    from start: SIMD3<Float>,
    to end: SIMD3<Float>,
    radius: Float,
    candidate: MateConnectorCandidate,
    segmentIndex: Int
  ) -> ModelEntity? {
    let delta = end - start
    let length = simd_length(delta)
    guard length.isFinite, length > 0.000_001 else { return nil }
    let segment = ModelEntity(
      mesh: .generateCylinder(height: length, radius: radius),
      materials: [material(for: .edge, state: .idle)]
    )
    segment.name = "meshFeature|edge|\(candidate.id)|\(segmentIndex)"
    segment.position = (start + end) / 2
    segment.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: delta / length)
    segment.components.set(MeshFeatureComponent(candidate: candidate, visualKind: .edge))
    segment.components.set(InputTargetComponent(allowedInputTypes: .indirect))
    segment.components.set(
      CollisionComponent(shapes: [.generateCapsule(height: length, radius: radius * 3.2)])
    )
    return segment
  }

  private static func matches(
    _ first: MateConnectorCandidate,
    _ second: MateConnectorCandidate?
  ) -> Bool {
    first.partID == second?.partID && first.id == second?.id
  }

  private static func candidate(
    id: String,
    partID: PartID,
    displayName: String,
    featureKind: MateConnectorFeatureKind,
    origin: SIMD3<Float>,
    primary: SIMD3<Float>,
    secondary: SIMD3<Float>
  ) -> MateConnectorCandidate {
    MateConnectorCandidate(
      id: id,
      partID: partID,
      displayName: displayName,
      featureKind: featureKind,
      connector: MateConnectorDefinition(
        originMeters: rigVector(origin),
        primaryAxis: rigVector(normalized(primary, fallback: SIMD3(0, 0, 1))),
        secondaryAxis: rigVector(normalized(secondary, fallback: SIMD3(1, 0, 0)))
      )
    )
  }

  private static func material(
    for kind: MeshFeatureVisualKind,
    state: InteractionState
  ) -> UnlitMaterial {
    let color: NSColor
    let opacity: Float
    switch (kind, state) {
    case (.face, .idle):
      color = .systemCyan
      opacity = 0.002
    case (.edge, .idle), (.corner, .idle):
      color = .systemCyan
      opacity = 0.09
    case (.face, .hovered):
      color = .systemCyan
      opacity = 0.28
    case (.edge, .hovered), (.corner, .hovered):
      color = .systemCyan
      opacity = 0.92
    case (.face, .selected):
      color = .systemOrange
      opacity = 0.48
    case (.edge, .selected), (.corner, .selected):
      color = .systemOrange
      opacity = 1
    }
    var material = UnlitMaterial(color: color)
    material.blending = .transparent(opacity: .init(floatLiteral: opacity))
    return material
  }

  private static func normalized(
    _ value: SIMD3<Float>,
    fallback: SIMD3<Float>
  ) -> SIMD3<Float> {
    let length = simd_length(value)
    return length.isFinite && length > 0.000_001 ? value / length : fallback
  }

  private static func perpendicular(to normal: SIMD3<Float>) -> SIMD3<Float> {
    let reference = abs(normal.x) < 0.8 ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
    return normalized(simd_cross(normal, reference), fallback: SIMD3(0, 0, 1))
  }

  private static func rigVector(_ value: SIMD3<Float>) -> RigVector3 {
    RigVector3(x: Double(value.x), y: Double(value.y), z: Double(value.z))
  }
}
