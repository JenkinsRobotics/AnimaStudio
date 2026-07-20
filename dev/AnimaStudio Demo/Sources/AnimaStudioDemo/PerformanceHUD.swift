// Pinned live-stats HUD — the persistent version of the Performance popover,
// floating in the render view's bottom-right corner (Codex-bench telemetry look).
import GeomKit
import SwiftUI

struct PerformanceHUD: View {
  let engine: RenderEngine
  let telemetry: LiveTelemetry
  let document: GeometryDocument?
  var onClose: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text("PERFORMANCE").font(.system(size: 9.5, weight: .semibold)).tracking(0.6)
          .foregroundStyle(UI.text3)
        Spacer(minLength: 20)
        Button(action: onClose) {
          Image(systemName: "pin.slash.fill").font(.system(size: 9, weight: .semibold))
            .foregroundStyle(UI.text3)
        }.buttonStyle(.plain).help("Unpin")
      }
      row("ENGINE", engine.rawValue)
      row("LOAD", String(format: "%.0f ms", document?.metrics.totalMilliseconds ?? 0))
      row("FPS", String(format: "%.0f", telemetry.framesPerSecond))
      row("CPU", String(format: "%.1f %%", telemetry.cpuPercent))
      row("MEMORY", String(format: "%.1f MB", telemetry.memoryMegabytes))
      row("TRIANGLES", "\(document?.triangleCount ?? 0)")
      row("KERNEL", GeomKernel.version)
    }
    .padding(12)
    .frame(width: 208)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(UI.stroke, lineWidth: 1))
    .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 9)
  }

  private func row(_ label: String, _ value: String) -> some View {
    HStack(spacing: 8) {
      Text(label).font(.system(size: 9.5, weight: .medium)).tracking(0.4)
        .foregroundStyle(UI.text3).frame(width: 74, alignment: .leading)
      Text(value).font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(UI.text).lineLimit(1)
      Spacer(minLength: 0)
    }
  }
}
