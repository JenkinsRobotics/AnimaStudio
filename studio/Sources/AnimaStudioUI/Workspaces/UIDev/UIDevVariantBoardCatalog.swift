import Foundation

enum UIDevVariantFamily: String, CaseIterable, Identifiable, Sendable {
  case workspaceChrome
  case sidePanels
  case inspectors
  case timelines
  case toolbars
  case dialogsAndMenus
  case statusAndFeedback

  var id: Self { self }

  var title: String {
    switch self {
    case .workspaceChrome: "Workspace Chrome"
    case .sidePanels: "Docked Panels"
    case .inspectors: "Inspector Variants"
    case .timelines: "Timeline Variants"
    case .toolbars: "Toolbars & Tool Rails"
    case .dialogsAndMenus: "Dialogs, Popovers & Menus"
    case .statusAndFeedback: "Status & Feedback"
    }
  }

  var detail: String {
    switch self {
    case .workspaceChrome:
      "Document, workspace, ribbon, and compact-header configurations."
    case .sidePanels:
      "Navigator and assistant states at their intended docked proportions."
    case .inspectors:
      "Selection-specific property panels sharing one shell and field language."
    case .timelines:
      "Dopesheet, motion-curve, show-control, and empty timeline presentations."
    case .toolbars:
      "Horizontal and vertical command groups with default, selected, and unavailable states."
    case .dialogsAndMenus:
      "Blocking decisions and contextual commands compared at production density."
    case .statusAndFeedback:
      "Empty, working, connected, and safety-critical operator feedback."
    }
  }

  var systemImage: String {
    switch self {
    case .workspaceChrome: "macwindow"
    case .sidePanels: "sidebar.left"
    case .inspectors: "sidebar.right"
    case .timelines: "timeline.selection"
    case .toolbars: "wrench.and.screwdriver"
    case .dialogsAndMenus: "rectangle.on.rectangle.angled"
    case .statusAndFeedback: "waveform.path.ecg.rectangle"
    }
  }
}

enum UIDevWindowVariantID: String, CaseIterable, Identifiable, Sendable {
  case documentChrome
  case workspaceRibbon
  case compactWorkspaceChrome
  case navigatorEmpty
  case navigatorHierarchy
  case agentDocked
  case componentInspector
  case mateInspector
  case appearanceInspector
  case hardwareInspector
  case dopeSheetTimeline
  case motionCurveTimeline
  case showControlTimeline
  case emptyTimeline
  case commandToolbar
  case selectionToolbar
  case disabledToolbar
  case verticalToolRail
  case informationDialog
  case confirmationDialog
  case graphicsPopover
  case componentContextMenu
  case emptyWorkspace
  case processingStatus
  case connectedStatus
  case emergencyStatus

  var id: Self { self }
}

struct UIDevWindowVariantDescriptor: Identifiable, Equatable, Sendable {
  let id: UIDevWindowVariantID
  let title: String
  let detail: String
  let family: UIDevVariantFamily
  let idealWidth: Int
  let idealHeight: Int
  let stateLabel: String
  let systemImage: String

  var idealSizeLabel: String {
    "\(idealWidth) × \(idealHeight)"
  }
}

enum UIDevVariantBoardCatalog {
  static let variants: [UIDevWindowVariantDescriptor] = [
    descriptor(
      .documentChrome, "Document Header", "Project identity, save state, and live output.",
      .workspaceChrome, 1_280, 44, "DOCUMENT", "doc.text"),
    descriptor(
      .workspaceRibbon, "Workspace + Ribbon", "Workspace selector with contextual creation tools.",
      .workspaceChrome, 1_280, 150, "EXPANDED", "rectangle.topthird.inset.filled"),
    descriptor(
      .compactWorkspaceChrome, "Compact Workspace",
      "Collapsed command row for viewport-first work.",
      .workspaceChrome, 1_280, 82, "COMPACT", "rectangle.compress.vertical"),

    descriptor(
      .navigatorEmpty, "Navigator · Empty", "First-use structure with a clear next action.",
      .sidePanels, 320, 520, "EMPTY", "sidebar.left"),
    descriptor(
      .navigatorHierarchy, "Navigator · Populated", "Groups, components, mates, and assets.",
      .sidePanels, 320, 520, "ACTIVE", "list.bullet.indent"),
    descriptor(
      .agentDocked, "Anima Agent · Docked", "In-app assistant constrained to the workspace.",
      .sidePanels, 360, 560, "DOCKED", "sparkles"),

    descriptor(
      .componentInspector, "Component", "Identity, transform, visibility, and selection actions.",
      .inspectors, 340, 520, "SELECTED", "cube"),
    descriptor(
      .mateInspector, "Mate", "Type, connectors, offsets, limits, and solve actions.",
      .inspectors, 350, 540, "EDITING", "link"),
    descriptor(
      .appearanceInspector, "Appearance", "Palette, material, opacity, and quality controls.",
      .inspectors, 340, 520, "APPEARANCE", "paintpalette"),
    descriptor(
      .hardwareInspector, "Hardware", "Driver, safety, device, channel, and heartbeat state.",
      .inspectors, 360, 500, "OFFLINE", "cable.connector"),

    descriptor(
      .dopeSheetTimeline, "Dopesheet", "Dense rows, frame ruler, keys, and blue playhead.",
      .timelines, 1_080, 460, "KEYFRAMES", "diamond.fill"),
    descriptor(
      .motionCurveTimeline, "Motion Curves", "Value-aware paths connecting authored waypoints.",
      .timelines, 1_080, 460, "CURVES", "point.topleft.down.to.point.bottomright.curvepath"),
    descriptor(
      .showControlTimeline, "Show Control", "Character, audio, video, and event lanes.",
      .timelines, 1_080, 420, "SHOW", "music.note.list"),
    descriptor(
      .emptyTimeline, "Empty Timeline", "First track action and transport without authored motion.",
      .timelines, 1_080, 300, "EMPTY", "timeline.selection"),

    descriptor(
      .commandToolbar, "Command Toolbar", "Default grouped viewport and authoring commands.",
      .toolbars, 720, 84, "DEFAULT", "rectangle.grid.3x2"),
    descriptor(
      .selectionToolbar, "Selection Toolbar", "Selected tools retain icon, label, and state.",
      .toolbars, 720, 84, "SELECTED", "checkmark.square"),
    descriptor(
      .disabledToolbar, "Unavailable Tools", "Planned commands remain legible and explainable.",
      .toolbars, 720, 84, "DISABLED", "lock"),
    descriptor(
      .verticalToolRail, "Vertical Tool Rail", "Compact mode and property-family navigation.",
      .toolbars, 76, 520, "VERTICAL", "rectangle.split.1x2"),

    descriptor(
      .informationDialog, "Information", "One blocking message with one safe exit.",
      .dialogsAndMenus, 360, 180, "MODAL", "info.circle"),
    descriptor(
      .confirmationDialog, "Confirmation", "Named consequence, Cancel, and destructive action.",
      .dialogsAndMenus, 400, 230, "DESTRUCTIVE", "trash"),
    descriptor(
      .graphicsPopover, "Graphics Popover", "Anchored render and viewport settings.",
      .dialogsAndMenus, 320, 300, "POPOVER", "cube.transparent"),
    descriptor(
      .componentContextMenu, "Component Menu", "CAD-style grouped commands and destructive tail.",
      .dialogsAndMenus, 300, 440, "CONTEXT", "filemenu.and.selection"),

    descriptor(
      .emptyWorkspace, "Empty Workspace", "Clear start action without fake content.",
      .statusAndFeedback, 460, 280, "EMPTY", "square.dashed"),
    descriptor(
      .processingStatus, "Processing", "Progress, current operation, and cancellation.",
      .statusAndFeedback, 400, 200, "WORKING", "progress.indicator"),
    descriptor(
      .connectedStatus, "Hardware Connected", "Positive device and heartbeat confirmation.",
      .statusAndFeedback, 400, 190, "READY", "checkmark.circle"),
    descriptor(
      .emergencyStatus, "Emergency Stop", "Safety state dominates every secondary action.",
      .statusAndFeedback, 440, 220, "CRITICAL", "stop.fill"),
  ]

  static func variants(in family: UIDevVariantFamily) -> [UIDevWindowVariantDescriptor] {
    variants.filter { $0.family == family }
  }

  private static func descriptor(
    _ id: UIDevWindowVariantID,
    _ title: String,
    _ detail: String,
    _ family: UIDevVariantFamily,
    _ idealWidth: Int,
    _ idealHeight: Int,
    _ stateLabel: String,
    _ systemImage: String
  ) -> UIDevWindowVariantDescriptor {
    UIDevWindowVariantDescriptor(
      id: id,
      title: title,
      detail: detail,
      family: family,
      idealWidth: idealWidth,
      idealHeight: idealHeight,
      stateLabel: stateLabel,
      systemImage: systemImage
    )
  }
}
