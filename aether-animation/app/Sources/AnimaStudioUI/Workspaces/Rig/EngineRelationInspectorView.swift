import AnimaCoreClient
import SwiftUI

struct EngineRelationInspectorView: View {
  @Bindable var workspace: StudioWorkspaceModel
  let relation: AnimaCoreRelationSummary
  let relationType: AnimaCoreRelationTypeSummary?

  @State private var draft: RelationDraft?
  @State private var isApplying = false
  @State private var errorMessage: String?

  private var label: String {
    relationType?.label
      ?? relation.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
  }

  private var fieldTitle: String {
    relationType.map { RelationEditorPresentation(type: $0).fieldTitle }
      ?? "Relation value"
  }

  var body: some View {
    identitySection
    relationshipSection
    referenceGeometrySection
    actionsSection
    contractSection
      .onAppear(perform: resetDraft)
      .onChange(of: relation.id) { _, _ in resetDraft() }
      .onChange(of: relation.ratio) { _, _ in resetDraft() }
      .onChange(of: relation.offset) { _, _ in resetDraft() }
  }

  private var identitySection: some View {
    Section("Advanced Relation") {
      Label(label, systemImage: relation.kind.systemImage)
        .foregroundStyle(StudioPalette.joint)
      LabeledContent("Driver", value: relation.driver)
      LabeledContent("Driven", value: relation.driven)
      if let relationType {
        LabeledContent(
          "Compatibility",
          value: RelationEditorPresentation(type: relationType).compatibilitySummary
        )
      }
    }
  }

  @ViewBuilder
  private var relationshipSection: some View {
    Section("Relationship") {
      if let draftBinding {
        StudioNumberFieldRow(
          title: fieldTitle,
          value: draftBinding.ratioFieldValue,
          unit: relationType?.ratioField.unit == "ratio" ? nil : relationType?.ratioField.unit,
          help: "Positive magnitude; direction is edited separately."
        )
        Toggle("Reverse direction", isOn: draftBinding.isReversed)
          .disabled(relationType?.supportsReverse == false)
        StudioNumberFieldRow(
          title: "Driven offset",
          value: draftBinding.offsetFieldValue,
          unit: relationType?.drivenKind == .translation ? "mm" : "deg",
          help: "Offset in the driven DOF's display units."
        )
        if let signedRatio = draft?.signedSemanticRatio {
          StudioReadoutRow(
            title: "Canonical ratio",
            value: signedRatio.formatted(.number.precision(.fractionLength(6))),
            unit: nativeRatioUnit
          )
        }
        if let validationMessage = draft?.validationError?.localizedDescription {
          Label(validationMessage, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        }
      } else {
        StudioReadoutRow(
          title: fieldTitle,
          value: relation.ratioFieldValue.formatted(.number.precision(.fractionLength(3))),
          unit: relationType?.ratioField.unit == "ratio" ? nil : relationType?.ratioField.unit
        )
        LabeledContent("Reverse direction", value: relation.isReversed ? "On" : "Off")
        StudioReadoutRow(
          title: "Signed ratio",
          value: relation.ratio.formatted(.number.precision(.fractionLength(6))),
          unit: nativeRatioUnit
        )
        StudioReadoutRow(
          title: "Driven offset",
          value: relation.offset.formatted(.number.precision(.fractionLength(6))),
          unit: relationType?.drivenKind == .translation ? "m" : "rad"
        )
      }
    }
  }

  @ViewBuilder
  private var referenceGeometrySection: some View {
    if !relation.display.isEmpty {
      Section("Reference Geometry") {
        ForEach(relation.display.keys.sorted(), id: \.self) { key in
          LabeledContent(
            key.replacingOccurrences(of: "_", with: " ").capitalized,
            value: relation.display[key, default: 0].formatted(
              .number.precision(.fractionLength(3))
            )
          )
        }
      }
    }
  }

  @ViewBuilder
  private var actionsSection: some View {
    if draft != nil {
      Section {
        HStack {
          Button("Revert") {
            resetDraft()
          }
          .disabled(isApplying || !hasChanges)
          Spacer()
          if isApplying {
            ProgressView()
              .controlSize(.small)
          }
          Button("Apply") {
            apply()
          }
          .buttonStyle(.borderedProminent)
          .disabled(isApplying || !hasChanges || draft?.validationError != nil)
        }
        if let errorMessage {
          Label(errorMessage, systemImage: "xmark.octagon")
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
    }
  }

  private var contractSection: some View {
    Section("Engine Contract") {
      Label("Evaluated and edited by AnimaCore", systemImage: "checkmark.shield.fill")
        .foregroundStyle(StudioPalette.hardware)
      Text(
        "The coupled mate components are highlighted in the viewport. Ratio sign, dependency ordering, motion, limits, and validation remain engine-owned."
      )
      .font(.caption)
      .foregroundStyle(StudioPalette.muted)
    }
  }

  private var draftBinding: Binding<RelationDraft>? {
    guard draft != nil else { return nil }
    return Binding(
      get: { draft! },
      set: { draft = $0 }
    )
  }

  private var baselineDraft: RelationDraft? {
    relationType.map { RelationDraft(relation: relation, type: $0) }
  }

  private var hasChanges: Bool {
    guard let draft, let baselineDraft else { return false }
    return !draft.hasSameEditableValues(as: baselineDraft)
  }

  private var nativeRatioUnit: String? {
    guard let relationType else { return nil }
    return switch (relationType.driverKind, relationType.drivenKind) {
    case (.rotation, .translation): "m/rad"
    default: nil
    }
  }

  private func resetDraft() {
    draft = baselineDraft
    errorMessage = nil
  }

  private func apply() {
    guard let draft else { return }
    isApplying = true
    errorMessage = nil
    Task {
      do {
        _ = try await workspace.updateEngineRelation(relation, with: draft)
      } catch {
        errorMessage = error.localizedDescription
      }
      isApplying = false
    }
  }
}
