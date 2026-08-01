import Foundation

enum TimelineEditorMode: String, CaseIterable, Sendable {
  case dopeSheet
  case graph

  var title: String {
    switch self {
    case .dopeSheet: "Dope Sheet"
    case .graph: "Graph"
    }
  }

  var systemImage: String {
    switch self {
    case .dopeSheet: "diamond.fill"
    case .graph: "point.3.filled.connected.trianglepath.dotted"
    }
  }
}

struct TimelineTimecode: Equatable, Sendable {
  let minutes: Int
  let seconds: Int
  let frames: Int
  let framesPerSecond: Int

  init(timeSeconds: Double, framesPerSecond: Int) {
    let safeFramesPerSecond = max(framesPerSecond, 1)
    let totalFrames = Int(floor(max(timeSeconds, 0) * Double(safeFramesPerSecond) + 1e-9))
    let totalSeconds = totalFrames / safeFramesPerSecond

    minutes = totalSeconds / 60
    seconds = totalSeconds % 60
    frames = totalFrames % safeFramesPerSecond
    self.framesPerSecond = safeFramesPerSecond
  }

  var displayString: String {
    String(format: "%02d:%02d:%02d", minutes, seconds, frames)
  }
}
