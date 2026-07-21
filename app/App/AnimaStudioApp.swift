import AnimaStudioUI
import SwiftUI

@main
struct AnimaStudioApp: App {
  var body: some Scene {
    WindowGroup("Anima Studio") {
      AnimaStudioRootView()
        .frame(minWidth: 1_100, minHeight: 720)
    }
    // The production header owns the window chrome. Extending content through
    // the transparent title-bar region keeps the traffic lights on the same
    // continuous surface instead of adding a second dark strip above it.
    .windowStyle(.hiddenTitleBar)
    // The window may grow freely above the root view's minimum. Without this,
    // SwiftUI can size-lock hidden-title-bar windows and suppress native edge
    // resize hit regions/cursors.
    .windowResizability(.contentMinSize)
    .defaultSize(width: 1_440, height: 900)

    Settings {
      AnimaStudioSettingsView()
    }
  }
}
