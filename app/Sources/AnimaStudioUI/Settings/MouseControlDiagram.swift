import RealityKitViewport
import SwiftUI

/// A compact, code-native mouse legend used by the navigation settings panel.
/// It deliberately avoids a bitmap so labels, accent color, and accessibility
/// stay synchronized with the active profile.
struct MouseControlDiagram: View {
  let profile: PreviewNavigationProfile
  let customMapping: CustomNavigationMapping

  private var summary: PreviewNavigationProfileSummary {
    profile.summary(customMapping: customMapping)
  }

  var body: some View {
    HStack(spacing: 22) {
      ZStack(alignment: .top) {
        RoundedRectangle(cornerRadius: 34)
          .fill(StudioPalette.panelInset)
          .frame(width: 128, height: 174)
          .overlay {
            RoundedRectangle(cornerRadius: 34)
              .stroke(StudioPalette.border, lineWidth: 1)
          }

        HStack(spacing: 2) {
          mouseButton(label: "L", detail: "Select")
          wheel
          mouseButton(label: "R", detail: rightButtonDetail)
        }
        .padding(.top, 12)
      }

      VStack(alignment: .leading, spacing: 10) {
        mappingRow("Orbit", summary.orbit, systemImage: "rotate.3d")
        mappingRow("Pan", summary.pan, systemImage: "move.3d")
        mappingRow("Zoom", summary.zoom, systemImage: "plus.magnifyingglass")
        mappingRow("Special", summary.special, systemImage: "sparkles")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Mouse mapping for \(profile.displayName)")
  }

  private var rightButtonDetail: String {
    summary.orbit.localizedCaseInsensitiveContains("right") ? "Orbit" : "Menu"
  }

  private func mouseButton(label: String, detail: String) -> some View {
    VStack(spacing: 5) {
      RoundedRectangle(cornerRadius: 14)
        .fill(detail == "Orbit" ? StudioPalette.accent.opacity(0.8) : StudioPalette.field)
        .frame(width: 37, height: 55)
        .overlay {
          Text(label)
            .font(.caption2.weight(.bold))
        }
      Text(detail)
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(StudioPalette.muted)
    }
  }

  private var wheel: some View {
    VStack(spacing: 5) {
      Capsule()
        .fill(StudioPalette.accent)
        .frame(width: 18, height: 42)
        .overlay {
          Image(systemName: "arrow.up.and.down")
            .font(.system(size: 8, weight: .bold))
        }
      Text("Wheel")
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(StudioPalette.muted)
    }
  }

  private func mappingRow(_ title: String, _ detail: String, systemImage: String) -> some View {
    HStack(alignment: .top, spacing: 9) {
      Image(systemName: systemImage)
        .foregroundStyle(StudioPalette.accent)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
      }
    }
  }
}
