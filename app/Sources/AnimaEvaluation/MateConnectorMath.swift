import AnimaModel
import Foundation
import simd

public struct RigPartTransform: Equatable, Sendable {
  public var positionMeters: RigVector3
  public var rotationEulerRadians: RigVector3

  public init(
    positionMeters: RigVector3,
    rotationEulerRadians: RigVector3
  ) {
    self.positionMeters = positionMeters
    self.rotationEulerRadians = rotationEulerRadians
  }
}

public enum MateConnectorMath {
  /// Returns the child transform that makes both connector frames coincident.
  /// The parent remains fixed, matching the first-selection-moves-to-second
  /// convention used by CAD assembly tools.
  public static func snappedChildTransform(
    childPart: RigPartDefinition,
    childConnector: MateConnectorDefinition,
    parentPart: RigPartDefinition,
    parentConnector: MateConnectorDefinition
  ) -> RigPartTransform {
    let targetMatrix =
      partMatrix(parentPart)
      * connectorMatrix(parentConnector)
      * opposingPrimaryAxisMatrix
    let childMatrix = targetMatrix * connectorMatrix(childConnector).inverse
    return transform(from: childMatrix)
  }

  public static func partMatrix(_ part: RigPartDefinition) -> simd_double4x4 {
    transformMatrix(
      position: vector(part.positionMeters),
      eulerRadians: vector(part.rotationEulerRadians)
    )
  }

  public static func connectorMatrix(
    _ connector: MateConnectorDefinition
  ) -> simd_double4x4 {
    let basis = orthonormalBasis(for: connector)
    return simd_double4x4(
      SIMD4<Double>(basis.x, 0),
      SIMD4<Double>(basis.y, 0),
      SIMD4<Double>(basis.z, 0),
      SIMD4<Double>(vector(connector.originMeters), 1)
    )
  }

  /// Default CAD mate alignment: connector origins coincide, secondary X axes
  /// agree, and the two outward-facing primary Z axes oppose one another.
  public static var opposingPrimaryAxisMatrix: simd_double4x4 {
    simd_double4x4(
      SIMD4<Double>(1, 0, 0, 0),
      SIMD4<Double>(0, -1, 0, 0),
      SIMD4<Double>(0, 0, -1, 0),
      SIMD4<Double>(0, 0, 0, 1)
    )
  }

  public static func transform(from matrix: simd_double4x4) -> RigPartTransform {
    let position = SIMD3<Double>(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
    let rotation = simd_double3x3(
      SIMD3<Double>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z),
      SIMD3<Double>(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z),
      SIMD3<Double>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
    )
    let euler = eulerZYX(from: rotation)
    return RigPartTransform(
      positionMeters: rigVector(position),
      rotationEulerRadians: rigVector(euler)
    )
  }

  public static func orthonormalBasis(
    for connector: MateConnectorDefinition
  ) -> (x: SIMD3<Double>, y: SIMD3<Double>, z: SIMD3<Double>) {
    let fallbackZ = SIMD3<Double>(0, 0, 1)
    let requestedZ = vector(connector.primaryAxis)
    let z = normalized(requestedZ, fallback: fallbackZ)

    let requestedX = vector(connector.secondaryAxis)
    let projectedX = requestedX - z * simd_dot(requestedX, z)
    let fallbackX = abs(z.x) < 0.9 ? SIMD3<Double>(1, 0, 0) : SIMD3<Double>(0, 1, 0)
    let fallbackProjectedX = fallbackX - z * simd_dot(fallbackX, z)
    let x = normalized(projectedX, fallback: fallbackProjectedX)
    let y = normalized(simd_cross(z, x), fallback: SIMD3<Double>(0, 1, 0))
    return (x, y, z)
  }

  private static func transformMatrix(
    position: SIMD3<Double>,
    eulerRadians: SIMD3<Double>
  ) -> simd_double4x4 {
    let x = simd_quatd(angle: eulerRadians.x, axis: SIMD3<Double>(1, 0, 0))
    let y = simd_quatd(angle: eulerRadians.y, axis: SIMD3<Double>(0, 1, 0))
    let z = simd_quatd(angle: eulerRadians.z, axis: SIMD3<Double>(0, 0, 1))
    var matrix = simd_double4x4(z * y * x)
    matrix.columns.3 = SIMD4<Double>(position, 1)
    return matrix
  }

  private static func eulerZYX(from matrix: simd_double3x3) -> SIMD3<Double> {
    let sineY = min(max(-matrix.columns.0.z, -1), 1)
    let y = asin(sineY)
    let cosineY = cos(y)
    if abs(cosineY) > 1e-8 {
      return SIMD3<Double>(
        atan2(matrix.columns.1.z, matrix.columns.2.z),
        y,
        atan2(matrix.columns.0.y, matrix.columns.0.x)
      )
    }
    return SIMD3<Double>(
      atan2(-matrix.columns.2.y, matrix.columns.1.y),
      y,
      0
    )
  }

  private static func normalized(
    _ vector: SIMD3<Double>,
    fallback: SIMD3<Double>
  ) -> SIMD3<Double> {
    let length = simd_length(vector)
    if length.isFinite, length > 1e-10 {
      return vector / length
    }
    let fallbackLength = simd_length(fallback)
    return fallbackLength > 1e-10 ? fallback / fallbackLength : SIMD3<Double>(1, 0, 0)
  }

  private static func vector(_ value: RigVector3) -> SIMD3<Double> {
    SIMD3<Double>(value.x, value.y, value.z)
  }

  private static func rigVector(_ value: SIMD3<Double>) -> RigVector3 {
    RigVector3(x: value.x, y: value.y, z: value.z)
  }
}
