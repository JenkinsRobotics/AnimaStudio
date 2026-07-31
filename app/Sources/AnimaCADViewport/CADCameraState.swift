import AnimaCAD
import Foundation
import Observation
import simd

/// Renderer-neutral snapshot of the CAD camera's orientation relative to the
/// fixed world axes. `direction` points from the target toward the camera.
public struct CADCameraOrientationPresentation: Equatable, Sendable {
  public let direction: SIMD3<Float>
  public let rollRadians: Float

  public init(direction: SIMD3<Float>, rollRadians: Float) {
    let length = simd_length(direction)
    self.direction =
      length.isFinite && length > 0.0001
      ? direction / length
      : SIMD3<Float>(0, 0, 1)
    self.rollRadians = rollRadians.isFinite ? rollRadians : 0
  }
}

@Observable
@MainActor
public final class CADCameraState {
  public var yaw: Float = 0.65
  public var pitch: Float = -0.45
  public var rollRadians: Float = 0
  public var distance: Float = 2.4
  public var target = SIMD3<Float>.zero

  public init() {}

  public var position: SIMD3<Float> {
    target
      + SIMD3(
        distance * cos(pitch) * sin(yaw),
        distance * sin(-pitch),
        distance * cos(pitch) * cos(yaw))
  }

  public var upVector: SIMD3<Float> {
    let forward = simd_normalize(target - position)
    let baseRight = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
    let baseUp = simd_normalize(simd_cross(baseRight, forward))
    return simd_normalize(
      baseUp * cos(rollRadians) + baseRight * sin(rollRadians))
  }

  public var orientationPresentation: CADCameraOrientationPresentation {
    CADCameraOrientationPresentation(
      direction: position - target,
      rollRadians: rollRadians
    )
  }

  public func set(orientation: CADCameraOrientationPresentation) {
    let direction = orientation.direction
    pitch = -asin(max(-1, min(1, direction.y)))
    yaw = atan2(direction.x, direction.z)
    rollRadians = orientation.rollRadians
  }

  public func orbit(deltaX: Float, deltaY: Float) {
    yaw -= deltaX * 0.006
    pitch = min(max(pitch - deltaY * 0.006, -1.52), 1.52)
  }

  public func pan(deltaX: Float, deltaY: Float, viewportHeight: Float) {
    let forward = simd_normalize(target - position)
    let right = simd_normalize(simd_cross(forward, upVector))
    let scale = distance / max(viewportHeight, 1) * 1.6
    target += (-right * deltaX + upVector * deltaY) * scale
  }

  public func roll(deltaX: Float) { rollRadians -= deltaX * 0.006 }

  public func zoom(scrollDelta: Float) {
    distance = min(max(distance * exp(scrollDelta * 0.0015), 0.002), 100_000)
  }

  public func frame(bounds: CADRenderBounds) {
    target = bounds.center
    distance = max(bounds.diagonal * 1.35, 0.05)
  }
}
