// TestLab — launcher for the standalone dev/test apps in dev/labs/.
// Each app runs as its own process, so a crash in one bench never takes the
// launcher (or another bench) down. Build everything with dev/labs/build.sh.
import AppKit
import SwiftUI

// dev/labs, resolved from this binary's location (…/OcctSwift/.build/debug/TestLab).
let labsRoot = URL(fileURLWithPath: Bundle.main.executablePath ?? ".")
  .deletingLastPathComponent()  // debug
  .deletingLastPathComponent()  // .build
  .deletingLastPathComponent()  // OcctSwift
let repoRoot = labsRoot.deletingLastPathComponent().deletingLastPathComponent()

struct LabApp: Identifiable {
  let id = UUID()
  let name: String
  let detail: String
  let path: URL
  let needsFile: Bool
  let isTerminal: Bool  // capture stdout into the output pane instead of a window
}

let apps: [LabApp] = [
  LabApp(
    name: "GeomBench",
    detail: "OCCT → Swift → Metal test bench. Multi-file workspace (STL/STEP/OBJ), face/edge click-select, FPS/CPU/MEM telemetry + Metal GPU HUD.",
    path: labsRoot.appendingPathComponent("OcctSwift/.build/debug/GeomBench"),
    needsFile: false, isTerminal: false),
  LabApp(
    name: "OcctSwiftViewer",
    detail: "OCCT kernel demo part + one STL, rendered by RealityKit. The minimal kernel→Metal proof.",
    path: labsRoot.appendingPathComponent("OcctSwift/.build/debug/OcctSwiftViewer"),
    needsFile: false, isTerminal: false),
  LabApp(
    name: "StlViewer (ModelIO)",
    detail: "The production app's loader (ModelIO → RealityKit) in isolation. Pick an STL to view.",
    path: labsRoot.appendingPathComponent("StlViewer/.build/debug/StlViewer"),
    needsFile: true, isTerminal: false),
  LabApp(
    name: "OCCT kernel report",
    detail: "Headless precision test: boolean exactness, fillets, STEP round-trip, tessellation dial, STL read. Output shown below.",
    path: labsRoot.appendingPathComponent("bin/occt_test"),
    needsFile: false, isTerminal: true),
  LabApp(
    name: "Anima Studio (main app)",
    detail: "The real app at the repo root — for comparing against the benches.",
    path: repoRoot.appendingPathComponent("Anima Studio.app"),
    needsFile: false, isTerminal: false),
]

struct TestLabView: View {
  @State private var output = "Terminal-style results appear here."
  @State private var status = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Anima Studio — Test Lab").font(.title2.bold())
      Text("Standalone benches, each its own process. Rebuild all: dev/labs/build.sh")
        .font(.caption).foregroundStyle(.secondary)
      ForEach(apps) { app in
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 2) {
            Text(app.name).font(.headline)
            Text(app.detail).font(.caption).foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Button(exists(app) ? "Launch" : "Missing — run build.sh") { launch(app) }
            .disabled(!exists(app))
        }
        .padding(8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
      }
      if !status.isEmpty {
        Text(status).font(.system(.caption, design: .monospaced))
      }
      ScrollView {
        Text(output)
          .font(.system(size: 11, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
      .frame(minHeight: 160)
      .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }
    .padding(16)
    .frame(minWidth: 760, minHeight: 640)
    .onAppear {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  private func exists(_ app: LabApp) -> Bool {
    FileManager.default.fileExists(atPath: app.path.path)
  }

  private func launch(_ app: LabApp) {
    if app.path.pathExtension == "app" {
      NSWorkspace.shared.open(app.path)
      status = "Opened \(app.name)"
      return
    }
    var arguments: [String] = []
    if app.needsFile {
      let panel = NSOpenPanel()
      panel.allowsMultipleSelection = false
      guard panel.runModal() == .OK, let url = panel.url else { return }
      arguments = [url.path, "0.001"]
    }
    let process = Process()
    process.executableURL = app.path
    process.arguments = arguments
    if app.isTerminal {
      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = pipe
      process.terminationHandler = { _ in
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        DispatchQueue.main.async {
          output = String(data: data, encoding: .utf8) ?? "(no output)"
        }
      }
    }
    do {
      try process.run()
      status = "Launched \(app.name)\(app.isTerminal ? " — output below when done" : "")"
    } catch {
      status = "Failed to launch \(app.name): \(error.localizedDescription)"
    }
  }
}

struct TestLabApp: App {
  var body: some SwiftUI.Scene {
    WindowGroup("Anima Studio Test Lab") {
      TestLabView()
    }
  }
}

TestLabApp.main()
