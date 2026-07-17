// Standalone STL render smoke test: loads a mesh through the EXACT production
// loader (RealityKitModelLoader) and shows it in a bare RealityKit window.
// No project machinery, no sandbox, no workspace. Usage:
//   swift run StlViewer "/path/to/part.stl" [unitScaleToMeters]
import AppKit
import RealityKit
import RealityKitViewport
import SwiftUI

let args = CommandLine.arguments
let stlPath =
  args.count > 1
  ? args[1]
  : "/Users/jonathanjenkins/Documents/AnimaStudio/single part/characters/test-part/assets/ARCADA001 - Part 1 (2).stl"
let unitScale = args.count > 2 ? Double(args[2]) ?? 0.001 : 0.001

struct ViewerView: View {
  let url: URL
  let unitScale: Double
  @State private var status = "loading…"

  var body: some View {
    VStack(spacing: 0) {
      Text(status).font(.system(.caption, design: .monospaced)).padding(4)
      RealityView { content in
        let camera = PerspectiveCamera()
        do {
          let start = Date()
          let loaded = try await RealityKitModelLoader.loadWithTopology(
            contentsOf: url, unitScaleToMeters: unitScale)
          let elapsed = String(format: "%.2fs", -start.timeIntervalSinceNow)
          let entity = loaded.entity
          let bounds = entity.visualBounds(relativeTo: nil)
          content.add(entity)
          // Frame the camera on the model's real bounds.
          let center = bounds.center
          let radius = max(bounds.boundingRadius, 0.001)
          camera.position = center + SIMD3<Float>(radius * 1.6, radius * 1.2, radius * 1.9)
          camera.look(at: center, from: camera.position, relativeTo: nil)
          content.add(camera)
          let meshCount = entity.children.count
          let size = bounds.extents
          status = String(
            format: "OK in %@ — meshes=%d topology=%@ size=%.3f × %.3f × %.3f m",
            elapsed, meshCount, loaded.topology != nil ? "yes" : "no",
            size.x, size.y, size.z)
          try? "RESULT: \(status)\n".write(
            toFile: "/tmp/stlviewer_result.txt", atomically: true, encoding: .utf8)
        } catch {
          status = "LOAD FAILED: \(error.localizedDescription)"
          try? "RESULT: \(status)\n".write(
            toFile: "/tmp/stlviewer_result.txt", atomically: true, encoding: .utf8)
        }
      }
    }
    .frame(minWidth: 900, minHeight: 640)
    .onAppear {
      // CLI-launched processes start as background apps; activate so the
      // window actually draws.
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
    }
  }
}

struct StlViewerApp: App {
  init() {
    // Activate once NSApp exists so the CLI-launched window actually draws.
    DispatchQueue.main.async {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
    }
    // Independent load check (no view involved): does the production loader
    // load this file in a plain process?
    let url = URL(fileURLWithPath: stlPath)
    let scale = unitScale
    Task { @MainActor in
      let start = Date()
      do {
        let loaded = try await RealityKitModelLoader.loadWithTopology(
          contentsOf: url, unitScaleToMeters: scale)
        let line = String(
          format: "LOAD OK in %.2fs meshes=%d topology=%@\n",
          -start.timeIntervalSinceNow, loaded.entity.children.count,
          loaded.topology != nil ? "yes" : "no")
        try? line.write(
          toFile: "/tmp/stlviewer_load.txt", atomically: true, encoding: .utf8)
      } catch {
        try? "LOAD FAILED: \(error)\n".write(
          toFile: "/tmp/stlviewer_load.txt", atomically: true, encoding: .utf8)
      }
    }
  }

  var body: some SwiftUI.Scene {
    WindowGroup("STL Render Test — \(URL(fileURLWithPath: stlPath).lastPathComponent)") {
      ViewerView(url: URL(fileURLWithPath: stlPath), unitScale: unitScale)
    }
  }
}

print("Loading: \(stlPath) (scale \(unitScale))")
StlViewerApp.main()
