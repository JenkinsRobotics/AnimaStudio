import AppKit
import SwiftUI

@main
struct GeomBenchApp: App {
  @State private var session = BenchSession()

  init() {
    DispatchQueue.main.async {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  var body: some Scene {
    WindowGroup("Codex Bench") {
      GeomBenchWorkspace(session: session)
        .frame(minWidth: 1_080, minHeight: 700)
        .preferredColorScheme(.dark)
    }
    .defaultSize(width: 1_380, height: 860)
    .defaultLaunchBehavior(.presented)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Open CAD File…") { session.presentOpenPanel() }
          .keyboardShortcut("o")
      }
    }

    Settings {
      BenchSettingsView(session: session)
        .preferredColorScheme(.dark)
    }
    .restorationBehavior(.disabled)
  }
}
