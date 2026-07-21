import AnimaDocument
import AnimaModel
import AppKit
import SwiftUI

struct AssetBuilderContentView: View {
  let selection: AssetBuilderSelection
  let characters: [ProjectCharacterReference]
  let characterLibrary: [CharacterLibraryEntry]
  let activeCharacterID: String?
  let parts: [AssetBuilderPartRow]
  let assets: [DocumentAssetReference]
  let animations: [AnimationClip]
  let assemblies: [AssetBuilderListItem]
  let renders: [AssetBuilderListItem]
  let scripts: [AssetBuilderListItem]
  let isSwitchingCharacter: Bool
  @Binding var selectedPartIDs: Set<PartID>
  let newCharacter: () -> Void
  let publishActiveCharacter: () -> Void
  let addLibraryCharacter: (CharacterLibraryEntry) -> Void
  let selectCharacter: (ProjectCharacterReference) -> Void
  let importModels: () -> Void
  let replaceModel: () -> Void
  let deleteParts: (Set<PartID>) -> Void

  @State private var searchText = ""
  @State private var layoutMode = AssetBuilderLayoutMode.defaultMode
  @State private var pendingDeletion = Set<PartID>()
  @State private var selectionAnchorID: PartID?
  @FocusState private var partsHaveKeyboardFocus: Bool

  var body: some View {
    VStack(spacing: 0) {
      toolbar
      Divider()
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(StudioPalette.panel)
    .onChange(of: selection) { _, _ in
      searchText = ""
      selectionAnchorID = nil
      partsHaveKeyboardFocus = false
    }
    .onChange(of: Set(parts.map(\.id))) { _, availableIDs in
      selectedPartIDs.formIntersection(availableIDs)
      if let selectionAnchorID, !availableIDs.contains(selectionAnchorID) {
        self.selectionAnchorID = nil
      }
    }
    .focusable()
    .focused($partsHaveKeyboardFocus)
    .focusEffectDisabled()
    .onKeyPress(keys: [.delete, .deleteForward]) { _ in
      guard !selectedPartIDs.isEmpty else { return .ignored }
      requestDeletion(selectedPartIDs)
      return .handled
    }
    .onDeleteCommand {
      requestDeletion(selectedPartIDs)
    }
    .confirmationDialog(
      deletionTitle,
      isPresented: Binding(
        get: { !pendingDeletion.isEmpty },
        set: { if !$0 { pendingDeletion.removeAll() } }
      ),
      titleVisibility: .visible
    ) {
      Button(deletionActionTitle, role: .destructive) {
        let ids = pendingDeletion
        pendingDeletion.removeAll()
        deleteParts(ids)
      }
      Button("Cancel", role: .cancel) { pendingDeletion.removeAll() }
    } message: {
      Text(
        "Dependent mates and relations will also be removed. Unused model files are removed from this project only."
      )
    }
  }

  private var toolbar: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(kicker)
          .font(.caption2.weight(.bold))
          .tracking(0.9)
          .foregroundStyle(StudioPalette.sourceModel)
        Text(title)
          .font(.title3.weight(.semibold))
      }

      Spacer()

      if supportsSearch {
        HStack(spacing: 6) {
          Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
          TextField("Filter", text: $searchText)
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, 9)
        .frame(width: 190, height: 30)
        .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 7))
        .overlay { RoundedRectangle(cornerRadius: 7).stroke(StudioPalette.border) }
      }

      Picker("Collection view", selection: $layoutMode) {
        ForEach(AssetBuilderLayoutMode.allCases) { mode in
          Label(mode.title, systemImage: mode.systemImage)
            .labelStyle(.iconOnly)
            .tag(mode)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(width: 72)
      .help("Switch between table and grid views")

      if case .characterCollection(_, let collection) = selection,
        collection == .parts || collection == .sourceAssets
      {
        if collection == .parts, selectedPartIDs.count == 1 {
          Button(action: replaceModel) {
            Label("Replace Part", systemImage: "arrow.triangle.2.circlepath")
          }
          .buttonStyle(.bordered)
          .help("Upload one replacement model and increment this part's simple V counter")
        }
        Button(action: importModels) {
          Label("Import", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        if collection == .parts, !selectedPartIDs.isEmpty {
          Button(role: .destructive) {
            requestDeletion(selectedPartIDs)
          } label: {
            Label(
              selectedPartIDs.count == 1 ? "Delete" : "Delete \(selectedPartIDs.count)",
              systemImage: "trash"
            )
          }
          .buttonStyle(.bordered)
          .help("Delete the selected parts from this character")
        }
      }
      if AssetBuilderFeatureAvailability.showsLibraries,
        selection == .characters,
        activeCharacterID != nil
      {
        Button(action: publishActiveCharacter) {
          Label(
            activeCharacter?.sourceKind == .librarySnapshot ? "Update Library" : "Publish",
            systemImage: "person.crop.square.badge.plus"
          )
        }
        .buttonStyle(.bordered)
        .help("Publish the active project Character as a reusable library source")
      }
    }
    .padding(.horizontal, 18)
    .frame(height: 62)
    .background(StudioPalette.panel)
  }

  @ViewBuilder private var content: some View {
    switch selection {
    case .characters:
      charactersView
    case .characterLibrary:
      characterLibraryView
    case .characterCollection(_, let collection):
      switch collection {
      case .parts: partsView
      case .sourceAssets: sourceAssetsView
      case .animations: animationsView
      case .assemblies: collectionList(assemblies, collection: collection)
      case .renders: collectionList(renders, collection: collection)
      case .scripts: collectionList(scripts, collection: collection)
      }
    case .partsLibrary(let category):
      partsLibraryView(category)
    }
  }

  private var charactersView: some View {
    collectionSurface(
      items: filteredCharacters,
      emptyTitle: characters.isEmpty ? "No characters yet" : "No matching characters",
      emptyDetail: "Create a character from the left sidebar to begin organizing assets.",
      systemImage: "person.crop.rectangle.stack"
    ) {
      tableHeader(
        "CHARACTER",
        columns: [
          AssetBuilderTableColumn(title: "TYPE", width: 190),
          AssetBuilderTableColumn(title: "SOURCE", width: 130),
          AssetBuilderTableColumn(title: "REV", width: 54),
          AssetBuilderTableColumn(title: "STATUS", width: 120),
        ]
      )
    } row: { character in
      characterTableRow(character)
    } card: { character in
      characterCard(character)
    }
  }

  private var characterLibraryView: some View {
    collectionSurface(
      items: filteredLibraryEntries,
      emptyTitle: characterLibrary.isEmpty ? "No library Characters yet" : "No matches",
      emptyDetail: "Publish a project Character to reuse it in other projects.",
      systemImage: "person.2.crop.square.stack"
    ) {
      tableHeader(
        "CHARACTER",
        columns: [
          AssetBuilderTableColumn(title: "REVISION", width: 90),
          AssetBuilderTableColumn(title: "MODIFIED", width: 150),
          AssetBuilderTableColumn(title: "ACTION", width: 92),
        ]
      )
    } row: { entry in
      characterLibraryTableRow(entry)
    } card: { entry in
      characterLibraryCard(entry)
    }
  }

  private var partsView: some View {
    collectionSurface(
      items: filteredParts,
      emptyTitle: parts.isEmpty ? "No parts yet" : "No matching parts",
      emptyDetail: "Imported rigid parts will appear as rows in this table.",
      systemImage: "cube"
    ) {
      tableHeader(
        "PART",
        columns: [
          AssetBuilderTableColumn(title: "SOURCE", width: 190),
          AssetBuilderTableColumn(title: "VERSION", width: 62),
          AssetBuilderTableColumn(title: "PARENT", width: 120),
          AssetBuilderTableColumn(title: "STATE", width: 92),
        ]
      )
    } row: { part in
      partTableRow(part)
    } card: { part in
      partGridCard(part)
    }
  }

  private var sourceAssetsView: some View {
    collectionList(sourceAssetItems, collection: .sourceAssets)
  }

  private var animationsView: some View {
    collectionList(animationItems, collection: .animations)
  }

  private func collectionList(
    _ items: [AssetBuilderListItem],
    collection: AssetBuilderCollection
  ) -> some View {
    let filteredItems = filteredListItems(items)
    return collectionSurface(
      items: filteredItems,
      emptyTitle: items.isEmpty
        ? "No \(collection.title.lowercased()) yet"
        : "No matching \(collection.title.lowercased())",
      emptyDetail: emptyCollectionDetail(collection),
      systemImage: collection.systemImage
    ) {
      tableHeader(
        tablePrimaryTitle(collection),
        columns: [
          AssetBuilderTableColumn(title: "DETAILS", width: 300),
          AssetBuilderTableColumn(title: "STATUS", width: 120),
        ]
      )
    } row: { item in
      listTableRow(item)
    } card: { item in
      listGridCard(item)
    }
  }

  private func partsLibraryView(_ category: AssetLibraryCategory?) -> some View {
    let items: [AssetBuilderListItem] = []
    return collectionSurface(
      items: items,
      emptyTitle: category.map { "No \($0.title.lowercased()) yet" } ?? "No library parts yet",
      emptyDetail:
        "Reusable parts will live outside a character so they can be added to future assemblies.",
      systemImage: category?.systemImage ?? "books.vertical"
    ) {
      tableHeader(
        "LIBRARY PART",
        columns: [
          AssetBuilderTableColumn(title: "CATEGORY", width: 180),
          AssetBuilderTableColumn(title: "STATUS", width: 120),
        ]
      )
    } row: { item in
      listTableRow(item)
    } card: { item in
      listGridCard(item)
    }
  }

  @ViewBuilder
  private func collectionSurface<
    Item: Identifiable,
    Header: View,
    Row: View,
    Card: View
  >(
    items: [Item],
    emptyTitle: String,
    emptyDetail: String,
    systemImage: String,
    @ViewBuilder header: () -> Header,
    @ViewBuilder row: @escaping (Item) -> Row,
    @ViewBuilder card: @escaping (Item) -> Card
  ) -> some View {
    switch layoutMode {
    case .table:
      VStack(spacing: 0) {
        header()
        ZStack {
          ScrollView {
            LazyVStack(spacing: 0) {
              ForEach(items) { item in
                row(item)
                Divider().padding(.leading, 16)
              }
            }
          }
          if items.isEmpty {
            emptyCollectionState(
              title: emptyTitle,
              detail: emptyDetail,
              systemImage: systemImage
            )
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

    case .grid:
      ZStack {
        ScrollView {
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 230), spacing: 14)],
            spacing: 14
          ) {
            ForEach(items) { item in
              card(item)
            }
          }
          .padding(18)
        }
        if items.isEmpty {
          emptyCollectionState(
            title: emptyTitle,
            detail: emptyDetail,
            systemImage: systemImage
          )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func tableHeader(
    _ primaryTitle: String,
    columns: [AssetBuilderTableColumn]
  ) -> some View {
    HStack(spacing: 12) {
      Text(primaryTitle)
        .frame(maxWidth: .infinity, alignment: .leading)
      ForEach(columns) { column in
        Text(column.title)
          .frame(width: column.width, alignment: .leading)
      }
    }
    .font(.caption2.weight(.bold))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 16)
    .frame(height: 34)
    .background(StudioPalette.panelInset)
  }

  private func characterTableRow(_ character: ProjectCharacterReference) -> some View {
    Button {
      selectCharacter(character)
    } label: {
      HStack(spacing: 12) {
        HStack(spacing: 10) {
          collectionIcon("cube.transparent")
          Text(character.displayName)
            .font(.callout.weight(.medium))
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Text("3D Assembly")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(width: 190, alignment: .leading)

        Text(character.sourceLabel)
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(width: 130, alignment: .leading)

        Text(character.libraryRevision.map { "V\($0)" } ?? "—")
          .font(.caption.weight(.semibold))
          .foregroundStyle(
            character.sourceKind == .librarySnapshot ? StudioPalette.sourceModel : .secondary
          )
          .frame(width: 54, alignment: .leading)

        if isSwitchingCharacter && character.id == activeCharacterID {
          ProgressView().controlSize(.small)
            .frame(width: 120, alignment: .leading)
        } else {
          Label(
            character.id == activeCharacterID ? "Active" : "Available",
            systemImage: character.id == activeCharacterID ? "checkmark.circle.fill" : "circle"
          )
          .font(.caption2.weight(.semibold))
          .foregroundStyle(
            character.id == activeCharacterID ? StudioPalette.sourceModel : .secondary
          )
          .frame(width: 120, alignment: .leading)
        }
      }
      .padding(.horizontal, 16)
      .frame(height: 54)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func characterLibraryTableRow(_ entry: CharacterLibraryEntry) -> some View {
    HStack(spacing: 12) {
      HStack(spacing: 10) {
        collectionIcon("person.crop.square")
        Text(entry.displayName).font(.callout.weight(.medium)).lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Text("V\(entry.revision)")
        .font(.caption.weight(.semibold))
        .foregroundStyle(StudioPalette.sourceModel)
        .frame(width: 90, alignment: .leading)
      Text(entry.modifiedDate.formatted(date: .abbreviated, time: .shortened))
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(width: 150, alignment: .leading)
      Button("Add") { addLibraryCharacter(entry) }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .frame(width: 92, alignment: .leading)
    }
    .padding(.horizontal, 16)
    .frame(height: 54)
  }

  private func partTableRow(_ part: AssetBuilderPartRow) -> some View {
    Button {
      selectPart(part.id)
    } label: {
      HStack(spacing: 12) {
        HStack(spacing: 10) {
          partThumbnail(part)
          VStack(alignment: .leading, spacing: 2) {
            Text(part.name).font(.callout.weight(.medium)).lineLimit(1)
            if !part.description.isEmpty {
              Text(part.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Text(part.sourceLabel)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .frame(width: 190, alignment: .leading)
        Text("V\(part.version)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(StudioPalette.sourceModel)
          .frame(width: 62, alignment: .leading)
        Text(part.parent ?? "Character origin")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .frame(width: 120, alignment: .leading)
        statusBadge(part.state)
          .frame(width: 92, alignment: .leading)
      }
      .padding(.horizontal, 16)
      .frame(height: 54)
      .background(
        selectedPartIDs.contains(part.id) ? StudioPalette.accent.opacity(0.22) : Color.clear
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .contextMenu { partContextMenu(part.id) }
  }

  private func listTableRow(_ item: AssetBuilderListItem) -> some View {
    HStack(spacing: 12) {
      HStack(spacing: 10) {
        collectionIcon(item.systemImage)
        Text(item.title)
          .font(.callout.weight(.medium))
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(item.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(width: 300, alignment: .leading)
      Text(item.badge)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 120, alignment: .leading)
    }
    .padding(.horizontal, 16)
    .frame(height: 54)
  }

  private func partGridCard(_ part: AssetBuilderPartRow) -> some View {
    Button {
      selectPart(part.id)
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          partThumbnail(part)
          Spacer()
          Text("V\(part.version)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(StudioPalette.sourceModel)
        }
        Text(part.name).font(.headline).lineLimit(1)
        Text(part.sourceLabel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        statusBadge(part.state)
      }
      .padding(14)
      .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
      .background(
        selectedPartIDs.contains(part.id)
          ? StudioPalette.accent.opacity(0.18) : StudioPalette.panel,
        in: RoundedRectangle(cornerRadius: 11)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 11).stroke(
          selectedPartIDs.contains(part.id) ? StudioPalette.accent : StudioPalette.border
        )
      }
    }
    .buttonStyle(.plain)
    .contextMenu { partContextMenu(part.id) }
  }

  private func selectPart(_ id: PartID) {
    let modifiers = NSEvent.modifierFlags
    let result = AssetBuilderPartSelection.selecting(
      id,
      in: selectedPartIDs,
      orderedIDs: filteredParts.map(\.id),
      anchor: selectionAnchorID,
      command: modifiers.contains(.command),
      shift: modifiers.contains(.shift)
    )
    selectedPartIDs = result.ids
    selectionAnchorID = result.anchor
    partsHaveKeyboardFocus = true
  }

  @ViewBuilder
  private func partContextMenu(_ id: PartID) -> some View {
    let deletion = selectedPartIDs.contains(id) ? selectedPartIDs : Set([id])
    Button(role: .destructive) {
      requestDeletion(deletion)
    } label: {
      Label(deletion.count == 1 ? "Delete Part" : "Delete Selected Parts", systemImage: "trash")
    }
  }

  private func requestDeletion(_ ids: Set<PartID>) {
    guard !ids.isEmpty else { return }
    pendingDeletion = ids
  }

  private var deletionTitle: String {
    pendingDeletion.count == 1
      ? "Delete the selected part?" : "Delete \(pendingDeletion.count) selected parts?"
  }

  private var deletionActionTitle: String {
    pendingDeletion.count == 1 ? "Delete Part" : "Delete \(pendingDeletion.count) Parts"
  }

  private func listGridCard(_ item: AssetBuilderListItem) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        collectionIcon(item.systemImage)
        Spacer()
        Text(item.badge)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      Text(item.title).font(.headline).lineLimit(1)
      Text(item.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 11))
    .overlay { RoundedRectangle(cornerRadius: 11).stroke(StudioPalette.border) }
  }

  private func collectionIcon(_ systemImage: String) -> some View {
    Image(systemName: systemImage)
      .frame(width: 34, height: 34)
      .background(StudioPalette.sourceModel.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
      .foregroundStyle(StudioPalette.sourceModel)
  }

  private func emptyCollectionState(
    title: String,
    detail: String,
    systemImage: String
  ) -> some View {
    VStack(spacing: 10) {
      Image(systemName: systemImage)
        .font(.system(size: 34, weight: .light))
        .foregroundStyle(StudioPalette.sourceModel)
      Text(title).font(.headline)
      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 420)
    }
    .padding(24)
  }

  private func characterCard(_ character: ProjectCharacterReference) -> some View {
    Button {
      selectCharacter(character)
    } label: {
      HStack(spacing: 13) {
        RoundedRectangle(cornerRadius: 9)
          .fill(StudioPalette.sourceModel.opacity(0.12))
          .overlay {
            Image(systemName: "cube.transparent")
              .font(.title2)
              .foregroundStyle(StudioPalette.sourceModel)
          }
          .frame(width: 54, height: 54)
        VStack(alignment: .leading, spacing: 4) {
          Text(character.displayName).font(.headline).lineLimit(1)
          Text(
            character.id == activeCharacterID
              ? "ACTIVE · \(character.sourceLabel.uppercased())"
              : character.sourceLabel.uppercased()
          )
          .font(.caption2.weight(.bold))
          .foregroundStyle(
            character.id == activeCharacterID ? StudioPalette.sourceModel : .secondary)
        }
        Spacer()
        if isSwitchingCharacter && character.id == activeCharacterID {
          ProgressView().controlSize(.small)
        } else if character.id == activeCharacterID {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(StudioPalette.sourceModel)
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
      .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12).stroke(
          character.id == activeCharacterID ? StudioPalette.sourceModel : StudioPalette.border,
          lineWidth: character.id == activeCharacterID ? 1.5 : 1
        )
      }
    }
    .buttonStyle(.plain)
  }

  private func characterLibraryCard(_ entry: CharacterLibraryEntry) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        collectionIcon("person.crop.square")
        Spacer()
        Text("V\(entry.revision)")
          .font(.caption2.weight(.bold))
          .foregroundStyle(StudioPalette.sourceModel)
      }
      Text(entry.displayName).font(.headline).lineLimit(1)
      Text(
        "Reusable Character · \(entry.modifiedDate.formatted(date: .abbreviated, time: .omitted))"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      Button("Add to Project") { addLibraryCharacter(entry) }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 11))
    .overlay { RoundedRectangle(cornerRadius: 11).stroke(StudioPalette.border) }
  }

  private func partThumbnail(_ part: AssetBuilderPartRow) -> some View {
    RoundedRectangle(cornerRadius: 6)
      .fill(StudioPalette.sourceModel.opacity(0.1))
      .overlay {
        Image(systemName: part.model.isEmpty ? "cube" : "cube.transparent")
          .foregroundStyle(StudioPalette.sourceModel)
      }
      .frame(width: 34, height: 34)
  }

  private func statusBadge(_ state: AssetBuilderPartState) -> some View {
    Label(state.label, systemImage: statusIcon(state))
      .font(.caption2.weight(.semibold))
      .foregroundStyle(statusColor(state))
  }

  private var filteredParts: [AssetBuilderPartRow] {
    AssetBuilderCatalog.filteredParts(parts, query: searchText)
  }

  private var filteredCharacters: [ProjectCharacterReference] {
    let needle = normalizedSearchText
    guard !needle.isEmpty else { return characters }
    return characters.filter {
      $0.displayName.lowercased().contains(needle) || $0.id.lowercased().contains(needle)
    }
  }

  private var filteredLibraryEntries: [CharacterLibraryEntry] {
    let needle = normalizedSearchText
    guard !needle.isEmpty else { return characterLibrary }
    return characterLibrary.filter {
      $0.displayName.lowercased().contains(needle)
        || $0.folderName.lowercased().contains(needle)
    }
  }

  private var activeCharacter: ProjectCharacterReference? {
    characters.first { $0.id == activeCharacterID }
  }

  private var sourceAssetItems: [AssetBuilderListItem] {
    let modelItems = parts.filter { !$0.model.isEmpty }.map { part in
      AssetBuilderListItem(
        id: "part-model:\(part.id)",
        title: URL(fileURLWithPath: part.model).lastPathComponent,
        detail: "Model for \(part.name)",
        systemImage: "cube.transparent",
        badge: "Embedded"
      )
    }
    let documentItems = assets.map { asset in
      AssetBuilderListItem(
        id: "document-asset:\(asset.id)",
        title: asset.originalFilename,
        detail: asset.kind,
        systemImage: "doc",
        badge: storageLabel(asset.storage)
      )
    }
    return modelItems + documentItems
  }

  private var animationItems: [AssetBuilderListItem] {
    animations.enumerated().map { index, clip in
      AssetBuilderListItem(
        id: "animation:\(index):\(clip.name)",
        title: clip.name,
        detail: "\(clip.jointTracks.count) track\(clip.jointTracks.count == 1 ? "" : "s")",
        systemImage: "waveform.path.ecg",
        badge: durationLabel(clip.durationSeconds)
      )
    }
  }

  private func filteredListItems(_ items: [AssetBuilderListItem]) -> [AssetBuilderListItem] {
    let needle = normalizedSearchText
    guard !needle.isEmpty else { return items }
    return items.filter { item in
      [item.title, item.detail, item.badge]
        .contains { $0.lowercased().contains(needle) }
    }
  }

  private var normalizedSearchText: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private var supportsSearch: Bool {
    true
  }

  private var kicker: String {
    switch selection {
    case .characters: "PROJECT SNAPSHOTS"
    case .characterLibrary: "REUSABLE SOURCES"
    case .characterCollection: "ACTIVE CHARACTER"
    case .partsLibrary: "SHARED LIBRARY"
    }
  }

  private var title: String {
    switch selection {
    case .characters: "Project Characters"
    case .characterLibrary: "Character Library"
    case .characterCollection(_, let collection): collection.title
    case .partsLibrary(let category): category?.title ?? "Parts Library"
    }
  }

  private func statusIcon(_ state: AssetBuilderPartState) -> String {
    switch state {
    case .ready: "checkmark.circle.fill"
    case .grounded: "pin.fill"
    case .suppressed: "eye.slash.fill"
    case .proxy: "cube"
    }
  }

  private func statusColor(_ state: AssetBuilderPartState) -> Color {
    switch state {
    case .ready: .green
    case .grounded: .blue
    case .suppressed: .orange
    case .proxy: .secondary
    }
  }

  private func storageLabel(_ storage: DocumentAssetStorage) -> String {
    switch storage {
    case .embedded: "Embedded"
    case .linked: "Linked"
    }
  }

  private func durationLabel(_ seconds: Double) -> String {
    String(format: "%.2f s", seconds)
  }

  private func tablePrimaryTitle(_ collection: AssetBuilderCollection) -> String {
    switch collection {
    case .parts: "PART"
    case .sourceAssets: "ASSET"
    case .renders: "RENDER"
    case .assemblies: "ASSEMBLY"
    case .scripts: "SCRIPT"
    case .animations: "ANIMATION"
    }
  }

  private func emptyCollectionDetail(_ collection: AssetBuilderCollection) -> String {
    switch collection {
    case .parts: "Imported rigid parts will appear here."
    case .sourceAssets: "Imported model, audio, image, and media files will appear here."
    case .assemblies: "Engine mates and relations, plus editor groups, will appear here."
    case .renders: "Per-part materials and appearance overrides from editor.json will appear here."
    case .scripts: "Project scene scripts from .scene.anima files will appear here."
    case .animations: "Animation clips authored for this character will appear here."
    }
  }
}

private struct AssetBuilderTableColumn: Identifiable {
  let title: String
  let width: CGFloat

  var id: String { title }
}
