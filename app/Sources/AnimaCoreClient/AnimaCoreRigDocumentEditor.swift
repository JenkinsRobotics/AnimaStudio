import Foundation

public enum AnimaCoreRigDocumentEditingError: Error, Equatable, Sendable {
  case rigIsNotAnObject
  case partsAreMissing
  case invalidPartEntry
  case invalidModelReference(String)
  case unknownPart(String)
}

extension AnimaCoreRigDocumentEditingError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .rigIsNotAnObject:
      "AnimaCore returned a rig document that is not an object."
    case .partsAreMissing:
      "AnimaCore returned a rig document without a parts list."
    case .invalidPartEntry:
      "AnimaCore returned a non-object entry in the rig parts list."
    case .invalidModelReference(let reference):
      "The model reference ‘\(reference)’ is not a safe relative assets path."
    case .unknownPart(let name):
      "The character does not contain a part named ‘\(name)’."
    }
  }
}

/// The app-side editing projection for AnimaCore's full-fidelity rig DTO.
///
/// This helper changes only authoring fields already declared by the engine
/// contract. The caller must still send the result through
/// `serialize_character` and reload it; AnimaCore remains the validator and
/// sole `.character.anima` author.
public enum AnimaCoreRigDocumentEditor {
  public static func assigningModel(
    _ model: String,
    modelNode: String? = nil,
    toPartNamed partName: String,
    in document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    try validateModelReference(model)
    var root = try rootObject(document)
    var parts = try partObjects(root)
    guard let index = parts.firstIndex(where: { stringValue($0["name"]) == partName }) else {
      throw AnimaCoreRigDocumentEditingError.unknownPart(partName)
    }
    parts[index]["model"] = .string(model)
    parts[index]["model_node"] = modelNode.map(AnimaCoreJSONValue.string) ?? .null
    root["parts"] = .array(parts.map(AnimaCoreJSONValue.object))
    return .object(root)
  }

  public static func addingPart(
    suggestedName: String,
    model: String,
    modelNode: String? = nil,
    to document: AnimaCoreJSONValue
  ) throws -> (document: AnimaCoreJSONValue, partName: String) {
    try validateModelReference(model)
    var root = try rootObject(document)
    var parts = try partObjects(root)
    let existingNames = Set(parts.compactMap { stringValue($0["name"]) })
    let baseName = safePartName(suggestedName)
    let partName = uniqueName(baseName, existingNames: existingNames)
    parts.append([
      "name": .string(partName),
      "parent": .null,
      "model": .string(model),
      "model_node": modelNode.map(AnimaCoreJSONValue.string) ?? .null,
      "description": .string(""),
    ])
    root["parts"] = .array(parts.map(AnimaCoreJSONValue.object))
    return (.object(root), partName)
  }

  private static func rootObject(
    _ document: AnimaCoreJSONValue
  ) throws -> [String: AnimaCoreJSONValue] {
    guard case .object(let root) = document else {
      throw AnimaCoreRigDocumentEditingError.rigIsNotAnObject
    }
    return root
  }

  private static func partObjects(
    _ root: [String: AnimaCoreJSONValue]
  ) throws -> [[String: AnimaCoreJSONValue]] {
    guard case .array(let values) = root["parts"] else {
      throw AnimaCoreRigDocumentEditingError.partsAreMissing
    }
    return try values.map { value in
      guard case .object(let object) = value else {
        throw AnimaCoreRigDocumentEditingError.invalidPartEntry
      }
      return object
    }
  }

  private static func stringValue(_ value: AnimaCoreJSONValue?) -> String? {
    guard case .string(let value) = value else { return nil }
    return value
  }

  private static func validateModelReference(_ reference: String) throws {
    let components = reference.split(separator: "/", omittingEmptySubsequences: false)
    guard reference.hasPrefix("assets/"), !reference.hasPrefix("/"),
      components.allSatisfy({ !$0.isEmpty && $0 != ".." && $0 != "." })
    else {
      throw AnimaCoreRigDocumentEditingError.invalidModelReference(reference)
    }
  }

  private static func safePartName(_ suggestedName: String) -> String {
    let lowered = suggestedName.lowercased()
    let scalars = lowered.unicodeScalars.map { scalar -> Character in
      if CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == "-" {
        return Character(String(scalar))
      }
      return "_"
    }
    let collapsed = String(scalars)
      .split(separator: "_", omittingEmptySubsequences: true)
      .joined(separator: "_")
    return collapsed.isEmpty ? "part" : collapsed
  }

  private static func uniqueName(_ base: String, existingNames: Set<String>) -> String {
    guard existingNames.contains(base) else { return base }
    var sequence = 2
    while existingNames.contains("\(base)_\(sequence)") {
      sequence += 1
    }
    return "\(base)_\(sequence)"
  }
}
