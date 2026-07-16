import AnimaCoreClient
import Foundation

struct RelationDOFOption: Identifiable, Equatable, Sendable {
  let path: String
  let mateName: String
  let mateTrackingID: String
  let kind: AnimaCoreDOFKind

  var id: String { path }

  var displayName: String {
    mateTrackingID.isEmpty ? mateName : mateTrackingID
  }
}

struct RelationDraft: Identifiable, Equatable, Sendable {
  let id = UUID()
  let type: AnimaCoreRelationTypeSummary
  var driverPath: String?
  var drivenPath: String?
  var ratioFieldValue: Double
  var isReversed = false

  init(type: AnimaCoreRelationTypeSummary) {
    self.type = type
    self.ratioFieldValue = type.ratioField.unit == "mm" ? 10 : 1
  }

  var canPrepareForAuthoring: Bool {
    guard let driverPath, let drivenPath else { return false }
    return driverPath != drivenPath && ratioFieldValue.isFinite && ratioFieldValue > 0
  }

  /// The signed value the future canonical-document mutation will send back
  /// through AnimaCore validation. This is UI unit conversion only; relation
  /// evaluation and dependency semantics remain engine-owned.
  var signedSemanticRatio: Double? {
    guard ratioFieldValue.isFinite, ratioFieldValue > 0 else { return nil }
    let magnitude =
      type.ratioField.unit == "mm"
      ? ratioFieldValue / 1_000 / (2 * .pi)
      : ratioFieldValue
    return isReversed ? -magnitude : magnitude
  }
}

struct RelationEditorPresentation: Equatable, Sendable {
  let type: AnimaCoreRelationTypeSummary

  var fieldTitle: String {
    switch type.ratioField.key {
    case "relation_ratio": "Relation ratio"
    case "distance_per_revolution": "Distance per revolution"
    default:
      type.ratioField.key
        .replacingOccurrences(of: "_", with: " ")
        .capitalized
    }
  }

  var fieldUnit: String? {
    type.ratioField.unit == "ratio" ? nil : type.ratioField.unit
  }

  var driverPrompt: String {
    "Select a \(type.driverKind.displayName.lowercased()) mate DOF"
  }

  var drivenPrompt: String {
    "Select a \(type.drivenKind.displayName.lowercased()) mate DOF"
  }

  var compatibilitySummary: String {
    "\(type.driverKind.displayName) driver → \(type.drivenKind.displayName) driven"
  }
}

extension AnimaCoreDOFKind {
  var displayName: String {
    switch self {
    case .rotation: "Rotation"
    case .translation: "Translation"
    }
  }
}

extension AnimaCoreRelationKind {
  var systemImage: String {
    switch self {
    case .gear: "gearshape.2"
    case .rackPinion: "arrow.left.and.right.circle"
    case .screw: "screwdriver"
    case .linear: "arrow.left.and.right"
    }
  }
}
