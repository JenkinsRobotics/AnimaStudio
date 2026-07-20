import Foundation
import simd

public struct CADCameraState: Sendable, Equatable {
  public var target = SIMD3<Float>(repeating: 0)
  public var distance: Float = 1.0
  public var yaw: Float = 0.65
  public var pitch: Float = -0.4
  public var rollRadians: Float = 0

  public init() {}

  public var position: SIMD3<Float> {
    let cosine = cos(pitch)
    return target + distance * SIMD3(cosine * sin(yaw), sin(pitch), cosine * cos(yaw))
  }

  /// Camera-up vector after applying roll about the current viewing axis.
  public var upVector: SIMD3<Float> {
    let forward = simd_normalize(target - position)
    var right = simd_cross(forward, SIMD3<Float>(0, 1, 0))
    if simd_length_squared(right) < 0.000_001 { right = SIMD3(1, 0, 0) }
    right = simd_normalize(right)
    let baseUp = simd_normalize(simd_cross(right, forward))
    return simd_quatf(angle: rollRadians, axis: forward).act(baseUp)
  }

  public mutating func orbit(deltaX: Float, deltaY: Float, sensitivity: Float = 0.006) {
    yaw -= deltaX * sensitivity
    pitch = max(-1.52, min(1.52, pitch + deltaY * sensitivity))
  }

  public mutating func pan(deltaX: Float, deltaY: Float, viewportHeight: Float) {
    let forward = simd_normalize(target - position)
    let right = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
    let up = simd_normalize(simd_cross(right, forward))
    let scale = max(distance, 0.001) / max(viewportHeight, 1) * 1.8
    let horizontal = right * (-deltaX * scale)
    let vertical = up * (deltaY * scale)
    target += horizontal + vertical
  }

  public mutating func zoom(scrollDelta: Float) {
    distance = max(0.002, min(10_000, distance * exp(scrollDelta * 0.0025)))
  }

  public mutating func roll(deltaX: Float, sensitivity: Float = 0.006) {
    rollRadians -= deltaX * sensitivity
    rollRadians.formTruncatingRemainder(dividingBy: 2 * .pi)
  }
}
