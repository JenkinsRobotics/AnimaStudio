import AnimaCoreClient
import SwiftUI

struct ArticulatedArmJointPresentation: Equatable, Sendable {
  let joint: AnimaCoreChainJointSummary

  var unitLabel: String { joint.jointType == .revolute ? "deg" : "mm" }

  func displayValue(_ nativeValue: Double) -> Double {
    switch joint.jointType {
    case .revolute: nativeValue * 180 / .pi
    case .prismatic: nativeValue * 1_000
    }
  }

  func nativeValue(_ displayValue: Double) -> Double {
    switch joint.jointType {
    case .revolute: displayValue * .pi / 180
    case .prismatic: displayValue / 1_000
    }
  }

  var displayRange: ClosedRange<Double> {
    let fallbackHalfWidth = joint.jointType == .revolute ? 180.0 : 250.0
    let neutral = displayValue(joint.neutral)
    let lower = joint.minimum.map(displayValue) ?? neutral - fallbackHalfWidth
    let upper = joint.maximum.map(displayValue) ?? neutral + fallbackHalfWidth
    return lower...upper
  }
}

struct ArticulatedArmControlsView: View {
  @Bindable var workspace: StudioWorkspaceModel
  let chain: AnimaCoreKinematicChainSummary

  var body: some View {
    Section("Articulated Arm") {
      LabeledContent("Chain", value: chain.name)
      LabeledContent("Axes", value: "\(chain.joints.count)")
      if let toolPart = chain.toolPart {
        LabeledContent("Tool", value: toolPart)
      }
      Label("Forward and inverse kinematics run in AnimaCore", systemImage: "cpu")
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    Section("Joint Jog") {
      ForEach(chain.joints) { joint in
        jointControl(joint)
      }
    }

    Section("End Effector") {
      LabeledContent("Target", value: "Drag the XYZ handle")
      ikStatus
      Button("Reset Target to Tool", systemImage: "scope") {
        workspace.armIKTargetPose = workspace.armToolPose
        workspace.armIKReachState = .idle
      }
      .disabled(workspace.armToolPose == nil)
    }
  }

  private func jointControl(_ joint: AnimaCoreChainJointSummary) -> some View {
    let presentation = ArticulatedArmJointPresentation(joint: joint)
    let nativeValue = workspace.armJointValues[joint.name] ?? joint.neutral
    let displayValue = presentation.displayValue(nativeValue)
    return VStack(alignment: .leading, spacing: 6) {
      HStack {
        VStack(alignment: .leading, spacing: 1) {
          Text(joint.name)
            .font(.callout.weight(.medium))
          if let part = joint.part {
            Text(part)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
        Text(
          displayValue.formatted(.number.precision(.fractionLength(1))) + " "
            + presentation.unitLabel
        )
        .font(.caption.monospacedDigit())
      }
      Slider(
        value: Binding(
          get: {
            presentation.displayValue(workspace.armJointValues[joint.name] ?? joint.neutral)
          },
          set: { newValue in
            Task {
              await workspace.jogArmJoint(
                named: joint.name,
                to: presentation.nativeValue(newValue)
              )
            }
          }
        ),
        in: presentation.displayRange
      )
      .accessibilityLabel("\(joint.name) joint")
      .accessibilityValue("\(displayValue) \(presentation.unitLabel)")
    }
    .padding(.vertical, 2)
  }

  @ViewBuilder
  private var ikStatus: some View {
    switch workspace.armIKReachState {
    case .idle:
      Label("Ready", systemImage: "scope")
        .foregroundStyle(.secondary)
    case .solving:
      HStack {
        ProgressView().controlSize(.small)
        Text("Solving target…")
      }
    case .reached(let iterations):
      Label("Target reached · \(iterations) iterations", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .unreachable(let positionErrorMeters, let orientationErrorRadians):
      VStack(alignment: .leading, spacing: 3) {
        Label("Target can't be reached", systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
        Text(
          "Residual: \((positionErrorMeters * 1_000).formatted(.number.precision(.fractionLength(1)))) mm · \((orientationErrorRadians * 180 / .pi).formatted(.number.precision(.fractionLength(1))))°"
        )
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
      }
    case .failed(let message):
      Label(message, systemImage: "xmark.octagon.fill")
        .font(.caption)
        .foregroundStyle(.red)
    }
  }
}
