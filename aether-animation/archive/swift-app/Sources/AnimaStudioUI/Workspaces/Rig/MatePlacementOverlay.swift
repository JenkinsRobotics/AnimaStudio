import AnimaCoreClient
import AnimaEvaluation
import AnimaModel
import RealityKitViewport
import SwiftUI

struct MatePlacementSession: Equatable {
  var kind: MateCreationToolKind = .revolute
  var preferredPartID: PartID?
  var sourceCandidate: MateConnectorCandidate?
  var targetCandidate: MateConnectorCandidate?
  var options = EngineMatePlacementOptions()
  var isPreviewing = false
  var previewErrorMessage: String?
  var isSubmitting = false

  var canConfirm: Bool {
    sourceCandidate != nil && targetCandidate != nil && !isPreviewing
      && previewErrorMessage == nil && !isSubmitting
  }

  var stepNumber: Int {
    if targetCandidate != nil { return 3 }
    return sourceCandidate == nil ? 1 : 2
  }

  var title: String {
    if isSubmitting {
      return "Creating \(kind.title) mate in AnimaCore"
    }
    if isPreviewing {
      return "Solving \(kind.title) mate preview"
    }
    if targetCandidate != nil { return "Review and create \(kind.title) mate" }
    return sourceCandidate == nil
      ? "Select the moving component connector"
      : "Select the fixed connector"
  }

  var detail: String {
    if isSubmitting {
      return "The engine is validating the mate and resolving the updated assembly pose."
    }
    if isPreviewing {
      return "AnimaCore is aligning the moving connector to the fixed connector."
    }
    if let previewErrorMessage {
      return previewErrorMessage
    }
    if targetCandidate != nil {
      return "Adjust orientation, offset, or limits, then click the green checkmark."
    }
    if let sourceCandidate {
      return "\(sourceCandidate.displayName) will move and align to your second selection."
    }
    return "Choose an orange face center, edge midpoint, corner, axis, or origin marker."
  }
}

struct MatePlacementOverlay: View {
  let session: MatePlacementSession
  let confirm: () -> Void
  let cancel: () -> Void
  let clearSource: () -> Void
  let clearTarget: () -> Void
  let updateOptions: (EngineMatePlacementOptions) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: session.kind.systemImage)
          .foregroundStyle(StudioPalette.joint)
        Text(session.kind.title)
          .font(.headline)
        Spacer()
        if session.isSubmitting || session.isPreviewing {
          ProgressView()
            .controlSize(.small)
        }
        Button(action: confirm) {
          Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(
              session.canConfirm ? Color.green : Color.gray, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
        .disabled(!session.canConfirm)
        .help("Create mate in AnimaCore")
        Button(action: cancel) {
          Image(systemName: "xmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.red)
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .disabled(session.isSubmitting)
        .help("Cancel mate")
      }
      .padding(10)
      .background(StudioPalette.panel.opacity(0.94))

      Divider()

      VStack(alignment: .leading, spacing: 10) {
        Label(session.title, systemImage: "\(session.stepNumber).circle.fill")
          .font(.callout.weight(.semibold))
          .foregroundStyle(StudioPalette.joint)
        Text(session.detail)
          .font(.caption)
          .foregroundStyle(
            session.previewErrorMessage == nil ? StudioPalette.muted : Color.red
          )
          .fixedSize(horizontal: false, vertical: true)

        VStack(spacing: 5) {
          connectorRow(
            label: "Moving",
            candidate: session.sourceCandidate,
            clear: clearSource
          )
          connectorRow(
            label: "Fixed",
            candidate: session.targetCandidate,
            clear: clearTarget
          )
        }

        Divider()

        Toggle("Flip primary axis", isOn: optionBinding(\.flipsPrimaryAxis))
        HStack {
          Text("Reorient secondary")
          Spacer()
          Picker("", selection: optionBinding(\.secondaryAxisRotationDegrees)) {
            ForEach([0, 90, 180, 270], id: \.self) { angle in
              Text("\(angle)°").tag(angle)
            }
          }
          .labelsHidden()
          .frame(width: 88)
        }
        Toggle("Offset", isOn: optionBinding(\.offsetEnabled))
        if session.options.offsetEnabled {
          HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
              VStack(alignment: .leading, spacing: 2) {
                Text(["X", "Y", "Z"][index])
                  .font(.caption2)
                  .foregroundStyle(StudioPalette.muted)
                TextField("0", value: offsetBinding(index), format: .number)
                  .textFieldStyle(.roundedBorder)
              }
            }
            Text("mm")
              .font(.caption)
              .foregroundStyle(StudioPalette.muted)
          }
          HStack {
            Picker("Rotate", selection: optionBinding(\.offsetRotationAxis)) {
              ForEach(AnimaCoreMateAxis.allCases, id: \.self) { axis in
                Text(axis.rawValue.uppercased()).tag(axis)
              }
            }
            TextField(
              "Angle",
              value: optionBinding(\.offsetRotationDegrees),
              format: .number
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 72)
            Text("°")
              .foregroundStyle(StudioPalette.muted)
          }
        }
        Toggle("Simulation connection", isOn: optionBinding(\.isSimulationConnection))
      }
      .padding(12)
    }
    .frame(width: 310)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11))
    .overlay {
      RoundedRectangle(cornerRadius: 11)
        .stroke(StudioPalette.joint.opacity(0.72), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(session.kind.title) mate placement, step \(session.stepNumber)")
  }

  private func connectorRow(
    label: String,
    candidate: MateConnectorCandidate?,
    clear: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 7) {
      Image(systemName: candidate == nil ? "scope" : "checkmark.circle.fill")
        .foregroundStyle(candidate == nil ? StudioPalette.muted : Color.green)
      VStack(alignment: .leading, spacing: 1) {
        Text(label)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(StudioPalette.muted)
        Text(candidate?.displayName ?? "Select a feature")
          .font(.caption)
          .lineLimit(1)
      }
      Spacer(minLength: 4)
      if candidate != nil {
        Button(action: clear) {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(StudioPalette.muted)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 8)
    .frame(minHeight: 39)
    .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 6))
  }

  private func optionBinding<Value>(
    _ keyPath: WritableKeyPath<EngineMatePlacementOptions, Value>
  ) -> Binding<Value> {
    Binding(
      get: { session.options[keyPath: keyPath] },
      set: { value in
        var options = session.options
        options[keyPath: keyPath] = value
        updateOptions(options)
      }
    )
  }

  private func offsetBinding(_ index: Int) -> Binding<Double> {
    Binding(
      get: { session.options.offsetTranslationMillimeters[index] },
      set: { value in
        var options = session.options
        options.offsetTranslationMillimeters[index] = value
        updateOptions(options)
      }
    )
  }
}
