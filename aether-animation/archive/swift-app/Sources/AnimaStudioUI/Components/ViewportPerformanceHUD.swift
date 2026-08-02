import AnimaCADViewport
import Foundation
import SwiftUI

enum ViewportPerformanceHUDLayout {
  static let edgePadding: CGFloat = 16
  static let compactHUDClearance: CGFloat = 104

  static func trailingPadding(hasFloatingRightPanel: Bool) -> CGFloat {
    hasFloatingRightPanel ? StudioMetrics.inspectorWidth + 32 : edgePadding
  }

  static func detailedMetricsBottomPadding(
    showsCompactHUD: Bool,
    hasEvaluatedFrame: Bool
  ) -> CGFloat {
    showsCompactHUD && hasEvaluatedFrame ? compactHUDClearance : edgePadding
  }
}

/// Compact, non-interactive runtime status for a spatial viewport.
///
/// The HUD deliberately lives at the trailing-bottom corner. The shell's
/// center-view switcher owns bottom-center, while the ViewCube owns top-trailing.
struct ViewportPerformanceHUD: View {
  let engineStatus: String
  let rendererName: String
  let performance: CADViewportPerformanceSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Label("PERFORMANCE", systemImage: "gauge.with.dots.needle.67percent")
        .font(.system(size: 10, weight: .bold))
        .tracking(0.7)
        .foregroundStyle(StudioPalette.accent)

      metric("ENGINE", engineStatus)
      metric("RENDER", rendererName)
      metric(
        "FPS",
        performance.framesPerSecond > 0.01
          ? String(format: "%.1f", performance.framesPerSecond) : "Measuring"
      )
      metric(
        "FRAME",
        performance.frameTimeMilliseconds.map { String(format: "%.2f ms", $0) } ?? "Measuring"
      )
      metric("CPU", String(format: "%.1f %%", performance.cpuPercent))
      metric("MEM", String(format: "%.1f MB", performance.memoryMegabytes))
    }
    .padding(11)
    .frame(width: 220, alignment: .leading)
    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(StudioPalette.border, lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.24), radius: 12, y: 4)
    .allowsHitTesting(false)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Viewport performance")
  }

  private func metric(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(label)
        .foregroundStyle(StudioPalette.muted)
        .frame(width: 46, alignment: .leading)
      Text(value)
        .foregroundStyle(StudioPalette.ink)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .font(.system(size: 10, design: .monospaced))
  }
}
