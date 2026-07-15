import AnimaCore
import AppKit
import RealityKit
import simd

/// How connector-candidate markers present in the viewport.
///
/// `placement` is the mate-placement flow (orange commit targets).
/// `standingSelection` is the persistent sub-object selection preview: the
/// same inferred candidates, drawn quietly until hover reveals the exact
/// clickable feature — the view-cube interaction generalized to components.
enum MateConnectorMarkerStyle: String, CaseIterable, Sendable {
  case placement
  case standingSelection

  struct Appearance: Equatable {
    let tint: NSColor
    /// Base opacity for the marker sphere; nil renders fully opaque.
    let opacity: Float?
    let radiusMeters: Float
    let hoverColor: NSColor
    let hoverStrength: Float
    let showsAxisStem: Bool
  }

  func appearance(isSelected: Bool) -> Appearance {
    switch (self, isSelected) {
    case (.placement, false):
      Appearance(
        tint: .systemOrange, opacity: nil, radiusMeters: 0.031,
        hoverColor: .systemYellow, hoverStrength: 1.45, showsAxisStem: true)
    case (.placement, true):
      Appearance(
        tint: .systemPurple, opacity: nil, radiusMeters: 0.042,
        hoverColor: .systemYellow, hoverStrength: 1.45, showsAxisStem: true)
    case (.standingSelection, false):
      Appearance(
        tint: .systemCyan, opacity: 0.34, radiusMeters: 0.024,
        hoverColor: .systemCyan, hoverStrength: 2.2, showsAxisStem: false)
    case (.standingSelection, true):
      Appearance(
        tint: .systemCyan, opacity: nil, radiusMeters: 0.038,
        hoverColor: .systemCyan, hoverStrength: 2.2, showsAxisStem: true)
    }
  }
}

@MainActor
enum MateConnectorMarkerFactory {
  static let layerName = "mateCandidateLayer"
  static let signaturePrefix = "mateCandidateSignature|"
  static let markerPrefix = "mateCandidate|"

  static func apply(
    rig: CharacterRig,
    visiblePartIDs: Set<PartID>,
    selectedCandidate: MateConnectorCandidate?,
    style: MateConnectorMarkerStyle = .placement,
    to root: Entity
  ) {
    let signature = makeSignature(
      visiblePartIDs: visiblePartIDs,
      selectedCandidate: selectedCandidate,
      style: style
    )
    if root.findEntity(named: signature) != nil { return }

    removeLayers(from: root)
    for partID in visiblePartIDs {
      guard let part = rig.parts.first(where: { $0.id == partID }),
        let partEntity = root.findEntity(named: RobotPreviewView.partEntityName(partID))
      else { continue }
      let layer = Entity()
      layer.name = layerName
      for candidate in MateConnectorInference.candidates(for: part) {
        let isSelected =
          selectedCandidate?.partID == candidate.partID && selectedCandidate?.id == candidate.id
        layer.addChild(
          makeMarker(candidate, isSelected: isSelected, acceptsInput: true, style: style))
      }
      partEntity.addChild(layer)
    }

    if let selectedCandidate,
      !visiblePartIDs.contains(selectedCandidate.partID),
      let partEntity = root.findEntity(
        named: RobotPreviewView.partEntityName(selectedCandidate.partID)
      )
    {
      let layer = Entity()
      layer.name = layerName
      layer.addChild(
        makeMarker(selectedCandidate, isSelected: true, acceptsInput: false, style: style))
      partEntity.addChild(layer)
    }

    let signatureEntity = Entity()
    signatureEntity.name = signature
    root.addChild(signatureEntity)
  }

  static func remove(from root: Entity) {
    removeLayers(from: root)
  }

  static func candidate(
    from entity: Entity,
    rig: CharacterRig
  ) -> MateConnectorCandidate? {
    var current: Entity? = entity
    while let candidateEntity = current {
      if candidateEntity.name.hasPrefix(markerPrefix) {
        let components = candidateEntity.name.split(
          separator: "|", omittingEmptySubsequences: false)
        guard components.count == 3,
          let uuid = UUID(uuidString: String(components[1]))
        else { return nil }
        let partID = PartID(rawValue: uuid)
        guard let part = rig.parts.first(where: { $0.id == partID }) else { return nil }
        let candidateID = String(components[2])
        return MateConnectorInference.candidates(for: part).first { $0.id == candidateID }
      }
      current = candidateEntity.parent
    }
    return nil
  }

  private static func makeMarker(
    _ candidate: MateConnectorCandidate,
    isSelected: Bool,
    acceptsInput: Bool,
    style: MateConnectorMarkerStyle
  ) -> ModelEntity {
    let appearance = style.appearance(isSelected: isSelected)
    var material = UnlitMaterial(color: appearance.tint)
    if let opacity = appearance.opacity {
      material.blending = .transparent(opacity: .init(floatLiteral: opacity))
    }
    let marker = ModelEntity(
      mesh: .generateSphere(radius: appearance.radiusMeters),
      materials: [material]
    )
    marker.name = "\(markerPrefix)\(candidate.partID.rawValue.uuidString)|\(candidate.id)"
    marker.position = vector(candidate.connector.originMeters)
    marker.orientation = orientation(candidate.connector)

    if appearance.showsAxisStem {
      let primaryAxis = ModelEntity(
        mesh: .generateCylinder(height: 0.105, radius: 0.007),
        materials: [UnlitMaterial(color: appearance.tint.withAlphaComponent(0.92))]
      )
      primaryAxis.position.z = 0.0525
      primaryAxis.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
      marker.addChild(primaryAxis)
    }

    if acceptsInput {
      marker.components.set(InputTargetComponent(allowedInputTypes: .indirect))
      marker.components.set(
        CollisionComponent(shapes: [.generateSphere(radius: appearance.radiusMeters * 1.8)])
      )
      marker.components.set(
        HoverEffectComponent(
          .highlight(.init(color: appearance.hoverColor, strength: appearance.hoverStrength))
        )
      )
    }
    return marker
  }

  static func orientation(_ connector: MateConnectorDefinition) -> simd_quatf {
    let basis = MateConnectorMath.orthonormalBasis(for: connector)
    let rotation = simd_float3x3(
      SIMD3<Float>(basis.x),
      SIMD3<Float>(basis.y),
      SIMD3<Float>(basis.z)
    )
    return simd_quatf(rotation)
  }

  private static func makeSignature(
    visiblePartIDs: Set<PartID>,
    selectedCandidate: MateConnectorCandidate?,
    style: MateConnectorMarkerStyle
  ) -> String {
    let visible = visiblePartIDs.map { $0.rawValue.uuidString }.sorted().joined(separator: ",")
    let selected =
      selectedCandidate.map {
        "\($0.partID.rawValue.uuidString):\($0.id)"
      } ?? "none"
    return "\(signaturePrefix)\(style.rawValue)|\(visible)|\(selected)"
  }

  private static func removeLayers(from root: Entity) {
    for partEntity in root.children where partEntity.name.hasPrefix("semanticPart-") {
      for child in Array(partEntity.children) where child.name == layerName {
        child.removeFromParent()
      }
    }
    for child in Array(root.children) where child.name.hasPrefix(signaturePrefix) {
      child.removeFromParent()
    }
  }

  private static func vector(_ value: RigVector3) -> SIMD3<Float> {
    SIMD3<Float>(Float(value.x), Float(value.y), Float(value.z))
  }
}
