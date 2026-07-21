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
  case studio
  case docked
  case canvas

  var id: Self { self }

  var title: String {
    switch self {
    case .studio: "Floating"
    case .docked: "Docked"
    case .canvas: "Canvas"
    }
  }

  var systemImage: String {
    switch self {
    case .studio: "macwindow.on.rectangle"
    case .docked: "rectangle.split.3x1"
    case .canvas: "viewfinder"
    }
  }

  var tintRole: WorkspaceRibbonGroupRole {
    switch self {
    case .studio: .components
    case .docked: .mates
    case .canvas: .hardware
    }
  }

  var navigatorPlacement: StudioPanelPlacement {
    switch self {
    case .studio: .floating
    case .docked: .docked
    case .canvas: .hidden
    }
  }

  var inspectorPlacement: StudioPanelPlacement { navigatorPlacement }

  var ribbonPlacement: StudioPanelPlacement {
    switch self {
    case .studio, .canvas: .floating
    case .docked: .docked
    }
  }

  var next: Self {
    switch self {
    case .studio: .docked
    case .docked: .canvas
    case .canvas: .studio
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

  var navigatorPlacement: StudioPanelPlacement = .floating
  var inspectorPlacement: StudioPanelPlacement = .floating
  var ribbonPlacement: StudioPanelPlacement = .floating
  var floatingRibbonEdge: StudioFloatingRibbonEdge = .top

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
