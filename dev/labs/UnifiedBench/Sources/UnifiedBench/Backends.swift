// The toggleable viewport backends and pipeline catalog for GeomBench.
import OcctGLKit
import RealityKit
import RealityKitViewport
import SwiftUI

/// The six architectural pipelines under evaluation. 1/2/3/6 are in-process
/// viewport backends; 4/5 are external Qt processes launched from the bench.
enum PipelineBackend: String, CaseIterable, Identifiable {
  case realityKit = "Open CASCADE → RealityKit"
  case metalKit = "Open CASCADE → Metal (custom)"
  case sceneKit = "Open CASCADE → SceneKit"
  case occtGL = "Open CASCADE built-in viewer"
  case webGL = "Open CASCADE → WebGL (Three.js)"
  case openGeometry = "OpenGeometry (Rust/WASM)"
  case qtOCCT = "Qt + Open CASCADE viewer"
  case unity = "Unity (Bottango's engine)"
  // STEP-only bench per Jonathan: the ModelIO backend (cannot read STEP,
  // ever — Apple framework) is kept in code for reference but not offered.
  case modelIO = "ModelIO (no STEP)"

  static var allCases: [PipelineBackend] {
    [.realityKit, .metalKit, .sceneKit, .occtGL, .webGL, .openGeometry, .qtOCCT, .unity]
  }

  var id: String { rawValue }

  /// True for pipelines that are a separate process (Qt/Unity own their own
  /// event loop and cannot embed in a Swift app) — shown as a launch panel.
  var isExternal: Bool { self == .qtOCCT || self == .unity }

  var fullName: String {
    switch self {
    case .realityKit: "Open CASCADE C-shim → Swift → RealityKit"
    case .metalKit: "Open CASCADE C-shim → Swift → custom MetalKit renderer"
    case .sceneKit: "Open CASCADE C-shim → Swift → SceneKit (Apple scene graph)"
    case .occtGL: "Open CASCADE built-in viewer (OpenGL) → SwiftUI"
    case .webGL: "Open CASCADE C-shim → WebGL (Three.js) in a Swift WKWebView"
    case .openGeometry: "OpenGeometry Rust/WASM kernel in a Swift WKWebView"
    case .qtOCCT: "Qt6 + Open CASCADE built-in viewer (separate window)"
    case .unity: "Open CASCADE shim → OBJ+colors → Unity (separate window)"
    case .modelIO: "ModelIO → RealityKit quick-parser (no B-rep)"
    }
  }

  var capabilities: String {
    switch self {
    case .realityKit: "STEP · face+edge select · CAD colors · native Metal"
    case .metalKit: "STEP · raw Metal buffers · CAD colors · display only"
    case .sceneKit: "STEP · SceneKit PBR + vertex colors · display only"
    case .occtGL: "STEP · Open CASCADE-native hover/select · deprecated OpenGL"
    case .webGL: "STEP · CAD colors · WebGL in-app · own mouse (drag orbit/right pan/scroll zoom)"
    case .openGeometry: "Builds primitives in-code · NO STEP import (export-only) · your files can't load"
    case .qtOCCT: "STEP · Qt owns its window — can't embed in Swift (event-loop conflict)"
    case .unity: "STEP via shim→OBJ · Unity renders converted mesh · separate editor window"
    case .modelIO: "STL/OBJ/USD only · STEP fails"
    }
  }
}

// ---- Pipeline 3: OCCT's V3d/AIS viewer inside SwiftUI ----------------------

struct OcctGLViewport: NSViewRepresentable {
  let model: BenchModel

  final class Coordinator {
    var lastLoadedPath: String?
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSView(context: Context) -> OcctGLView {
    let view = OcctGLView()
    model.occtFPSSource = { [weak view] in view?.takeRedrawCount() ?? 0 }
    return view
  }

  func updateNSView(_ view: OcctGLView, context: Context) {
    guard let url = model.lastFileURL,
      ["step", "stp"].contains(url.pathExtension.lowercased()),
      context.coordinator.lastLoadedPath != url.path
    else { return }
    context.coordinator.lastLoadedPath = url.path
    let seconds = view.loadStep(atPath: url.path)
    model.status =
      seconds >= 0
      ? "P3 OCCT-GL: \(url.lastPathComponent) in \(String(format: "%.2f", seconds))s — hover a face, click to select"
      : "P3 OCCT-GL: load failed for \(url.lastPathComponent)"
  }
}

// ---- Pipeline 6: ModelIO baseline ------------------------------------------

struct ModelIOViewport: View {
  let model: BenchModel
  @State private var loadedPath: String?
  @State private var info = "P6 ModelIO: load a file — STEP will fail here by design"

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      RealityView { content in
        let root = Entity()
        root.name = "modelio-root"
        content.add(root)
        let camera = PerspectiveCamera()
        camera.name = "camera"
        content.add(camera)
        addBenchLighting(to: content)
        model.modelIOSubscription = content.subscribe(to: SceneEvents.Update.self) { _ in
          Task { @MainActor in model.frameCount += 1 }
        }
      } update: { content in
        if let camera = content.entities.first(where: { $0.name == "camera" }) {
          camera.position = model.cameraPosition
          camera.look(at: model.cameraTarget, from: camera.position, relativeTo: nil)
        }
        if let url = model.lastFileURL, loadedPath != url.path,
          let root = content.entities.first(where: { $0.name == "modelio-root" })
        {
          Task { @MainActor in
            loadedPath = url.path
            root.children.removeAll()
            let start = Date()
            do {
              let entity = try await RealityKitModelLoader.load(
                contentsOf: url, unitScaleToMeters: 0.001)
              let bounds = entity.visualBounds(relativeTo: nil)
              let scale = 0.11 / max(bounds.boundingRadius, 0.000_1)
              entity.scale *= SIMD3<Float>(repeating: scale)
              entity.position = -bounds.center * scale
              root.addChild(entity)
              info = String(
                format: "P6 ModelIO: %@ in %.0fms (mesh only — no faces/edges/colors)",
                url.lastPathComponent, -start.timeIntervalSinceNow * 1000)
            } catch {
              info = "P6 ModelIO: LOAD FAILED — \(url.lastPathComponent): \(error.localizedDescription)"
            }
            model.status = info
          }
        }
      }
      Text(info)
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(info.contains("FAILED") ? .red : .secondary)
        .padding(6)
    }
  }
}

// Shared lighting for the ModelIO baseline view (uses the default theme).
@MainActor
func addBenchLighting(to content: some RealityViewContentProtocol) {
  CADTheme.studioBlue.addLighting(to: content)
}
