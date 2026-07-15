import Foundation

enum StudioWorkspaceKind: String, CaseIterable, Identifiable, Hashable, Sendable {
  case assets
  case rig
  case animate
  case show
  case hardware

  var id: Self { self }

  var descriptor: StudioWorkspaceDescriptor {
    switch self {
    case .assets:
      StudioWorkspaceDescriptor(
        id: self,
        title: "Assets",
        systemImage: "square.and.arrow.down",
        purpose: "Import and organize source media",
        viewportLabel: "ASSET PREVIEW",
        defaultPresentation: WorkspacePresentation(
          showsNavigator: true,
          showsInspector: true,
          showsBottomEditor: false
        )
      )
    case .rig:
      StudioWorkspaceDescriptor(
        id: self,
        title: "Rig",
        systemImage: "point.3.connected.trianglepath.dotted",
        purpose: "Define components, mates, DOFs, and limits",
        viewportLabel: "RIG VIEW",
        defaultPresentation: WorkspacePresentation(
          showsNavigator: true,
          showsInspector: true,
          showsBottomEditor: false
        )
      )
    case .animate:
      StudioWorkspaceDescriptor(
        id: self,
        title: "Animate",
        systemImage: "play.circle.fill",
        purpose: "Author clips, keyframes, and curves",
        viewportLabel: "ANIMATION PREVIEW",
        defaultPresentation: WorkspacePresentation(
          showsNavigator: true,
          showsInspector: true,
          showsBottomEditor: true
        )
      )
    case .show:
      StudioWorkspaceDescriptor(
        id: self,
        title: "Show",
        systemImage: "sparkles.rectangle.stack",
        purpose: "Sequence characters, media, screens, and events",
        viewportLabel: "SHOW PREVIEW",
        defaultPresentation: WorkspacePresentation(
          showsNavigator: true,
          showsInspector: true,
          showsBottomEditor: true
        )
      )
    case .hardware:
      StudioWorkspaceDescriptor(
        id: self,
        title: "Hardware",
        systemImage: "cable.connector",
        purpose: "Map, calibrate, monitor, and safely arm outputs",
        viewportLabel: "HARDWARE STATUS",
        defaultPresentation: WorkspacePresentation(
          showsNavigator: true,
          showsInspector: true,
          showsBottomEditor: false
        )
      )
    }
  }

  var shortcutNumber: Int {
    switch self {
    case .assets: 1
    case .rig: 2
    case .animate: 3
    case .show: 4
    case .hardware: 5
    }
  }
}

struct StudioWorkspaceDescriptor: Identifiable, Hashable, Sendable {
  let id: StudioWorkspaceKind
  let title: String
  let systemImage: String
  let purpose: String
  let viewportLabel: String
  let defaultPresentation: WorkspacePresentation
}

struct WorkspacePresentation: Equatable, Hashable, Sendable {
  var showsNavigator: Bool
  var showsInspector: Bool
  var showsBottomEditor: Bool
}
