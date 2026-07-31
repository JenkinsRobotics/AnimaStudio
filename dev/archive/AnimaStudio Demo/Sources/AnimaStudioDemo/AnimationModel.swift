// Real animation: clips hold tracks bound to authored mates, tracks hold
// keyframes, and playback evaluates them into live mate values (which the
// viewport poses). Evaluation is pure so it can be self-tested.
import Foundation
import SwiftUI

struct Keyframe: Identifiable, Equatable, Codable {
  var id = UUID()
  var time: Double     // seconds
  var value: Double
}

struct Track: Identifiable, Equatable, Codable {
  var id = UUID()
  var mateID: UUID
  var keys: [Keyframe] = []
}

struct Clip: Identifiable, Equatable, Codable {
  var id = UUID()
  var name: String
  var duration: Double = 8
  var tracks: [Track] = []
}

@MainActor @Observable final class AnimationModel {
  static let shared = AnimationModel()

  var clips: [Clip] = [Clip(name: "Greeting", duration: 8)]
  var selectedClipID: UUID?
  var time: Double = 0
  var isPlaying = false
  var loops = true
  // Animate workspace sidebar. Model-owned, not @State, so it survives the
  // float/dock flip that rebuilds the workspace view.
  let animatePanels = PanelStackState(
    order: ["Clips", "Channels"],
    defaults: [], side: .left)

  @ObservationIgnored private var timer: Timer?

  var clipIndex: Int? {
    if let id = selectedClipID, let i = clips.firstIndex(where: { $0.id == id }) { return i }
    return clips.isEmpty ? nil : 0
  }
  var clip: Clip? { clipIndex.map { clips[$0] } }
  var duration: Double { max(clip?.duration ?? 8, 0.1) }
  /// Playhead as a 0...1 fraction (what the timeline draws).
  var progress: Double { min(max(time / duration, 0), 1) }

  // MARK: - Pure evaluation

  /// Linear interpolation between surrounding keys; clamps outside the range.
  static func value(_ keys: [Keyframe], at t: Double) -> Double? {
    guard !keys.isEmpty else { return nil }
    let sorted = keys.sorted { $0.time < $1.time }
    guard let first = sorted.first, let last = sorted.last else { return nil }
    if t <= first.time { return first.value }
    if t >= last.time { return last.value }
    for i in 0..<(sorted.count - 1) {
      let a = sorted[i], b = sorted[i + 1]
      if t >= a.time, t <= b.time {
        let span = b.time - a.time
        guard span > 0 else { return b.value }
        return a.value + (b.value - a.value) * ((t - a.time) / span)
      }
    }
    return last.value
  }

  // MARK: - Playback

  func togglePlay() { isPlaying ? pause() : play() }

  func play() {
    guard !isPlaying else { return }
    isPlaying = true
    timer?.invalidate()
    let step = 1.0 / 60.0
    timer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.advance(by: step) }
    }
  }

  func pause() {
    isPlaying = false
    timer?.invalidate()
    timer = nil
  }

  func advance(by delta: Double) {
    var next = time + delta
    if next >= duration {
      if loops { next = next.truncatingRemainder(dividingBy: duration) } else { next = duration; pause() }
    }
    time = next
    apply()
  }

  func scrub(toProgress fraction: Double) {
    time = min(max(fraction, 0), 1) * duration
    apply()
  }

  /// Push evaluated track values into the rig so the viewport re-poses.
  func apply() {
    guard let clip else { return }
    let rig = RigModel.shared
    for track in clip.tracks {
      guard let value = Self.value(track.keys, at: time),
        let index = rig.mates.firstIndex(where: { $0.id == track.mateID })
      else { continue }
      rig.mates[index].value = value
    }
  }

  // MARK: - Authoring

  /// Records the mate's current value as a key at the playhead.
  @discardableResult
  func addKey(for mateID: UUID, value: Double) -> Bool {
    guard let index = clipIndex else { return false }
    var clip = clips[index]
    let trackIndex: Int
    if let existing = clip.tracks.firstIndex(where: { $0.mateID == mateID }) {
      trackIndex = existing
    } else {
      clip.tracks.append(Track(mateID: mateID))
      trackIndex = clip.tracks.count - 1
    }
    // Replace a key at (nearly) the same time rather than stacking duplicates.
    if let hit = clip.tracks[trackIndex].keys.firstIndex(where: { abs($0.time - time) < 0.01 }) {
      clip.tracks[trackIndex].keys[hit].value = value
    } else {
      clip.tracks[trackIndex].keys.append(Keyframe(time: time, value: value))
    }
    clips[index] = clip
    return true
  }

  func addClip() {
    let clip = Clip(name: "Clip \(clips.count + 1)")
    clips.append(clip)
    selectedClipID = clip.id
  }

  func removeTrack(mateID: UUID) {
    guard let index = clipIndex else { return }
    clips[index].tracks.removeAll { $0.mateID == mateID }
  }

  /// Timeline rows for the current clip — one per authored mate, so an unkeyed
  /// mate still shows an (empty) track you can key onto.
  var timelineTracks: [TimelineTrack] {
    let rig = RigModel.shared
    let clip = self.clip
    return rig.mates.map { mate in
      let keys = clip?.tracks.first { $0.mateID == mate.id }?.keys ?? []
      return TimelineTrack(
        mateID: mate.id,
        name: mate.name,
        color: mate.type.isDriven ? UI.accent : UI.text3,
        keys: keys.map { CGFloat(min(max($0.time / duration, 0), 1)) })
    }
  }
}

struct TimelineTrack: Identifiable {
  var id: UUID { mateID }
  let mateID: UUID
  let name: String
  let color: Color
  let keys: [CGFloat]      // normalized 0...1 positions
}
