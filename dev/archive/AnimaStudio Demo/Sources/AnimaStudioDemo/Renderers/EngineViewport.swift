// Renderer switchboard: the main viewport routes the selected part to whichever
// engine is chosen in Settings. RealityKit keeps our polished nav/grid path; the
// other engines are the Codex-bench renderers (Metal, raw WebGPU, Three.js WebGPU).
import GeomKit
import SwiftUI

// Slim stand-in for Codex Bench's 377-line BenchSession — just the surface the
// ported renderer views actually read (theme, camera, telemetry, diagnostics).
@MainActor @Observable final class BenchSession {
  var theme: BenchTheme { RenderState.shared.theme }   // shared across all engines
  var camera = CADCameraState()
  var isModelSelected = false   // start unselected so true STEP colors show
  var renderRevision = 0
  var benchmarkPulse = 0
  var status = ""
  var rendererBackend: String?
  var rendererDiagnostic: String?
  var telemetry = LiveTelemetry()

  func tickFrame() { telemetry.recordFrames(1) }
  func tickFrames(_ count: Int) { telemetry.recordFrames(count) }
  func toggleModelSelection() {
    isModelSelected.toggle()
    renderRevision += 1
  }
}

struct EngineViewport: View {
  let document: GeometryDocument
  var assetName: String = ""
  @State private var session = BenchSession()

  var body: some View {
    Group {
      switch RenderState.shared.engine {
      case .realityKit:
        PartViewport(document: document, assetName: assetName, session: session)
      case .metal:
        MetalBenchView(session: session, document: document)
      case .rayTraced:
        RayTracedBenchView(session: session, document: document)
      case .webGPU:
        RawWebGPUBenchView(session: session, document: document)
      case .threeJS:
        ThreeJSBenchView(session: session, document: document)
      }
    }
    .overlay(alignment: .bottomTrailing) {
      if RenderState.shared.pinPerformance {
        PerformanceHUD(
          engine: RenderState.shared.engine, telemetry: session.telemetry, document: document,
          onClose: { RenderState.shared.pinPerformance = false }
        )
        .padding(16)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
      }
    }
    .onAppear { session.telemetry.start() }
  }
}
