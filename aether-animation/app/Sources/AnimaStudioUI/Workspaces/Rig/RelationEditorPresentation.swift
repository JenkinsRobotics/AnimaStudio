import AnimaCoreClient
import Foundation

enum RelationAuthoringError: LocalizedError, Equatable {
  case missingDriver
  case missingDriven
  case sameDegreeOfFreedom
  case invalidMagnitude
  case invalidOffset
  case incompatibleDriver
  case incompatibleDriven
  case invalidDocument

  var errorDescription: String? {
    switch self {
    case .missingDriver:
      "Select a driver DOF."
    case .missingDriven:
      "Select a driven DOF."
    case .sameDegreeOfFreedom:
      "Driver and driven must be different DOFs."
    case .invalidMagnitude:
      "Enter a finite relation value greater than zero."
    case .invalidOffset:
      "Enter a finite driven offset."
    case .incompatibleDriver:
      "The selected driver no longer matches this relation type."
    case .incompatibleDriven:
      "The selected driven DOF no longer matches this relation type."
    case .invalidDocument:
      "The engine relation document is not an object."
    }
  }
}

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
  var offsetFieldValue: Double
  var isReversed = false

  init(type: AnimaCoreRelationTypeSummary) {
    self.type = type
    self.ratioFieldValue = type.ratioField.unit == "mm" ? 10 : 1
    self.offsetFieldValue = 0
  }

  init(
    relation: AnimaCoreRelationSummary,
    type: AnimaCoreRelationTypeSummary
  ) {
    self.type = type
    self.driverPath = relation.driver
    self.drivenPath = relation.driven
    self.ratioFieldValue = relation.ratioFieldValue
    self.offsetFieldValue =
      type.drivenKind == .translation
      ? relation.offset * 1_000
      : relation.offset * 180 / .pi
    self.isReversed = relation.isReversed
  }

  var canPrepareForAuthoring: Bool {
    validationError == nil
  }

  var validationError: RelationAuthoringError? {
    guard let driverPath, !driverPath.isEmpty else { return .missingDriver }
    guard let drivenPath, !drivenPath.isEmpty else { return .missingDriven }
    guard driverPath != drivenPath else { return .sameDegreeOfFreedom }
    guard ratioFieldValue.isFinite, ratioFieldValue > 0 else { return .invalidMagnitude }
    guard offsetFieldValue.isFinite else { return .invalidOffset }
    return nil
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

  var nativeOffset: Double? {
    guard offsetFieldValue.isFinite else { return nil }
    return type.drivenKind == .translation
      ? offsetFieldValue / 1_000
      : offsetFieldValue * .pi / 180
  }

  func hasSameEditableValues(as other: RelationDraft) -> Bool {
    type == other.type
      && driverPath == other.driverPath
      && drivenPath == other.drivenPath
      && ratioFieldValue == other.ratioFieldValue
      && offsetFieldValue == other.offsetFieldValue
      && isReversed == other.isReversed
  }

  /// Builds the canonical bridge DTO while preserving unknown future fields
  /// from an existing relation document.
  func document(
    preserving source: AnimaCoreJSONValue? = nil
  ) throws -> AnimaCoreJSONValue {
    if let validationError { throw validationError }
    guard let driverPath else { throw RelationAuthoringError.missingDriver }
    guard let drivenPath else { throw RelationAuthoringError.missingDriven }
    guard let ratio = signedSemanticRatio else {
      throw RelationAuthoringError.invalidMagnitude
    }
    guard let offset = nativeOffset else { throw RelationAuthoringError.invalidOffset }

    var object: [String: AnimaCoreJSONValue]
    if let source {
      guard case .object(let sourceObject) = source else {
        throw RelationAuthoringError.invalidDocument
      }
      object = sourceObject
    } else {
      object = [:]
    }
    object["kind"] = .string(type.kind.rawValue)
    object["driver"] = .string(driverPath)
    object["driven"] = .string(drivenPath)
    object["ratio"] = .number(ratio)
    object["offset"] = .number(offset)
    return .object(object)
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
