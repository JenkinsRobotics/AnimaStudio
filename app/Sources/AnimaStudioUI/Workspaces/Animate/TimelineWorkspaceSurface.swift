import SwiftUI

/// Timelines are structured editors, not spatial canvases. They may use the
/// broad center while overlays are absent, but their controls and tracks must
/// reflow inside any floating sidebar that enters the workspace.
enum TimelineWorkspaceSurfaceSizing {
  static let baseHorizontalInset: CGFloat = 18
  static let topInset: CGFloat = 10
  static let bottomInset: CGFloat = 12

  static func leadingInset(for overlays: StudioWorkspaceOverlayInsets) -> CGFloat {
    max(baseHorizontalInset, overlays.leading)
  }

  static func trailingInset(for overlays: StudioWorkspaceOverlayInsets) -> CGFloat {
    max(baseHorizontalInset, overlays.trailing)
  }
}

struct TimelineWorkspaceSurface<Content: View>: View {
  @Environment(\.studioWorkspaceOverlayInsets) private var overlayInsets
  @ViewBuilder let content: Content

  private var isDocked: Bool {
    StudioLayoutState.shared.detectedPreset == .docked
  }

  var body: some View {
    if isDocked {
      VStack(spacing: 0) {
        Divider().overlay(StudioPalette.border)
        content
      }
    } else {
      content
        .clipShape(
          RoundedRectangle(cornerRadius: StudioMetrics.panelCornerRadius, style: .continuous)
        )
        .overlay {
          RoundedRectangle(
            cornerRadius: StudioMetrics.panelCornerRadius,
            style: .continuous
          )
          .stroke(StudioPalette.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.30), radius: 14, y: 6)
        .padding(.top, TimelineWorkspaceSurfaceSizing.topInset)
        .padding(.bottom, TimelineWorkspaceSurfaceSizing.bottomInset)
        .padding(
          .leading,
          TimelineWorkspaceSurfaceSizing.leadingInset(for: overlayInsets)
        )
        .padding(
          .trailing,
          TimelineWorkspaceSurfaceSizing.trailingInset(for: overlayInsets)
        )
        .frame(maxWidth: .infinity, alignment: .bottom)
        .animation(
          .spring(response: 0.24, dampingFraction: 0.9),
          value: overlayInsets
        )
    }
  }
}
