import AppKit
import SwiftUI

/// One construction path for Studio-owned auxiliary windows.
@MainActor
enum StudioWindowFactory {
  static func utilityPanel<Content: View>(
    title: String,
    autosaveName: String,
    contentSize: NSSize,
    minimumSize: NSSize,
    @ViewBuilder content: () -> Content
  ) -> NSPanel {
    let panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: contentSize),
      styleMask: [.titled, .closable, .resizable, .utilityWindow],
      backing: .buffered,
      defer: false
    )
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.fullScreenAuxiliary]
    configure(
      panel,
      title: title,
      autosaveName: autosaveName,
      contentSize: contentSize,
      minimumSize: minimumSize,
      content: content
    )
    return panel
  }

  static func workspaceWindow<Content: View>(
    title: String,
    autosaveName: String,
    contentSize: NSSize,
    minimumSize: NSSize,
    @ViewBuilder content: () -> Content
  ) -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: contentSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    configure(
      window,
      title: title,
      autosaveName: autosaveName,
      contentSize: contentSize,
      minimumSize: minimumSize,
      content: content
    )
    return window
  }

  private static func configure<Content: View>(
    _ window: NSWindow,
    title: String,
    autosaveName: String,
    contentSize: NSSize,
    minimumSize: NSSize,
    @ViewBuilder content: () -> Content
  ) {
    window.title = title
    window.isReleasedWhenClosed = false
    window.contentViewController = NSHostingController(rootView: content())
    if !window.setFrameUsingName(autosaveName) {
      window.setContentSize(contentSize)
      window.center()
    }
    window.contentMinSize = minimumSize
    if window.contentLayoutRect.width < minimumSize.width
      || window.contentLayoutRect.height < minimumSize.height
    {
      window.setContentSize(
        NSSize(
          width: max(window.contentLayoutRect.width, minimumSize.width),
          height: max(window.contentLayoutRect.height, minimumSize.height)
        )
      )
    }
    _ = window.setFrameAutosaveName(autosaveName)
  }
}
