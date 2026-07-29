import Foundation

enum StudioSettingsGroup: String, CaseIterable, Identifiable {
  case general = "General"
  case viewport = "Viewport"
  case advanced = "Advanced"

  var id: Self { self }
}

enum StudioSettingsTab: String, CaseIterable, Identifiable {
  case workspace
  case renderer = "rendering"
  case appearance
  case materialsAndEdges
  case lighting
  case layout
  case navigation
  case interface = "ui"
  case developer

  var id: Self { self }

  var title: String {
    switch self {
    case .workspace: "Workspace"
    case .renderer: "Renderer"
    case .appearance: "Appearance"
    case .materialsAndEdges: "Materials & Edges"
    case .lighting: "Lighting"
    case .layout: "Layout"
    case .navigation: "Navigation"
    case .interface: "UI"
    case .developer: "Developer"
    }
  }

  var systemImage: String {
    switch self {
    case .workspace: "folder"
    case .renderer: "cube.transparent"
    case .appearance: "paintpalette"
    case .materialsAndEdges: "square.3.layers.3d"
    case .lighting: "light.max"
    case .layout: "rectangle.split.3x1"
    case .navigation: "computermouse"
    case .interface: "sidebar.squares.left"
    case .developer: "hammer"
    }
  }

  var detail: String {
    switch self {
    case .workspace: "Projects and authoring defaults"
    case .renderer: "Viewport backend and quality"
    case .appearance: "Scene and environment presets"
    case .materialsAndEdges: "Surface and CAD edge treatment"
    case .lighting: "Viewport and CAD light rigs"
    case .layout: "Studio mode and panel placement"
    case .navigation: "Mouse and trackpad controls"
    case .interface: "Chrome, tools, and visual language"
    case .developer: "Diagnostics and experimental workspaces"
    }
  }

  var group: StudioSettingsGroup {
    switch self {
    case .workspace, .layout, .interface: .general
    case .renderer, .appearance, .materialsAndEdges, .lighting, .navigation: .viewport
    case .developer: .advanced
    }
  }
}

enum StudioWorkspaceTabDefaults {
  static let showsNodes = false
  static let showsDesign = false
  static let showsUIDev = true
}

enum StudioWorkspaceNavigation {
  static func visibleStages(
    characterType: StudioCharacterType = .threeD,
    showNodes: Bool,
    showDesign: Bool
  ) -> [StudioWorkspaceKind] {
    // One character-type-specific authoring tab replaces the fixed Rig tab.
    var stages: [StudioWorkspaceKind] = [
      .assets, characterType.authoringWorkspace, .animate, .show,
    ]
    if showNodes { stages.append(.nodes) }
    stages.append(.hardware)
    if showDesign { stages.append(.design) }
    return stages
  }
}
