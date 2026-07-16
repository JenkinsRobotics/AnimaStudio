import Foundation

enum UIDevSection: String, CaseIterable, Identifiable, Sendable {
  case overview
  case templateMatrix
  case designKit
  case navigator
  case inspector
  case timeline
  case workspace3D
  case buttons
  case inputs
  case menus
  case panels
  case mateEditor
  case triadManipulator
  case dialogs
  case popovers
  case tokens

  var id: Self { self }

  var title: String {
    switch self {
    case .overview: "Overview"
    case .templateMatrix: "Template Matrix"
    case .designKit: "Live UI Kit"
    case .navigator: "Navigator Preview"
    case .inspector: "Inspector Preview"
    case .timeline: "Timeline Preview"
    case .workspace3D: "3D Workspace Preview"
    case .buttons: "Buttons"
    case .inputs: "Inputs"
    case .menus: "Menus"
    case .panels: "Windows & Panels"
    case .mateEditor: "Mate Editor"
    case .triadManipulator: "Triad Manipulator"
    case .dialogs: "Dialogs"
    case .popovers: "Popovers"
    case .tokens: "Design Tokens"
    }
  }

  var systemImage: String {
    switch self {
    case .overview: "square.grid.2x2"
    case .templateMatrix: "rectangle.3.group.fill"
    case .designKit: "paintbrush.pointed.fill"
    case .navigator: "sidebar.left"
    case .inspector: "sidebar.right"
    case .timeline: "rectangle.bottomthird.inset.filled"
    case .workspace3D: "view.3d"
    case .buttons: "button.programmable"
    case .inputs: "character.cursor.ibeam"
    case .menus: "filemenu.and.selection"
    case .panels: "macwindow.on.rectangle"
    case .mateEditor: "link.badge.plus"
    case .triadManipulator: "move.3d"
    case .dialogs: "rectangle.on.rectangle.angled"
    case .popovers: "bubble.left.and.text.bubble.right"
    case .tokens: "paintpalette"
    }
  }

  var purpose: String {
    switch self {
    case .overview: "The shared interaction and visual rules for every Studio surface."
    case .templateMatrix:
      "Review every current Studio window, panel, inspector, timeline, and control together."
    case .designKit: "Edit the shared visual tokens and review every production UI family live."
    case .navigator: "Review the real Navigator docked at the left of the production viewport."
    case .inspector: "Review the real Inspector docked at the right of the production viewport."
    case .timeline: "Review the real Timeline docked below the production viewport."
    case .workspace3D: "Review the production 3D viewport inside the UI Dev workspace canvas."
    case .buttons: "Primary, secondary, quiet, destructive, selected, and disabled actions."
    case .inputs: "Text, number, picker, search, toggle, unit, and read-only fields."
    case .menus: "System-native command menus with consistent labels and hierarchy."
    case .panels: "Reusable headers, spacing, surfaces, resizing, and dismissal patterns."
    case .mateEditor: "Refine the compact connector, offset, and mate-action workflow."
    case .triadManipulator: "Tune the interactive translation, rotation, and plane handles."
    case .dialogs: "Alerts and confirmation flows reserved for blocking decisions."
    case .popovers: "Lightweight contextual help and settings without leaving the task."
    case .tokens: "One source of truth for color, spacing, radii, and control dimensions."
    }
  }

  var isEmbeddedWorkspacePreview: Bool {
    switch self {
    case .navigator, .inspector, .timeline, .workspace3D:
      true
    case .overview, .templateMatrix, .designKit, .buttons, .inputs, .menus, .panels, .mateEditor,
      .triadManipulator, .dialogs, .popovers, .tokens:
      false
    }
  }
}

enum UIDevWorkspaceDescriptor {
  static let title = "UI Dev"
  static let systemImage = "hammer.fill"
  static let purpose = "Build and review the Studio design system"
  static let shortcutNumber = 6
}

enum UIDevAgentPanelDescriptor {
  static let title = "Anima Agent"
  static var width: CGFloat { StudioMetrics.agentWidth }
  static let isDocked = true
}
