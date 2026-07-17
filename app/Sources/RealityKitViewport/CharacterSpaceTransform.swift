import AnimaModel
import simd

/// Renderer conversion for AnimaCore's normative intrinsic XYZ convention.
/// The product is `qx * qy * qz`, matching `Rx · Ry · Rz` in
/// `Coordinate_Frames.md`; no world-space placement enters this helper.
public enum CharacterSpaceTransform {
  public static func orientation(
    rotationEulerRadians: RigVector3
  ) -> simd_quatf {
    let x = simd_quatf(
      angle: Float(rotationEulerRadians.x),
      axis: SIMD3<Float>(1, 0, 0)
    )
    let y = simd_quatf(
      angle: Float(rotationEulerRadians.y),
      axis: SIMD3<Float>(0, 1, 0)
    )
    let z = simd_quatf(
      angle: Float(rotationEulerRadians.z),
      axis: SIMD3<Float>(0, 0, 1)
    )
    return simd_normalize(x * y * z)
  }
}
