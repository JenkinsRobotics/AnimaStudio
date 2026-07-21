import AnimaCAD
import SwiftUI

/// Production host for the four Codex Bench pipelines. It imports every STEP
/// source once through Open CASCADE, then switches only the renderer consumer.
public struct CADPipelineViewport: View {
  public let sourceURLs: [URL]
  public let backend: CADRenderBackend
  public let theme: CADViewportTheme
  public let showsTelemetry: Bool
  public let isSelected: Bool
  public let onSourceTriangleCountsChange: ([URL: Int]) -> Void

  @State private var document: CADGeometryDocument?
  @State private var camera = CADCameraState()
  @State private var telemetry = CADLiveTelemetry()
  @State private var status = "Waiting for STEP geometry"
  @State private var errorMessage: String?

  public init(
    sourceURLs: [URL],
    backend: CADRenderBackend,
    theme: CADViewportTheme,
    showsTelemetry: Bool = false,
    isSelected: Bool = false,
    onSourceTriangleCountsChange: @escaping ([URL: Int]) -> Void = { _ in }
  ) {
    self.sourceURLs = sourceURLs
    self.backend = backend
    self.theme = theme
    self.showsTelemetry = showsTelemetry
    self.isSelected = isSelected
    self.onSourceTriangleCountsChange = onSourceTriangleCountsChange
  }

  public var body: some View {
    ZStack {
      renderer
      if document == nil {
        ContentUnavailableView {
          Label(
            errorMessage == nil ? "Loading STEP" : "STEP Could Not Load",
            systemImage: errorMessage == nil ? "gearshape.2" : "exclamationmark.triangle")
        } description: {
          Text(
            errorMessage ?? "Open CASCADE is reading hierarchy, colors, faces, and feature edges.")
        }
      }
      if showsTelemetry, let document {
        telemetry(document)
      }
    }
    .task(id: sourceSignature) { await loadSources() }
    .onAppear { telemetry.start() }
    .onDisappear { telemetry.stop() }
  }

  @ViewBuilder
  private var renderer: some View {
    switch backend {
    case .metalKit:
      CADMetalViewport(
        document: document, camera: camera, theme: theme, isSelected: isSelected,
        onFrame: recordFrame,
        onError: { errorMessage = $0 })
    case .realityKit:
      CADRealityKitViewport(
        document: document, camera: camera, theme: theme, isSelected: isSelected,
        onFrame: recordFrame)
    case .threeJSWebGPU, .rawWebGPU:
      CADWebGPUViewport(
        backend: backend, document: document, theme: theme,
        onStatus: { status = $0 },
        onFrameCount: telemetry.recordFrames)
    }
  }

  private func telemetry(_ document: CADGeometryDocument) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      metric("PIPELINE", backend.title)
      metric("ROLE", backend.role)
      metric("LOAD", String(format: "%.1f ms", document.metrics.totalMilliseconds))
      metric("FPS", String(format: "%.1f", telemetry.framesPerSecond))
      metric("CPU", String(format: "%.1f %%", telemetry.cpuPercent))
      metric("MEMORY", String(format: "%.1f MB", telemetry.memoryMegabytes))
      metric("GPU", gpuLabel)
      metric("FACES", "\(document.faces.count)")
      metric("EDGES", "\(document.edges.count)")
      metric("TRIS", "\(document.triangleCount)")
      metric("KERNEL", "Open CASCADE \(CADGeometryKernel.version)")
      Text(status)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .padding(.top, 3)
      if backend == .threeJSWebGPU || backend == .rawWebGPU {
        Text("CPU/memory exclude WebKit helper processes")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .font(.system(.caption, design: .monospaced))
    .padding(12)
    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.12)))
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    .padding(14)
    .allowsHitTesting(false)
  }

  private func metric(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(label).foregroundStyle(.secondary).frame(width: 62, alignment: .leading)
      Text(value).foregroundStyle(.primary)
    }
  }

  private var gpuLabel: String {
    switch backend {
    case .metalKit: "Apple Metal"
    case .realityKit: "RealityKit / Apple Metal"
    case .threeJSWebGPU: "Three.js via Apple WebKit"
    case .rawWebGPU: "WebGPU/WGSL via Apple WebKit"
    }
  }

  private var sourceSignature: String {
    sourceURLs.map { url in
      let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
      let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
      let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
      return "\(url.standardizedFileURL.path)|\(modified)|\(size)"
    }.sorted().joined(separator: "||")
  }

  @MainActor
  private func loadSources() async {
    document = nil
    errorMessage = nil
    onSourceTriangleCountsChange([:])
    let urls = sourceURLs.filter { ["step", "stp"].contains($0.pathExtension.lowercased()) }
    guard !urls.isEmpty else {
      errorMessage = "The selected CAD backend needs at least one STEP or STP source."
      return
    }
    do {
      let imported = try await Task.detached(priority: .userInitiated) {
        try urls.map { try CADGeometryDocument.loadSTEP($0) }
      }.value
      var counts: [URL: Int] = [:]
      for (url, sourceDocument) in zip(urls, imported) {
        counts[url.standardizedFileURL] = sourceDocument.triangleCount
      }
      onSourceTriangleCountsChange(counts)
      let merged = try CADGeometryDocument.merging(imported)
      document = merged
      camera.frame(bounds: merged.renderGeometry.bounds)
      status = "Loaded \(urls.count) STEP source\(urls.count == 1 ? "" : "s")"
    } catch {
      errorMessage = error.localizedDescription
      status = "STEP import failed"
    }
  }

  @MainActor private func recordFrame() { telemetry.recordFrames() }
}
