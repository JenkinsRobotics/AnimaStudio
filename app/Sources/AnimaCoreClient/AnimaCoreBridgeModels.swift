import Foundation

public struct AnimaCoreHello: Codable, Equatable, Sendable {
  public let engine: String
  public let engineVersion: String
  public let protocolVersion: Int
  public let capabilities: [String]

  enum CodingKeys: String, CodingKey {
    case engine
    case engineVersion = "engine_version"
    case protocolVersion = "protocol_version"
    case capabilities
  }
}

public struct AnimaCoreCharacterLoad: Codable, Equatable, Sendable {
  public let handle: String
  public let rig: AnimaCoreRigSummary
}

public struct AnimaCoreRigSummary: Codable, Equatable, Sendable {
  public let identity: AnimaCoreRigIdentity
  public let parts: [AnimaCorePartSummary]
  public let joints: [AnimaCoreJointSummary]
  public let parameters: [AnimaCoreParameterSummary]
  public let clips: [AnimaCoreClipSummary]
  public let outputs: [AnimaCoreOutputSummary]
  public let relations: [AnimaCoreRelationSummary]
}

public struct AnimaCoreRigIdentity: Codable, Equatable, Sendable {
  public let name: String
  public let displayName: String
  public let description: String
  public let version: String
  public let author: String

  enum CodingKeys: String, CodingKey {
    case name
    case displayName = "display_name"
    case description
    case version
    case author
  }
}

public struct AnimaCorePartSummary: Codable, Equatable, Sendable {
  public let name: String
  public let parent: String?
  public let modelNode: String?
  public let description: String

  enum CodingKeys: String, CodingKey {
    case name
    case parent
    case modelNode = "model_node"
    case description
  }
}

public enum AnimaCoreDOFKind: String, Codable, Sendable {
  case rotation
  case translation
}

public enum AnimaCoreDOFUnit: String, Codable, Sendable {
  case radians
  case meters
}

public enum AnimaCoreMateCategory: String, Codable, Sendable {
  case kinematic
  case geometryConstraint = "geometry_constraint"
}

public struct AnimaCoreJointSummary: Codable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let type: String
  public let category: AnimaCoreMateCategory
  public let parentPart: String?
  public let childPart: String?
  public let controls: AnimaCoreMateControls?
  public let tangent: AnimaCoreTangentControls?
  public let degreesOfFreedom: [AnimaCoreDOFSummary]

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case type
    case category
    case parentPart = "parent_part"
    case childPart = "child_part"
    case controls
    case tangent
    case degreesOfFreedom = "dofs"
  }

  /// The engine tracking id is authoritative when present. Legacy files may
  /// still carry an empty id; the fallback is session-local presentation
  /// identity only and must never be persisted as a replacement engine id.
  public var selectionKey: String {
    id.isEmpty ? "untracked:\(type):\(name)" : id
  }
}

public struct AnimaCoreTangentControls: Codable, Equatable, Sendable {
  public let selectionA: String
  public let selectionB: String
  public let propagatesAcrossTangentFaces: Bool

  enum CodingKeys: String, CodingKey {
    case selectionA = "selection_a"
    case selectionB = "selection_b"
    case propagatesAcrossTangentFaces = "propagation"
  }
}

public struct AnimaCoreMateControls: Codable, Equatable, Sendable {
  public let connectors: AnimaCoreMateConnectorPair
  public let offset: AnimaCoreMateOffset
  public let flipsPrimaryAxis: Bool
  public let secondaryAxisRotationDegrees: Int
  public let isSimulationConnection: Bool

  enum CodingKeys: String, CodingKey {
    case connectors
    case offset
    case flipsPrimaryAxis = "flip_primary_axis"
    case secondaryAxisRotationDegrees = "secondary_axis_rotation_deg"
    case isSimulationConnection = "simulation_connection"
  }
}

public struct AnimaCoreMateConnectorPair: Codable, Equatable, Sendable {
  public let a: AnimaCoreMateConnector?
  public let b: AnimaCoreMateConnector?
}

public struct AnimaCoreMateConnector: Codable, Equatable, Sendable {
  public let part: String
  public let originMeters: [Double]
  public let primaryAxis: [Double]
  public let secondaryAxis: [Double]
  public let isFlipped: Bool
  public let feature: String

  enum CodingKeys: String, CodingKey {
    case part
    case originMeters = "origin_m"
    case primaryAxis = "primary_axis"
    case secondaryAxis = "secondary_axis"
    case isFlipped = "flipped"
    case feature
  }
}

public enum AnimaCoreMateAxis: String, Codable, CaseIterable, Sendable {
  case x
  case y
  case z
}

public struct AnimaCoreMateOffset: Codable, Equatable, Sendable {
  public let isEnabled: Bool
  public let translationMeters: [Double]
  public let rotationAxis: AnimaCoreMateAxis
  public let rotationRadians: Double

  enum CodingKeys: String, CodingKey {
    case isEnabled = "enabled"
    case translationMeters = "translation_m"
    case rotationAxis = "rotation_axis"
    case rotationRadians = "rotation_radians"
  }
}

public struct AnimaCoreMateTypeCatalog: Codable, Equatable, Sendable {
  public let mateTypes: [AnimaCoreMateTypeSummary]

  enum CodingKeys: String, CodingKey {
    case mateTypes = "mate_types"
  }
}

public struct AnimaCoreMateTypeSummary: Codable, Equatable, Sendable {
  public let type: String
  public let label: String
  public let category: AnimaCoreMateCategory
  public let isDrivable: Bool
  public let degreeOfFreedomCount: Int
  public let universalControls: [String]
  public let degreesOfFreedom: [AnimaCoreMateTypeDOF]
  public let note: String?

  enum CodingKeys: String, CodingKey {
    case type
    case label
    case category
    case isDrivable = "drivable"
    case degreeOfFreedomCount = "dof_count"
    case universalControls = "universal_controls"
    case degreesOfFreedom = "dofs"
    case note
  }
}

public struct AnimaCoreMateTypeDOF: Codable, Equatable, Sendable {
  public let name: String
  public let kind: AnimaCoreDOFKind
  public let unit: AnimaCoreDOFUnit
  public let axis: AnimaCoreMateAxis
}

public enum AnimaCoreRelationKind: String, Codable, CaseIterable, Sendable {
  case gear
  case rackPinion = "rack_pinion"
  case screw
  case linear
}

public struct AnimaCoreRelationTypeCatalog: Codable, Equatable, Sendable {
  public let relationTypes: [AnimaCoreRelationTypeSummary]

  enum CodingKeys: String, CodingKey {
    case relationTypes = "relation_types"
  }
}

public struct AnimaCoreRelationTypeSummary: Codable, Equatable, Sendable, Identifiable {
  public let kind: AnimaCoreRelationKind
  public let label: String
  public let driverKind: AnimaCoreDOFKind
  public let drivenKind: AnimaCoreDOFKind
  public let ratioField: AnimaCoreRelationRatioField
  public let supportsReverse: Bool

  public var id: AnimaCoreRelationKind { kind }

  enum CodingKeys: String, CodingKey {
    case kind
    case label
    case driverKind = "driver_kind"
    case drivenKind = "driven_kind"
    case ratioField = "ratio_field"
    case supportsReverse = "reverse_supported"
  }
}

public struct AnimaCoreRelationRatioField: Codable, Equatable, Sendable {
  public let key: String
  public let unit: String
}

public struct AnimaCoreRelationSummary: Codable, Equatable, Sendable, Identifiable {
  public let kind: AnimaCoreRelationKind
  public let driver: String
  public let driven: String
  public let ratio: Double
  public let offset: Double
  public let isReversed: Bool
  public let magnitude: Double
  public let ratioFieldValue: Double
  public let display: [String: Double]

  /// Relations do not yet carry a persisted tracking id. This deterministic
  /// key is presentation identity only and is never written into `.anima`.
  public var id: String {
    "\(kind.rawValue):\(driver)->\(driven)"
  }

  enum CodingKeys: String, CodingKey {
    case kind
    case driver
    case driven
    case ratio
    case offset
    case isReversed = "reverse"
    case magnitude
    case ratioFieldValue = "ratio_field_value"
    case display
  }
}

public struct AnimaCoreDOFSummary: Codable, Equatable, Sendable {
  public let path: String
  public let kind: AnimaCoreDOFKind
  public let unit: AnimaCoreDOFUnit
  public let axis: AnimaCoreMateAxis
  public let minimum: Double?
  public let maximum: Double?
  public let neutral: Double

  enum CodingKeys: String, CodingKey {
    case path
    case kind
    case unit
    case axis
    case minimum = "min"
    case maximum = "max"
    case neutral
  }
}

public struct AnimaCoreResolvedPose: Codable, Equatable, Sendable {
  public let parts: [String: AnimaCoreResolvedPartPose]
}

public struct AnimaCoreResolvedPartPose: Codable, Equatable, Sendable {
  /// World-space position in metres.
  public let position: [Double]
  /// Quaternion imaginary XYZ components followed by the real component.
  public let orientation: [Double]
}

public struct AnimaCoreParameterSummary: Codable, Equatable, Sendable {
  public let name: String
  public let neutral: Double
  public let description: String
}

public struct AnimaCoreClipSummary: Codable, Equatable, Sendable {
  public let name: String
  public let durationSeconds: Double
  public let loop: Bool

  enum CodingKeys: String, CodingKey {
    case name
    case durationSeconds = "duration_s"
    case loop
  }
}

public struct AnimaCoreOutputSummary: Codable, Equatable, Sendable {
  public let targetPath: String
  public let channel: Int

  enum CodingKeys: String, CodingKey {
    case targetPath = "dof_path"
    case channel
  }
}

public struct AnimaCoreEvaluation: Codable, Equatable, Sendable {
  public let degreesOfFreedom: [String: Double]
  public let parameters: [String: Double]
  public let channels: [String: Double]
  public let limitViolations: [AnimaCoreLimitViolation]

  public var channelsByIndex: [Int: Double] {
    Dictionary(
      uniqueKeysWithValues: channels.compactMap { key, value in
        Int(key).map { ($0, value) }
      }
    )
  }

  enum CodingKeys: String, CodingKey {
    case degreesOfFreedom = "dof_values"
    case parameters
    case channels
    case limitViolations = "limit_violations"
  }
}

public struct AnimaCoreLimitViolation: Codable, Equatable, Sendable {
  public let degreeOfFreedomPath: String
  public let value: Double
  public let minimum: Double
  public let maximum: Double

  enum CodingKeys: String, CodingKey {
    case degreeOfFreedomPath = "dof_path"
    case value
    case minimum = "min"
    case maximum = "max"
  }
}

public struct AnimaCoreDiagnostic: Codable, Equatable, Sendable {
  public let code: String
  public let message: String
  public let path: String?
}

public struct AnimaCoreValidation: Codable, Equatable, Sendable {
  public let diagnostics: [AnimaCoreDiagnostic]
}

public struct AnimaCoreRemoteError: Codable, Error, Equatable, Sendable {
  public let code: String
  public let message: String
  public let path: String?
}

extension AnimaCoreRemoteError: LocalizedError {
  public var errorDescription: String? {
    if let path {
      return "\(path): \(message)"
    }
    return message
  }
}
