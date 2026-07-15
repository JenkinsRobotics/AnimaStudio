import SwiftUI

struct RigGuideOverlay: View {
  @Bindable var workspace: StudioWorkspaceModel

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Label("Mate Guides", systemImage: "scope")
          .font(.caption.weight(.bold))
        Spacer()
        Text("REVOLUTE PREVIEW")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(StudioPalette.muted)
      }

      Text("Local connector frame and allowed degree of freedom")
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)

      HStack(spacing: 6) {
        guideToggle(
          "XYZ",
          systemImage: "move.3d",
          isOn: workspace.rigGuideVisibility.showsConnectors,
          action: workspace.toggleRigConnectors
        )
        guideToggle(
          "DOF",
          systemImage: "rotate.3d",
          isOn: workspace.rigGuideVisibility.showsDOFHandles,
          action: workspace.toggleRigDOFHandles
        )
        guideToggle(
          "Plane",
          systemImage: "square.dashed",
          isOn: workspace.rigGuideVisibility.showsReferencePlanes,
          action: workspace.toggleRigReferencePlanes
        )
        guideToggle(
          "Limits",
          systemImage: "gauge.with.dots.needle.33percent",
          isOn: workspace.rigGuideVisibility.showsLimits,
          action: workspace.toggleRigLimits
        )
      }

      HStack(spacing: 10) {
        axisKey("X", color: .red)
        axisKey("Y", color: .green)
        axisKey("Z", color: .blue)
        Spacer()
        Text("Select a mapped joint to edit")
          .font(.system(size: 9))
          .foregroundStyle(.tertiary)
      }
    }
    .padding(10)
    .frame(width: 330)
    .background(StudioPalette.panel.opacity(0.94), in: RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
  }

  private func guideToggle(
    _ title: String,
    systemImage: String,
    isOn: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 7)
        .frame(height: 26)
        .foregroundStyle(isOn ? Color.white : StudioPalette.muted)
        .background(
          isOn ? StudioPalette.accent.opacity(0.42) : StudioPalette.panelInset,
          in: RoundedRectangle(cornerRadius: 6)
        )
    }
    .buttonStyle(.plain)
  }

  private func axisKey(_ axis: String, color: Color) -> some View {
    HStack(spacing: 4) {
      Circle()
        .fill(color)
        .frame(width: 6, height: 6)
      Text(axis)
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(StudioPalette.muted)
    }
  }
}
