import Foundation
import RealityKit
import simd

/// Renderer-ready character-space transform projected from AnimaCore
/// `resolve_pose`. The scene places it beneath the character root; a future
/// Character-in-World transform belongs above that root.
///
/// This type deliberately contains no mate or hierarchy semantics. It validates
/// the bridge's array shape and converts the engine's quaternion convention
/// (imaginary XYZ, then real W) into RealityKit's native representation.
public struct EngineResolvedPartPose: Equatable, Sendable {
  public let positionMeters: SIMD3<Float>
  public let orientationImaginaryReal: SIMD4<Float>

  public init?(
    positionMeters: [Double],
    orientationImaginaryReal: [Double]
  ) {
    guard positionMeters.count == 3,
      orientationImaginaryReal.count == 4,
      positionMeters.allSatisfy(\.isFinite),
      orientationImaginaryReal.allSatisfy(\.isFinite)
    else { return nil }

    let orientation = SIMD4<Float>(
      Float(orientationImaginaryReal[0]),
      Float(orientationImaginaryReal[1]),
      Float(orientationImaginaryReal[2]),
      Float(orientationImaginaryReal[3])
    )
    guard simd_length(orientation) > 0 else { return nil }

    self.positionMeters = SIMD3<Float>(
      Float(positionMeters[0]),
      Float(positionMeters[1]),
      Float(positionMeters[2])
    )
    self.orientationImaginaryReal = orientation
  }

  var realityKitTransform: Transform {
    Transform(
      scale: .one,
      rotation: simd_normalize(
        simd_quatf(
          ix: orientationImaginaryReal.x,
          iy: orientationImaginaryReal.y,
          iz: orientationImaginaryReal.z,
          r: orientationImaginaryReal.w
        )
      ),
      translation: positionMeters
    )
  }
}
