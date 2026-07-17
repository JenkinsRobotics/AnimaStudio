import AnimaCoreClient
import Testing

@testable import AnimaStudioUI

struct ArticulatedArmControlsTests {
  @Test
  func revoluteJointUsesDegreesOnlyForPresentation() {
    let presentation = ArticulatedArmJointPresentation(
      joint: joint(type: .revolute, minimum: -.pi, maximum: .pi, neutral: .pi / 2)
    )

    #expect(abs(presentation.displayValue(.pi / 4) - 45) < 1e-9)
    #expect(abs(presentation.nativeValue(90) - .pi / 2) < 1e-9)
    #expect(presentation.displayRange == -180...180)
    #expect(presentation.unitLabel == "deg")
  }

  @Test
  func prismaticJointUsesMillimetersOnlyForPresentation() {
    let presentation = ArticulatedArmJointPresentation(
      joint: joint(type: .prismatic, minimum: 0, maximum: 0.25, neutral: 0.1)
    )

    #expect(presentation.displayValue(0.125) == 125)
    #expect(presentation.nativeValue(50) == 0.05)
    #expect(presentation.displayRange == 0...250)
    #expect(presentation.unitLabel == "mm")
  }

  private func joint(
    type: AnimaCoreChainJointType,
    minimum: Double?,
    maximum: Double?,
    neutral: Double
  ) -> AnimaCoreChainJointSummary {
    AnimaCoreChainJointSummary(
      name: "axis_1",
      degreeOfFreedomPath: "arm.axis_1",
      jointType: type,
      linkLengthMeters: 0,
      linkTwistRadians: 0,
      linkOffsetMeters: 0,
      jointAngleRadians: 0,
      minimum: minimum,
      maximum: maximum,
      neutral: neutral,
      part: "link_1"
    )
  }
}
