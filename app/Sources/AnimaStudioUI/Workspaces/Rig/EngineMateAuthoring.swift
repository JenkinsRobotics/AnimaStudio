import AnimaCoreClient
import AnimaModel
import Foundation
import RealityKitViewport

enum EngineMateAuthoringError: LocalizedError, Equatable {
  case typeUnavailable(String)
  case unsupportedGeometryMate(String)
  case missingPartMapping
  case invalidJointDocument
  case invalidOffsetVector
  case invalidDOFLimits(String)
  case invalidEdit(String)

  var errorDescription: String? {
    switch self {
    case .typeUnavailable(let type):
      "AnimaCore did not publish the \(type) mate type."
    case .unsupportedGeometryMate(let type):
      "\(type) requires a geometry-specific selection flow that is not available yet."
    case .missingPartMapping:
      "The selected connector is not mapped to an AnimaCore part."
    case .invalidJointDocument:
      "AnimaCore returned a mate document that Studio cannot edit."
    case .invalidOffsetVector:
      "Mate offsets must contain three finite values."
    case .invalidDOFLimits(let path):
      "The limits for \(path) are invalid. Minimum must not exceed maximum, and neutral must remain inside the limits."
    case .invalidEdit(let message):
      message
    }
  }
}

struct EngineMateDraft: Equatable {
  let name: String
  let trackingID: String
  let document: AnimaCoreJSONValue
}

struct EngineMatePlacementOptions: Equatable {
  var connectorAFlipped = false
  var connectorBFlipped = false
  var offsetEnabled = false
  var offsetTranslationMillimeters = [0.0, 0.0, 0.0]
  var offsetRotationAxis: AnimaCoreMateAxis = .z
  var offsetRotationDegrees = 0.0
  var flipsPrimaryAxis = false
  var secondaryAxisRotationDegrees = 0
  var isSimulationConnection = true
}

struct EngineMateDOFEditDraft: Equatable, Identifiable {
  let path: String
  let name: String
  let kind: AnimaCoreDOFKind
  let unit: AnimaCoreDOFUnit
  let axis: AnimaCoreMateAxis
  var minimum: Double?
  var maximum: Double?
  var neutral: Double

  var id: String { path }

  var unitLabel: String {
    switch unit {
    case .radians: "°"
    case .meters: "mm"
    }
  }

  init(summary: AnimaCoreDOFSummary) {
    path = summary.path
    name = summary.path.split(separator: ".").last.map(String.init) ?? summary.path
    kind = summary.kind
    unit = summary.unit
    axis = summary.axis
    minimum = Self.displayValue(summary.minimum, unit: summary.unit)
    maximum = Self.displayValue(summary.maximum, unit: summary.unit)
    neutral = Self.displayValue(summary.neutral, unit: summary.unit)
  }

  func nativeValue(_ displayValue: Double) -> Double {
    switch unit {
    case .radians: displayValue * .pi / 180
    case .meters: displayValue / 1_000
    }
  }

  private static func displayValue(_ nativeValue: Double, unit: AnimaCoreDOFUnit) -> Double {
    switch unit {
    case .radians: nativeValue * 180 / .pi
    case .meters: nativeValue * 1_000
    }
  }

  private static func displayValue(
    _ nativeValue: Double?,
    unit: AnimaCoreDOFUnit
  ) -> Double? {
    nativeValue.map { displayValue($0, unit: unit) }
  }
}

struct EngineMateEditDraft: Equatable {
  var connectorAFlipped: Bool
  var connectorBFlipped: Bool
  var offsetEnabled: Bool
  var offsetTranslationMillimeters: [Double]
  var offsetRotationAxis: AnimaCoreMateAxis
  var offsetRotationDegrees: Double
  var flipsPrimaryAxis: Bool
  var secondaryAxisRotationDegrees: Int
  var isSimulationConnection: Bool
  var degreesOfFreedom: [EngineMateDOFEditDraft]

  init(mate: AnimaCoreJointSummary) {
    let controls = mate.controls
    connectorAFlipped = controls?.connectors.a?.isFlipped ?? false
    connectorBFlipped = controls?.connectors.b?.isFlipped ?? false
    offsetEnabled = controls?.offset.isEnabled ?? false
    offsetTranslationMillimeters =
      controls?.offset.translationMeters.map { $0 * 1_000 } ?? [0, 0, 0]
    offsetRotationAxis = controls?.offset.rotationAxis ?? .z
    offsetRotationDegrees = (controls?.offset.rotationRadians ?? 0) * 180 / .pi
    flipsPrimaryAxis = controls?.flipsPrimaryAxis ?? false
    secondaryAxisRotationDegrees = controls?.secondaryAxisRotationDegrees ?? 0
    isSimulationConnection = controls?.isSimulationConnection ?? true
    degreesOfFreedom = mate.degreesOfFreedom.map(EngineMateDOFEditDraft.init)
  }

  var validationMessage: String? {
    guard offsetTranslationMillimeters.count == 3,
      offsetTranslationMillimeters.allSatisfy(\.isFinite),
      offsetRotationDegrees.isFinite
    else {
      return EngineMateAuthoringError.invalidOffsetVector.localizedDescription
    }
    for degreeOfFreedom in degreesOfFreedom {
      guard degreeOfFreedom.neutral.isFinite,
        degreeOfFreedom.minimum?.isFinite ?? true,
        degreeOfFreedom.maximum?.isFinite ?? true
      else {
        return EngineMateAuthoringError.invalidDOFLimits(
          degreeOfFreedom.path
        ).localizedDescription
      }
      if let minimum = degreeOfFreedom.minimum,
        let maximum = degreeOfFreedom.maximum,
        minimum > maximum
      {
        return EngineMateAuthoringError.invalidDOFLimits(
          degreeOfFreedom.path
        ).localizedDescription
      }
      if let minimum = degreeOfFreedom.minimum, degreeOfFreedom.neutral < minimum {
        return EngineMateAuthoringError.invalidDOFLimits(
          degreeOfFreedom.path
        ).localizedDescription
      }
      if let maximum = degreeOfFreedom.maximum, degreeOfFreedom.neutral > maximum {
        return EngineMateAuthoringError.invalidDOFLimits(
          degreeOfFreedom.path
        ).localizedDescription
      }
    }
    return nil
  }

  func applying(to jointDocument: AnimaCoreJSONValue) throws -> AnimaCoreJSONValue {
    if let validationMessage {
      throw EngineMateAuthoringError.invalidEdit(validationMessage)
    }
    guard case .object(var joint) = jointDocument else {
      throw EngineMateAuthoringError.invalidJointDocument
    }

    if case .object(var controls) = joint["controls"] {
      if case .object(var connectors) = controls["connectors"] {
        connectors["a"] = Self.settingConnectorFlipped(
          connectorAFlipped,
          in: connectors["a"]
        )
        connectors["b"] = Self.settingConnectorFlipped(
          connectorBFlipped,
          in: connectors["b"]
        )
        controls["connectors"] = .object(connectors)
      }
      var offset: [String: AnimaCoreJSONValue] = [:]
      if case .object(let existingOffset) = controls["offset"] {
        offset = existingOffset
      }
      offset["enabled"] = .bool(offsetEnabled)
      offset["translation_m"] = .array(
        offsetTranslationMillimeters.map { .number($0 / 1_000) }
      )
      offset["rotation_axis"] = .string(offsetRotationAxis.rawValue)
      offset["rotation_radians"] = .number(offsetRotationDegrees * .pi / 180)
      controls["offset"] = .object(offset)
      controls["flip_primary_axis"] = .bool(flipsPrimaryAxis)
      controls["secondary_axis_rotation_deg"] = .number(
        Double(secondaryAxisRotationDegrees)
      )
      controls["simulation_connection"] = .bool(isSimulationConnection)
      joint["controls"] = .object(controls)
    }

    if case .array(let values) = joint["dofs"] {
      joint["dofs"] = .array(
        values.map { value in
          guard case .object(var degreeOfFreedom) = value,
            case .string(let name) = degreeOfFreedom["name"],
            let edit = degreesOfFreedom.first(where: { $0.name == name })
          else { return value }
          degreeOfFreedom["neutral"] = .number(edit.nativeValue(edit.neutral))
          if let minimum = edit.minimum {
            degreeOfFreedom["min"] = .number(edit.nativeValue(minimum))
          } else {
            degreeOfFreedom.removeValue(forKey: "min")
          }
          if let maximum = edit.maximum {
            degreeOfFreedom["max"] = .number(edit.nativeValue(maximum))
          } else {
            degreeOfFreedom.removeValue(forKey: "max")
          }
          return .object(degreeOfFreedom)
        }
      )
    }
    return .object(joint)
  }

  private static func settingConnectorFlipped(
    _ isFlipped: Bool,
    in value: AnimaCoreJSONValue?
  ) -> AnimaCoreJSONValue {
    guard case .object(var connector) = value else { return value ?? .null }
    connector["flipped"] = .bool(isFlipped)
    return .object(connector)
  }
}

/// Builds the bridge DTO from engine catalog data plus the two app-selected
/// connector frames. This is serialization/presentation glue only: the engine
/// catalog defines the DOF set, and AnimaCore validates and solves the result.
enum EngineMateAuthoring {
  static func makeDraft(
    kind: MateCreationToolKind,
    type: AnimaCoreMateTypeSummary,
    movingPartName: String,
    movingConnector: MateConnectorCandidate,
    fixedPartName: String,
    fixedConnector: MateConnectorCandidate,
    existingMateNames: Set<String>,
    options: EngineMatePlacementOptions = .init()
  ) throws -> EngineMateDraft {
    guard kind.supportsTwoConnectorAuthoring else {
      throw EngineMateAuthoringError.unsupportedGeometryMate(kind.title)
    }

    let sequence = nextSequence(
      baseName: type.type,
      existingMateNames: existingMateNames
    )
    let name = "\(type.type)_\(sequence)"
    let trackingID = "\(type.label) \(sequence)"
    let degreesOfFreedom = type.degreesOfFreedom.map { degreeOfFreedom in
      AnimaCoreJSONValue.object([
        "name": .string(degreeOfFreedom.name),
        "kind": .string(degreeOfFreedom.kind.rawValue),
        "neutral": .number(0),
        "axis_vector": .array(
          axisVector(for: degreeOfFreedom.axis).map {
            .number($0)
          }),
      ])
    }

    let controls: AnimaCoreJSONValue = .object([
      "connectors": .object([
        "a": connectorDocument(
          partName: fixedPartName,
          candidate: fixedConnector,
          isFlipped: options.connectorAFlipped
        ),
        "b": connectorDocument(
          partName: movingPartName,
          candidate: movingConnector,
          isFlipped: options.connectorBFlipped
        ),
      ]),
      "offset": .object([
        "enabled": .bool(options.offsetEnabled),
        "translation_m": .array(
          options.offsetTranslationMillimeters.map { .number($0 / 1_000) }
        ),
        "rotation_axis": .string(options.offsetRotationAxis.rawValue),
        "rotation_radians": .number(options.offsetRotationDegrees * .pi / 180),
      ]),
      "flip_primary_axis": .bool(options.flipsPrimaryAxis),
      "secondary_axis_rotation_deg": .number(
        Double(options.secondaryAxisRotationDegrees)
      ),
      "simulation_connection": .bool(options.isSimulationConnection),
    ])

    return EngineMateDraft(
      name: name,
      trackingID: trackingID,
      document: .object([
        "id": .string(trackingID),
        "name": .string(name),
        "type": .string(type.type),
        "parent_part": .string(fixedPartName),
        "child_part": .string(movingPartName),
        "dofs": .array(degreesOfFreedom),
        "controls": controls,
        "suppressed": .bool(false),
      ])
    )
  }

  private static func nextSequence(
    baseName: String,
    existingMateNames: Set<String>
  ) -> Int {
    var sequence = 1
    while existingMateNames.contains("\(baseName)_\(sequence)") {
      sequence += 1
    }
    return sequence
  }

  private static func connectorDocument(
    partName: String,
    candidate: MateConnectorCandidate,
    isFlipped: Bool = false
  ) -> AnimaCoreJSONValue {
    .object([
      "part": .string(partName),
      "origin_m": vectorDocument(candidate.connector.originMeters),
      "primary_axis": vectorDocument(candidate.connector.primaryAxis),
      "secondary_axis": vectorDocument(candidate.connector.secondaryAxis),
      "flipped": .bool(isFlipped),
      "feature": .string(candidate.id),
    ])
  }

  private static func vectorDocument(_ vector: RigVector3) -> AnimaCoreJSONValue {
    .array([
      .number(vector.x),
      .number(vector.y),
      .number(vector.z),
    ])
  }

  private static func axisVector(for axis: AnimaCoreMateAxis) -> [Double] {
    switch axis {
    case .x: [1, 0, 0]
    case .y: [0, 1, 0]
    case .z: [0, 0, 1]
    }
  }
}

extension MateCreationToolKind {
  var engineTypeID: String {
    switch self {
    case .slider: "prismatic"
    case .pinSlot: "pin_slot"
    default: rawValue
    }
  }

  /// Every kinematic mate uses the same engine-defined two-connector contract.
  /// Width and Tangent remain separate because they require geometry-specific
  /// selection rather than two general connector frames.
  var supportsTwoConnectorAuthoring: Bool {
    switch self {
    case .fastened, .parallel, .slider, .revolute, .cylindrical, .pinSlot, .planar, .ball:
      true
    case .width, .tangent:
      false
    }
  }
}
