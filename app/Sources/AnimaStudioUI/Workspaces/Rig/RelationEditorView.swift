import AnimaCoreClient
import SwiftUI

struct RelationEditorView: View {
  @Binding var draft: RelationDraft
  let driverOptions: [RelationDOFOption]
  let drivenOptions: [RelationDOFOption]
  let create: (RelationDraft) async throws -> Void
  let dismiss: () -> Void
  @State private var isApplying = false
  @State private var errorMessage: String?

  private var presentation: RelationEditorPresentation {
    RelationEditorPresentation(type: draft.type)
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      Form {
        typeSection
        couplingSection
        ratioSection
        statusSection
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
      .background(StudioPalette.panel)
      Divider()
      footer
    }
    .frame(width: 430, height: 510)
    .studioPanelSurface()
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: draft.type.kind.systemImage)
        .font(.title3)
        .foregroundStyle(StudioPalette.joint)
      VStack(alignment: .leading, spacing: 2) {
        Text(draft.type.label)
          .font(.headline)
        Text("Advanced relation")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }
      Spacer()
      Button("Close", systemImage: "xmark", action: dismiss)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
    }
    .padding(14)
  }

  private var typeSection: some View {
    Section("Relation Type") {
      LabeledContent("Type", value: draft.type.label)
      LabeledContent("Compatibility", value: presentation.compatibilitySummary)
    }
  }

  private var couplingSection: some View {
    Section("Coupled Mate DOFs") {
      relationDOFPicker(
        title: "1 · Driver",
        prompt: presentation.driverPrompt,
        selection: $draft.driverPath,
        options: driverOptions
      )
      relationDOFPicker(
        title: "2 · Driven",
        prompt: presentation.drivenPrompt,
        selection: $draft.drivenPath,
        options: drivenOptions
      )
      if driverOptions.isEmpty || drivenOptions.isEmpty {
        Label(
          "The loaded rig does not contain both required DOF kinds.",
          systemImage: "exclamationmark.triangle"
        )
        .font(.caption)
        .foregroundStyle(.orange)
      }
    }
  }

  private var ratioSection: some View {
    Section("Relationship") {
      StudioNumberFieldRow(
        title: presentation.fieldTitle,
        value: $draft.ratioFieldValue,
        unit: presentation.fieldUnit,
        help: ratioHelp
      )
      Toggle("Reverse direction", isOn: $draft.isReversed)
        .disabled(!draft.type.supportsReverse)
      StudioNumberFieldRow(
        title: "Driven offset",
        value: $draft.offsetFieldValue,
        unit: draft.type.drivenKind == .translation ? "mm" : "deg",
        help: "Initial offset applied in the driven DOF's display units."
      )
      if let signedRatio = draft.signedSemanticRatio {
        StudioReadoutRow(
          title: "Canonical ratio",
          value: signedRatio.formatted(.number.precision(.fractionLength(6))),
          unit: canonicalUnit,
          help: "Preview of the signed native-unit value the document writer will validate."
        )
      }
    }
  }

  private var statusSection: some View {
    Section("Authoring Status") {
      Label("Catalog and compatibility are engine-backed", systemImage: "checkmark.shield")
        .foregroundStyle(StudioPalette.hardware)
      Text("Create validates and mutates the loaded character through AnimaCore.")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      if let validationError = draft.validationError?.localizedDescription {
        Label(validationError, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.orange)
      }
      if let errorMessage {
        Label(errorMessage, systemImage: "xmark.octagon")
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
  }

  private var footer: some View {
    HStack {
      Button("Cancel", role: .cancel, action: dismiss)
        .disabled(isApplying)
      Spacer()
      if isApplying {
        ProgressView()
          .controlSize(.small)
      }
      Button("Create Relation", systemImage: "checkmark") {
        isApplying = true
        errorMessage = nil
        Task {
          do {
            try await create(draft)
          } catch {
            errorMessage = error.localizedDescription
          }
          isApplying = false
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(!draft.canPrepareForAuthoring || isApplying)
      .help(
        draft.canPrepareForAuthoring
          ? "Create this relation through AnimaCore"
          : "Select compatible driver and driven DOFs and enter a positive value"
      )
    }
    .padding(14)
  }

  private func relationDOFPicker(
    title: String,
    prompt: String,
    selection: Binding<String?>,
    options: [RelationDOFOption]
  ) -> some View {
    Picker(title, selection: selection) {
      Text(prompt).tag(String?.none)
      ForEach(options) { option in
        VStack(alignment: .leading) {
          Text(option.displayName)
          Text(option.path)
        }
        .tag(Optional(option.path))
      }
    }
  }

  private var ratioHelp: String {
    draft.type.ratioField.unit == "mm"
      ? "Positive travel in millimetres for one full driver revolution. Direction is controlled separately."
      : "Positive driven-to-driver magnitude. Direction is controlled separately."
  }

  private var canonicalUnit: String? {
    draft.type.ratioField.unit == "mm" ? "m/rad" : nil
  }
}
