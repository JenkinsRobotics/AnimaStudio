import AnimaDocument
import SwiftUI

struct AssetBuilderSidebar: View {
  let projectName: String
  let revision: Int
  let characters: [ProjectCharacterReference]
  let characterLibraryCount: Int
  let activeCharacterID: String?
  let counts: [AssetBuilderCollection: Int]
  let isSwitchingCharacter: Bool
  @Binding var selection: AssetBuilderSelection
  let newCharacter: () -> Void
  let selectCharacter: (ProjectCharacterReference) -> Void

  @State private var filterText = ""
  @State private var showSearch = false
  @State private var expandedIDs: Set<AssetBuilderTreeNodeID> = [.characters]
  @State private var activeDragPayload: NavigatorDragPayload?

  var body: some View {
    VStack(spacing: 0) {
      // Compact panel header: name + search toggle. Creating a character is a
      // toolbar action; the project name/revision live in the document bar — so
      // neither belongs here, and dropping them maximizes content area.
      header

      if showSearch { searchField }

      Divider()

      ScrollView {
        LazyVStack(spacing: 2) {
          TreeView(
            nodes: nodes,
            filterText: filterText,
            expandedIDs: $expandedIDs,
            activeDragPayload: $activeDragPayload,
            rowContent: treeRow,
            dragPayload: { _ in nil },
            dropBehavior: { _ in nil },
            onDrop: { _, _, _ in false }
          )
        }
        .padding(8)
      }
    }
    .background(StudioPalette.panel)
    .onAppear { expandActiveCharacter() }
    .onChange(of: activeCharacterID) { _, _ in expandActiveCharacter() }
  }

  private var header: some View {
    HStack(spacing: 7) {
      Image(systemName: panelIcon)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(StudioPalette.accent)
        .frame(width: 16)
      Text(panelTitle.uppercased())
        .font(.system(size: 10.5, weight: .semibold))
        .tracking(0.6)
        .lineLimit(1)
      Spacer(minLength: 8)
      Button {
        withAnimation(.easeOut(duration: 0.15)) { showSearch.toggle() }
        if !showSearch { filterText = "" }
      } label: {
        Image(systemName: "magnifyingglass")
          .font(.caption.bold())
          .foregroundStyle(showSearch ? StudioPalette.accent : StudioPalette.muted)
          .frame(width: 24, height: 24)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("Search this panel")
    }
    .foregroundStyle(StudioPalette.ink.opacity(0.92))
    .padding(.horizontal, StudioMetrics.panelPadding)
    .frame(height: StudioMetrics.panelHeaderHeight)
    .background(StudioPalette.panelInset.opacity(0.52))
  }

  private var searchField: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
      TextField("Search", text: $filterText)
        .textFieldStyle(.plain)
      if !filterText.isEmpty {
        Button { filterText = "" } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 8)
    .frame(height: 29)
    .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 6))
    .overlay { RoundedRectangle(cornerRadius: 6).stroke(StudioPalette.border) }
    .padding(8)
  }

  // This view is the full character-profile panel (the "Characters" rail tab).
  // Its header is fixed — collection panels are handled by
  // AssetCollectionSidebarPanel, so the title must not follow the shared
  // selection (which would mislabel the profile as e.g. "SOURCE ASSETS").
  private let panelTitle = "Characters"
  private let panelIcon = "person.2"

  private var nodes: [AssetBuilderTreeNode] {
    AssetBuilderTreeAdapter.nodes(
      characters: characters,
      characterLibraryCount: characterLibraryCount,
      activeCharacterID: activeCharacterID,
      counts: counts
    )
  }

  private func treeRow(_ node: AssetBuilderTreeNode) -> some View {
    Button {
      activate(node)
    } label: {
      HStack(spacing: 7) {
        Image(systemName: node.systemImage)
          .font(.caption)
          .frame(width: 16)
          .foregroundStyle(rowColor(node))
        VStack(alignment: .leading, spacing: 1) {
          Text(node.title)
            .font(.callout.weight(isActiveCharacter(node) ? .semibold : .regular))
            .lineLimit(1)
        }
        Spacer(minLength: 5)
        if isSwitchingCharacter && isActiveCharacter(node) {
          ProgressView().controlSize(.mini)
        } else if let detail = node.detail {
          Text(detail)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        if isActiveCharacter(node), !isSwitchingCharacter {
          Circle().fill(StudioPalette.sourceModel).frame(width: 6, height: 6)
        }
      }
      .padding(.horizontal, 6)
      .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
      .background(
        node.selectionValue == selection ? StudioPalette.accent.opacity(0.24) : Color.clear,
        in: RoundedRectangle(cornerRadius: 6)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func activate(_ node: AssetBuilderTreeNode) {
    if let characterID = node.selectionValue.characterID,
      characterID != activeCharacterID,
      let character = characters.first(where: { $0.id == characterID })
    {
      selectCharacter(character)
    }
    selection = node.selectionValue
    if case .character(let id) = node.id { expandedIDs.insert(.character(id)) }
  }

  private func expandActiveCharacter() {
    guard let activeCharacterID else { return }
    expandedIDs.insert(.character(activeCharacterID))
  }

  private func isActiveCharacter(_ node: AssetBuilderTreeNode) -> Bool {
    guard case .character(let id) = node.id else { return false }
    return id == activeCharacterID
  }

  private func rowColor(_ node: AssetBuilderTreeNode) -> Color {
    if isActiveCharacter(node) || node.selectionValue == selection {
      return StudioPalette.sourceModel
    }
    if case .library = node.id { return StudioPalette.sourceModel }
    if case .characterLibrary = node.id { return StudioPalette.sourceModel }
    return .secondary
  }
}
