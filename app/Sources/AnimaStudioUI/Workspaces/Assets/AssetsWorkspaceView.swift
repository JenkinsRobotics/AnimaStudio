import AnimaDocument
import AnimaModel
import SwiftUI

/// Asset Builder follows the same durable three-column workspace grammar as Rig:
/// navigation on the left, the active collection in the center, and task tools /
/// selected-item context on the right.
struct AssetsWorkspaceView: View {
  @Bindable var workspace: StudioWorkspaceModel
  let projectName: String
  let projectRevision: Int
  let characters: [ProjectCharacterReference]
  let projectScenes: [ProjectSceneReference]
  let projectAssets: [DocumentAssetReference]
  let partAssetVersions: [String: Int]
  let activeCharacterID: String?
  let importProgress: CharacterImportProgress?
  let importErrorMessage: String?
  let isSwitchingCharacter: Bool
  let newCharacter: () -> Void
  let selectCharacter: (ProjectCharacterReference) -> Void
  let importModels: () -> Void
  let replaceModel: () -> Void
  let deleteParts: (Set<PartID>) -> Void
  let dropModels: ([URL]) -> Void

  @State private var selection = AssetBuilderSelection.characters

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      AssetBuilderSidebar(
        projectName: projectName,
        revision: projectRevision,
        characters: characters,
        activeCharacterID: activeCharacterID,
        counts: collectionCounts,
        isSwitchingCharacter: isSwitchingCharacter,
        selection: $selection,
        newCharacter: newCharacter,
        selectCharacter: selectCharacter
      )
      .frame(width: 260)

      Divider()

      AssetBuilderContentView(
        selection: selection,
        characters: characters,
        activeCharacterID: activeCharacterID,
        parts: partRows,
        assets: activeCharacterAssets,
        animations: workspace.project.clips,
        assemblies: assemblyItems,
        renders: renderItems,
        scripts: scriptItems,
        isSwitchingCharacter: isSwitchingCharacter,
        selectedPartIDs: selectedPartIDsBinding,
        newCharacter: newCharacter,
        selectCharacter: selectCharacter,
        importModels: importModels,
        replaceModel: replaceModel,
        deleteParts: deleteParts
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

      Divider()

      AssetBuilderInspector(
        activeCharacter: activeCharacter,
        selectedPart: selectedPart,
        selectedPartIDs: selectedPartIDs,
        workspace: workspace,
        importProgress: importProgress,
        importErrorMessage: importErrorMessage,
        importModels: importModels,
        dropModels: dropModels
      )
      .frame(width: 350)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(StudioPalette.canvas)
    .onAppear {
      selection = .initial(activeCharacterID: activeCharacterID)
    }
    .onChange(of: activeCharacterID) { _, newValue in
      selection = .initial(activeCharacterID: newValue)
    }
  }

  private var partRows: [AssetBuilderPartRow] {
    AssetBuilderCatalog.partRows(parts: workspace.engineParts) {
      workspace.partID(forEngineName: $0)
    } version: {
      partAssetVersions[$0] ?? 1
    }
  }

  private var selectedPart: AssetBuilderPartRow? {
    partRows.first { selectedPartIDs.contains($0.id) }
  }

  private var selectedPartIDs: Set<PartID> { Set(workspace.selectedComponentIDs) }

  private var activeCharacter: ProjectCharacterReference? {
    characters.first { $0.id == activeCharacterID }
  }

  private var selectedPartIDsBinding: Binding<Set<PartID>> {
    Binding(
      get: { Set(workspace.selectedComponentIDs) },
      set: { workspace.selectParts(ids: $0) }
    )
  }

  private var collectionCounts: [AssetBuilderCollection: Int] {
    [
      .parts: partRows.count,
      .sourceAssets: Set(partRows.map(\.model).filter { !$0.isEmpty }).count
        + activeCharacterAssets.count,
      .animations: workspace.project.clips.count,
      .renders: renderItems.count,
      .assemblies: assemblyItems.count,
      .scripts: scriptItems.count,
    ]
  }

  private var activeCharacterAssets: [DocumentAssetReference] {
    guard let activeCharacter else { return [] }
    return projectAssets.filter { asset in
      switch asset.storage {
      case .embedded(let path): path.hasPrefix(activeCharacter.assetsDirectoryPath + "/")
      case .linked: true
      }
    }
  }

  private var assemblyItems: [AssetBuilderListItem] {
    let mates = workspace.engineMates.map { mate in
      AssetBuilderListItem(
        id: "mate:\(mate.selectionKey)",
        title: mate.name,
        detail: [mate.parentPart, mate.childPart].compactMap { $0 }.joined(separator: " → "),
        systemImage: "link",
        badge: mate.isSuppressed ? "Suppressed" : mate.type.capitalized
      )
    }
    let relations = workspace.engineRelations.map { relation in
      AssetBuilderListItem(
        id: "relation:\(relation.id)",
        title: relation.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
        detail: "\(relation.driver) → \(relation.driven)",
        systemImage: "arrow.triangle.branch",
        badge: relation.isSuppressed ? "Suppressed" : "Relation"
      )
    }
    let groups = workspace.componentGroups.map { group in
      AssetBuilderListItem(
        id: "group:\(group.id.uuidString)",
        title: group.displayName,
        detail: "\(group.componentIDs.count) parts",
        systemImage: "folder",
        badge: group.isLocked ? "Locked group" : "Editor group"
      )
    }
    return mates + relations + groups
  }

  private var renderItems: [AssetBuilderListItem] {
    workspace.componentAppearances.compactMap { partID, appearance in
      guard let name = workspace.enginePartName(for: partID) else { return nil }
      return AssetBuilderListItem(
        id: "appearance:\(partID.rawValue.uuidString)",
        title: name,
        detail: "\(appearance.finish.rawValue.capitalized) · \(appearance.hexRGB)",
        systemImage: "paintpalette",
        badge: appearance.isVisible ? "Visible" : "Hidden"
      )
    }
  }

  private var scriptItems: [AssetBuilderListItem] {
    projectScenes.map { scene in
      AssetBuilderListItem(
        id: scene.id,
        title: scene.displayName,
        detail: scene.filename,
        systemImage: "curlybraces",
        badge: ".scene.anima"
      )
    }
  }
}

#Preview("Assets · Three Column") {
  AssetsWorkspaceView(
    workspace: StudioWorkspaceModel(),
    projectName: "Lobby Robots",
    projectRevision: 12,
    characters: [
      ProjectCharacterReference(folderName: "walle", displayName: "WALL-E"),
      ProjectCharacterReference(folderName: "greeter", displayName: "Greeter Robot"),
    ],
    projectScenes: [],
    projectAssets: [],
    partAssetVersions: [:],
    activeCharacterID: "walle",
    importProgress: nil,
    importErrorMessage: nil,
    isSwitchingCharacter: false,
    newCharacter: {},
    selectCharacter: { _ in },
    importModels: {},
    replaceModel: {},
    deleteParts: { _ in },
    dropModels: { _ in }
  )
  .frame(width: 1380, height: 760)
  .preferredColorScheme(.dark)
}
