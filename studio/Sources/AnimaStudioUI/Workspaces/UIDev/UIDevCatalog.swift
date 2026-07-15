import Foundation

enum UIDevSection: String, CaseIterable, Identifiable, Sendable {
  case overview
  case buttons
  case inputs
  case menus
  case panels
  case dialogs
  case popovers
  case tokens

  var id: Self { self }

  var title: String {
    switch self {
    case .overview: "Overview"
    case .buttons: "Buttons"
    case .inputs: "Inputs"
    case .menus: "Menus"
    case .panels: "Windows & Panels"
    case .dialogs: "Dialogs"
    case .popovers: "Popovers"
    case .tokens: "Design Tokens"
    }
  }

  var systemImage: String {
    switch self {
    case .overview: "square.grid.2x2"
    case .buttons: "button.programmable"
    case .inputs: "character.cursor.ibeam"
    case .menus: "filemenu.and.selection"
    case .panels: "macwindow.on.rectangle"
    case .dialogs: "rectangle.on.rectangle.angled"
    case .popovers: "bubble.left.and.text.bubble.right"
    case .tokens: "paintpalette"
    }
  }

  var purpose: String {
    switch self {
    case .overview: "The shared interaction and visual rules for every Studio surface."
    case .buttons: "Primary, secondary, quiet, destructive, selected, and disabled actions."
    case .inputs: "Text, number, picker, search, toggle, unit, and read-only fields."
    case .menus: "System-native command menus with consistent labels and hierarchy."
    case .panels: "Reusable headers, spacing, surfaces, resizing, and dismissal patterns."
    case .dialogs: "Alerts and confirmation flows reserved for blocking decisions."
    case .popovers: "Lightweight contextual help and settings without leaving the task."
    case .tokens: "One source of truth for color, spacing, radii, and control dimensions."
    }
  }
}

enum UIDevWorkspaceDescriptor {
  static let title = "UI Dev"
  static let systemImage = "hammer.fill"
  static let purpose = "Build and review the Studio design system"
  static let shortcutNumber = 6
}
