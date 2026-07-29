import Foundation

enum StudioWorkspaceKind: String, CaseIterable, Identifiable, Hashable, Sendable {
  case assets
  case rig
  case animate
  case canvas2d
  case vr
  case show
  case nodes
  case hardware
  case design

  var id: Self { self }

  // Matches the accepted demo strip: the five authoring stages + UI Dev
  // (appended in WorkspaceStageTabs). Nodes and Design remain reachable
  // workspaces (⌘5 / ⌘7, home cards) but are not top-level tabs.
  static let centeredNavigation: [Self] = [
    .assets, .rig, .animate, .show, .hardware,
  ]

  var descriptor: StudioWorkspaceDescriptor {
    switch self {
    case .assets:
      StudioWorkspaceDescriptor(
        id: self,
        title: "Assets",
        systemImage: "square.and.arrow.down",
        purpose: "Import and organize character assets and source media",
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
        title: "3D Modeling",
        systemImage: "point.3.connected.trianglepath.dotted",
        purpose: "Assemble parts and mates, group sub-assemblies, and set the ground",
        viewportLabel: "3D MODELING VIEW",
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
          showsBottomEditor: false
        )
      )
    case .canvas2d:
      StudioWorkspaceDescriptor(
        id: self,
        title: "2D",
        systemImage: "face.smiling",
        purpose: "Compose 2D surfaces, faces, and media; drive an LED panel",
        viewportLabel: "2D PREVIEW",
        defaultPresentation: WorkspacePresentation(
          showsNavigator: true,
          showsInspector: true,
          showsBottomEditor: false
        )
      )
    case .vr:
      StudioWorkspaceDescriptor(
        id: self,
        title: "VR",
        systemImage: "faceid",
        purpose: "Perform a live avatar driven by face tracking",
        viewportLabel: "VR PREVIEW",
        defaultPresentation: WorkspacePresentation(
          showsNavigator: true,
          showsInspector: true,
          showsBottomEditor: false
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
          showsBottomEditor: false
        )
      )
    case .nodes:
      StudioWorkspaceDescriptor(
        id: self,
        title: "Nodes",
        systemImage: "point.3.connected.trianglepath.dotted",
        purpose: "Plan scene logic, cues, gates, and events",
        viewportLabel: "NODE GRAPH",
        defaultPresentation: WorkspacePresentation(
          showsNavigator: false,
          showsInspector: false,
          showsBottomEditor: false
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
    case .design:
      StudioWorkspaceDescriptor(
        id: self,
        title: "Design",
        systemImage: "pencil.and.ruler",
        purpose: "Sandbox future in-app CAD tools and part properties",
        viewportLabel: "DESIGN SANDBOX",
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
    case .nodes: 5
    case .hardware: 6
    case .design: 7
    case .canvas2d: 8
    case .vr: 9
    }
  }
}

/// A character's authoring type. The Character workspace selects it, and the
/// second workspace tab routes to the matching authoring workspace so 3D, 2D,
/// and VR characters each get an optimal production surface.
enum StudioCharacterType: String, CaseIterable, Identifiable, Sendable {
  case threeD
  case twoD
  case vr

  var id: String { rawValue }

  var title: String {
    switch self {
    case .threeD: "3D"
    case .twoD: "2D"
    case .vr: "VR"
    }
  }

  var systemImage: String {
    switch self {
    case .threeD: "cube"
    case .twoD: "square.on.square"
    case .vr: "faceid"
    }
  }

  /// The authoring workspace the second tab shows for this character type.
  var authoringWorkspace: StudioWorkspaceKind {
    switch self {
    case .threeD: .rig
    case .twoD: .canvas2d
    case .vr: .vr
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
