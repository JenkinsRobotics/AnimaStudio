import Foundation

public struct AssetID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: UUID

  public init(rawValue: UUID = UUID()) {
    self.rawValue = rawValue
  }
}

public struct JointID: RawRepresentable, Hashable, Codable, Sendable,
  ExpressibleByStringLiteral
{
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: String) {
    self.init(rawValue: value)
  }
}
