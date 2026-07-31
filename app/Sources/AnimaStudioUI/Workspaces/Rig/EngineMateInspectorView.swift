import AnimaCoreClient
import SwiftUI

/// One presentation-only mate inspector driven by AnimaCore descriptors.
/// Every mate kind uses this surface; the engine catalog supplies the label
/// and DOF rows, while `describe_mate` supplies the instance controls.
struct EngineMateInspectorView: View {
  @Bindable var workspace: StudioWorkspaceModel
  let mate: AnimaCoreJointSummary
  let mateType: AnimaCoreMateTypeSummary?
  @State private var baseline: EngineMateEditDraft
  @State private var draft: EngineMateEditDraft
  @State private var isApplying = false
  @State private var editErrorMessage: String?

  init(
    workspace: StudioWorkspaceModel,
    mate: AnimaCoreJointSummary,
    mateType: AnimaCoreMateTypeSummary?
  ) {
    self.workspace = workspace
    self.mate = mate
    self.mateType = mateType
    let initialDraft = EngineMateEditDraft(mate: mate)
    _baseline = State(initialValue: initialDraft)
    _draft = State(initialValue: initialDraft)
  }

  private var presentation: EngineMateInspectorPresentation {
    EngineMateInspectorPresentation(mate: mate, mateType: mateType)
  }

  var body: some View {
    editActionsSection
    identitySection
    connectorSection
    tangentSelectionSection
    offsetSection
    orientationSection
    degreesOfFreedomSection
    authoringBoundarySection
    if let editErrorMessage {
      Section {
        Label(editErrorMessage, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
    Group {}
      .onChange(of: mate) { _, updatedMate in
        let updatedDraft = EngineMateEditDraft(mate: updatedMate)
        baseline = updatedDraft
        draft = updatedDraft
        editErrorMessage = nil
      }
  }

  private var editActionsSection: some View {
    Section {
      HStack(spacing: 8) {
        Button("Revert") {
          draft = baseline
          editErrorMessage = nil
        }
        .disabled(isApplying || draft == baseline)

        Spacer(minLength: 8)

        if isApplying {
          ProgressView()
            .controlSize(.small)
        }
        Button("Apply") {
          applyDraft()
        }
        .buttonStyle(.borderedProminent)
        .disabled(
          isApplying || draft == baseline || draft.validationMessage != nil
        )
      }
      if let validationMessage = draft.validationMessage {
        Text(validationMessage)
          .font(.caption)
          .foregroundStyle(.orange)
      }
    } header: {
      Text("Engine Edit")
    } footer: {
      Text("Apply validates the complete mate through AnimaCore and refreshes the solved pose.")
    }
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
      LabeledContent("Category", value: presentation.categoryLabel)
      LabeledContent("Animation Driver", value: presentation.isDrivable ? "Yes" : "No")
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
    if let controls = mate.controls,
      supports("connector_a") || supports("connector_b")
    {
      Section("Mate Connectors") {
        if supports("connector_a") {
          EngineMateConnectorRow(
            label: "A",
            connector: controls.connectors.a,
            isFlipped: $draft.connectorAFlipped
          )
        }
        if supports("connector_b") {
          EngineMateConnectorRow(
            label: "B",
            connector: controls.connectors.b,
            isFlipped: $draft.connectorBFlipped
          )
        }
      }
    }
  }

  @ViewBuilder
  private var tangentSelectionSection: some View {
    if let tangent = mate.tangent {
      Section("Tangent Surfaces") {
        EngineMateSurfaceSelectionRow(label: "Surface A", selection: tangent.selectionA)
        EngineMateSurfaceSelectionRow(label: "Surface B", selection: tangent.selectionB)
        EngineMateReadOnlyToggle(
          title: "Tangent Propagation",
          isOn: tangent.propagatesAcrossTangentFaces
        )
        LabeledContent("Simulation Connection", value: "Engine default")
      }
    }
  }

  @ViewBuilder
  private var offsetSection: some View {
    if mate.controls != nil, supports("offset") {
      Section("Offset") {
        Toggle("Enable Offset", isOn: $draft.offsetEnabled)
        Group {
          ForEach(0..<3, id: \.self) { index in
            EngineMateAxisField(
              axis: ["X", "Y", "Z"][index],
              value: offsetBinding(at: index),
              unit: "mm"
            )
          }
          Picker("Rotate About", selection: $draft.offsetRotationAxis) {
            ForEach(AnimaCoreMateAxis.allCases, id: \.self) { axis in
              Text(axis.rawValue.uppercased()).tag(axis)
            }
          }
          LabeledContent("Rotation Angle") {
            TextField(
              "Angle",
              value: $draft.offsetRotationDegrees,
              format: .number.precision(.fractionLength(0...3))
            )
            .multilineTextAlignment(.trailing)
            .frame(width: 88)
            Text("°")
              .foregroundStyle(StudioPalette.muted)
          }
        }
        .disabled(!draft.offsetEnabled)
        .opacity(draft.offsetEnabled ? 1 : 0.55)
      }
    }
  }

  @ViewBuilder
  private var orientationSection: some View {
    if mate.controls != nil,
      supports("flip_primary_axis") || supports("secondary_axis_rotation")
        || supports("simulation_connection") || !presentation.additionalControlIDs.isEmpty
    {
      Section("Orientation & Simulation") {
        if supports("flip_primary_axis") {
          Toggle("Flip Primary Axis", isOn: $draft.flipsPrimaryAxis)
        }
        if supports("secondary_axis_rotation") {
          LabeledContent("Secondary Axis Rotation") {
            TextField(
              "Rotation",
              value: $draft.secondaryAxisRotationDegrees,
              format: .number
            )
            .multilineTextAlignment(.trailing)
            .frame(width: 72)
            Text("°")
              .foregroundStyle(StudioPalette.muted)
          }
        }
        if supports("simulation_connection") {
          Toggle("Simulation Connection", isOn: $draft.isSimulationConnection)
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
          Image(systemName: presentation.zeroDOFSystemImage)
            .foregroundStyle(StudioPalette.joint)
          VStack(alignment: .leading, spacing: 2) {
            Text(presentation.zeroDOFTitle)
              .font(.callout.weight(.semibold))
            Text(presentation.zeroDOFDetail)
              .font(.caption)
              .foregroundStyle(StudioPalette.muted)
          }
        }
        .accessibilityElement(children: .combine)
      } else {
        ForEach($draft.degreesOfFreedom) { $degreeOfFreedom in
          EngineMateDOFEditor(degreeOfFreedom: $degreeOfFreedom)
        }
      }
    }
  }

  private var authoringBoundarySection: some View {
    Section("Authoring State") {
      Label("Validated by AnimaCore", systemImage: "checkmark.shield.fill")
        .foregroundStyle(StudioPalette.hardware)
      Text(
        "This editor changes the retained engine DTO and submits it through update_mate. AnimaCore remains the validator, solver, and canonical character author."
      )
      .font(.caption)
      .foregroundStyle(StudioPalette.muted)
    }
  }

  private func supports(_ controlID: String) -> Bool {
    if let mateType {
      return mateType.universalControls.contains(controlID)
    }
    return mate.controls != nil && mate.type != "tangent"
  }

  private func offsetBinding(at index: Int) -> Binding<Double> {
    Binding(
      get: {
        draft.offsetTranslationMillimeters.indices.contains(index)
          ? draft.offsetTranslationMillimeters[index] : 0
      },
      set: { newValue in
        guard draft.offsetTranslationMillimeters.indices.contains(index) else { return }
        draft.offsetTranslationMillimeters[index] = newValue
      }
    )
  }

  private func applyDraft() {
    guard !isApplying else { return }
    isApplying = true
    editErrorMessage = nil
    Task { @MainActor in
      defer { isApplying = false }
      do {
        let updated = try await workspace.updateEngineMate(mate, with: draft)
        let updatedDraft = EngineMateEditDraft(mate: updated)
        baseline = updatedDraft
        draft = updatedDraft
      } catch {
        editErrorMessage = error.localizedDescription
      }
    }
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

  var categoryLabel: String {
    switch mate.category {
    case .kinematic: "Kinematic"
    case .geometryConstraint: "Geometry constraint"
    }
  }

  var isDrivable: Bool {
    mateType?.isDrivable ?? (mate.category == .kinematic)
  }

  var offsetMillimeters: [Double] {
    mate.controls?.offset.translationMeters.map { $0 * 1_000 } ?? []
  }

  var offsetRotationDegrees: Double {
    (mate.controls?.offset.rotationRadians ?? 0) * 180 / .pi
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
    case "width": "arrow.left.and.right.square"
    case "tangent": "circle.dotted.and.circle"
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
      "tangent_selection_a",
      "tangent_selection_b",
      "tangent_propagation",
    ]
    return mateType?.universalControls.filter { !renderedControls.contains($0) } ?? []
  }

  var zeroDOFTitle: String {
    switch mate.type {
    case "fastened": "Fully bonded"
    case "width": "Width constraint"
    case "tangent": "Tangent constraint"
    default: "No drivable motion"
    }
  }

  var zeroDOFDetail: String {
    switch mate.type {
    case "fastened":
      "Fastened removes all six relative degrees of freedom."
    case "width":
      "Width centers geometry between its references and is not offered as an animation driver."
    case "tangent":
      "Tangent keeps the selected surfaces in contact and is not offered as an animation driver."
    default:
      "AnimaCore reports no animation-driving degrees of freedom for this mate."
    }
  }

  var zeroDOFSystemImage: String {
    mate.category == .geometryConstraint ? "ruler.fill" : "lock.fill"
  }
}

private struct EngineMateSurfaceSelectionRow: View {
  let label: String
  let selection: String

  var body: some View {
    LabeledContent(label) {
      Text(selection.isEmpty ? "Not assigned" : selection)
        .foregroundStyle(selection.isEmpty ? StudioPalette.muted : .primary)
        .textSelection(.enabled)
    }
  }
}

private struct EngineMateConnectorRow: View {
  let label: String
  let connector: AnimaCoreMateConnector?
  @Binding var isFlipped: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 8) {
        Label("Connector \(label)", systemImage: "scope")
          .font(.callout.weight(.semibold))
        Spacer(minLength: 8)
        Toggle("Flip", isOn: $isFlipped)
          .toggleStyle(.checkbox)
          .controlSize(.small)
          .disabled(connector == nil)
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

private struct EngineMateAxisField: View {
  let axis: String
  @Binding var value: Double
  let unit: String

  var body: some View {
    LabeledContent {
      TextField(
        axis,
        value: $value,
        format: .number.precision(.fractionLength(0...3))
      )
      .multilineTextAlignment(.trailing)
      .frame(width: 88)
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

private struct EngineMateDOFEditor: View {
  @Binding var degreeOfFreedom: EngineMateDOFEditDraft

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(degreeOfFreedom.path)
        .font(.caption.monospaced().weight(.semibold))
      LabeledContent("Kind", value: degreeOfFreedom.kind.rawValue.capitalized)
      LabeledContent("Axis", value: degreeOfFreedom.axis.rawValue.uppercased())
      numericField("Neutral", value: $degreeOfFreedom.neutral)
      optionalLimitField("Minimum", value: $degreeOfFreedom.minimum)
      optionalLimitField("Maximum", value: $degreeOfFreedom.maximum)
    }
    .padding(.vertical, 3)
  }

  private func numericField(_ title: String, value: Binding<Double>) -> some View {
    LabeledContent(title) {
      TextField(
        title,
        value: value,
        format: .number.precision(.fractionLength(0...3))
      )
      .multilineTextAlignment(.trailing)
      .frame(width: 88)
      Text(degreeOfFreedom.unitLabel)
        .foregroundStyle(StudioPalette.muted)
    }
  }

  private func optionalLimitField(
    _ title: String,
    value: Binding<Double?>
  ) -> some View {
    HStack(spacing: 8) {
      Toggle(
        title,
        isOn: Binding(
          get: { value.wrappedValue != nil },
          set: { isEnabled in
            value.wrappedValue = isEnabled ? (value.wrappedValue ?? 0) : nil
          }
        )
      )
      .toggleStyle(.checkbox)
      Spacer(minLength: 8)
      if value.wrappedValue != nil {
        TextField(
          title,
          value: Binding(
            get: { value.wrappedValue ?? 0 },
            set: { value.wrappedValue = $0 }
          ),
          format: .number.precision(.fractionLength(0...3))
        )
        .multilineTextAlignment(.trailing)
        .frame(width: 88)
        Text(degreeOfFreedom.unitLabel)
          .foregroundStyle(StudioPalette.muted)
      } else {
        Text("Unbounded")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }
    }
  }
}
