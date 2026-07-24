import Foundation
import Observation
import SwiftUI

/// The center representation shown inside a workspace. These modes change
/// how the same project data is presented; they never create a second model.
enum StudioCenterViewMode: String, CaseIterable, Identifiable, Sendable {
  case threeD
  case gallery
  case table
  case exploded
  case dopeSheet
  case curves
  case nodeGraph
  case servoTimeline

  var id: Self { self }

  var title: String {
    switch self {
    case .threeD: "3D"
    case .gallery: "Gallery"
    case .table: "Table"
    case .exploded: "Exploded"
    case .dopeSheet: "Dope Sheet"
    case .curves: "Curves"
    case .nodeGraph: "Node Graph"
    case .servoTimeline: "Servo Timeline"
    }
  }

  var systemImage: String {
    switch self {
    case .threeD: "cube"
    case .gallery: "square.grid.2x2"
    case .table: "list.bullet.rectangle"
    case .exploded: "square.3.layers.3d"
    case .dopeSheet: "diamond.fill"
    case .curves: "point.3.filled.connected.trianglepath.dotted"
    case .nodeGraph: "point.3.connected.trianglepath.dotted"
    case .servoTimeline: "slider.horizontal.3"
    }
  }
}

enum StudioCenterViewCatalog {
  static func modes(for workspace: StudioWorkspaceKind) -> [StudioCenterViewMode] {
    switch workspace {
    case .assets: [.threeD, .gallery, .table]
    case .rig: [.threeD, .table, .exploded]
    case .animate: [.threeD, .dopeSheet, .curves]
    case .show: [.nodeGraph, .table, .threeD]
    case .hardware: [.servoTimeline, .table, .threeD]
    case .nodes, .design, .canvas2d: []
    }
  }

  static func defaultMode(for workspace: StudioWorkspaceKind) -> StudioCenterViewMode? {
    modes(for: workspace).first
  }
}

/// The rectangular area guaranteed not to sit behind live shell chrome.
/// Spatial canvases intentionally ignore this value; structured content reads
/// it from the environment and pads itself into the visible zone.
struct StudioVisibleZoneInsets: Equatable, Sendable {
  var top: CGFloat = 0
  var leading: CGFloat = 0
  var bottom: CGFloat = 0
  var trailing: CGFloat = 0

  var edgeInsets: EdgeInsets {
    EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
  }
}

/// Compatibility name for structured views built before the visible-zone
/// system gained a bottom edge.
typealias StudioWorkspaceOverlayInsets = StudioVisibleZoneInsets

private struct StudioVisibleZoneInsetsKey: EnvironmentKey {
  static let defaultValue = StudioVisibleZoneInsets()
}

extension EnvironmentValues {
  var studioVisibleZoneInsets: StudioVisibleZoneInsets {
    get { self[StudioVisibleZoneInsetsKey.self] }
    set { self[StudioVisibleZoneInsetsKey.self] = newValue }
  }

  var studioWorkspaceOverlayInsets: StudioWorkspaceOverlayInsets {
    get { studioVisibleZoneInsets }
    set { studioVisibleZoneInsets = newValue }
  }
}

struct StudioFloatingPanelFootprint: Equatable, Sendable {
  let side: StudioSidebarSide
  let minimumX: CGFloat
  let maximumX: CGFloat
}

enum StudioVisibleZoneLayout {
  // Rail edge (14 pad + 44 rail = 58) plus the same gap panels use, so the
  // visible zone never sits flush against the side rails — the left/right
  // margins read symmetric with the top/bottom breathing room.
  static let sideRailInset: CGFloat = 58 + 22
  static let bottomSwitcherInset: CGFloat = 76
  static let dockedInset: CGFloat = 10
  // Breathing room between a floating panel's outer edge and the center canvas,
  // so the sidebar stack doesn't sit flush against the visual workspace.
  static let floatingPanelGap: CGFloat = 22
  /// An open docked-in-floating stack's origin is rail(44) + edge pad(14) inboard
  /// of the window edge; add the panel width + this to clear it plus the gap.
  static let openStackInset: CGFloat = 44 + 14 + floatingPanelGap

  static func insets(
    preset: StudioLayoutPreset,
    toolInset: CGFloat,
    hasCenterSwitcher: Bool,
    leftStackOpen: Bool,
    rightStackOpen: Bool,
    revealedTop: Bool = true,
    revealedLeading: Bool = true,
    revealedTrailing: Bool = true,
    canvasWidth: CGFloat = 0,
    floatingPanels: [StudioFloatingPanelFootprint] = []
  ) -> StudioVisibleZoneInsets {
    if preset == .docked {
      return StudioVisibleZoneInsets(
        top: dockedInset,
        leading: dockedInset,
        bottom: hasCenterSwitcher ? bottomSwitcherInset : dockedInset,
        trailing: dockedInset
      )
    }

    let topVisible = preset == .floating || revealedTop
    let leadingVisible = preset == .floating || revealedLeading
    let trailingVisible = preset == .floating || revealedTrailing
    var result = StudioVisibleZoneInsets(
      top: topVisible ? toolInset : 0,
      leading: leadingVisible
        ? (leftStackOpen ? StudioSidebarSizing.workspacePanelWidth + openStackInset : sideRailInset)
        : 0,
      bottom: hasCenterSwitcher ? bottomSwitcherInset : 0,
      trailing: trailingVisible
        ? (rightStackOpen ? StudioSidebarSizing.viewPanelWidth + openStackInset : sideRailInset)
        : 0
    )

    guard canvasWidth > 0 else { return result }
    for panel in floatingPanels {
      switch panel.side {
      case .leading:
        result.leading = max(result.leading, panel.maximumX + floatingPanelGap)
      case .trailing:
        result.trailing = max(
          result.trailing,
          canvasWidth - panel.minimumX + floatingPanelGap
        )
      }
    }
    return result
  }
}

/// One presentation contract for every in-window workspace region.
///
/// Docked regions participate in layout, floating regions overlay a spatial
/// canvas, and hidden regions stay available through the layout menu (and the
/// canvas edge reveal affordance).
enum StudioPanelPlacement: String, CaseIterable, Identifiable, Sendable {
  case docked
  case floating
  case hidden

  var id: Self { self }

  var title: String {
    switch self {
    case .docked: "Docked"
    case .floating: "Floating"
    case .hidden: "Hidden"
    }
  }

  var systemImage: String {
    switch self {
    case .docked: "rectangle.split.3x1"
    case .floating: "macwindow"
    case .hidden: "eye.slash"
    }
  }
}

enum StudioFloatingRibbonEdge: String, CaseIterable, Identifiable, Sendable {
  case top
  case bottom

  var id: Self { self }
  var title: String { self == .top ? "Top" : "Bottom" }
}

enum StudioLayoutPreset: String, CaseIterable, Identifiable, Sendable {
  case floating = "studio"
  case docked
  case canvas

  var id: Self { self }

  var title: String {
    switch self {
    case .floating: "Floating"
    case .docked: "Docked"
    case .canvas: "Canvas"
    }
  }

  var systemImage: String {
    switch self {
    case .floating: "macwindow.on.rectangle"
    case .docked: "rectangle.split.3x1"
    case .canvas: "viewfinder"
    }
  }

  var tintRole: WorkspaceRibbonGroupRole {
    switch self {
    case .floating: .components
    case .docked: .mates
    case .canvas: .hardware
    }
  }

  var navigatorPlacement: StudioPanelPlacement {
    switch self {
    case .floating: .floating
    case .docked: .docked
    case .canvas: .hidden
    }
  }

  var inspectorPlacement: StudioPanelPlacement { navigatorPlacement }

  var ribbonPlacement: StudioPanelPlacement {
    switch self {
    case .floating, .canvas: .floating
    case .docked: .docked
    }
  }

  var next: Self {
    switch self {
    case .floating: .docked
    case .docked: .canvas
    case .canvas: .floating
    }
  }
}

/// One app-global owner for the shell's Floating, Docked, and Canvas mode.
/// Workspaces read this shared state instead of keeping placement in local view
/// branches, so switching workspace or presentation cannot reset the shell.
@MainActor
@Observable
final class StudioLayoutState {
  static let shared = StudioLayoutState()

  @ObservationIgnored private let defaults: UserDefaults

  var navigatorPlacement: StudioPanelPlacement = .floating
  var inspectorPlacement: StudioPanelPlacement = .floating
  var ribbonPlacement: StudioPanelPlacement = .floating
  var floatingRibbonEdge: StudioFloatingRibbonEdge = .top
  /// Keeps the floating panel stack against the window edge and moves the
  /// icon rail inboard. The standard arrangement keeps the rail at the edge.
  var panelsOnOuterEdge: Bool {
    didSet { defaults.set(panelsOnOuterEdge, forKey: StudioPreferenceKey.panelsOnOuterEdge) }
  }
  /// Development-only visualization for the shell's content-safe rectangle.
  var showsLayoutZones: Bool {
    didSet { defaults.set(showsLayoutZones, forKey: StudioPreferenceKey.showsLayoutZones) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.panelsOnOuterEdge = defaults.bool(forKey: StudioPreferenceKey.panelsOnOuterEdge)
    self.showsLayoutZones = defaults.bool(forKey: StudioPreferenceKey.showsLayoutZones)
  }

  var detectedPreset: StudioLayoutPreset? {
    StudioLayoutPreset.allCases.first {
      $0.navigatorPlacement == navigatorPlacement
        && $0.inspectorPlacement == inspectorPlacement
        && $0.ribbonPlacement == ribbonPlacement
    }
  }

  func apply(_ preset: StudioLayoutPreset) {
    navigatorPlacement = preset.navigatorPlacement
    inspectorPlacement = preset.inspectorPlacement
    ribbonPlacement = preset.ribbonPlacement
  }

  func cyclePreset() {
    apply((detectedPreset ?? .canvas).next)
  }
}
