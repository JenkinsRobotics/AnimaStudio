import AnimaModel
import XCTest

@testable import AnimaEvaluation

final class AnimationEvaluatorTests: XCTestCase {
  private let evaluator = AnimationEvaluator()

  func testLinearInterpolationAtMidpoint() {
    let frame = evaluator.evaluate(
      clip: SampleContent.clip,
      rig: SampleContent.rig,
      atSeconds: 0.5
    )

    XCTAssertEqual(frame.timeSeconds, 0.5)
    XCTAssertEqual(
      frame.jointAnglesRadians[SampleContent.headYawID]!,
      -.pi / 8,
      accuracy: 0.000_001
    )
  }

  func testRequestedTimeIsClampedToClipDuration() {
    let frame = evaluator.evaluate(
      clip: SampleContent.clip,
      rig: SampleContent.rig,
      atSeconds: 99
    )

    XCTAssertEqual(frame.timeSeconds, SampleContent.clip.durationSeconds)
    XCTAssertEqual(frame.jointAnglesRadians[SampleContent.headYawID], 0)
  }

  func testTrackValueIsClampedToJointLimits() {
    let jointID: JointID = "limited"
    let rig = CharacterRig(
      joints: [
        JointDefinition(
          id: jointID,
          displayName: "Limited",
          axis: .x,
          minimumRadians: -0.5,
          maximumRadians: 0.5
        )
      ]
    )
    let clip = AnimationClip(
      name: "Over Limit",
      durationSeconds: 1,
      jointTracks: [
        JointTrack(
          jointID: jointID,
          keyframes: [ScalarKeyframe(timeSeconds: 0, value: 2)]
        )
      ]
    )

    let frame = evaluator.evaluate(clip: clip, rig: rig, atSeconds: 0)

    XCTAssertEqual(frame.jointAnglesRadians[jointID], 0.5)
  }

  func testUntrackedJointUsesNeutralValue() {
    let jointID: JointID = "idle"
    let rig = CharacterRig(
      joints: [
        JointDefinition(
          id: jointID,
          displayName: "Idle",
          axis: .z,
          minimumRadians: -1,
          maximumRadians: 1,
          neutralRadians: 0.25
        )
      ]
    )
    let clip = AnimationClip(name: "Empty", durationSeconds: 1, jointTracks: [])

    let frame = evaluator.evaluate(clip: clip, rig: rig, atSeconds: 0.5)

    XCTAssertEqual(frame.jointAnglesRadians[jointID], 0.25)
  }

  func testProjectRoundTripsThroughJSON() throws {
    let asset = ProjectAsset(
      name: "robot.usdz",
      kind: .model3D,
      sourcePath: "Assets/robot.usdz"
    )
    let project = AnimaProject(
      name: "Robot",
      assets: [asset],
      rig: SampleContent.rig,
      clips: [SampleContent.clip]
    )

    let data = try JSONEncoder().encode(project)
    let decoded = try JSONDecoder().decode(AnimaProject.self, from: data)

    XCTAssertEqual(decoded, project)
  }
}
