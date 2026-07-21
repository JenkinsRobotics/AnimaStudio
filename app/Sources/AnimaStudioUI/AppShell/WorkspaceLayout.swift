import Foundation
import Observation

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

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.panelsOnOuterEdge = defaults.bool(forKey: StudioPreferenceKey.panelsOnOuterEdge)
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
