import AnimaCoreClient
import SwiftUI

struct HardwareWorkspaceView: View {
  @Bindable var workspace: StudioWorkspaceModel

  @State private var editorContext: OutputEditorContext?
  @State private var pendingRemoval: AnimaCoreOutputSummary?
  @State private var errorMessage: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top, spacing: 16) {
          statusCard
          safetyCard
          mappingCard
        }
        outputMappings
        driverLog
      }
      .padding(24)
      .frame(maxWidth: 1100)
      .frame(maxWidth: .infinity)
    }
    .background(StudioPalette.canvas)
    .sheet(item: $editorContext) { context in
      HardwareOutputMappingEditor(
        title: context.originalChannel == nil ? "Add Output Mapping" : "Edit Output Mapping",
        initialDraft: context.draft,
        targets: workspace.hardwareOutputTargets,
        mappings: workspace.engineOutputs,
        originalChannel: context.originalChannel
      ) { draft in
        try await workspace.saveOutputMapping(
          draft,
          originalChannel: context.originalChannel
        )
      }
    }
    .confirmationDialog(
      "Remove Output Mapping?",
      isPresented: Binding(
        get: { pendingRemoval != nil },
        set: { if !$0 { pendingRemoval = nil } }
      ),
      titleVisibility: .visible,
      presenting: pendingRemoval
    ) { mapping in
      Button("Remove Channel \(mapping.channel)", role: .destructive) {
        remove(mapping)
      }
      Button("Cancel", role: .cancel) {}
    } message: { mapping in
      Text(
        "This removes channel \(mapping.channel) from \(mapping.targetPath). "
          + "It does not connect to or move hardware."
      )
    }
    .alert(
      "Output Mapping Could Not Be Changed",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    ) {
      Button("OK") {}
    } message: {
      Text(errorMessage ?? "An unknown error occurred.")
    }
  }

  private var statusCard: some View {
    HardwareCard(title: "Driver Connection", systemImage: "cable.connector") {
      HardwareStatusRow(
        title: "Authoring",
        value: workspace.engineOutputs.isEmpty ? "No mappings" : "Mappings ready",
        tint: workspace.engineOutputs.isEmpty ? .secondary : .green
      )
      HardwareStatusRow(title: "Live transport", value: "Offline", tint: .secondary)
      HardwareStatusRow(title: "Drivers", value: "0 connected")
      Divider()
      Button("Connect Driver", systemImage: "powerplug") {}
        .buttonStyle(StudioPrimaryButtonStyle())
        .disabled(true)
        .help("Live transport remains safely offline in this milestone")
    }
  }

  private var safetyCard: some View {
    HardwareCard(title: "Safety", systemImage: "lock.shield") {
      HardwareStatusRow(title: "Master Live", value: "Disarmed", tint: .secondary)
      HardwareStatusRow(title: "Failsafe", value: "No active session")
      HardwareStatusRow(title: "Heartbeat", value: "Not running")
      Divider()
      Label("Editing mappings never arms or moves outputs.", systemImage: "info.circle")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var mappingCard: some View {
    let reversedCount = workspace.engineOutputs.count {
      $0.valueAtZero > $0.valueAtOne
    }
    return HardwareCard(title: "Output Mapping", systemImage: "arrow.triangle.branch") {
      HardwareStatusRow(title: "Mappings", value: "\(workspace.engineOutputs.count)")
      HardwareStatusRow(
        title: "Channels",
        value: "\(Set(workspace.engineOutputs.map(\.channel)).count)"
      )
      HardwareStatusRow(title: "Reversed", value: "\(reversedCount)")
      Divider()
      Button("Add Mapping", systemImage: "plus") {
        beginAdding()
      }
      .buttonStyle(.bordered)
      .disabled(workspace.hardwareOutputTargets.isEmpty)
      .help(
        workspace.hardwareOutputTargets.isEmpty
          ? "Create a bounded mate DOF or parameter first"
          : "Map a bounded DOF or parameter to a normalized hardware channel"
      )
    }
  }

  private var outputMappings: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Label("Output Mappings", systemImage: "point.3.connected.trianglepath.dotted")
          .font(.headline)
        Text("AnimaCore validated")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.green)
        Spacer()
        Button("Add", systemImage: "plus") {
          beginAdding()
        }
        .disabled(workspace.hardwareOutputTargets.isEmpty)
      }
      .padding(12)

      Divider()

      HStack(spacing: 12) {
        Text("CHANNEL")
          .frame(width: 72, alignment: .leading)
        Text("TARGET")
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("0% → 100%")
          .frame(width: 190, alignment: .leading)
        Text("DIRECTION")
          .frame(width: 86, alignment: .leading)
        Color.clear.frame(width: 62)
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12)
      .frame(height: 34)
      .background(StudioPalette.panel)

      if workspace.engineOutputs.isEmpty {
        ContentUnavailableView(
          "No Output Mappings",
          systemImage: "arrow.triangle.branch",
          description: Text(
            workspace.hardwareOutputTargets.isEmpty
              ? "Create a bounded mate DOF or parameter before assigning hardware channels."
              : "Add a mapping to project an authored value onto a normalized 0–1 channel."
          )
        )
        .frame(minHeight: 180)
      } else {
        LazyVStack(spacing: 0) {
          ForEach(workspace.engineOutputs.sorted(by: { $0.channel < $1.channel }), id: \.channel) {
            mapping in
            outputRow(mapping)
            Divider()
          }
        }
      }
    }
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }

  private func outputRow(_ mapping: AnimaCoreOutputSummary) -> some View {
    let target = workspace.hardwareOutputTargets.first { $0.path == mapping.targetPath }
    let kind = target?.kind ?? .parameter
    let zero = kind.displayValue(fromNative: mapping.valueAtZero)
    let one = kind.displayValue(fromNative: mapping.valueAtOne)
    return HStack(spacing: 12) {
      Text("\(mapping.channel)")
        .font(.body.monospacedDigit().weight(.semibold))
        .frame(width: 72, alignment: .leading)
      VStack(alignment: .leading, spacing: 2) {
        Text(target?.label ?? mapping.targetPath)
        Text(mapping.targetPath)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Text("\(formatted(zero)) → \(formatted(one)) \(kind.unitLabel)")
        .font(.callout.monospacedDigit())
        .frame(width: 190, alignment: .leading)
      Label(
        mapping.valueAtZero > mapping.valueAtOne ? "Reverse" : "Forward",
        systemImage: mapping.valueAtZero > mapping.valueAtOne
          ? "arrow.left" : "arrow.right"
      )
      .font(.caption)
      .foregroundStyle(mapping.valueAtZero > mapping.valueAtOne ? .orange : .secondary)
      .frame(width: 86, alignment: .leading)
      HStack(spacing: 6) {
        Button("Edit", systemImage: "pencil") {
          beginEditing(mapping)
        }
        .labelStyle(.iconOnly)
        Button("Remove", systemImage: "trash", role: .destructive) {
          pendingRemoval = mapping
        }
        .labelStyle(.iconOnly)
      }
      .frame(width: 62, alignment: .trailing)
    }
    .padding(.horizontal, 12)
    .frame(minHeight: 54)
    .contentShape(Rectangle())
    .contextMenu {
      Button("Edit Mapping", systemImage: "pencil") {
        beginEditing(mapping)
      }
      Divider()
      Button("Remove Mapping", systemImage: "trash", role: .destructive) {
        pendingRemoval = mapping
      }
    }
  }

  private var driverLog: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Label("Driver Log", systemImage: "terminal")
          .font(.headline)
        Spacer()
        Text("Offline")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .padding(12)

      Divider()

      ContentUnavailableView(
        "No Driver Session",
        systemImage: "terminal",
        description: Text(
          "Live transport and device traffic remain disabled until the safety connection "
            + "milestone."
        )
      )
      .frame(minHeight: 160)
    }
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }

  private func beginAdding() {
    guard let target = workspace.hardwareOutputTargets.first else { return }
    editorContext = OutputEditorContext(
      originalChannel: nil,
      draft: HardwareOutputMappingDraft(
        target: target,
        channel: workspace.nextAvailableOutputChannel
      )
    )
  }

  private func beginEditing(_ mapping: AnimaCoreOutputSummary) {
    guard
      let target = workspace.hardwareOutputTargets.first(where: {
        $0.path == mapping.targetPath
      })
    else {
      errorMessage =
        "The mapping target ‘\(mapping.targetPath)’ is unavailable. "
        + "Restore that DOF or remove the mapping."
      return
    }
    editorContext = OutputEditorContext(
      originalChannel: mapping.channel,
      draft: HardwareOutputMappingDraft(mapping: mapping, target: target)
    )
  }

  private func remove(_ mapping: AnimaCoreOutputSummary) {
    pendingRemoval = nil
    Task {
      do {
        try await workspace.removeOutputMapping(channel: mapping.channel)
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  private func formatted(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...3)))
  }
}

private struct OutputEditorContext: Identifiable {
  let id = UUID()
  let originalChannel: Int?
  let draft: HardwareOutputMappingDraft
}

private struct HardwareOutputMappingEditor: View {
  @Environment(\.dismiss) private var dismiss

  let title: String
  let targets: [HardwareOutputTargetOption]
  let mappings: [AnimaCoreOutputSummary]
  let originalChannel: Int?
  let onSave: (HardwareOutputMappingDraft) async throws -> Void

  @State private var draft: HardwareOutputMappingDraft
  @State private var isSaving = false
  @State private var errorMessage: String?

  init(
    title: String,
    initialDraft: HardwareOutputMappingDraft,
    targets: [HardwareOutputTargetOption],
    mappings: [AnimaCoreOutputSummary],
    originalChannel: Int?,
    onSave: @escaping (HardwareOutputMappingDraft) async throws -> Void
  ) {
    self.title = title
    self.targets = targets
    self.mappings = mappings
    self.originalChannel = originalChannel
    self.onSave = onSave
    _draft = State(initialValue: initialDraft)
  }

  private var selectedTarget: HardwareOutputTargetOption? {
    targets.first { $0.path == draft.targetPath }
  }

  private var validationMessage: String? {
    do {
      _ = try draft.validatedNativeValues(
        targets: targets,
        existingMappings: mappings,
        originalChannel: originalChannel
      )
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        Label(title, systemImage: "arrow.triangle.branch")
          .font(.title3.weight(.semibold))
        Spacer()
        Text("AUTHORING ONLY")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.secondary)
      }

      Form {
        Picker("Target", selection: $draft.targetPath) {
          ForEach(targets) { target in
            Text(target.label).tag(target.path)
          }
        }

        TextField("Channel", value: $draft.channel, format: .number)

        Section("Normalized Channel Range") {
          HStack {
            Text("0%")
              .frame(width: 42, alignment: .leading)
            TextField(
              "Value at zero",
              value: $draft.valueAtZero,
              format: .number.precision(.fractionLength(0...4))
            )
            Text(selectedTarget?.kind.unitLabel ?? "")
              .foregroundStyle(.secondary)
              .frame(width: 42, alignment: .leading)
          }
          HStack {
            Text("100%")
              .frame(width: 42, alignment: .leading)
            TextField(
              "Value at one",
              value: $draft.valueAtOne,
              format: .number.precision(.fractionLength(0...4))
            )
            Text(selectedTarget?.kind.unitLabel ?? "")
              .foregroundStyle(.secondary)
              .frame(width: 42, alignment: .leading)
          }
          Button("Reverse Endpoints", systemImage: "arrow.left.arrow.right") {
            draft.reverse()
          }
        }
      }
      .formStyle(.grouped)
      .onChange(of: draft.targetPath) { oldValue, newValue in
        guard oldValue != newValue,
          let target = targets.first(where: { $0.path == newValue })
        else { return }
        draft.select(target)
      }

      if let message = errorMessage ?? validationMessage {
        Label(message, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
      } else {
        Label(
          "AnimaCore converts this native target range to normalized channel values 0–1.",
          systemImage: "checkmark.shield"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      HStack {
        Button("Cancel", role: .cancel) { dismiss() }
        Spacer()
        if isSaving {
          ProgressView()
            .controlSize(.small)
        }
        Button("Save Mapping") {
          save()
        }
        .buttonStyle(StudioPrimaryButtonStyle())
        .disabled(isSaving || validationMessage != nil)
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 500)
  }

  private func save() {
    guard !isSaving else { return }
    isSaving = true
    errorMessage = nil
    Task {
      do {
        try await onSave(draft)
        dismiss()
      } catch {
        errorMessage = error.localizedDescription
        isSaving = false
      }
    }
  }
}

private struct HardwareCard<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(title, systemImage: systemImage)
        .font(.headline)
      content()
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }
}

private struct HardwareStatusRow: View {
  let title: String
  let value: String
  var tint: Color = .primary

  var body: some View {
    HStack {
      Text(title)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .foregroundStyle(tint)
    }
    .font(.callout)
  }
}
