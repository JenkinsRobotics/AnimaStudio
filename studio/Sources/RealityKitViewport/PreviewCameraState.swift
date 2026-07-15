import Foundation
import simd

public enum PreviewCameraProjection: String, CaseIterable, Identifiable, Sendable {
  case perspective
  case orthographic

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .perspective: "Perspective"
    case .orthographic: "Orthographic"
    }
  }
}

public enum PreviewCameraViewpoint: String, Sendable {
  case home
  case front
  case right
  case top
  case selection
  case custom
}

public struct PreviewCameraDirection: Equatable, Sendable {
  public let x: Float
  public let y: Float
  public let z: Float

  public init(x: Float, y: Float, z: Float) {
    let candidate = SIMD3<Float>(x, y, z)
    let length = simd_length(candidate)
    let normalized =
      length.isFinite && length > 0.0001
      ? candidate / length
      : SIMD3<Float>(0, 0, 1)
    self.x = normalized.x
    self.y = normalized.y
    self.z = normalized.z
  }

  public static let home = PreviewCameraDirection(x: 0.62, y: 0.22, z: 0.78)
  public static let front = PreviewCameraDirection(x: 0, y: 0, z: 1)
  public static let back = PreviewCameraDirection(x: 0, y: 0, z: -1)
  public static let right = PreviewCameraDirection(x: 1, y: 0, z: 0)
  public static let left = PreviewCameraDirection(x: -1, y: 0, z: 0)
  public static let top = PreviewCameraDirection(x: 0, y: 1, z: 0)
  public static let bottom = PreviewCameraDirection(x: 0, y: -1, z: 0)

  public var vector: SIMD3<Float> {
    SIMD3<Float>(x, y, z)
  }

  public var markerID: String {
    [x, y, z]
      .map { String(format: "%.4f", $0) }
      .joined(separator: ",")
  }

  public func nudged(horizontalRadians: Float, verticalRadians: Float) -> Self {
    var direction = rotate(vector, around: SIMD3<Float>(0, 1, 0), by: horizontalRadians)
    var right = simd_cross(SIMD3<Float>(0, 1, 0), direction)
    if simd_length_squared(right) < 0.0001 {
      right = SIMD3<Float>(1, 0, 0)
    } else {
      right = simd_normalize(right)
    }
    direction = rotate(direction, around: right, by: -verticalRadians)
    return PreviewCameraDirection(x: direction.x, y: direction.y, z: direction.z)
  }

  private func rotate(
    _ value: SIMD3<Float>,
    around axis: SIMD3<Float>,
    by angle: Float
  ) -> SIMD3<Float> {
    simd_quatf(angle: angle, axis: simd_normalize(axis)).act(value)
  }
}

public struct PreviewCameraOrientation: Equatable, Sendable {
  public var direction: PreviewCameraDirection

  public init(direction: PreviewCameraDirection = .home) {
    self.direction = direction
  }
}

public struct PreviewCameraPoint: Equatable, Sendable {
  public var x: Float
  public var y: Float
  public var z: Float

  public init(x: Float, y: Float, z: Float) {
    self.x = x
    self.y = y
    self.z = z
  }

  public var vector: SIMD3<Float> {
    SIMD3<Float>(x, y, z)
  }
}

public struct PreviewCameraState: Equatable, Sendable {
  public var orientation: PreviewCameraOrientation
  public var target: PreviewCameraPoint
  public var distance: Float
  public var orthographicScale: Float

  public init(
    orientation: PreviewCameraOrientation = PreviewCameraOrientation(),
    target: PreviewCameraPoint = PreviewCameraPoint(x: 0, y: 0.8, z: 0),
    distance: Float = 4.5,
    orthographicScale: Float = 2.8
  ) {
    self.orientation = orientation
    self.target = target
    self.distance = max(distance, 0.001)
    self.orthographicScale = max(orthographicScale, 0.001)
  }
}
