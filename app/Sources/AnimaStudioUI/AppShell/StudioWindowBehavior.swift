import AppKit
import SwiftUI

enum StudioWindowDoubleClickAction: Equatable, Sendable {
  case zoom
  case minimize
  case none

  static func resolve(preference: String?) -> Self {
    switch preference?.lowercased() {
    case "minimize": .minimize
    case "none": .none
    default: .zoom
    }
  }
}

/// Restores native title-bar interaction to empty regions of Studio's custom
/// header while leaving its SwiftUI controls in front and fully interactive.
struct StudioWindowControlArea: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    StudioWindowControlView()
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class StudioWindowControlView: NSView {
  override func mouseDown(with event: NSEvent) {
    guard let window else {
      super.mouseDown(with: event)
      return
    }

    guard event.clickCount == 2 else {
      window.performDrag(with: event)
      return
    }

    switch StudioWindowDoubleClickAction.resolve(
      preference: UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick")
    ) {
    case .zoom:
      window.zoom(nil)
    case .minimize:
      window.miniaturize(nil)
    case .none:
      break
    }
  }
}
