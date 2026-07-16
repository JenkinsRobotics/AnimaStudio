import AnimaCoreClient
import AnimaEvaluation
import AnimaModel
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
    HStack(spacing: 0) {
      ScrollView(.horizontal) {
        HStack(alignment: .center, spacing: 0) {
          structuresGroup
          matesGroup
          relationsGroup
          futureGroup(
            title: "Connectors",
            systemImage: "scope",
            tools: [
              ("Custom", "plus.circle"),
              ("Move", "arrow.up.and.down.and.arrow.left.and.right"),
              ("Rotate", "rotate.3d"),
              ("Flip Axis", "arrow.triangle.2.circlepath"),
              ("Offset", "arrow.up.right"),
              ("Planes", "square.3.layers.3d"),
            ]
          )
          futureGroup(
            title: "Assemble",
            systemImage: "wrench.and.screwdriver",
            tools: [
              ("Move", "arrow.up.and.down.and.arrow.left.and.right"),
              ("Rotate", "rotate.right"),
              ("Snap", "dot.scope"),
              ("Align", "align.horizontal.left"),
              ("Measure", "ruler"),
              ("Explode", "arrow.up.left.and.arrow.down.right"),
            ]
          )
          futureGroup(
            title: "Inspect",
            systemImage: "checkmark.magnifyingglass",
            tools: [
              ("DOF Limits", "gauge.with.dots.needle.50percent"),
              ("Neutral", "scope"),
              ("Test Motion", "play.square"),
              ("Validate", "checkmark.shield"),
              ("Conflicts", "exclamationmark.triangle"),
            ]
          )
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
        .padding(.vertical, 8)
      }
      .scrollIndicators(.hidden)

      Button("Close creation tools", systemImage: "xmark") {
        workspace.showsCreationPalette = false
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.plain)
      .frame(width: 32, height: 32)
      .help("Collapse the Rig creation ribbon")
      .padding(.trailing, 8)
    }
    .frame(maxWidth: .infinity)
    .frame(height: StudioMetrics.rigCreationRibbonHeight)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Rig creation tools")
    .sheet(item: $workspace.relationDraft) { draft in
      RelationEditorView(
        draft: Binding(
          get: { workspace.relationDraft ?? draft },
          set: { workspace.relationDraft = $0 }
        ),
        driverOptions: workspace.relationDOFOptions(kind: draft.type.driverKind),
        drivenOptions: workspace.relationDOFOptions(kind: draft.type.drivenKind),
        dismiss: workspace.dismissRelationDraft
      )
    }
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
      tint: StudioPalette.joint,
      detail: "10 engine types · 1 draft action"
    ) {
      ForEach(MateCreationToolKind.allCases) { kind in
        CreationToolButton(
          title: kind.title,
          systemImage: kind.systemImage,
          tint: StudioPalette.joint,
          isEnabled: isMateToolEnabled(kind),
          help: mateToolHelp(kind)
        ) {
          if kind == .revolute {
            workspace.beginRevoluteMatePlacement()
          }
        }
      }
    }
  }

  private func isMateToolEnabled(_ kind: MateCreationToolKind) -> Bool {
    kind.hasLocalDraftAuthoringAction && workspace.canCreateRevoluteJoint
  }

  private func mateToolHelp(_ kind: MateCreationToolKind) -> String {
    guard kind.hasLocalDraftAuthoringAction else {
      return
        "\(kind.motionSummary) Engine-backed inspection is available; canonical document editing is the next authoring packet."
    }
    guard workspace.canCreateRevoluteJoint else {
      return "\(kind.motionSummary) Add two unlocked components before creating this mate."
    }
    return
      "\(kind.motionSummary) Choose a connector on the moving component, then one on the fixed component."
  }

  private var relationsGroup: some View {
    CreationToolGroup(
      title: "Relations",
      systemImage: "link",
      tint: StudioPalette.joint,
      detail: "4 engine types"
    ) {
      if workspace.engineRelationTypes.isEmpty {
        CreationToolButton(
          title: "Loading",
          systemImage: "ellipsis.circle",
          tint: StudioPalette.muted,
          isEnabled: false,
          help: "The Relations catalog appears after AnimaCore connects"
        ) {}
      } else {
        ForEach(workspace.engineRelationTypes) { type in
          CreationToolButton(
            title: type.label,
            systemImage: type.kind.systemImage,
            tint: StudioPalette.joint,
            help: relationToolHelp(type)
          ) {
            workspace.beginRelationDraft(type)
          }
        }
      }
    }
  }

  private func relationToolHelp(_ type: AnimaCoreRelationTypeSummary) -> String {
    let presentation = RelationEditorPresentation(type: type)
    return
      "\(presentation.compatibilitySummary). Opens the engine-backed relation draft dialog; document mutation is not wired yet."
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

struct CreationToolGroup<Content: View>: View {
  let title: String
  let systemImage: String
  let tint: Color
  var detail: String?
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
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
    .padding(.horizontal, 12)
    .frame(height: 92)
    .overlay {
      HStack {
        Spacer()
        Divider()
      }
    }
  }
}

struct CreationToolButton: View {
  let title: String
  let systemImage: String
  let tint: Color
  var isEnabled = true
  var isSelected = false
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
      .frame(width: 68, height: 57)
      .background(
        isSelected ? tint.opacity(0.14) : Color.clear,
        in: RoundedRectangle(cornerRadius: 7)
      )
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
