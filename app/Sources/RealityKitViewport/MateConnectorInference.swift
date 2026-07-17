import AnimaEvaluation
import AnimaModel
import Foundation
import simd

public enum MateConnectorFeatureKind: String, CaseIterable, Sendable {
  case origin
  case faceCenter
  case edgeMidpoint
  case corner
  case axis
  case surfacePoint
}

public struct MateConnectorCandidate: Identifiable, Equatable, Sendable {
  public let id: String
  public let partID: PartID
  public let displayName: String
  public let featureKind: MateConnectorFeatureKind
  public let connector: MateConnectorDefinition

  public init(
    id: String,
    partID: PartID,
    displayName: String,
    featureKind: MateConnectorFeatureKind,
    connector: MateConnectorDefinition
  ) {
    self.id = id
    self.partID = partID
    self.displayName = displayName
    self.featureKind = featureKind
    self.connector = connector
  }
}

public enum RigPrimitivePreviewGeometry {
  public static let boxSizeMeters = 0.55
  public static let cylinderHeightMeters = 0.72
  public static let cylinderRadiusMeters = 0.25
  public static let sphereRadiusMeters = 0.32
  public static let locatorRadiusMeters = 0.08
}

/// Infers stable attachment choices for Studio-created proxy geometry.
/// Imported geometry is classified by `ImportedMeshTopologyBuilder` and then
/// projected into this same `MateConnectorCandidate` contract by the viewport.
public enum MateConnectorInference {
  public static func candidates(for part: RigPartDefinition) -> [MateConnectorCandidate] {
    switch part.primitiveKind {
    case .box, .mesh:
      boxCandidates(partID: part.id)
    case .cylinder:
      cylinderCandidates(partID: part.id)
    case .sphere:
      sphereCandidates(partID: part.id)
    case .locator:
      [
        candidate(
          id: "origin",
          partID: part.id,
          name: "Component Origin",
          kind: .origin,
          origin: SIMD3<Double>(repeating: 0),
          primary: SIMD3<Double>(0, 0, 1),
          secondary: SIMD3<Double>(1, 0, 0)
        )
      ]
    }
  }

  private static func boxCandidates(partID: PartID) -> [MateConnectorCandidate] {
    let half = RigPrimitivePreviewGeometry.boxSizeMeters / 2
    var result = [
      candidate(
        id: "face-right", partID: partID, name: "Right Face Center", kind: .faceCenter,
        origin: SIMD3<Double>(half, 0, 0), primary: SIMD3<Double>(1, 0, 0),
        secondary: SIMD3<Double>(0, 0, 1)),
      candidate(
        id: "face-left", partID: partID, name: "Left Face Center", kind: .faceCenter,
        origin: SIMD3<Double>(-half, 0, 0), primary: SIMD3<Double>(-1, 0, 0),
        secondary: SIMD3<Double>(0, 0, 1)),
      candidate(
        id: "face-top", partID: partID, name: "Top Face Center", kind: .faceCenter,
        origin: SIMD3<Double>(0, half, 0), primary: SIMD3<Double>(0, 1, 0),
        secondary: SIMD3<Double>(1, 0, 0)),
      candidate(
        id: "face-bottom", partID: partID, name: "Bottom Face Center", kind: .faceCenter,
        origin: SIMD3<Double>(0, -half, 0), primary: SIMD3<Double>(0, -1, 0),
        secondary: SIMD3<Double>(1, 0, 0)),
      candidate(
        id: "face-front", partID: partID, name: "Front Face Center", kind: .faceCenter,
        origin: SIMD3<Double>(0, 0, half), primary: SIMD3<Double>(0, 0, 1),
        secondary: SIMD3<Double>(1, 0, 0)),
      candidate(
        id: "face-back", partID: partID, name: "Back Face Center", kind: .faceCenter,
        origin: SIMD3<Double>(0, 0, -half), primary: SIMD3<Double>(0, 0, -1),
        secondary: SIMD3<Double>(1, 0, 0)),
    ]

    let axes: [(String, Int, Int, Int)] = [
      ("x", 0, 1, 2), ("y", 1, 0, 2), ("z", 2, 0, 1),
    ]
    for (axisName, edgeAxis, sideAxisA, sideAxisB) in axes {
      for signA in [-1.0, 1.0] {
        for signB in [-1.0, 1.0] {
          var origin = SIMD3<Double>(repeating: 0)
          origin[sideAxisA] = signA * half
          origin[sideAxisB] = signB * half
          var primary = SIMD3<Double>(repeating: 0)
          primary[sideAxisA] = signA
          primary[sideAxisB] = signB
          var secondary = SIMD3<Double>(repeating: 0)
          secondary[edgeAxis] = 1
          let suffix = "\(signA > 0 ? "p" : "n")\(signB > 0 ? "p" : "n")"
          result.append(
            candidate(
              id: "edge-\(axisName)-\(suffix)",
              partID: partID,
              name: "\(axisName.uppercased()) Edge Midpoint",
              kind: .edgeMidpoint,
              origin: origin,
              primary: primary,
              secondary: secondary
            ))
        }
      }
    }

    for x in [-1.0, 1.0] {
      for y in [-1.0, 1.0] {
        for z in [-1.0, 1.0] {
          let suffix = "\(x > 0 ? "p" : "n")\(y > 0 ? "p" : "n")\(z > 0 ? "p" : "n")"
          result.append(
            candidate(
              id: "corner-\(suffix)",
              partID: partID,
              name: "Corner \(suffix.uppercased())",
              kind: .corner,
              origin: SIMD3<Double>(x * half, y * half, z * half),
              primary: SIMD3<Double>(x, y, z),
              secondary: SIMD3<Double>(1, 0, 0)
            ))
        }
      }
    }
    return result
  }

  private static func cylinderCandidates(partID: PartID) -> [MateConnectorCandidate] {
    let halfHeight = RigPrimitivePreviewGeometry.cylinderHeightMeters / 2
    return [
      candidate(
        id: "axis-center", partID: partID, name: "Cylinder Axis", kind: .axis,
        origin: SIMD3<Double>(0, 0, 0), primary: SIMD3<Double>(0, 1, 0),
        secondary: SIMD3<Double>(1, 0, 0)),
      candidate(
        id: "face-top", partID: partID, name: "Top Circular Center", kind: .faceCenter,
        origin: SIMD3<Double>(0, halfHeight, 0), primary: SIMD3<Double>(0, 1, 0),
        secondary: SIMD3<Double>(1, 0, 0)),
      candidate(
        id: "face-bottom", partID: partID, name: "Bottom Circular Center", kind: .faceCenter,
        origin: SIMD3<Double>(0, -halfHeight, 0), primary: SIMD3<Double>(0, -1, 0),
        secondary: SIMD3<Double>(1, 0, 0)),
    ]
  }

  private static func sphereCandidates(partID: PartID) -> [MateConnectorCandidate] {
    let radius = RigPrimitivePreviewGeometry.sphereRadiusMeters
    let directions: [(String, SIMD3<Double>, SIMD3<Double>)] = [
      ("right", SIMD3<Double>(1, 0, 0), SIMD3<Double>(0, 0, 1)),
      ("left", SIMD3<Double>(-1, 0, 0), SIMD3<Double>(0, 0, 1)),
      ("top", SIMD3<Double>(0, 1, 0), SIMD3<Double>(1, 0, 0)),
      ("bottom", SIMD3<Double>(0, -1, 0), SIMD3<Double>(1, 0, 0)),
      ("front", SIMD3<Double>(0, 0, 1), SIMD3<Double>(1, 0, 0)),
      ("back", SIMD3<Double>(0, 0, -1), SIMD3<Double>(1, 0, 0)),
    ]
    var result = [
      candidate(
        id: "origin",
        partID: partID,
        name: "Sphere Center",
        kind: .origin,
        origin: SIMD3<Double>(repeating: 0),
        primary: SIMD3<Double>(0, 0, 1),
        secondary: SIMD3<Double>(1, 0, 0)
      )
    ]
    result.append(
      contentsOf: directions.map { name, direction, secondary in
        candidate(
          id: "surface-\(name)",
          partID: partID,
          name: "\(name.capitalized) Surface Point",
          kind: .surfacePoint,
          origin: direction * radius,
          primary: direction,
          secondary: secondary
        )
      })
    return result
  }

  private static func candidate(
    id: String,
    partID: PartID,
    name: String,
    kind: MateConnectorFeatureKind,
    origin: SIMD3<Double>,
    primary: SIMD3<Double>,
    secondary: SIMD3<Double>
  ) -> MateConnectorCandidate {
    MateConnectorCandidate(
      id: id,
      partID: partID,
      displayName: name,
      featureKind: kind,
      connector: MateConnectorDefinition(
        originMeters: rigVector(origin),
        primaryAxis: rigVector(primary),
        secondaryAxis: rigVector(secondary)
      )
    )
  }

  private static func rigVector(_ value: SIMD3<Double>) -> RigVector3 {
    RigVector3(x: value.x, y: value.y, z: value.z)
  }
}
