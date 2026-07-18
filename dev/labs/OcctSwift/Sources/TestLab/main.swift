// TestLab — launcher for the standalone dev/test apps in dev/labs/.
// Each app runs as its own process, so a crash in one bench never takes the
// launcher (or another bench) down. Build everything with dev/labs/build.sh.
import AppKit
import SwiftUI

// dev/labs, found by walking up from this binary until the folder containing
// build.sh appears. (A fixed number of deletingLastPathComponent calls breaks
// because SwiftPM's .build/debug is a symlink — the resolved real path has an
// extra arm64-apple-macosx component.)
let labsRoot: URL = {
  var url = URL(fileURLWithPath: Bundle.main.executablePath ?? ".")
    .resolvingSymlinksInPath()
  for _ in 0..<8 {
    url.deleteLastPathComponent()
    if FileManager.default.fileExists(atPath: url.appendingPathComponent("build.sh").path) {
      return url
    }
  }
  return URL(fileURLWithPath: "/Users/jonathanjenkins/GITHUB/AnimaStudio/dev/labs")
}()
let repoRoot = labsRoot.deletingLastPathComponent().deletingLastPathComponent()

struct LabApp: Identifiable {
  let id = UUID()
  let name: String
  let detail: String
  let path: URL
  let needsFile: Bool
  let isTerminal: Bool  // capture stdout into the output pane instead of a window
  var disabledReason: String? = nil  // listed but deliberately not built
}

let apps: [LabApp] = [
  LabApp(
    name: "PIPELINE 1 — Native: SwiftUI + OCCT shim + RealityKit (GeomBench)",
    detail: "The champion config. Loads STEP (faces/edges selectable, CAD colors), STL, OBJ into one workspace. Telemetry HUD + Metal GPU HUD. THIS is the STEP viewer.",
    path: labsRoot.appendingPathComponent("OcctSwift/.build/debug/GeomBench"),
    needsFile: false, isTerminal: false),
  LabApp(
    name: "PIPELINE 2 — Rust kernel → web viewport (truck + Three.js/WebGPU)",
    detail: "Rust B-rep kernel parses/tessellates the file, browser renders it. Pick a STEP file; a viewer page opens in your browser. Output/timing below.",
    path: labsRoot.appendingPathComponent("rustbench/run.sh"),
    needsFile: true, isTerminal: true),
  LabApp(
    name: "PIPELINE 3 — Qt + OCCT built-in GL + MetalANGLE",
    detail: "Legacy hybrid. Deliberately not built: Jonathan ruled out Qt for now, and MetalANGLE exists only to life-support Apple-deprecated OpenGL. Revisit only if 1 and 2 both fail.",
    path: labsRoot.appendingPathComponent("nonexistent"),
    needsFile: false, isTerminal: false,
    disabledReason: "skipped by decision"),
  LabApp(
    name: "BASELINE — today's app loader (ModelIO → RealityKit)",
    detail: "What Anima Studio ships now. STL/OBJ/USD only — STEP ALWAYS FAILS here, which is the baseline problem the pipelines above solve.",
    path: labsRoot.appendingPathComponent("StlViewer/.build/debug/StlViewer"),
    needsFile: true, isTerminal: false),
  LabApp(
    name: "OCCT kernel report",
    detail: "Headless precision numbers: boolean exactness, fillets, STEP round-trip, tessellation dial. Output shown below.",
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
          if let reason = app.disabledReason {
            Button(reason) {}.disabled(true)
          } else {
            Button(exists(app) ? "Launch" : "Missing — run build.sh") { launch(app) }
              .disabled(!exists(app))
          }
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
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    let name = app.name
    let isTerminal = app.isTerminal
    process.terminationHandler = { proc in
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let text = String(data: data, encoding: .utf8) ?? "(no output)"
      DispatchQueue.main.async {
        if isTerminal {
          output = text
        } else if proc.terminationStatus != 0 {
          // A GUI bench that dies should say so loudly, with its output.
          status = "\(name) EXITED code \(proc.terminationStatus)"
          output = text
        } else {
          status = "\(name) closed"
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
  init() {
    // Before window creation — a CLI-launched process is background-only and
    // .onAppear never fires on a window that never shows.
    DispatchQueue.main.async {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  var body: some SwiftUI.Scene {
    WindowGroup("Anima Studio Test Lab") {
      TestLabView()
    }
  }
}

TestLabApp.main()
