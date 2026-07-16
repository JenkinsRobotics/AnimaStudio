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

public struct AnimaCoreJointSummary: Codable, Equatable, Sendable {
  public let name: String
  public let type: String
  public let degreesOfFreedom: [AnimaCoreDOFSummary]

  enum CodingKeys: String, CodingKey {
    case name
    case type
    case degreesOfFreedom = "dofs"
  }
}

public struct AnimaCoreDOFSummary: Codable, Equatable, Sendable {
  public let path: String
  public let kind: AnimaCoreDOFKind
  public let unit: AnimaCoreDOFUnit
  public let minimum: Double?
  public let maximum: Double?
  public let neutral: Double

  enum CodingKeys: String, CodingKey {
    case path
    case kind
    case unit
    case minimum = "min"
    case maximum = "max"
    case neutral
  }
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
