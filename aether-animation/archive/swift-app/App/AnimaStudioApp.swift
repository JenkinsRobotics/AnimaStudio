import AnimaStudioUI
import SwiftUI

@main
struct AnimaStudioApp: App {
  @State private var applicationState = AnimaStudioApplicationState()

  var body: some Scene {
    WindowGroup("Anima Studio") {
      AnimaStudioRootView(applicationState: applicationState)
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

    // Programmatic workspace windows use the same application/project session
    // as the primary WindowGroup. The request controls only presentation:
    // which workspace opens and whether AppKit joins it to an existing tab
    // group. Native dragging, detaching, Merge All Windows, and Split View are
    // still owned by macOS.
    WindowGroup(
      "Anima Studio Workspace",
      id: "studio-workspace",
      for: StudioWorkspaceWindowRequest.self
    ) { $request in
      AnimaStudioRootView(
        applicationState: applicationState,
        windowRequest: request
      )
      .frame(minWidth: 1_100, minHeight: 720)
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentMinSize)
    .defaultSize(width: 1_440, height: 900)

    Settings {
      AnimaStudioSettingsView()
    }
  }
}
