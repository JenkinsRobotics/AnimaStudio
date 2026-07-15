import AnimaCore
import XCTest

@testable import AnimaStudioUI

@MainActor
final class AnimationWorkspaceTests: XCTestCase {
  private func sampleModel() -> StudioWorkspaceModel {
    StudioWorkspaceModel(
      project: AnimaProject(
        name: "Sample",
        rig: SampleContent.rig,
        clips: [SampleContent.clip]
      )
    )
  }

  func testTimecodeUsesConfigurableDisplayRate() {
    XCTAssertEqual(
      TimelineTimecode(timeSeconds: 2 + 29.0 / 30.0, framesPerSecond: 30).displayString,
      "00:02:29"
    )
    XCTAssertEqual(
      TimelineTimecode(timeSeconds: 3, framesPerSecond: 30).displayString,
      "00:03:00"
    )
    XCTAssertEqual(
      TimelineTimecode(timeSeconds: 65.5, framesPerSecond: 24).displayString,
      "01:05:12"
    )
  }

  func testFrameSteppingUsesDisplayRateAndClampsToClip() {
    let model = sampleModel()
    model.timelineDisplayFramesPerSecond = 25

    model.stepTimeline(byFrames: 1)
    XCTAssertEqual(model.playheadSeconds, 0.04, accuracy: 0.000_001)

    model.seekTimeline(to: model.activeClip.durationSeconds)
    model.stepTimeline(byFrames: 1)
    XCTAssertEqual(model.playheadSeconds, model.activeClip.durationSeconds)
  }

  func testAdjacentKeyframeNavigation() {
    let model = sampleModel()
    model.seekTimeline(to: 1.25)

    model.seekAdjacentKeyframe(forward: true)
    XCTAssertEqual(model.playheadSeconds, 2)

    model.seekAdjacentKeyframe(forward: false)
    XCTAssertEqual(model.playheadSeconds, 1)
  }

  func testNonLoopingPlaybackStopsAtEnd() {
    let model = sampleModel()
    model.loopsPreviewPlayback = false
    model.seekTimeline(to: model.activeClip.durationSeconds - 0.01)
    model.isPlaying = true

    model.advancePlayback(by: 0.02)

    XCTAssertEqual(model.playheadSeconds, model.activeClip.durationSeconds)
    XCTAssertFalse(model.isPlaying)
  }

  func testLoopingPlaybackWrapsOvershoot() {
    let model = sampleModel()
    model.loopsPreviewPlayback = true
    model.seekTimeline(to: model.activeClip.durationSeconds - 0.01)
    model.isPlaying = true

    model.advancePlayback(by: 0.03)

    XCTAssertEqual(model.playheadSeconds, 0.02, accuracy: 0.000_001)
    XCTAssertTrue(model.isPlaying)
  }
}
