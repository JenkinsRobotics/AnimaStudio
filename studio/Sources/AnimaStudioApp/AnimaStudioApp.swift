import SwiftUI

@main
struct AnimaStudioApp: App {
  var body: some Scene {
    WindowGroup("Anima Studio") {
      AnimaStudioRootView()
        .frame(minWidth: 1_100, minHeight: 720)
    }
    .windowToolbarStyle(.unified)
  }
}

struct AnimaStudioRootView: View {
  @State private var hasOpenProject = false

  var body: some View {
    Group {
      if hasOpenProject {
        StudioWorkspaceView {
          hasOpenProject = false
        }
      } else {
        StudioHomeView {
          hasOpenProject = true
        }
      }
    }
  }
}
