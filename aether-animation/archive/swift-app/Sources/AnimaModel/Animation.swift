import Foundation

public enum ScalarInterpolation: String, Codable, Sendable {
  case hold
  case linear
}

public struct ScalarKeyframe: Equatable, Codable, Sendable {
  public var timeSeconds: Double
  public var value: Double
  public var interpolation: ScalarInterpolation

  public init(
    timeSeconds: Double,
    value: Double,
    interpolation: ScalarInterpolation = .linear
  ) {
    precondition(timeSeconds >= 0)
    self.timeSeconds = timeSeconds
    self.value = value
    self.interpolation = interpolation
  }
}

public struct JointTrack: Equatable, Codable, Sendable {
  public var jointID: JointID
  public var keyframes: [ScalarKeyframe]

  public init(jointID: JointID, keyframes: [ScalarKeyframe]) {
    precondition(
      zip(keyframes, keyframes.dropFirst()).allSatisfy {
        $0.timeSeconds < $1.timeSeconds
      },
      "Keyframe times must be strictly increasing"
    )
    self.jointID = jointID
    self.keyframes = keyframes
  }
}

public struct AnimationClip: Equatable, Codable, Sendable {
  public var name: String
  public var durationSeconds: Double
  public var jointTracks: [JointTrack]

  public init(name: String, durationSeconds: Double, jointTracks: [JointTrack]) {
    precondition(durationSeconds >= 0)
    precondition(Set(jointTracks.map(\.jointID)).count == jointTracks.count)
    precondition(
      jointTracks.allSatisfy { ($0.keyframes.last?.timeSeconds ?? 0) <= durationSeconds }
    )

    self.name = name
    self.durationSeconds = durationSeconds
    self.jointTracks = jointTracks
  }
}
