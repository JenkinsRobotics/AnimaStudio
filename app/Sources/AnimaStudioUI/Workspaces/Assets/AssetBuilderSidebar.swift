import AnimaDocument
import SwiftUI

struct AssetBuilderSidebar: View {
  let projectName: String
  let revision: Int
  let characters: [ProjectCharacterReference]
  let activeCharacterID: String?
  let counts: [AssetBuilderCollection: Int]
  let isSwitchingCharacter: Bool
  @Binding var selection: AssetBuilderSelection
  let newCharacter: () -> Void
  let selectCharacter: (ProjectCharacterReference) -> Void

  @State private var filterText = ""
  @State private var expandedIDs: Set<AssetBuilderTreeNodeID> = [.project, .characters, .library]
  @State private var activeDragPayload: NavigatorDragPayload?

  var body: some View {
    VStack(spacing: 0) {
      Button(action: newCharacter) {
        Label("Create New Character", systemImage: "plus")
          .font(.callout.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .padding(12)

      Divider()

      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
        TextField("Filter project contents", text: $filterText)
          .textFieldStyle(.plain)
      }
      .padding(.horizontal, 8)
      .frame(height: 29)
      .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 6))
      .overlay { RoundedRectangle(cornerRadius: 6).stroke(StudioPalette.border) }
      .padding(10)

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

  private var nodes: [AssetBuilderTreeNode] {
    AssetBuilderTreeAdapter.nodes(
      projectName: projectName,
      revision: revision,
      characters: characters,
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
          if case .project = node.id, let detail = node.detail {
            Text(detail).font(.caption2).foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 5)
        if isSwitchingCharacter && isActiveCharacter(node) {
          ProgressView().controlSize(.mini)
        } else if let detail = node.detail, !isProject(node) {
          Text(detail)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        if isActiveCharacter(node), !isSwitchingCharacter {
          Circle().fill(StudioPalette.sourceModel).frame(width: 6, height: 6)
        }
      }
      .padding(.horizontal, 6)
      .frame(maxWidth: .infinity, minHeight: isProject(node) ? 38 : 28, alignment: .leading)
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

  private func isProject(_ node: AssetBuilderTreeNode) -> Bool {
    if case .project = node.id { return true }
    return false
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
    return .secondary
  }
}
