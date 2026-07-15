import AnimaCore
import AppKit
import RealityKitViewport
import SwiftUI

enum UIDevUtilityWindowKind: String, CaseIterable, Identifiable, Sendable {
  case navigator
  case inspector
  case timeline
  case floatingTemplate
  case workspace3D

  var id: Self { self }

  var title: String {
    switch self {
    case .navigator: "Navigator"
    case .inspector: "Inspector"
    case .timeline: "Timeline"
    case .floatingTemplate: "Floating Template"
    case .workspace3D: "3D Workspace"
    }
  }

  var systemImage: String {
    switch self {
    case .navigator: "sidebar.left"
    case .inspector: "sidebar.right"
    case .timeline: "rectangle.bottomthird.inset.filled"
    case .floatingTemplate: "macwindow.badge.plus"
    case .workspace3D: "view.3d"
    }
  }

  var isUtilityPanel: Bool { self != .workspace3D }

  var contentSize: NSSize {
    switch self {
    case .navigator: NSSize(width: 330, height: 640)
    case .inspector: NSSize(width: 360, height: 640)
    case .timeline: NSSize(width: 980, height: 360)
    case .floatingTemplate: NSSize(width: 360, height: 420)
    case .workspace3D: NSSize(width: 960, height: 680)
    }
  }

  var minimumSize: NSSize {
    switch self {
    case .navigator: NSSize(width: 290, height: 420)
    case .inspector: NSSize(width: 320, height: 420)
    case .timeline: NSSize(width: 680, height: 280)
    case .floatingTemplate: NSSize(width: 320, height: 320)
    case .workspace3D: NSSize(width: 720, height: 520)
    }
  }

  var autosaveName: String { "AnimaUIDev\(rawValue.capitalized)Window" }
}

@MainActor
enum UIDevUtilityWindowRegistry {
  private static var windows: [UIDevUtilityWindowKind: NSWindow] = [:]

  static func show(_ kind: UIDevUtilityWindowKind) {
    let window = windows[kind] ?? makeWindow(for: kind)
    windows[kind] = window
    window.makeKeyAndOrderFront(nil)
    NSApp.activate()
  }

  static func existingWindow(for kind: UIDevUtilityWindowKind) -> NSWindow? {
    windows[kind]
  }

  static func hide(_ kind: UIDevUtilityWindowKind) {
    windows[kind]?.orderOut(nil)
  }

  private static func makeWindow(for kind: UIDevUtilityWindowKind) -> NSWindow {
    let workspace = makeSampleWorkspace(for: kind)
    if kind.isUtilityPanel {
      return StudioWindowFactory.utilityPanel(
        title: kind.title,
        autosaveName: kind.autosaveName,
        contentSize: kind.contentSize,
        minimumSize: kind.minimumSize
      ) {
        UIDevUtilityWindowContent(kind: kind, workspace: workspace)
      }
    }
    return StudioWindowFactory.workspaceWindow(
      title: kind.title,
      autosaveName: kind.autosaveName,
      contentSize: kind.contentSize,
      minimumSize: kind.minimumSize
    ) {
      UIDevUtilityWindowContent(kind: kind, workspace: workspace)
    }
  }

  private static func makeSampleWorkspace(
    for kind: UIDevUtilityWindowKind
  ) -> StudioWorkspaceModel {
    let workspace = StudioWorkspaceModel(project: UIDevSampleProject.project)
    workspace.switchWorkspace(to: kind == .timeline ? .animate : .rig)
    workspace.selectPart(id: UIDevSampleProject.headID, extendingSelection: false)
    return workspace
  }
}

private enum UIDevSampleProject {
  static let baseID = PartID()
  static let torsoID = PartID()
  static let headID = PartID()
  static let yawID: JointID = "ui_dev_head_yaw"

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

private struct UIDevUtilityWindowContent: View {
  let kind: UIDevUtilityWindowKind
  @Bindable var workspace: StudioWorkspaceModel

  var body: some View {
    Group {
      switch kind {
      case .navigator:
        ProjectNavigatorView(workspace: workspace, importModel: {})
          .padding(12)
      case .inspector:
        InspectorView(workspace: workspace)
          .padding(12)
      case .timeline:
        TimelineEditorView(workspace: workspace)
      case .floatingTemplate:
        UIDevFloatingPanelTemplateView()
      case .workspace3D:
        UIDev3DWorkspaceWindow(workspace: workspace)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(StudioPalette.canvas)
    .preferredColorScheme(.dark)
  }
}

private struct UIDev3DWorkspaceWindow: View {
  @Bindable var workspace: StudioWorkspaceModel

  var body: some View {
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
        Label("UI DEV · REAL 3D VIEWPORT", systemImage: "view.3d")
          .font(.caption2.weight(.bold))
          .tracking(0.8)
          .foregroundStyle(StudioPalette.muted)
        Spacer()
        Button("Home", systemImage: "house") {
          workspace.setCameraViewpoint(.home)
        }
        .buttonStyle(
          StudioButtonStyle(
            role: .secondary,
            density: .compact,
            expandsHorizontally: false
          )
        )
        Button(
          workspace.showsPreviewGrid ? "Hide Grid" : "Show Grid",
          systemImage: "grid"
        ) {
          workspace.showsPreviewGrid.toggle()
        }
        .buttonStyle(
          StudioButtonStyle(
            role: .secondary,
            density: .compact,
            expandsHorizontally: false
          )
        )
      }
      .padding(10)
      .background(StudioPalette.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
      .padding(14)
    }
  }
}
