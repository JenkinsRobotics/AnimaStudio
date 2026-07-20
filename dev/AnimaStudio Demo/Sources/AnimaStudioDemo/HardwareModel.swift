// Hardware binding — one servo channel per driven mate. Live positions come
// from the evaluated rig (so animation playback drives the servo readouts).
// Mapping math is pure so it can be self-tested.
import Foundation
import SwiftUI

struct ServoChannel: Identifiable, Equatable, Codable {
  var id = UUID()
  var mateID: UUID
  var channel: Int
  var name: String
  var trimDegrees: Double = 0
  var inverted = false
  var minPulse: Double = 500      // µs
  var maxPulse: Double = 2500     // µs
}

@MainActor @Observable final class HardwareModel {
  static let shared = HardwareModel()

  var channels: [ServoChannel] = []
  var armed = false
  var selectedChannelID: UUID?
  var controllerSelected = true
  var controllerName = "PCA9685"
  // Hardware workspace sidebar. Model-owned, not @State, so it survives the
  // float/dock flip that rebuilds the workspace view.
  let hardwarePanels = PanelStackState(
    order: ["Controller", "Channels"],
    defaults: ["Controller"], side: .left)

  var selectedChannel: ServoChannel? { channels.first { $0.id == selectedChannelID } }

  /// Keeps one channel per driven mate — adds new ones, drops removed mates.
  func sync() {
    let mates = RigModel.shared.mates
    channels.removeAll { channel in !mates.contains { $0.id == channel.mateID } }
    for mate in mates where mate.type.isDriven {
      guard !channels.contains(where: { $0.mateID == mate.id }) else { continue }
      channels.append(ServoChannel(mateID: mate.id, channel: nextFreeChannel(), name: mate.name))
    }
    // Keep display names in step with the rig.
    for index in channels.indices {
      if let mate = mates.first(where: { $0.id == channels[index].mateID }) {
        channels[index].name = mate.name
      }
    }
    if selectedChannelID == nil { selectedChannelID = channels.first?.id }
  }

  private func nextFreeChannel() -> Int {
    let used = Set(channels.map(\.channel))
    var candidate = 0
    while used.contains(candidate) { candidate += 1 }
    return candidate
  }

  func mate(for channel: ServoChannel) -> Mate? {
    RigModel.shared.mates.first { $0.id == channel.mateID }
  }

  // MARK: - Pure mapping

  /// Commanded angle: the mate value with trim applied, optionally inverted.
  static func commandedDegrees(mateValue: Double, trim: Double, inverted: Bool) -> Double {
    (inverted ? -mateValue : mateValue) + trim
  }

  /// Position within the mate's limits, 0...1 (what the position bar draws).
  static func fraction(value: Double, min lo: Double, max hi: Double) -> Double {
    let span = hi - lo
    guard span > 0 else { return 0 }
    return Swift.min(Swift.max((value - lo) / span, 0), 1)
  }

  /// Servo pulse width for a 0...1 position.
  static func pulse(fraction: Double, minPulse: Double, maxPulse: Double) -> Double {
    minPulse + (maxPulse - minPulse) * Swift.min(Swift.max(fraction, 0), 1)
  }

  // MARK: - Live values

  func degrees(_ channel: ServoChannel) -> Double {
    guard let mate = mate(for: channel) else { return 0 }
    return Self.commandedDegrees(
      mateValue: mate.value, trim: channel.trimDegrees, inverted: channel.inverted)
  }

  func fraction(_ channel: ServoChannel) -> Double {
    guard let mate = mate(for: channel) else { return 0 }
    return Self.fraction(value: degrees(channel), min: mate.minValue, max: mate.maxValue)
  }

  func pulse(_ channel: ServoChannel) -> Double {
    Self.pulse(fraction: fraction(channel), minPulse: channel.minPulse, maxPulse: channel.maxPulse)
  }

  /// Drive a channel directly (manual jog) — writes back into the mate.
  func setDegrees(_ channel: ServoChannel, to value: Double) {
    guard let index = RigModel.shared.mates.firstIndex(where: { $0.id == channel.mateID })
    else { return }
    let raw = value - channel.trimDegrees
    RigModel.shared.mates[index].value = channel.inverted ? -raw : raw
  }
}
