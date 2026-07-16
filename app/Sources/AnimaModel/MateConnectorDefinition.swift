import Foundation

/// A part-local coordinate frame used to attach one component to another.
///
/// The primary axis is local Z (the motion axis for a revolute mate). The
/// secondary axis establishes local X and removes the remaining roll ambiguity.
/// Local Y is derived to keep the frame right-handed.
public struct MateConnectorDefinition: Equatable, Codable, Sendable {
  public var originMeters: RigVector3
  public var primaryAxis: RigVector3
  public var secondaryAxis: RigVector3

  public init(
    originMeters: RigVector3 = RigVector3(),
    primaryAxis: RigVector3 = RigVector3(x: 0, y: 0, z: 1),
    secondaryAxis: RigVector3 = RigVector3(x: 1, y: 0, z: 0)
  ) {
    self.originMeters = originMeters
    self.primaryAxis = primaryAxis
    self.secondaryAxis = secondaryAxis
  }
}
