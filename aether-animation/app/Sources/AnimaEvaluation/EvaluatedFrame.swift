import AnimaModel

/// The renderer- and hardware-neutral result of evaluating animation at one time.
public struct EvaluatedFrame: Equatable, Sendable {
  public let timeSeconds: Double
  public let jointAnglesRadians: [JointID: Double]

  public init(timeSeconds: Double, jointAnglesRadians: [JointID: Double]) {
    self.timeSeconds = timeSeconds
    self.jointAnglesRadians = jointAnglesRadians
  }
}
