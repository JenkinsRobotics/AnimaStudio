import AnimaCoreClient
import SwiftUI

/// One presentation-only mate inspector driven by AnimaCore descriptors.
/// Every mate kind uses this surface; the engine catalog supplies the label
/// and DOF rows, while `describe_mate` supplies the instance controls.
struct EngineMateInspectorView: View {
  let mate: AnimaCoreJointSummary
  let mateType: AnimaCoreMateTypeSummary?

  private var presentation: EngineMateInspectorPresentation {
    EngineMateInspectorPresentation(mate: mate, mateType: mateType)
  }

  var body: some View {
    identitySection
    connectorSection
    offsetSection
    orientationSection
    degreesOfFreedomSection
    authoringBoundarySection
  }

  private var identitySection: some View {
    Section("Mate") {
      engineTypeRow
      LabeledContent("Name", value: mate.name)
      LabeledContent("Tracking ID") {
        if mate.id.isEmpty {
          Text(presentation.trackingIDLabel)
            .foregroundStyle(.orange)
            .textSelection(.enabled)
        } else {
          Text(presentation.trackingIDLabel)
            .textSelection(.enabled)
        }
      }
      LabeledContent("Parent", value: mate.parentPart ?? "World")
      LabeledContent("Child", value: mate.childPart ?? "Unassigned")
      LabeledContent("Degrees of Freedom", value: presentation.degreeOfFreedomSummary)
    }
  }

  private var engineTypeRow: some View {
    VStack(alignment: .leading, spacing: 6) {
      StudioFieldLabel(
        title: "Type",
        help: "AnimaCore defines the mate type and its available degrees of freedom."
      )
      HStack(spacing: 8) {
        Image(systemName: presentation.systemImage)
          .foregroundStyle(StudioPalette.joint)
        Text(presentation.typeLabel)
          .fontWeight(.medium)
        Spacer(minLength: 8)
        Label("Engine", systemImage: "cpu")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(.horizontal, 9)
      .frame(minHeight: StudioMetrics.fieldHeight)
      .background(StudioPalette.field)
      .clipShape(RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius))
      .overlay {
        RoundedRectangle(cornerRadius: StudioMetrics.controlCornerRadius)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
    }
  }

  @ViewBuilder
  private var connectorSection: some View {
    if supports("connector_a") || supports("connector_b") {
      Section("Mate Connectors") {
        if supports("connector_a") {
          EngineMateConnectorRow(
            label: "A",
            connector: mate.controls.connectors.a
          )
        }
        if supports("connector_b") {
          EngineMateConnectorRow(
            label: "B",
            connector: mate.controls.connectors.b
          )
        }
      }
    }
  }

  @ViewBuilder
  private var offsetSection: some View {
    if supports("offset") {
      Section("Offset") {
        EngineMateReadOnlyToggle(
          title: "Enable Offset",
          isOn: mate.controls.offset.isEnabled
        )
        Group {
          ForEach(0..<3, id: \.self) { index in
            EngineMateAxisReadout(
              axis: ["X", "Y", "Z"][index],
              value: presentation.offsetMillimeters.indices.contains(index)
                ? presentation.offsetMillimeters[index] : 0,
              unit: "mm"
            )
          }
          LabeledContent(
            "Rotate About", value: mate.controls.offset.rotationAxis.rawValue.uppercased())
          LabeledContent("Rotation Angle") {
            Text(
              presentation.offsetRotationDegrees,
              format: .number.precision(.fractionLength(0...3))
            )
            .monospacedDigit()
            Text("°")
              .foregroundStyle(StudioPalette.muted)
          }
        }
        .opacity(mate.controls.offset.isEnabled ? 1 : 0.55)
      }
    }
  }

  @ViewBuilder
  private var orientationSection: some View {
    if supports("flip_primary_axis") || supports("secondary_axis_rotation")
      || supports("simulation_connection") || !presentation.additionalControlIDs.isEmpty
    {
      Section("Orientation & Simulation") {
        if supports("flip_primary_axis") {
          EngineMateReadOnlyToggle(
            title: "Flip Primary Axis",
            isOn: mate.controls.flipsPrimaryAxis
          )
        }
        if supports("secondary_axis_rotation") {
          LabeledContent("Secondary Axis Rotation") {
            Text("\(mate.controls.secondaryAxisRotationDegrees)°")
              .monospacedDigit()
          }
        }
        if supports("simulation_connection") {
          EngineMateReadOnlyToggle(
            title: "Simulation Connection",
            isOn: mate.controls.isSimulationConnection
          )
        }
        ForEach(presentation.additionalControlIDs, id: \.self) { controlID in
          LabeledContent(
            controlID.replacingOccurrences(of: "_", with: " ").capitalized,
            value: "Engine control"
          )
        }
      }
    }
  }

  @ViewBuilder
  private var degreesOfFreedomSection: some View {
    Section("Degrees of Freedom") {
      if mate.degreesOfFreedom.isEmpty {
        HStack(alignment: .top, spacing: 9) {
          Image(systemName: "lock.fill")
            .foregroundStyle(StudioPalette.joint)
          VStack(alignment: .leading, spacing: 2) {
            Text("Fully bonded")
              .font(.callout.weight(.semibold))
            Text("Fastened removes all six relative degrees of freedom.")
              .font(.caption)
              .foregroundStyle(StudioPalette.muted)
          }
        }
        .accessibilityElement(children: .combine)
      } else {
        ForEach(mate.degreesOfFreedom, id: \.path) { degreeOfFreedom in
          EngineMateDOFRow(degreeOfFreedom: degreeOfFreedom)
        }
      }
    }
  }

  private var authoringBoundarySection: some View {
    Section("Authoring State") {
      Label("Validated by AnimaCore", systemImage: "checkmark.shield.fill")
        .foregroundStyle(StudioPalette.hardware)
      Text(
        "This panel is an engine-backed snapshot. Connector and control editing will write the canonical character document and revalidate it in the next packet."
      )
      .font(.caption)
      .foregroundStyle(StudioPalette.muted)
    }
  }

  private func supports(_ controlID: String) -> Bool {
    mateType?.universalControls.contains(controlID) ?? true
  }
}

struct EngineMateInspectorPresentation {
  let mate: AnimaCoreJointSummary
  let mateType: AnimaCoreMateTypeSummary?

  var typeLabel: String {
    mateType?.label
      ?? mate.type.replacingOccurrences(of: "_", with: " ").capitalized
  }

  var trackingIDLabel: String {
    mate.id.isEmpty ? "Not assigned" : mate.id
  }

  var degreeOfFreedomSummary: String {
    let count = mateType?.degreeOfFreedomCount ?? mate.degreesOfFreedom.count
    return count == 1 ? "1 available" : "\(count) available"
  }

  var offsetMillimeters: [Double] {
    mate.controls.offset.translationMeters.map { $0 * 1_000 }
  }

  var offsetRotationDegrees: Double {
    mate.controls.offset.rotationRadians * 180 / .pi
  }

  var systemImage: String {
    switch mate.type {
    case "fastened": "link"
    case "parallel": "equal.circle"
    case "prismatic": "arrow.up.and.down"
    case "revolute": "rotate.3d"
    case "cylindrical": "cylinder"
    case "pin_slot": "arrow.left.and.right.circle"
    case "planar": "square.3.layers.3d"
    case "ball": "move.3d"
    default: "point.3.connected.trianglepath.dotted"
    }
  }

  var additionalControlIDs: [String] {
    let renderedControls: Set<String> = [
      "connector_a",
      "connector_b",
      "offset",
      "flip_primary_axis",
      "secondary_axis_rotation",
      "simulation_connection",
    ]
    return mateType?.universalControls.filter { !renderedControls.contains($0) } ?? []
  }
}

private struct EngineMateConnectorRow: View {
  let label: String
  let connector: AnimaCoreMateConnector?

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 8) {
        Label("Connector \(label)", systemImage: "scope")
          .font(.callout.weight(.semibold))
        Spacer(minLength: 8)
        EngineMateReadOnlyToggle(
          title: "Flip",
          isOn: connector?.isFlipped ?? false,
          isCompact: true
        )
      }

      if let connector {
        LabeledContent("Part", value: connector.part)
        LabeledContent(
          "Feature", value: connector.feature.isEmpty ? "Custom frame" : connector.feature)
        LabeledContent("Origin") {
          Text(vector(connector.originMeters, multiplier: 1_000))
            .monospacedDigit()
          Text("mm")
            .foregroundStyle(StudioPalette.muted)
        }
        LabeledContent("Primary Z", value: vector(connector.primaryAxis))
        LabeledContent("Secondary X", value: vector(connector.secondaryAxis))
      } else {
        Label("Not assigned", systemImage: "plus.circle.dashed")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }
    }
    .padding(.vertical, 3)
  }

  private func vector(_ values: [Double], multiplier: Double = 1) -> String {
    values.map { value in
      (value * multiplier).formatted(.number.precision(.fractionLength(0...3)))
    }.joined(separator: ", ")
  }
}

private struct EngineMateReadOnlyToggle: View {
  let title: String
  let isOn: Bool
  var isCompact = false

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: isOn ? "checkmark.square.fill" : "square")
        .foregroundStyle(isOn ? StudioPalette.accent : StudioPalette.muted)
      Text(title)
        .font(isCompact ? .caption : .callout)
      if !isCompact {
        Spacer(minLength: 8)
        Text(isOn ? "On" : "Off")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(title)
    .accessibilityValue(isOn ? "On, read only" : "Off, read only")
  }
}

private struct EngineMateAxisReadout: View {
  let axis: String
  let value: Double
  let unit: String

  var body: some View {
    LabeledContent {
      Text(value, format: .number.precision(.fractionLength(0...3)))
        .monospacedDigit()
      Text(unit)
        .foregroundStyle(StudioPalette.muted)
    } label: {
      Text(axis)
        .fontWeight(.semibold)
        .foregroundStyle(axisColor)
    }
  }

  private var axisColor: Color {
    switch axis {
    case "X": .red
    case "Y": .green
    default: .blue
    }
  }
}

private struct EngineMateDOFRow: View {
  let degreeOfFreedom: AnimaCoreDOFSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(degreeOfFreedom.path)
        .font(.caption.monospaced().weight(.semibold))
      LabeledContent("Kind", value: degreeOfFreedom.kind.rawValue.capitalized)
      LabeledContent("Neutral", value: formatted(degreeOfFreedom.neutral))
      LabeledContent(
        "Limits",
        value: limitsLabel
      )
    }
    .padding(.vertical, 3)
  }

  private var limitsLabel: String {
    guard let minimum = degreeOfFreedom.minimum,
      let maximum = degreeOfFreedom.maximum
    else { return "Unbounded" }
    return "\(formatted(minimum)) … \(formatted(maximum))"
  }

  private func formatted(_ nativeValue: Double) -> String {
    let value: Double
    let unit: String
    switch degreeOfFreedom.unit {
    case .radians:
      value = nativeValue * 180 / .pi
      unit = "°"
    case .meters:
      value = nativeValue * 1_000
      unit = " mm"
    }
    return value.formatted(.number.precision(.fractionLength(0...3))) + unit
  }
}
