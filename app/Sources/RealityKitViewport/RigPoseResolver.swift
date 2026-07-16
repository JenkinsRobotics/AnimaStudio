import AnimaEvaluation
import AnimaModel
import simd

/// Resolves renderer transforms from the core rest pose and evaluated joint values.
/// Connector-authored mates compose recursively so downstream links follow their
/// animated parents. Legacy origin-axis joints retain their earlier behavior.
enum RigPoseResolver {
  static func matrices(
    rig: CharacterRig,
    frame: EvaluatedFrame
  ) -> [PartID: simd_float4x4] {
    let partsByID = Dictionary(uniqueKeysWithValues: rig.parts.map { ($0.id, $0) })
    var jointsByChild: [PartID: JointDefinition] = [:]
    for joint in rig.joints {
      guard let childPartID = joint.childPartID, jointsByChild[childPartID] == nil else {
        continue
      }
      jointsByChild[childPartID] = joint
    }
    var result: [PartID: simd_float4x4] = [:]
    var resolving: Set<PartID> = []

    func resolve(_ partID: PartID) -> simd_float4x4? {
      if let cached = result[partID] { return cached }
      guard let part = partsByID[partID], !resolving.contains(partID) else { return nil }
      resolving.insert(partID)
      defer { resolving.remove(partID) }

      let rest = floatMatrix(MateConnectorMath.partMatrix(part))
      guard let joint = jointsByChild[partID] else {
        result[partID] = rest
        return rest
      }

      let value = Float(frame.jointAnglesRadians[joint.id] ?? joint.neutralRadians)
      let resolved: simd_float4x4
      if let parentID = joint.parentPartID,
        let parentMatrix = resolve(parentID),
        let parentConnector = joint.parentConnector,
        let childConnector = joint.childConnector
      {
        let delta = value - Float(joint.neutralRadians)
        let motion = simd_float4x4(
          simd_quatf(angle: delta, axis: SIMD3<Float>(0, 0, 1))
        )
        resolved =
          parentMatrix
          * floatMatrix(MateConnectorMath.connectorMatrix(parentConnector))
          * motion
          * floatMatrix(MateConnectorMath.opposingPrimaryAxisMatrix)
          * floatMatrix(MateConnectorMath.connectorMatrix(childConnector)).inverse
      } else {
        let axis: SIMD3<Float> =
          switch joint.axis {
          case .x: SIMD3<Float>(1, 0, 0)
          case .y: SIMD3<Float>(0, 1, 0)
          case .z: SIMD3<Float>(0, 0, 1)
          }
        resolved = rest * simd_float4x4(simd_quatf(angle: value, axis: axis))
      }
      result[partID] = resolved
      return resolved
    }

    for part in rig.parts {
      _ = resolve(part.id)
    }
    return result
  }

  private static func floatMatrix(_ matrix: simd_double4x4) -> simd_float4x4 {
    simd_float4x4(
      SIMD4<Float>(matrix.columns.0),
      SIMD4<Float>(matrix.columns.1),
      SIMD4<Float>(matrix.columns.2),
      SIMD4<Float>(matrix.columns.3)
    )
  }
}
