import AnimaDocument
import SwiftUI

struct NewCharacterSheet: View {
  let existingCharacters: [ProjectCharacterReference]
  let isCreating: Bool
  let cancel: () -> Void
  let create: (String) -> Void

  @State private var name = ""
  @State private var selectedKind = CharacterPipelineKind.rigidParts3D
  @FocusState private var nameIsFocused: Bool

  private var validationMessage: String? {
    NewCharacterValidation.message(name: name, existingCharacters: existingCharacters)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 12) {
        Image(systemName: "person.crop.rectangle.stack.fill")
          .font(.title2)
          .foregroundStyle(StudioPalette.accent)
        VStack(alignment: .leading, spacing: 3) {
          Text("New Character")
            .font(.title3.weight(.semibold))
          Text("Characters are independent of the project name.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      VStack(alignment: .leading, spacing: 7) {
        Text("NAME")
          .font(.caption2.weight(.bold))
          .tracking(0.8)
          .foregroundStyle(StudioPalette.muted)
        TextField("Character name", text: $name)
          .textFieldStyle(.roundedBorder)
          .focused($nameIsFocused)
          .disabled(isCreating)
        if !name.isEmpty, let validationMessage {
          Label(validationMessage, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
        }
      }

      VStack(alignment: .leading, spacing: 9) {
        Text("CHARACTER TYPE")
          .font(.caption2.weight(.bold))
          .tracking(0.8)
          .foregroundStyle(StudioPalette.muted)
        ForEach(CharacterPipelineKind.allCases) { kind in
          characterKindRow(kind)
        }
      }

      Label(
        "The current 3D pipeline is for rigid parts and mates. Skinned meshes and skeletons are not supported yet.",
        systemImage: "info.circle"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      HStack {
        Spacer()
        Button("Cancel", role: .cancel, action: cancel)
          .keyboardShortcut(.cancelAction)
          .disabled(isCreating)
        Button {
          create(name.trimmingCharacters(in: .whitespacesAndNewlines))
        } label: {
          if isCreating {
            ProgressView()
              .controlSize(.small)
              .frame(minWidth: 70)
          } else {
            Text("Create")
              .frame(minWidth: 70)
          }
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(validationMessage != nil || selectedKind != .rigidParts3D || isCreating)
      }
    }
    .padding(24)
    .frame(width: 500)
    .onAppear { nameIsFocused = true }
  }

  private func characterKindRow(_ kind: CharacterPipelineKind) -> some View {
    Button {
      if kind.isAvailable { selectedKind = kind }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: kind == .rigidParts3D ? "cube.transparent" : "square.3.layers.3d")
          .font(.title3)
          .foregroundStyle(kind.isAvailable ? StudioPalette.accent : StudioPalette.muted)
          .frame(width: 30)
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 7) {
            Text(kind.title)
              .font(.callout.weight(.semibold))
            if !kind.isAvailable {
              Text("COMING LATER")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(StudioPalette.field, in: Capsule())
            }
          }
          Text(kind.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: selectedKind == kind ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(kind.isAvailable ? StudioPalette.accent : StudioPalette.muted)
      }
      .padding(12)
      .background(
        selectedKind == kind ? StudioPalette.accent.opacity(0.12) : StudioPalette.panel,
        in: RoundedRectangle(cornerRadius: 10)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(
            selectedKind == kind ? StudioPalette.accent.opacity(0.8) : StudioPalette.border,
            lineWidth: 1
          )
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!kind.isAvailable || isCreating)
    .opacity(kind.isAvailable ? 1 : 0.52)
  }
}
