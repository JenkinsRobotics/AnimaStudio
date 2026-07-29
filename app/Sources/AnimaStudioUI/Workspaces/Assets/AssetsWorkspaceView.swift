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
  var centerLayoutMode: AssetBuilderLayoutMode? = nil
  /// Which left-rail tab this sidebar instance represents. Each open panel is
  /// bound to its own tab, so multiple stacked panels show different content
  /// instead of all mirroring the shared `assetBuilderSelection`.
  var sidebarTab: String? = nil
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
      deleteParts: deleteParts,
      forcedLayoutMode: centerLayoutMode
    )
    .studioPanelSurface()
  }

  @ViewBuilder private var centerCollection: some View {
    if centerLayoutMode != nil {
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    } else if StudioLayoutState.shared.detectedPreset == .docked {
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

  // The "Characters" rail tab shows the full character profile; every collection
  // rail tab opens only that collection's own file list. Previously all tabs
  // rendered the same full browser.
  /// The collection this panel instance renders, from its own rail tab (NOT the
  /// shared selection) — so stacked panels stay independent.
  private var sidebarCollection: AssetBuilderCollection? {
    guard let sidebarTab else { return nil }
    return AssetBuilderCollection.allCases.first { $0.title == sidebarTab }
  }

  @ViewBuilder private var sidebarSurface: some View {
    if let collection = sidebarCollection {
      let items = collectionItems(collection)
      sizedPanel(
        AssetCollectionSidebarPanel(
          collection: collection,
          items: items,
          selectedIDs: collectionSelectedIDs(collection),
          interaction: collectionInteraction(collection),
          onSelect: { selectCollectionItem($0, in: collection) }
        ),
        floatingHeight: AssetsWorkspacePanelSizing.collectionHeight(itemCount: items.count)
      )
    } else {
      // "Characters" (or any non-collection tab) → the full character profile.
      sizedPanel(
        sidebar,
        floatingHeight: AssetsWorkspacePanelSizing.browserHeight(
          characterCount: characters.count,
          hasActiveCharacter: activeCharacterID != nil
        )
      )
    }
  }

  @ViewBuilder private func sizedPanel<V: View>(_ panel: V, floatingHeight: CGFloat) -> some View {
    if panelSurfaceMode == .docked {
      panel.frame(maxHeight: .infinity, alignment: .top)
    } else {
      panel.frame(height: floatingHeight, alignment: .top)
    }
  }

  /// Maps a collection row's item id back to its PartID. Parts collection
  /// items encode the PartID's UUID string as their id (see collectionItems).
  private var partIDsByItemID: [String: PartID] {
    Dictionary(uniqueKeysWithValues: partRows.map { ($0.id.rawValue.uuidString, $0.id) })
  }

  /// The shared tree control layer for a collection. Parts wire straight onto
  /// the existing engine mutations; other collections stay read-only for now.
  private func collectionInteraction(
    _ collection: AssetBuilderCollection
  ) -> TreeInteraction<AssetBuilderListItem>? {
    guard collection == .parts else { return nil }
    let lookup = partIDsByItemID
    return TreeInteraction(
      editableName: { $0.title },
      commitRename: { item, name in
        if let id = lookup[item.id] { workspace.renamePart(id: id, to: name) }
      },
      delete: { ids in
        let partIDs = Set(ids.compactMap { lookup[$0] })
        if !partIDs.isEmpty { deleteParts(partIDs) }
      },
      canDelete: { _ in true },
      selectedIDs: { Set(workspace.selectedComponentIDs.map(\.rawValue.uuidString)) },
      extraActions: { _ in [] }
    )
  }

  private func collectionSelectedIDs(_ collection: AssetBuilderCollection) -> Set<String> {
    guard collection == .parts else { return [] }
    return Set(workspace.selectedComponentIDs.map(\.rawValue.uuidString))
  }

  private func selectCollectionItem(_ id: String, in collection: AssetBuilderCollection) {
    guard collection == .parts, let partID = partIDsByItemID[id] else { return }
    workspace.selectPart(id: partID, extendingSelection: false)
  }

  private func collectionItems(_ collection: AssetBuilderCollection) -> [AssetBuilderListItem] {
    switch collection {
    case .parts:
      partRows.map { row in
        AssetBuilderListItem(
          id: row.id.rawValue.uuidString,
          title: row.name,
          detail: row.sourceLabel,
          systemImage: "cube",
          badge: "v\(row.version)"
        )
      }
    case .sourceAssets:
      activeCharacterAssets.map { asset in
        AssetBuilderListItem(
          id: asset.id.rawValue.uuidString,
          title: asset.originalFilename,
          detail: asset.kind,
          systemImage: "shippingbox",
          badge: ""
        )
      }
    case .animations:
      workspace.project.clips.enumerated().map { index, clip in
        AssetBuilderListItem(
          id: "clip:\(index):\(clip.name)",
          title: clip.name,
          detail: "",
          systemImage: "waveform.path",
          badge: ""
        )
      }
    case .renders: renderItems
    case .assemblies: assemblyItems
    case .scripts: scriptItems
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
    // Each distinct source file counts once: a copied part model is also a
    // document asset, so exclude assets that back a part model.
    let modelFilenames = Set(
      partRows.map(\.model).filter { !$0.isEmpty }
        .map { URL(fileURLWithPath: $0).lastPathComponent })
    let extraAssets = activeCharacterAssets.filter { !modelFilenames.contains($0.originalFilename) }
    return [
      .parts: partRows.count,
      .sourceAssets: modelFilenames.count + extraAssets.count,
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
  .preferredColorScheme(StudioAppearanceMode.current.colorScheme)
}
