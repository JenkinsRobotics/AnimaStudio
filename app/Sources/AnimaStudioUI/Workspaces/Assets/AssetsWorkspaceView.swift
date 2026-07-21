import AnimaDocument
import AnimaModel
import SwiftUI

/// Character uses a collection document in the center, project navigation at
/// left, and import/selection context at right. Unlike a spatial viewport, its
/// center becomes a bounded card in Floating and Canvas modes so overlay
/// sidebars never obscure table content.
enum AssetsWorkspaceSurface {
  case center
  case workspaceSidebar
  case viewInspector
}

enum AssetsWorkspacePanelSizing {
  static let floatingMinimumHeight: CGFloat = 300
  static let floatingMaximumHeight: CGFloat = 520

  static func collectionHeight(itemCount: Int) -> CGFloat {
    let visibleRows = min(max(itemCount, 0), 6)
    let bodyHeight = visibleRows == 0 ? 190 : CGFloat(visibleRows) * 54 + 24
    return min(floatingMaximumHeight, max(floatingMinimumHeight, 96 + bodyHeight))
  }

  static func browserHeight(characterCount: Int, hasActiveCharacter: Bool) -> CGFloat {
    let rootRows = 1
    let characterRows = max(characterCount, 0)
    let activeCollectionRows = hasActiveCharacter ? AssetBuilderCollection.allCases.count : 0
    let treeHeight = CGFloat(rootRows + characterRows + activeCollectionRows) * 30
    return min(floatingMaximumHeight, max(floatingMinimumHeight, 146 + treeHeight))
  }
}

struct AssetsWorkspaceView: View {
  @Bindable var workspace: StudioWorkspaceModel
  @Environment(\.studioPanelSurfaceMode) private var panelSurfaceMode
  @Environment(\.studioWorkspaceOverlayInsets) private var overlayInsets
  var surface = AssetsWorkspaceSurface.center
  let projectName: String
  let projectRevision: Int
  let characters: [ProjectCharacterReference]
  let characterLibrary: [CharacterLibraryEntry]
  let projectScenes: [ProjectSceneReference]
  let projectAssets: [DocumentAssetReference]
  let partAssetVersions: [String: Int]
  let activeCharacterID: String?
  let importProgress: CharacterImportProgress?
  let importErrorMessage: String?
  let isSwitchingCharacter: Bool
  let newCharacter: () -> Void
  let publishActiveCharacter: () -> Void
  let addLibraryCharacter: (CharacterLibraryEntry) -> Void
  let selectCharacter: (ProjectCharacterReference) -> Void
  let importModels: () -> Void
  let replaceModel: () -> Void
  let deleteParts: (Set<PartID>) -> Void
  let dropModels: ([URL]) -> Void

  var body: some View {
    Group {
      switch surface {
      case .center:
        centerCollection
      case .workspaceSidebar:
        sidebarSurface
      case .viewInspector:
        inspector
      }
    }
    .onAppear {
      normalizeSelectionForAvailableFeatures()
      guard surface == .center, !workspace.hasInitializedAssetBuilderSelection else {
        return
      }
      workspace.assetBuilderSelection = .initial(activeCharacterID: activeCharacterID)
      workspace.hasInitializedAssetBuilderSelection = true
    }
    .onChange(of: activeCharacterID) { _, newValue in
      workspace.assetBuilderSelection = .initial(activeCharacterID: newValue)
      workspace.hasInitializedAssetBuilderSelection = true
    }
  }

  private func normalizeSelectionForAvailableFeatures() {
    guard !AssetBuilderFeatureAvailability.showsLibraries else { return }
    switch workspace.assetBuilderSelection {
    case .characterLibrary, .partsLibrary:
      workspace.assetBuilderSelection = .initial(activeCharacterID: activeCharacterID)
    case .characters, .characterCollection:
      break
    }
  }

  private var content: some View {
    AssetBuilderContentView(
      selection: workspace.assetBuilderSelection,
      characters: characters,
      characterLibrary: characterLibrary,
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
      publishActiveCharacter: publishActiveCharacter,
      addLibraryCharacter: addLibraryCharacter,
      selectCharacter: selectCharacter,
      importModels: importModels,
      replaceModel: replaceModel,
      deleteParts: deleteParts
    )
    .studioPanelSurface()
  }

  @ViewBuilder private var centerCollection: some View {
    if StudioLayoutState.shared.detectedPreset == .docked {
      content
        .environment(\.studioPanelSurfaceMode, .docked)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    } else {
      content
        .environment(\.studioPanelSurfaceMode, .floating)
        .frame(maxWidth: .infinity)
        .frame(height: floatingCollectionHeight, alignment: .top)
        .padding(.top, floatingTopClearance)
        .padding(.bottom, 18)
        .padding(.leading, floatingLeadingClearance)
        .padding(.trailing, floatingTrailingClearance)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
  }

  private var floatingLeadingClearance: CGFloat {
    max(18, overlayInsets.leading)
  }

  private var floatingTopClearance: CGFloat {
    max(18, overlayInsets.top)
  }

  private var floatingTrailingClearance: CGFloat {
    max(18, overlayInsets.trailing)
  }

  private var sidebar: some View {
    AssetBuilderSidebar(
      projectName: projectName,
      revision: projectRevision,
      characters: characters,
      characterLibraryCount: characterLibrary.count,
      activeCharacterID: activeCharacterID,
      counts: collectionCounts,
      isSwitchingCharacter: isSwitchingCharacter,
      selection: Binding(
        get: { workspace.assetBuilderSelection },
        set: { workspace.assetBuilderSelection = $0 }
      ),
      newCharacter: newCharacter,
      selectCharacter: selectCharacter
    )
    .studioPanelSurface()
  }

  @ViewBuilder private var sidebarSurface: some View {
    if panelSurfaceMode == .docked {
      sidebar.frame(maxHeight: .infinity, alignment: .top)
    } else {
      sidebar.frame(
        height: AssetsWorkspacePanelSizing.browserHeight(
          characterCount: characters.count,
          hasActiveCharacter: activeCharacterID != nil
        ),
        alignment: .top
      )
    }
  }

  private var floatingCollectionHeight: CGFloat {
    AssetsWorkspacePanelSizing.collectionHeight(itemCount: activeCollectionItemCount)
  }

  private var activeCollectionItemCount: Int {
    switch workspace.assetBuilderSelection {
    case .characters:
      characters.count
    case .characterLibrary:
      characterLibrary.count
    case .characterCollection(_, let collection):
      collectionCounts[collection] ?? 0
    case .partsLibrary:
      0
    }
  }

  private var inspector: some View {
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
    .studioPanelSurface()
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
    characterLibrary: [],
    projectScenes: [],
    projectAssets: [],
    partAssetVersions: [:],
    activeCharacterID: "walle",
    importProgress: nil,
    importErrorMessage: nil,
    isSwitchingCharacter: false,
    newCharacter: {},
    publishActiveCharacter: {},
    addLibraryCharacter: { _ in },
    selectCharacter: { _ in },
    importModels: {},
    replaceModel: {},
    deleteParts: { _ in },
    dropModels: { _ in }
  )
  .frame(width: 1380, height: 760)
  .preferredColorScheme(.dark)
}
