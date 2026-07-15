import Foundation

public struct AnimationEvaluator: Sendable {
  public init() {}

  public func evaluate(
    clip: AnimationClip,
    rig: CharacterRig,
    atSeconds requestedTimeSeconds: Double
  ) -> EvaluatedFrame {
    let timeSeconds = min(max(requestedTimeSeconds, 0), clip.durationSeconds)
    let tracksByJoint = Dictionary(
      uniqueKeysWithValues: clip.jointTracks.map { ($0.jointID, $0) }
    )

    var values: [JointID: Double] = [:]
    values.reserveCapacity(rig.joints.count)

    for joint in rig.joints {
      guard let track = tracksByJoint[joint.id] else {
        values[joint.id] = joint.neutralRadians
        continue
      }

      values[joint.id] = joint.clamped(
        evaluate(track: track, atSeconds: timeSeconds) ?? joint.neutralRadians
      )
    }

    return EvaluatedFrame(
      timeSeconds: timeSeconds,
      jointAnglesRadians: values
    )
  }

  private func evaluate(
    track: JointTrack,
    atSeconds timeSeconds: Double
  ) -> Double? {
    guard let first = track.keyframes.first else { return nil }
    guard timeSeconds > first.timeSeconds else { return first.value }
    guard let last = track.keyframes.last, timeSeconds < last.timeSeconds else {
      return track.keyframes.last?.value
    }

    var lowerIndex = 0
    var upperIndex = track.keyframes.count - 1
    while upperIndex - lowerIndex > 1 {
      let middleIndex = (lowerIndex + upperIndex) / 2
      if track.keyframes[middleIndex].timeSeconds <= timeSeconds {
        lowerIndex = middleIndex
      } else {
        upperIndex = middleIndex
      }
    }

    let lower = track.keyframes[lowerIndex]
    let upper = track.keyframes[upperIndex]
    guard lower.interpolation == .linear else { return lower.value }

    let progress =
      (timeSeconds - lower.timeSeconds)
      / (upper.timeSeconds - lower.timeSeconds)
    return lower.value + ((upper.value - lower.value) * progress)
  }
}
