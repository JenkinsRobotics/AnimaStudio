import AppKit
import SwiftUI

enum UIDevDetachedWindowDescriptor {
  static let title = "Detached Window"
  static let systemImage = "macwindow.badge.plus"
  static let contentSize = NSSize(width: 360, height: 420)
  static let minimumSize = NSSize(width: 320, height: 320)
  static let autosaveName = "AnimaUIDevDetachedWindow"
}

/// The one intentionally detached UI Dev surface.
///
/// Navigator, Inspector, Timeline, 3D View, and Agent are embedded in the main
/// app so UI review happens in the same layout operators use.
@MainActor
enum UIDevDetachedWindowRegistry {
  private static var window: NSPanel?

  static func show() {
    let panel = window ?? makeWindow()
    window = panel
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate()
  }

  static func existingWindow() -> NSPanel? {
    window
  }

  static func hide() {
    window?.orderOut(nil)
  }

  private static func makeWindow() -> NSPanel {
    StudioWindowFactory.utilityPanel(
      title: UIDevDetachedWindowDescriptor.title,
      autosaveName: UIDevDetachedWindowDescriptor.autosaveName,
      contentSize: UIDevDetachedWindowDescriptor.contentSize,
      minimumSize: UIDevDetachedWindowDescriptor.minimumSize
    ) {
      UIDevFloatingPanelTemplateView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StudioPalette.canvas)
        .preferredColorScheme(.dark)
    }
  }
}
