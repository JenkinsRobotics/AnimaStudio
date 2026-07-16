import AnimaEvaluation
import AnimaModel
import RealityKitViewport
import SwiftUI

struct UIDevEmbeddedWorkspacePreview: View {
  let surface: UIDevSection
  let close: () -> Void

  @State private var workspace = UIDevSampleProject.makeWorkspace()

  var body: some View {
    VStack(spacing: 0) {
      previewHeader
      Divider()
      VStack(spacing: 0) {
        embeddedCanvas
        if surface == .timeline {
          Divider()
          TimelineEditorView(workspace: workspace)
            .frame(minHeight: 250, idealHeight: 300, maxHeight: 360)
        }
      }
    }
    .background(StudioPalette.canvas)
    .onAppear { configureWorkspace() }
    .onChange(of: surface) { _, _ in configureWorkspace() }
  }

  private var previewHeader: some View {
    HStack(spacing: 10) {
      Image(systemName: surface.systemImage)
        .foregroundStyle(StudioPalette.accent)
      VStack(alignment: .leading, spacing: 2) {
        Text(surface.title.uppercased())
          .font(.caption.weight(.bold))
          .tracking(0.8)
        Text("Embedded in the main app layout · not a detached window")
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
      }
      Spacer()
      Button("Back to UI Gallery", systemImage: "xmark") {
        close()
      }
      .labelStyle(.iconOnly)
      .buttonStyle(StudioIconButtonStyle())
      .help("Close this embedded preview and return to the UI Dev gallery")
    }
    .padding(.horizontal, 16)
    .frame(height: 44)
    .background(StudioPalette.chrome)
  }

  private var embeddedCanvas: some View {
    ZStack {
      viewport

      HStack(alignment: .top, spacing: 16) {
        if surface == .navigator {
          ProjectNavigatorView(workspace: workspace, importModel: {})
            .frame(width: StudioMetrics.navigatorWidth)
        }

        Spacer(minLength: 320)

        if surface == .inspector {
          InspectorView(workspace: workspace)
            .frame(width: StudioMetrics.inspectorWidth)
        }
      }
      .padding(16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }

  private var viewport: some View {
    ZStack(alignment: .top) {
      RobotPreviewView(
        frame: workspace.evaluatedFrame,
        rig: workspace.project.rig,
        showsGrid: workspace.showsPreviewGrid,
        projection: workspace.cameraProjection,
        viewpoint: workspace.cameraViewpoint,
        cameraCommandRevision: workspace.cameraCommandRevision,
        cameraState: workspace.cameraState,
        focusedPartID: workspace.selectedPartID,
        focusedPartIsLocked: false,
        rigGuideVisibility: RigGuideVisibility(
          showsConnectors: true,
          showsDOFHandles: true,
          showsReferencePlanes: true,
          showsLimits: true
        ),
        appearance: .graphite,
        renderStyle: .shaded,
        edgeDisplay: .mesh,
        lightingPreset: .balanced,
        materialFinish: .satin,
        reflectionMode: .subtle,
        showsShadows: true,
        onSelectPartID: { id in
          workspace.selectPart(id: id, extendingSelection: false)
        },
        onSetPartPosition: { id, position in
          workspace.setPartPosition(id: id, to: position)
        },
        onSetPartRotation: { id, rotation in
          workspace.setPartRotation(id: id, to: rotation)
        },
        onSelectMateCandidate: workspace.selectMateConnector,
        onCameraStateChange: workspace.reportCameraState
      )

      HStack(spacing: 8) {
        Label("UI DEV · PRODUCTION 3D VIEW", systemImage: "view.3d")
          .font(.caption2.weight(.bold))
          .tracking(0.8)
          .foregroundStyle(StudioPalette.muted)
        Spacer()
        Button("Home", systemImage: "house") {
          workspace.setCameraViewpoint(.home)
        }
        .buttonStyle(
          StudioButtonStyle(role: .secondary, density: .compact, expandsHorizontally: false)
        )
        Button(
          workspace.showsPreviewGrid ? "Hide Grid" : "Show Grid",
          systemImage: "grid"
        ) {
          workspace.showsPreviewGrid.toggle()
        }
        .buttonStyle(
          StudioButtonStyle(role: .secondary, density: .compact, expandsHorizontally: false)
        )
      }
      .padding(10)
      .background(StudioPalette.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
      .padding(14)
      .padding(.leading, surface == .navigator ? StudioMetrics.navigatorWidth + 20 : 0)
      .padding(.trailing, surface == .inspector ? StudioMetrics.inspectorWidth + 20 : 0)
    }
  }

  private func configureWorkspace() {
    workspace.switchWorkspace(to: surface == .timeline ? .animate : .rig)
    workspace.selectPart(id: UIDevSampleProject.headID, extendingSelection: false)
  }
}

private enum UIDevSampleProject {
  static let baseID = PartID()
  static let torsoID = PartID()
  static let headID = PartID()
  static let yawID: JointID = "ui_dev_head_yaw"

  @MainActor
  static func makeWorkspace() -> StudioWorkspaceModel {
    StudioWorkspaceModel(project: project)
  }

  static let project = AnimaProject(
    name: "UI Dev Sample Rig",
    rig: CharacterRig(
      parts: [
        RigPartDefinition(
          id: baseID,
          displayName: "Base",
          primitiveKind: .box,
          positionMeters: RigVector3(x: 0, y: 0.12, z: 0)
        ),
        RigPartDefinition(
          id: torsoID,
          displayName: "Torso",
          primitiveKind: .cylinder,
          positionMeters: RigVector3(x: 0, y: 0.72, z: 0)
        ),
        RigPartDefinition(
          id: headID,
          displayName: "Head",
          primitiveKind: .sphere,
          positionMeters: RigVector3(x: 0, y: 1.45, z: 0)
        ),
      ],
      joints: [
        JointDefinition(
          id: yawID,
          displayName: "Head Yaw",
          axis: .y,
          minimumRadians: -.pi / 2,
          maximumRadians: .pi / 2,
          parentPartID: torsoID,
          childPartID: headID
        )
      ]
    ),
    clips: [
      AnimationClip(
        name: "Look Around",
        durationSeconds: 4,
        jointTracks: [
          JointTrack(
            jointID: yawID,
            keyframes: [
              ScalarKeyframe(timeSeconds: 0, value: 0),
              ScalarKeyframe(timeSeconds: 1, value: -.pi / 4),
              ScalarKeyframe(timeSeconds: 2, value: 0),
              ScalarKeyframe(timeSeconds: 3, value: .pi / 4),
              ScalarKeyframe(timeSeconds: 4, value: 0),
            ]
          )
        ]
      )
    ]
  )
}
