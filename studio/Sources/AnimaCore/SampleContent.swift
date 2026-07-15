import Foundation

public enum SampleContent {
  public static let headYawID: JointID = "head_yaw"

  public static let rig = CharacterRig(
    joints: [
      JointDefinition(
        id: headYawID,
        displayName: "Head Yaw",
        axis: .y,
        minimumRadians: -.pi / 3,
        maximumRadians: .pi / 3
      )
    ]
  )

  public static let clip = AnimationClip(
    name: "Look Around",
    durationSeconds: 4,
    jointTracks: [
      JointTrack(
        jointID: headYawID,
        keyframes: [
          ScalarKeyframe(timeSeconds: 0, value: 0),
          ScalarKeyframe(timeSeconds: 1, value: -.pi / 4),
          ScalarKeyframe(timeSeconds: 2, value: 0),
          ScalarKeyframe(timeSeconds: 3, value: .pi / 4),
          ScalarKeyframe(timeSeconds: 4, value: 0),
        ]
      )
    ]
  )

  public static let emptyClip = AnimationClip(
    name: "Main",
    durationSeconds: 5,
    jointTracks: []
  )
}
