import AnimaStudioUI
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
