import SwiftUI

/// Reusable in-viewport telemetry presentation. CodexUI is intentionally a
/// presentation prototype, so these values demonstrate the information
/// hierarchy and are visibly marked as sample data until a renderer supplies
/// real measurements.
struct ViewportPerformanceHUD: View {
  @Environment(\.prototypeTheme) private var theme
  let viewportMode: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 7) {
        Circle().fill(theme.green).frame(width: 7, height: 7)
        Text("PERFORMANCE")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
        Spacer()
        Text("SAMPLE")
          .font(.system(size: 8, weight: .bold, design: .monospaced))
          .foregroundStyle(theme.orange)
      }
      .foregroundStyle(theme.primaryText)

      metric("VIEW", viewportMode)
      metric("RENDERER", "Native Metal preview")
      metric("FRAME", "60.0 FPS")
      metric("CPU", "5.2 %")
      metric("MEMORY", "284 MB")
      metric("GPU", "Apple Metal")

      Text("Preview telemetry · renderer hook pending")
        .font(.system(size: 8, design: .monospaced))
        .foregroundStyle(theme.secondaryText.opacity(0.86))
        .padding(.top, 2)
    }
    .padding(12)
    .frame(width: 300, alignment: .leading)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(theme.line.opacity(1.3), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.3), radius: 16, y: 7)
  }

  private func metric(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(label)
        .foregroundStyle(theme.secondaryText)
        .frame(width: 60, alignment: .leading)
      Text(value)
        .foregroundStyle(theme.primaryText)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
  }
}
