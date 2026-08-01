import Foundation

public enum AnimaCoreRigDocumentEditingError: Error, Equatable, Sendable {
  case rigIsNotAnObject
  case partsAreMissing
  case invalidPartEntry
  case invalidModelReference(String)
  case unknownPart(String)
  case unknownJoint(String)
  case unknownRelation(String)
  case unknownOutputChannel(Int)
  case duplicateOutputChannel(Int)
  case invalidOutputMapping(String)
  case invalidTransformVector(String)
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
    case .unknownJoint(let name):
      "The character does not contain a mate named ‘\(name)’."
    case .unknownRelation(let id):
      "The character does not contain relation ‘\(id)’."
    case .unknownOutputChannel(let channel):
      "The character does not contain an output on channel \(channel)."
    case .duplicateOutputChannel(let channel):
      "Output channel \(channel) is already assigned."
    case .invalidOutputMapping(let reason):
      "The output mapping is invalid: \(reason)"
    case .invalidTransformVector(let field):
      "\(field) must contain three finite values."
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
  /// Builds the engine DTO for a newly-created empty rigid-parts character.
  /// The DTO is not a file; callers must pass it to `serialize_character` so
  /// AnimaCore validates and authors the canonical document text.
  public static func emptyCharacter(
    name: String,
    displayName: String
  ) -> AnimaCoreJSONValue {
    .object([
      "identity": .object([
        "name": .string(name),
        "display_name": .string(displayName),
        "description": .string("Rigid-parts 3D character"),
        "version": .string("0.1.0"),
      ]),
      "parts": .array([]),
      "joints": .array([]),
      "parameters": .array([]),
      "clips": .array([]),
      "outputs": .array([]),
      "relations": .array([]),
    ])
  }

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

  /// Removes parts and every rig-semantic reference that would otherwise
  /// become invalid. The edited DTO must still be serialized by AnimaCore,
  /// which remains the final validator and canonical file author.
  public static func removingParts(
    named partNames: Set<String>,
    from document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    guard !partNames.isEmpty else { return document }
    var root = try rootObject(document)
    var parts = try partObjects(root)
    let existingNames = Set(parts.compactMap { stringValue($0["name"]) })
    if let unknown = partNames.subtracting(existingNames).sorted().first {
      throw AnimaCoreRigDocumentEditingError.unknownPart(unknown)
    }

    parts.removeAll { part in
      stringValue(part["name"]).map(partNames.contains) ?? false
    }
    for index in parts.indices {
      if let parent = stringValue(parts[index]["parent"]), partNames.contains(parent) {
        parts[index]["parent"] = .null
      }
    }
    root["parts"] = .array(parts.map(AnimaCoreJSONValue.object))

    var removedDOFPaths = Set<String>()
    var joints = try objectArray(root, key: "joints")
    joints.removeAll { joint in
      let removesJoint = [stringValue(joint["parent_part"]), stringValue(joint["child_part"])]
        .compactMap { $0 }
        .contains(where: partNames.contains)
      guard removesJoint else { return false }
      collectDOFPaths(from: joint, into: &removedDOFPaths)
      return true
    }
    root["joints"] = .array(joints.map(AnimaCoreJSONValue.object))

    if case .object(let chain) = root["kinematic_chain"],
      kinematicChain(chain, referencesAny: partNames)
    {
      let chainName = stringValue(chain["name"]) ?? ""
      if case .array(let chainJoints) = chain["joints"] {
        for case .object(let joint) in chainJoints {
          if let jointName = stringValue(joint["name"]), !chainName.isEmpty {
            removedDOFPaths.insert("\(chainName).\(jointName)")
          }
        }
      }
      root["kinematic_chain"] = .null
    }

    root["relations"] = .array(
      try objectArray(root, key: "relations").compactMap { relation in
        guard !referencesRemovedDOF(relation["driver"], removedDOFPaths: removedDOFPaths),
          !referencesRemovedDOF(relation["driven"], removedDOFPaths: removedDOFPaths)
        else { return nil }
        return .object(relation)
      }
    )
    root["outputs"] = .array(
      try objectArray(root, key: "outputs").compactMap { output in
        referencesRemovedDOF(output["dof_path"], removedDOFPaths: removedDOFPaths)
          ? nil : .object(output)
      }
    )

    let clips = try objectArray(root, key: "clips").map { clip -> AnimaCoreJSONValue in
      var editedClip = clip
      if case .array(let keyframes) = clip["keyframes"] {
        editedClip["keyframes"] = .array(
          keyframes.compactMap { keyframe -> AnimaCoreJSONValue? in
            guard case .object(var entry) = keyframe,
              case .object(var values) = entry["values"]
            else { return keyframe }
            values = values.filter {
              !referencesRemovedDOF(.string($0.key), removedDOFPaths: removedDOFPaths)
            }
            guard !values.isEmpty else { return nil }
            entry["values"] = .object(values)
            return .object(entry)
          }
        )
      }
      return .object(editedClip)
    }
    root["clips"] = .array(clips)
    return .object(root)
  }

  public static func settingPartTransform(
    named partName: String,
    positionMeters: [Double],
    rotationEulerRadians: [Double],
    in document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    try validateVector(positionMeters, field: "position_m")
    try validateVector(rotationEulerRadians, field: "rotation_euler_rad")
    var root = try rootObject(document)
    var parts = try objectArray(root, key: "parts")
    guard let index = parts.firstIndex(where: { stringValue($0["name"]) == partName }) else {
      throw AnimaCoreRigDocumentEditingError.unknownPart(partName)
    }
    parts[index]["position_m"] = .array(positionMeters.map(AnimaCoreJSONValue.number))
    parts[index]["rotation_euler_rad"] = .array(
      rotationEulerRadians.map(AnimaCoreJSONValue.number)
    )
    root["parts"] = .array(parts.map(AnimaCoreJSONValue.object))
    return .object(root)
  }

  public static func settingPartState(
    named partName: String,
    suppressed: Bool? = nil,
    grounded: Bool? = nil,
    in document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    var root = try rootObject(document)
    var parts = try objectArray(root, key: "parts")
    guard let index = parts.firstIndex(where: { stringValue($0["name"]) == partName }) else {
      throw AnimaCoreRigDocumentEditingError.unknownPart(partName)
    }
    if let suppressed { parts[index]["suppressed"] = .bool(suppressed) }
    if let grounded { parts[index]["grounded"] = .bool(grounded) }
    root["parts"] = .array(parts.map(AnimaCoreJSONValue.object))
    return .object(root)
  }

  public static func settingJointSuppressed(
    named jointName: String,
    suppressed: Bool,
    in document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    var root = try rootObject(document)
    var joints = try objectArray(root, key: "joints")
    guard let index = joints.firstIndex(where: { stringValue($0["name"]) == jointName }) else {
      throw AnimaCoreRigDocumentEditingError.unknownJoint(jointName)
    }
    joints[index]["suppressed"] = .bool(suppressed)
    root["joints"] = .array(joints.map(AnimaCoreJSONValue.object))
    return .object(root)
  }

  /// Returns one full-fidelity joint DTO exactly as AnimaCore supplied it.
  ///
  /// Inspector editors use this as their mutation base, then submit the
  /// resulting joint through `update_mate`. This preserves additive engine
  /// fields that an older Swift summary may not understand.
  /// One part's full document entry (the `update_part` bridge DTO). The
  /// entry carries its own `name` key, matching the joint twin below.
  public static func partDocument(
    named partName: String,
    from document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    let root = try rootObject(document)
    let parts = try objectArray(root, key: "parts")
    guard let part = parts.first(where: { stringValue($0["name"]) == partName }) else {
      throw AnimaCoreRigDocumentEditingError.unknownPart(partName)
    }
    return .object(part)
  }

  public static func jointDocument(
    identifiedBy identifier: String,
    from document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    let root = try rootObject(document)
    let joints = try objectArray(root, key: "joints")
    guard
      let joint = joints.first(where: {
        stringValue($0["id"]) == identifier || stringValue($0["name"]) == identifier
      })
    else { throw AnimaCoreRigDocumentEditingError.unknownJoint(identifier) }
    return .object(joint)
  }

  public static func settingRelationSuppressed(
    kind: AnimaCoreRelationKind,
    driver: String,
    driven: String,
    suppressed: Bool,
    in document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    var root = try rootObject(document)
    var relations = try objectArray(root, key: "relations")
    guard
      let index = relations.firstIndex(where: {
        stringValue($0["kind"]) == kind.rawValue
          && stringValue($0["driver"]) == driver
          && stringValue($0["driven"]) == driven
      })
    else {
      throw AnimaCoreRigDocumentEditingError.unknownRelation(
        "\(kind.rawValue):\(driver)->\(driven)"
      )
    }
    relations[index]["suppressed"] = .bool(suppressed)
    root["relations"] = .array(relations.map(AnimaCoreJSONValue.object))
    return .object(root)
  }

  /// Returns one full-fidelity relation DTO exactly as AnimaCore supplied it.
  ///
  /// A relation's driven DOF is unique in the canonical rig and is therefore
  /// its mutation key. `kind` and `driver` additionally protect against
  /// accidentally editing a stale selection after the document changes.
  public static func relationDocument(
    kind: AnimaCoreRelationKind,
    driver: String,
    driven: String,
    from document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    let root = try rootObject(document)
    let relations = try objectArray(root, key: "relations")
    guard
      let relation = relations.first(where: {
        stringValue($0["kind"]) == kind.rawValue
          && stringValue($0["driver"]) == driver
          && stringValue($0["driven"]) == driven
      })
    else {
      throw AnimaCoreRigDocumentEditingError.unknownRelation(
        "\(kind.rawValue):\(driver)->\(driven)"
      )
    }
    return .object(relation)
  }

  /// Removes one mate and every relation, output, and keyframe value that
  /// references one of its DOFs. AnimaCore still validates and serializes the
  /// returned DTO before it can become a canonical character file.
  public static func removingJoint(
    identifiedBy identifier: String,
    from document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    var root = try rootObject(document)
    var joints = try objectArray(root, key: "joints")
    guard
      let index = joints.firstIndex(where: {
        stringValue($0["id"]) == identifier || stringValue($0["name"]) == identifier
      })
    else { throw AnimaCoreRigDocumentEditingError.unknownJoint(identifier) }

    var removedDOFPaths = Set<String>()
    collectDOFPaths(from: joints[index], into: &removedDOFPaths)
    joints.remove(at: index)
    root["joints"] = .array(joints.map(AnimaCoreJSONValue.object))
    try removeReferences(to: removedDOFPaths, from: &root)
    return .object(root)
  }

  /// Removes exactly one advanced relation. The positive magnitude/reverse
  /// convention remains owned by AnimaCore; this only removes the matching
  /// already-described entry.
  public static func removingRelation(
    kind: AnimaCoreRelationKind,
    driver: String,
    driven: String,
    from document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    var root = try rootObject(document)
    var relations = try objectArray(root, key: "relations")
    guard
      let index = relations.firstIndex(where: {
        stringValue($0["kind"]) == kind.rawValue
          && stringValue($0["driver"]) == driver
          && stringValue($0["driven"]) == driven
      })
    else {
      throw AnimaCoreRigDocumentEditingError.unknownRelation(
        "\(kind.rawValue):\(driver)->\(driven)"
      )
    }
    relations.remove(at: index)
    root["relations"] = .array(relations.map(AnimaCoreJSONValue.object))
    return .object(root)
  }

  /// Adds or replaces one output mapping in the full-fidelity engine DTO.
  ///
  /// `originalChannel` is the stable edit key supplied by the UI before a
  /// channel number is changed. AnimaCore still performs semantic validation
  /// (known target, bounded DOF, unique channel, valid range) when the caller
  /// serializes and reloads the returned document.
  public static func settingOutputMapping(
    originalChannel: Int?,
    targetPath: String,
    channel: Int,
    valueAtZero: Double,
    valueAtOne: Double,
    in document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    guard !targetPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AnimaCoreRigDocumentEditingError.invalidOutputMapping("select a target")
    }
    guard channel >= 0 else {
      throw AnimaCoreRigDocumentEditingError.invalidOutputMapping(
        "the channel must be zero or greater"
      )
    }
    guard valueAtZero.isFinite, valueAtOne.isFinite else {
      throw AnimaCoreRigDocumentEditingError.invalidOutputMapping(
        "range endpoints must be finite"
      )
    }
    guard valueAtZero != valueAtOne else {
      throw AnimaCoreRigDocumentEditingError.invalidOutputMapping(
        "range endpoints must differ"
      )
    }

    var root = try rootObject(document)
    var outputs = try objectArray(root, key: "outputs")
    let editIndex: Int?
    if let originalChannel {
      guard
        let index = outputs.firstIndex(where: {
          numberValue($0["channel"]).map(Int.init) == originalChannel
        })
      else {
        throw AnimaCoreRigDocumentEditingError.unknownOutputChannel(originalChannel)
      }
      editIndex = index
    } else {
      editIndex = nil
    }

    if outputs.indices.contains(where: { index in
      index != editIndex && numberValue(outputs[index]["channel"]).map(Int.init) == channel
    }) {
      throw AnimaCoreRigDocumentEditingError.duplicateOutputChannel(channel)
    }

    var mapping = editIndex.map { outputs[$0] } ?? [:]
    mapping["dof_path"] = .string(targetPath)
    mapping["channel"] = .number(Double(channel))
    mapping["value_at_zero"] = .number(valueAtZero)
    mapping["value_at_one"] = .number(valueAtOne)
    if let editIndex {
      outputs[editIndex] = mapping
    } else {
      outputs.append(mapping)
    }
    outputs.sort {
      (numberValue($0["channel"]) ?? 0) < (numberValue($1["channel"]) ?? 0)
    }
    root["outputs"] = .array(outputs.map(AnimaCoreJSONValue.object))
    return .object(root)
  }

  public static func removingOutput(
    channel: Int,
    from document: AnimaCoreJSONValue
  ) throws -> AnimaCoreJSONValue {
    var root = try rootObject(document)
    var outputs = try objectArray(root, key: "outputs")
    guard
      let index = outputs.firstIndex(where: {
        numberValue($0["channel"]).map(Int.init) == channel
      })
    else {
      throw AnimaCoreRigDocumentEditingError.unknownOutputChannel(channel)
    }
    outputs.remove(at: index)
    root["outputs"] = .array(outputs.map(AnimaCoreJSONValue.object))
    return .object(root)
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

  private static func objectArray(
    _ root: [String: AnimaCoreJSONValue],
    key: String
  ) throws -> [[String: AnimaCoreJSONValue]] {
    guard case .array(let values) = root[key] else {
      if key == "parts" { throw AnimaCoreRigDocumentEditingError.partsAreMissing }
      return []
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

  private static func numberValue(_ value: AnimaCoreJSONValue?) -> Double? {
    guard case .number(let value) = value else { return nil }
    return value
  }

  private static func collectDOFPaths(
    from joint: [String: AnimaCoreJSONValue],
    into paths: inout Set<String>
  ) {
    if case .array(let dofs) = joint["dofs"] {
      for case .object(let dof) in dofs {
        if let path = stringValue(dof["path"]) { paths.insert(path) }
      }
    }
    if let jointName = stringValue(joint["name"]) {
      paths.insert(jointName)
    }
  }

  private static func referencesRemovedDOF(
    _ value: AnimaCoreJSONValue?,
    removedDOFPaths: Set<String>
  ) -> Bool {
    guard let path = stringValue(value) else { return false }
    return removedDOFPaths.contains(path)
      || removedDOFPaths.contains { path.hasPrefix("\($0).") }
  }

  private static func removeReferences(
    to removedDOFPaths: Set<String>,
    from root: inout [String: AnimaCoreJSONValue]
  ) throws {
    root["relations"] = .array(
      try objectArray(root, key: "relations").compactMap { relation in
        guard !referencesRemovedDOF(relation["driver"], removedDOFPaths: removedDOFPaths),
          !referencesRemovedDOF(relation["driven"], removedDOFPaths: removedDOFPaths)
        else { return nil }
        return .object(relation)
      }
    )
    root["outputs"] = .array(
      try objectArray(root, key: "outputs").compactMap { output in
        referencesRemovedDOF(output["dof_path"], removedDOFPaths: removedDOFPaths)
          ? nil : .object(output)
      }
    )
    root["clips"] = .array(
      try objectArray(root, key: "clips").map { clip in
        var editedClip = clip
        if case .array(let keyframes) = clip["keyframes"] {
          editedClip["keyframes"] = .array(
            keyframes.compactMap { keyframe in
              guard case .object(var entry) = keyframe,
                case .object(var values) = entry["values"]
              else { return keyframe }
              values = values.filter {
                !referencesRemovedDOF(.string($0.key), removedDOFPaths: removedDOFPaths)
              }
              guard !values.isEmpty else { return nil }
              entry["values"] = .object(values)
              return .object(entry)
            }
          )
        }
        return .object(editedClip)
      }
    )
  }

  private static func kinematicChain(
    _ chain: [String: AnimaCoreJSONValue],
    referencesAny partNames: Set<String>
  ) -> Bool {
    if [stringValue(chain["base_part"]), stringValue(chain["tool_part"])]
      .compactMap({ $0 })
      .contains(where: partNames.contains)
    {
      return true
    }
    guard case .array(let joints) = chain["joints"] else { return false }
    return joints.contains { value in
      guard case .object(let joint) = value,
        let part = stringValue(joint["part"])
      else { return false }
      return partNames.contains(part)
    }
  }

  private static func validateModelReference(_ reference: String) throws {
    let components = reference.split(separator: "/", omittingEmptySubsequences: false)
    guard reference.hasPrefix("assets/"), !reference.hasPrefix("/"),
      components.allSatisfy({ !$0.isEmpty && $0 != ".." && $0 != "." })
    else {
      throw AnimaCoreRigDocumentEditingError.invalidModelReference(reference)
    }
  }

  private static func validateVector(_ values: [Double], field: String) throws {
    guard values.count == 3, values.allSatisfy(\.isFinite) else {
      throw AnimaCoreRigDocumentEditingError.invalidTransformVector(field)
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
