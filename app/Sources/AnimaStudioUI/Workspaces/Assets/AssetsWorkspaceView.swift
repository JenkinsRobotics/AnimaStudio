import AnimaDocument
import SwiftUI

struct AssetsWorkspaceView: View {
  let projectName: String
  let characters: [ProjectCharacterReference]
  let activeCharacterID: String?
  let activePartCount: Int
  let showsLoadingStage: Bool
  let importProgress: CharacterImportProgress?
  let importErrorMessage: String?
  let isSwitchingCharacter: Bool
  let newCharacter: () -> Void
  let selectCharacter: (ProjectCharacterReference) -> Void
  let importModels: () -> Void
  let dropModels: ([URL]) -> Void

  @State private var isDropTargeted = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        header

        if characters.isEmpty {
          emptyState
        } else {
          characterGrid
        }

        if let activeCharacter = characters.first(where: { $0.id == activeCharacterID }),
          showsLoadingStage
        {
          modelLoadingStage(character: activeCharacter)
        }
      }
      .padding(28)
      .frame(maxWidth: 1120, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .background(StudioPalette.canvas)
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("ASSETS")
          .font(.caption2.weight(.bold))
          .tracking(1.2)
          .foregroundStyle(StudioPalette.sourceModel)
        Text("Characters")
          .font(.largeTitle.weight(.semibold))
        Text("Manage the characters in \(projectName). Select one to use it in Rig and Animate.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button(action: newCharacter) {
        Label("New Character", systemImage: "plus")
          .padding(.horizontal, 4)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
  }

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "person.crop.rectangle.stack")
        .font(.system(size: 46, weight: .light))
        .foregroundStyle(StudioPalette.sourceModel)
      VStack(spacing: 6) {
        Text("Create your first character")
          .font(.title2.weight(.semibold))
        Text("Start with a 3D rigid-parts assembly, then connect its parts with mates in Rig.")
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      Button("Create 3D Character", action: newCharacter)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    .frame(maxWidth: .infinity, minHeight: 310)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 16))
    .overlay { RoundedRectangle(cornerRadius: 16).stroke(StudioPalette.border) }
  }

  private var characterGrid: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
      ForEach(characters) { character in
        Button {
          selectCharacter(character)
        } label: {
          HStack(spacing: 13) {
            ZStack {
              RoundedRectangle(cornerRadius: 10)
                .fill(StudioPalette.sourceModel.opacity(0.12))
              Image(systemName: "cube.transparent")
                .font(.title2)
                .foregroundStyle(StudioPalette.sourceModel)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
              Text(character.displayName)
                .font(.headline)
                .lineLimit(1)
              Text(character.id == activeCharacterID ? "ACTIVE · 3D ASSEMBLY" : "3D ASSEMBLY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(
                  character.id == activeCharacterID ? StudioPalette.sourceModel : .secondary)
              if character.id == activeCharacterID {
                Text("\(activePartCount) part\(activePartCount == 1 ? "" : "s")")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            Spacer()
            if isSwitchingCharacter && character.id == activeCharacterID {
              ProgressView().controlSize(.small)
            } else if character.id == activeCharacterID {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(StudioPalette.sourceModel)
            }
          }
          .padding(14)
          .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
          .background(
            character.id == activeCharacterID
              ? StudioPalette.sourceModel.opacity(0.1) : StudioPalette.panel,
            in: RoundedRectangle(cornerRadius: 13)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 13)
              .stroke(
                character.id == activeCharacterID
                  ? StudioPalette.sourceModel.opacity(0.75) : StudioPalette.border,
                lineWidth: character.id == activeCharacterID ? 1.5 : 1
              )
          }
        }
        .buttonStyle(.plain)
        .disabled(isSwitchingCharacter || importProgress != nil)
      }
    }
  }

  private func modelLoadingStage(character: ProjectCharacterReference) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("LOAD 3D ASSEMBLY")
            .font(.caption2.weight(.bold))
            .tracking(1)
            .foregroundStyle(StudioPalette.sourceModel)
          Text("Add models to \(character.displayName)")
            .font(.title2.weight(.semibold))
          Text(
            "Import multiple part files, or one multi-node USD. Each model becomes a rigid Part ready for mates."
          )
          .font(.callout)
          .foregroundStyle(.secondary)
        }
        Spacer()
        Text("STL · OBJ · USD · USDZ")
          .font(.caption2.weight(.bold))
          .foregroundStyle(StudioPalette.muted)
      }

      Button(action: importModels) {
        VStack(spacing: 13) {
          if let importProgress {
            ProgressView(value: importProgress.fractionCompleted)
              .progressViewStyle(.linear)
              .frame(maxWidth: 360)
            Text("Loading \(importProgress.currentFilename)")
              .font(.headline)
            Text("\(importProgress.completedFiles) of \(importProgress.totalFiles) complete")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            Image(systemName: "square.and.arrow.down.on.square")
              .font(.system(size: 34, weight: .light))
              .foregroundStyle(StudioPalette.sourceModel)
            Text("Drop model files here")
              .font(.headline)
            Text("or click to choose files")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .background(
          isDropTargeted ? StudioPalette.sourceModel.opacity(0.16) : StudioPalette.field,
          in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 14)
            .stroke(
              isDropTargeted ? StudioPalette.sourceModel : StudioPalette.border,
              style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [7, 5])
            )
        }
      }
      .buttonStyle(.plain)
      .disabled(importProgress != nil)
      .dropDestination(for: URL.self) { urls, _ in
        dropModels(urls)
        return !urls.isEmpty
      } isTargeted: {
        isDropTargeted = $0
      }

      if let importErrorMessage {
        Label(importErrorMessage, systemImage: "exclamationmark.triangle.fill")
          .font(.callout)
          .foregroundStyle(.orange)
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
      }

      Label(
        "STL and OBJ are unitless, so Anima asks for mm, cm, or m before loading. STEP must be converted in your CAD tool.",
        systemImage: "info.circle"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(20)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 16))
    .overlay { RoundedRectangle(cornerRadius: 16).stroke(StudioPalette.border) }
  }
}

#Preview("Assets · Empty Project") {
  AssetsWorkspaceView(
    projectName: "Audio-Animatronic Show",
    characters: [],
    activeCharacterID: nil,
    activePartCount: 0,
    showsLoadingStage: false,
    importProgress: nil,
    importErrorMessage: nil,
    isSwitchingCharacter: false,
    newCharacter: {},
    selectCharacter: { _ in },
    importModels: {},
    dropModels: { _ in }
  )
  .frame(width: 1100, height: 720)
  .preferredColorScheme(.dark)
}

#Preview("Assets · Loading Stage") {
  let character = ProjectCharacterReference(folderName: "walle", displayName: "WALL-E")
  AssetsWorkspaceView(
    projectName: "Lobby Robots",
    characters: [character],
    activeCharacterID: character.id,
    activePartCount: 0,
    showsLoadingStage: true,
    importProgress: nil,
    importErrorMessage: nil,
    isSwitchingCharacter: false,
    newCharacter: {},
    selectCharacter: { _ in },
    importModels: {},
    dropModels: { _ in }
  )
  .frame(width: 1100, height: 720)
  .preferredColorScheme(.dark)
}
