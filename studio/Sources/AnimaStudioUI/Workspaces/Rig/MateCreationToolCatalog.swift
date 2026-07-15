import Foundation

/// UI-facing mate catalog used by the Rig creation ribbon.
///
/// The operational type and DOF definitions will come from AnimaCore when the
/// typed-mate backend lands. Until then, only Revolute maps to an authoring
/// action; the remaining entries are honest, disabled previews of that contract.
enum MateCreationToolKind: String, CaseIterable, Identifiable, Sendable {
  case fastened
  case parallel
  case slider
  case revolute
  case cylindrical
  case pinSlot
  case planar
  case ball

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
    }
  }

  var isImplemented: Bool {
    self == .revolute
  }
}
