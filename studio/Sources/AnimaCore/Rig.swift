import Foundation

public enum JointAxis: String, Codable, Sendable {
  case x
  case y
  case z
}

public struct JointDefinition: Equatable, Codable, Sendable {
  public let id: JointID
  public var displayName: String
  public var axis: JointAxis
  public var minimumRadians: Double
  public var maximumRadians: Double
  public var neutralRadians: Double

  public init(
    id: JointID,
    displayName: String,
    axis: JointAxis,
    minimumRadians: Double,
    maximumRadians: Double,
    neutralRadians: Double = 0
  ) {
    precondition(minimumRadians <= maximumRadians)
    precondition((minimumRadians...maximumRadians).contains(neutralRadians))

    self.id = id
    self.displayName = displayName
    self.axis = axis
    self.minimumRadians = minimumRadians
    self.maximumRadians = maximumRadians
    self.neutralRadians = neutralRadians
  }

  public func clamped(_ radians: Double) -> Double {
    min(max(radians, minimumRadians), maximumRadians)
  }
}

public struct CharacterRig: Equatable, Codable, Sendable {
  public var joints: [JointDefinition]

  public init(joints: [JointDefinition]) {
    precondition(Set(joints.map(\.id)).count == joints.count)
    self.joints = joints
  }
}
