import AnimaEvaluation
import AnimaModel
import Foundation

/// A pick outcome the viewport reports to the owning workspace model.
///
/// One callback channel carries both mate-placement forwarding and the
/// standing sub-object (face/edge/corner/axis/origin) selection so
/// `RobotPreviewView` keeps a single feature-pick contract.
public enum ViewportPickEvent: Equatable, Sendable {
  /// A feature candidate marker was clicked.
  case feature(MateConnectorCandidate)
  /// Clear the standing feature selection; component selection stays.
  case clearFeature
  /// Empty space was clicked: clear feature and component selection.
  case clearAll
}

/// What the pointer hit inside the viewport, reduced to selection semantics.
public enum SubObjectTapTarget: Equatable, Sendable {
  case feature(MateConnectorCandidate)
  case component(PartID)
  case importedNode
  case empty
}

/// Lightweight pointer identity shared with the SwiftUI workspace shell.
/// It deliberately carries semantic IDs rather than RealityKit entities.
public enum ViewportPointerTarget: Equatable, Sendable {
  case feature(PartID)
  case component(PartID)
  case importedNode
  case canvas

  public var semanticPartID: PartID? {
    switch self {
    case .feature(let partID), .component(let partID): partID
    case .importedNode, .canvas: nil
    }
  }
}

public enum ViewportContextMenuTarget: Equatable, Sendable {
  case selectedComponent(PartID)
  case canvas
}

/// The deterministic reaction to a viewport tap.
public enum SubObjectTapOutcome: Equatable, Sendable {
  /// Standing mode: mark the feature selected and report `.feature`.
  case selectFeature(MateConnectorCandidate)
  /// Placement mode: forward to the mate-placement flow untouched.
  case forwardToPlacement(MateConnectorCandidate)
  /// Plain component selection; any standing feature clears.
  case selectComponent(PartID)
  /// Imported source-node selection; any standing feature clears.
  case selectImportedNode
  /// Empty click: clear the feature and the component selection.
  case clearAll
  /// No selection change (empty click during mate placement).
  case ignore
}

/// Rules for standing sub-object selection in the main viewport — the
/// view-cube-style hover/commit interaction generalized to component
/// features. Pure functions so hit resolution and state transitions stay
/// unit-testable without RealityKit.
public enum SubObjectSelection {
  public static func pointerTarget(for target: SubObjectTapTarget) -> ViewportPointerTarget {
    switch target {
    case .feature(let candidate): .feature(candidate.partID)
    case .component(let partID): .component(partID)
    case .importedNode: .importedNode
    case .empty: .canvas
    }
  }

  /// The detailed object menu is intentionally limited to the selected
  /// component under the pointer. Right-clicking anywhere else gets the
  /// compact canvas menu, even while another component remains selected.
  public static func contextMenuTarget(
    pointerTarget: ViewportPointerTarget,
    selectedPartID: PartID?
  ) -> ViewportContextMenuTarget {
    guard let hoveredPartID = pointerTarget.semanticPartID,
      hoveredPartID == selectedPartID
    else { return .canvas }
    return .selectedComponent(hoveredPartID)
  }

  /// Resolves a tap into its selection outcome. During mate placement the
  /// existing placement flow wins: feature taps forward unchanged and empty
  /// clicks do nothing, so placement is never double-handled.
  public static func outcome(
    forTapOn target: SubObjectTapTarget,
    isPlacementActive: Bool
  ) -> SubObjectTapOutcome {
    switch target {
    case .feature(let candidate):
      isPlacementActive ? .forwardToPlacement(candidate) : .selectFeature(candidate)
    case .component(let partID):
      .selectComponent(partID)
    case .importedNode:
      .selectImportedNode
    case .empty:
      isPlacementActive ? .ignore : .clearAll
    }
  }

  /// Escape clears the standing feature before component selection clears.
  /// The key event is consumed only for that first stage; mate placement and
  /// text editing keep their existing Escape behavior.
  public static func shouldConsumeEscape(
    hasFeatureSelection: Bool,
    isPlacementActive: Bool,
    isTextInputActive: Bool
  ) -> Bool {
    hasFeatureSelection && !isPlacementActive && !isTextInputActive
  }

  /// A standing feature stays selected only while its owning component is
  /// the focused component.
  public static func featureSurvivesFocusChange(
    _ feature: MateConnectorCandidate?,
    focusedPartID: PartID?
  ) -> Bool {
    guard let feature else { return false }
    return feature.partID == focusedPartID
  }
}

extension MateConnectorFeatureKind {
  /// Operator-facing label for inspector readouts.
  public var displayName: String {
    switch self {
    case .origin: "Origin"
    case .faceCenter: "Face Center"
    case .edgeMidpoint: "Edge Midpoint"
    case .corner: "Corner"
    case .axis: "Axis"
    case .surfacePoint: "Surface Point"
    }
  }
}
