import Foundation
import SwiftUI

enum UIDevTimelineBVariant: String, CaseIterable, Identifiable, Sendable {
  case dopeSheet
  case motionCurves
  case waypointLanes

  var id: Self { self }

  var title: String {
    switch self {
    case .dopeSheet: "Dopesheet"
    case .motionCurves: "Motion Curves"
    case .waypointLanes: "Waypoint Lanes"
    }
  }

  var detail: String {
    switch self {
    case .dopeSheet: "Compact timing and key density across many channels."
    case .motionCurves: "Value-aware curves make acceleration and direction visible."
    case .waypointLanes: "Readable motion paths for show operators and animatronics."
    }
  }

  var systemImage: String {
    switch self {
    case .dopeSheet: "diamond.fill"
    case .motionCurves: "waveform.path.ecg"
    case .waypointLanes: "point.topleft.down.to.point.bottomright.curvepath"
    }
  }

  var rowHeight: CGFloat {
    switch self {
    case .dopeSheet: 46
    case .motionCurves: 76
    case .waypointLanes: 60
    }
  }
}

struct UIDevTimelineBKeyframe: Identifiable, Equatable, Sendable {
  let id: UUID
  var time: Double
  var value: Double

  init(id: UUID = UUID(), time: Double, value: Double) {
    self.id = id
    self.time = time
    self.value = value
  }
}

struct UIDevTimelineBTrack: Identifiable, Equatable, Sendable {
  let id: UUID
  var name: String
  var colorIndex: Int
  var keyframes: [UIDevTimelineBKeyframe]

  init(
    id: UUID = UUID(),
    name: String,
    colorIndex: Int,
    keyframes: [UIDevTimelineBKeyframe] = []
  ) {
    self.id = id
    self.name = name
    self.colorIndex = colorIndex
    self.keyframes = keyframes.sorted { $0.time < $1.time }
  }

  mutating func insertKeyframe(time: Double, value: Double, duration: Double) -> UUID {
    let keyframe = UIDevTimelineBKeyframe(
      time: min(max(time, 0), duration),
      value: min(max(value, 0), 1)
    )
    keyframes.append(keyframe)
    keyframes.sort { $0.time < $1.time }
    return keyframe.id
  }
}

enum UIDevTimelineBGeometry {
  static func normalizedPoint(
    for keyframe: UIDevTimelineBKeyframe,
    variant: UIDevTimelineBVariant,
    duration: Double
  ) -> CGPoint {
    let x = min(max(keyframe.time / max(duration, 0.001), 0), 1)
    let y: Double
    switch variant {
    case .dopeSheet:
      y = 0.5
    case .motionCurves:
      y = 0.12 + (1 - keyframe.value) * 0.76
    case .waypointLanes:
      y = 0.24 + (1 - keyframe.value) * 0.52
    }
    return CGPoint(x: x, y: y)
  }

  static func value(atNormalizedY y: Double, variant: UIDevTimelineBVariant) -> Double {
    switch variant {
    case .dopeSheet:
      0.5
    case .motionCurves:
      min(max(1 - ((y - 0.12) / 0.76), 0), 1)
    case .waypointLanes:
      min(max(1 - ((y - 0.24) / 0.52), 0), 1)
    }
  }
}

enum UIDevTimelineBSamples {
  static let duration = 8.0

  static let tracks = [
    UIDevTimelineBTrack(
      name: "Head Yaw",
      colorIndex: 0,
      keyframes: [
        .init(time: 0.0, value: 0.50), .init(time: 1.4, value: 0.78),
        .init(time: 3.1, value: 0.28), .init(time: 5.2, value: 0.72),
        .init(time: 7.4, value: 0.50),
      ]
    ),
    UIDevTimelineBTrack(
      name: "Head Pitch",
      colorIndex: 1,
      keyframes: [
        .init(time: 0.0, value: 0.48), .init(time: 2.0, value: 0.66),
        .init(time: 4.0, value: 0.38), .init(time: 6.6, value: 0.55),
      ]
    ),
    UIDevTimelineBTrack(
      name: "Left Eyelid",
      colorIndex: 2,
      keyframes: [
        .init(time: 0.0, value: 0.0), .init(time: 2.6, value: 0.0),
        .init(time: 2.8, value: 1.0), .init(time: 3.0, value: 0.0),
        .init(time: 6.0, value: 0.0), .init(time: 6.2, value: 1.0),
        .init(time: 6.4, value: 0.0),
      ]
    ),
    UIDevTimelineBTrack(
      name: "Jaw",
      colorIndex: 3,
      keyframes: [
        .init(time: 0.0, value: 0.10), .init(time: 1.1, value: 0.62),
        .init(time: 2.3, value: 0.22), .init(time: 4.8, value: 0.76),
        .init(time: 7.6, value: 0.10),
      ]
    ),
  ]
}
