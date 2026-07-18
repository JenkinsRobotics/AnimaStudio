// The toggleable viewport backends and pipeline catalog for GeomBench.
import OcctGLKit
import RealityKit
import RealityKitViewport
import SwiftUI

/// The six architectural pipelines under evaluation. 1/2/3/6 are in-process
/// viewport backends; 4/5 are external Qt processes launched from the bench.
enum PipelineBackend: String, CaseIterable, Identifiable {
  case realityKit = "P1 RealityKit"
  case metalKit = "P2 MetalKit"
  case occtGL = "P3 OCCT-GL"
  // STEP-only bench per Jonathan: the ModelIO backend (cannot read STEP,
  // ever — Apple framework) is kept in code for reference but not offered.
  case modelIO = "P6 ModelIO"

  static var allCases: [PipelineBackend] { [.realityKit, .metalKit, .occtGL] }

  var id: String { rawValue }

  var fullName: String {
    switch self {
    case .realityKit: "Pipeline 1 — OCCT C-shim → Swift → RealityKit"
    case .metalKit: "Pipeline 2 — OCCT C-shim → Swift → custom MetalKit renderer"
    case .occtGL: "Pipeline 3 — OCCT built-in GL viewer → SwiftUI (NSViewRepresentable)"
    case .modelIO: "Pipeline 6 — ModelIO → RealityKit quick-parser (no B-rep)"
    }
  }

  var capabilities: String {
    switch self {
    case .realityKit: "STEP/STL/OBJ · face+edge select · XDE colors · Metal"
    case .metalKit: "STEP/STL/OBJ · raw MTLBuffers · XDE colors · display only"
    case .occtGL: "STEP only · OCCT-native hover/select · deprecated OpenGL"
    case .modelIO: "STL/OBJ/USD only · STEP fails (that's the baseline point)"
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

// Shared three-point lighting for the RealityKit-based backends.
@MainActor
func addBenchLighting(to content: some RealityViewContentProtocol) {
  let key = Entity()
  key.components.set(DirectionalLightComponent(color: .white, intensity: 3_000))
  key.look(at: .zero, from: SIMD3<Float>(0.5, 0.9, 0.6), relativeTo: nil)
  content.add(key)
  let fill = Entity()
  fill.components.set(
    DirectionalLightComponent(
      color: NSColor(calibratedRed: 0.75, green: 0.82, blue: 1.0, alpha: 1),
      intensity: 1_200))
  fill.look(at: .zero, from: SIMD3<Float>(-0.7, 0.3, 0.4), relativeTo: nil)
  content.add(fill)
  let rim = Entity()
  rim.components.set(DirectionalLightComponent(color: .white, intensity: 900))
  rim.look(at: .zero, from: SIMD3<Float>(0.1, 0.5, -0.8), relativeTo: nil)
  content.add(rim)
}
