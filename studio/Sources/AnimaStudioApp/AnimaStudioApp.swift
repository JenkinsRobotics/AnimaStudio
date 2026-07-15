import SwiftUI

@main
struct AnimaStudioApp: App {
  var body: some Scene {
    WindowGroup("Anima Studio") {
      StudioWorkspaceView()
        .frame(minWidth: 1_000, minHeight: 680)
    }
    .windowToolbarStyle(.unified)
  }
}
