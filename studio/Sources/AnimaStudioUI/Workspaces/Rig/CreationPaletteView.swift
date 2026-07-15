import AnimaCore
import SwiftUI

extension RigPrimitiveKind {
  var displayName: String {
    switch self {
    case .box: "Box"
    case .cylinder: "Cylinder"
    case .sphere: "Sphere"
    case .locator: "Empty Point"
    }
  }

  var systemImage: String {
    switch self {
    case .box: "cube"
    case .cylinder: "cylinder"
    case .sphere: "circle.grid.cross"
    case .locator: "scope"
    }
  }
}

struct CreationPaletteView: View {
  @Bindable var workspace: StudioWorkspaceModel

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Label("Add to Rig", systemImage: "plus.circle.fill")
          .font(.callout.weight(.semibold))
        Text("Create simple rig proxies now; replace them with imported geometry later.")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.72))
        Spacer()
        Button("Close creation tools", systemImage: "xmark") {
          workspace.showsCreationPalette = false
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .frame(height: 34)
      .background(StudioPalette.accent)

      ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 10) {
          structuresGroup
          matesGroup
          futureGroup(
            title: "Motors",
            systemImage: "gearshape.2.fill",
            tools: [
              ("Servo", "capsule"),
              ("Stepper", "move.3d"),
              ("Custom", "shippingbox"),
              ("DYNAMIXEL", "hexagon"),
            ]
          )
          futureGroup(
            title: "3D Models & Media",
            systemImage: "photo.on.rectangle.angled",
            tools: [
              ("Video", "play.rectangle"),
              ("Imported Model", "cube.transparent"),
            ]
          )
          futureGroup(
            title: "Events",
            systemImage: "wave.3.right.circle",
            tools: [
              ("Curve", "point.topleft.down.curvedto.point.bottomright.up"),
              ("On / Off", "switch.2"),
              ("Trigger", "bolt.circle"),
            ]
          )
        }
        .padding(10)
      }
      .scrollIndicators(.visible)
    }
    .frame(maxWidth: 1_140)
    .background(StudioPalette.panel)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.42), radius: 18, y: 7)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Rig creation tools")
  }

  private var structuresGroup: some View {
    CreationToolGroup(
      title: "Structures",
      systemImage: "cube.fill",
      tint: StudioPalette.semanticPart
    ) {
      ForEach(RigPrimitiveKind.allCases, id: \.self) { kind in
        CreationToolButton(
          title: kind.displayName,
          systemImage: kind.systemImage,
          tint: StudioPalette.semanticPart,
          help: "Add a \(kind.displayName.lowercased()) proxy to the semantic rig"
        ) {
          workspace.addPart(kind: kind)
        }
      }
    }
  }

  private var matesGroup: some View {
    CreationToolGroup(
      title: "Mates",
      systemImage: "rotate.3d",
      tint: StudioPalette.joint
    ) {
      CreationToolButton(
        title: "Revolute Mate",
        systemImage: "rotate.3d",
        tint: StudioPalette.joint,
        isEnabled: workspace.canCreateRevoluteJoint,
        help: workspace.canCreateRevoluteJoint
          ? "Choose a connector on the moving component, then one on the fixed component"
          : "Add two unlocked components before creating a mate"
      ) {
        workspace.beginRevoluteMatePlacement()
      }
      CreationToolButton(
        title: "Insert Mate",
        systemImage: "arrow.triangle.branch",
        tint: StudioPalette.joint,
        isEnabled: false,
        help: "Inserting mates between two existing components is planned"
      ) {}
    }
  }

  private func futureGroup(
    title: String,
    systemImage: String,
    tools: [(String, String)]
  ) -> some View {
    CreationToolGroup(
      title: title,
      systemImage: systemImage,
      tint: StudioPalette.muted,
      detail: "Coming later"
    ) {
      ForEach(Array(tools.enumerated()), id: \.offset) { _, tool in
        CreationToolButton(
          title: tool.0,
          systemImage: tool.1,
          tint: StudioPalette.muted,
          isEnabled: false,
          help: "\(tool.0) creation is reserved for a later workspace slice"
        ) {}
      }
    }
  }
}

private struct CreationToolGroup<Content: View>: View {
  let title: String
  let systemImage: String
  let tint: Color
  var detail: String?
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Label(title, systemImage: systemImage)
          .font(.caption.weight(.semibold))
          .foregroundStyle(tint)
        if let detail {
          Text(detail)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(StudioPalette.muted)
        }
      }
      HStack(alignment: .top, spacing: 4) {
        content()
      }
    }
    .padding(9)
    .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }
}

private struct CreationToolButton: View {
  let title: String
  let systemImage: String
  let tint: Color
  var isEnabled = true
  let help: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 5) {
        Image(systemName: systemImage)
          .font(.system(size: 25, weight: .light))
          .frame(height: 29)
        Text(title)
          .font(.system(size: 10, weight: .medium))
          .lineLimit(1)
      }
      .foregroundStyle(tint)
      .frame(width: 70, height: 58)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.34)
    .help(help)
    .accessibilityLabel(title)
    .accessibilityHint(help)
  }
}

struct EmptyRigWorkspaceView: View {
  let showCreationTools: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "cube.transparent")
        .font(.system(size: 42, weight: .light))
        .foregroundStyle(StudioPalette.semanticPart)
      Text("Start an Empty Rig")
        .font(.title2.weight(.semibold))
      Text("Add a simple proxy component, then select it and create a mate.")
        .font(.callout)
        .foregroundStyle(StudioPalette.muted)
      Button("Add First Part", systemImage: "plus") {
        showCreationTools()
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(24)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .accessibilityElement(children: .contain)
  }
}
