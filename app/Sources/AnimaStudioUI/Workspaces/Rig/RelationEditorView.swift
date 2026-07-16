import AnimaCoreClient
import SwiftUI

struct RelationEditorView: View {
  @Binding var draft: RelationDraft
  let driverOptions: [RelationDOFOption]
  let drivenOptions: [RelationDOFOption]
  let dismiss: () -> Void

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
      Text(
        "This dialog prepares a relation draft. Creating or editing the canonical character document is the next authoring packet, so no rig mutation occurs here."
      )
      .font(.caption)
      .foregroundStyle(StudioPalette.muted)
    }
  }

  private var footer: some View {
    HStack {
      Button("Cancel", role: .cancel, action: dismiss)
      Spacer()
      Button("Create Relation", systemImage: "checkmark") {}
        .buttonStyle(.borderedProminent)
        .disabled(true)
        .help(
          draft.canPrepareForAuthoring
            ? "Canonical document mutation is not wired yet"
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
