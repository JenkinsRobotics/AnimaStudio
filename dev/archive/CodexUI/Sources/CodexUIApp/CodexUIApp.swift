import AppKit
import SwiftUI

@main
struct CodexUIApp: App {
  @State private var model = PrototypeModel()

  init() {
    DispatchQueue.main.async {
      NSApplication.shared.setActivationPolicy(.regular)
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
  }

  var body: some Scene {
    WindowGroup("CodexUI") {
      CodexUIShell(model: model)
        .frame(minWidth: 1_180, minHeight: 760)
    }
    .defaultSize(width: 1_560, height: 980)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandMenu("Prototype") {
        Button("Previous Workspace") { model.previousWorkspace() }
          .keyboardShortcut("[", modifiers: [.command])
        Button("Next Workspace") { model.nextWorkspace() }
          .keyboardShortcut("]", modifiers: [.command])
        Divider()
        Button("Toggle Walkthrough") { model.showsTour.toggle() }
          .keyboardShortcut("t", modifiers: [.command, .shift])
      }
    }

    Settings {
      PrototypeSettingsView(model: model)
    }
  }
}
