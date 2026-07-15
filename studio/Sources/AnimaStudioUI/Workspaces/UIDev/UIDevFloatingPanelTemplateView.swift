import SwiftUI

/// A deliberately floating AppKit surface for short-lived tools that must stay
/// visible above the main workspace. Product panels should prefer the in-app
/// docked pattern unless they truly need this behavior.
struct UIDevFloatingPanelTemplateView: View {
  @State private var pinsAboveWorkspace = true
  @State private var sampleValue = 24.0

  var body: some View {
    VStack(spacing: 0) {
      StudioPanelHeader(
        title: "Floating Tool Template",
        detail: "Utility panel · independent from Agent",
        systemImage: "macwindow.badge.plus"
      )
      Divider()
      VStack(alignment: .leading, spacing: 16) {
        Label("Use sparingly", systemImage: "exclamationmark.bubble")
          .font(.headline)
        Text(
          "Floating tools stay visible while an operator works elsewhere. Use this pattern for a compact temporary instrument—not navigation, inspectors, or the Agent."
        )
        .font(.callout)
        .foregroundStyle(StudioPalette.muted)
        .fixedSize(horizontal: false, vertical: true)

        StudioNumberFieldRow(title: "Sample Value", value: $sampleValue, unit: "mm")
        Toggle("Stay above workspace windows", isOn: $pinsAboveWorkspace)
          .disabled(true)
          .help("This template is created as a floating NSPanel by the shared window factory.")

        Spacer(minLength: 0)

        HStack {
          Spacer()
          Button("Apply") {}
            .buttonStyle(StudioButtonStyle(role: .primary, expandsHorizontally: false))
        }
      }
      .padding(StudioMetrics.panelPadding)
    }
    .background(StudioPalette.panel)
  }
}
