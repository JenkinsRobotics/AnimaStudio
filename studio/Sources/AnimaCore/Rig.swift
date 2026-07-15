import Foundation

public enum JointAxis: String, Codable, Sendable {
  case x
  case y
  case z
}

public enum RigPrimitiveKind: String, CaseIterable, Codable, Sendable {
  case box
  case cylinder
  case sphere
  case locator
}

public struct RigVector3: Equatable, Codable, Sendable {
  public var x: Double
  public var y: Double
  public var z: Double

  public init(x: Double = 0, y: Double = 0, z: Double = 0) {
    self.x = x
    self.y = y
    self.z = z
  }
}

public struct RigPartDefinition: Identifiable, Equatable, Codable, Sendable {
  public let id: PartID
  public var displayName: String
  public var primitiveKind: RigPrimitiveKind
  public var positionMeters: RigVector3

  public init(
    id: PartID = PartID(),
    displayName: String,
    primitiveKind: RigPrimitiveKind,
    positionMeters: RigVector3 = RigVector3()
  ) {
    self.id = id
    self.displayName = displayName
    self.primitiveKind = primitiveKind
    self.positionMeters = positionMeters
  }
}

public struct JointDefinition: Equatable, Codable, Sendable {
  public let id: JointID
  public var displayName: String
  public var axis: JointAxis
  public var minimumRadians: Double
  public var maximumRadians: Double
  public var neutralRadians: Double
  public var parentPartID: PartID?
  public var childPartID: PartID?

  public init(
    id: JointID,
    displayName: String,
    axis: JointAxis,
    minimumRadians: Double,
    maximumRadians: Double,
    neutralRadians: Double = 0,
    parentPartID: PartID? = nil,
    childPartID: PartID? = nil
  ) {
    precondition(minimumRadians <= maximumRadians)
    precondition((minimumRadians...maximumRadians).contains(neutralRadians))

    self.id = id
    self.displayName = displayName
    self.axis = axis
    self.minimumRadians = minimumRadians
    self.maximumRadians = maximumRadians
    self.neutralRadians = neutralRadians
    self.parentPartID = parentPartID
    self.childPartID = childPartID
  }

  public func clamped(_ radians: Double) -> Double {
    min(max(radians, minimumRadians), maximumRadians)
  }
}

public struct CharacterRig: Equatable, Codable, Sendable {
  public var parts: [RigPartDefinition]
  public var joints: [JointDefinition]

  public init(parts: [RigPartDefinition] = [], joints: [JointDefinition]) {
    precondition(Set(parts.map(\.id)).count == parts.count)
    precondition(Set(joints.map(\.id)).count == joints.count)
    let partIDs = Set(parts.map(\.id))
    precondition(
      joints.allSatisfy { joint in
        (joint.parentPartID.map(partIDs.contains) ?? true)
          && (joint.childPartID.map(partIDs.contains) ?? true)
      }
    )
    self.parts = parts
    self.joints = joints
  }
}
