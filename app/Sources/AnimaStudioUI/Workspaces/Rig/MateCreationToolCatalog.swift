import Foundation

/// UI-facing mate catalog used by the Rig creation ribbon.
///
/// AnimaCore supplies the operational type/category/DOF contract at runtime.
/// This enum is only the stable ribbon presentation order. Revolute retains the
/// transitional local draft action until canonical character mutation ships.
enum MateCreationToolKind: String, CaseIterable, Identifiable, Sendable {
  case fastened
  case parallel
  case slider
  case revolute
  case cylindrical
  case pinSlot
  case planar
  case ball
  case width
  case tangent

  var id: Self { self }

  var title: String {
    switch self {
    case .fastened: "Fastened"
    case .parallel: "Parallel"
    case .slider: "Slider"
    case .revolute: "Revolute"
    case .cylindrical: "Cylindrical"
    case .pinSlot: "Pin Slot"
    case .planar: "Planar"
    case .ball: "Ball"
    case .width: "Width"
    case .tangent: "Tangent"
    }
  }

  var systemImage: String {
    switch self {
    case .fastened: "link"
    case .parallel: "equal.circle"
    case .slider: "arrow.up.and.down"
    case .revolute: "rotate.3d"
    case .cylindrical: "cylinder"
    case .pinSlot: "arrow.left.and.right.circle"
    case .planar: "square.3.layers.3d"
    case .ball: "move.3d"
    case .width: "arrow.left.and.right.square"
    case .tangent: "circle.dotted.and.circle"
    }
  }

  var motionSummary: String {
    switch self {
    case .fastened:
      "Removes all six degrees of freedom."
    case .parallel:
      "Keeps the connector axes parallel while allowing XYZ translation and Z rotation."
    case .slider:
      "Allows translation along the connector Z-axis only."
    case .revolute:
      "Allows rotation around the connector Z-axis only."
    case .cylindrical:
      "Allows translation along and rotation around the connector Z-axis."
    case .pinSlot:
      "Allows translation along X and rotation around Z."
    case .planar:
      "Allows translation in X and Y plus rotation around Z."
    case .ball:
      "Allows rotation around X, Y, and Z while preventing translation."
    case .width:
      "Centers a component between two geometry references; it is not an animation driver."
    case .tangent:
      "Keeps two selected surfaces in contact; geometry is resolved by the app."
    }
  }

  /// Compact degrees-of-freedom readout for inspector rows.
  var dofSummary: String {
    editorDofSummary
  }

  var hasLocalDraftAuthoringAction: Bool {
    self == .revolute
  }
}
