// The universal browser tree: renders a TreeModel with folders, drag-and-drop
// (reorder + move into folders), grouping, delete, rename, and visibility — the
// same functions for every panel. Built on TreeRow so it matches the rest.
import SwiftUI
import UniformTypeIdentifiers

struct TreeView: View {
  @Bindable var model: TreeModel
  /// Called when a leaf is activated (single selection), e.g. to select the part.
  var onActivate: (TreeNode) -> Void = { _ in }

  @State private var dropTarget: UUID?

  var body: some View {
    VStack(spacing: 0) {
      // Rows.
      ForEach(model.nodes) { node in rows(node, depth: 0) }

      // Drop zone for "move to top level".
      Color.clear.frame(height: 10)
        .dropDestination(for: String.self) { items, _ in
          if let id = items.first.flatMap({ UUID(uuidString: $0) }) {
            model.move(id, intoFolder: nil); return true
          }
          return false
        }

      Divider().overlay(UI.stroke).padding(.top, 2)
      actionBar
    }
  }

  // Recursively render a node and (if an expanded folder) its children.
  // AnyView because the function refers to itself.
  private func rows(_ node: TreeNode, depth: Int) -> AnyView {
    AnyView(
      VStack(spacing: 0) {
        row(node, depth: depth)
        if node.isFolder, model.expanded.contains(node.id) {
          ForEach(node.children) { child in rows(child, depth: depth + 1) }
        }
      }
    )
  }

  @ViewBuilder private func row(_ node: TreeNode, depth: Int) -> some View {
    let selected = model.selection.contains(node.id)
    Group {
      if model.renaming == node.id {
        renameRow(node, depth: depth)
      } else {
        TreeRow(depth: depth, icon: node.isFolder ? "folder" : node.icon,
          title: node.name, detail: node.detail,
          expandable: node.isFolder, expanded: model.expanded.contains(node.id),
          selected: selected, bold: node.isFolder,
          visible: node.visible, onToggleVisible: { model.toggleVisible(node.id) },
          onToggleExpand: { model.toggleExpanded(node.id) },
          onTap: { activate(node) })
      }
    }
    .overlay(alignment: .top) {
      if dropTarget == node.id { Rectangle().fill(UI.accent).frame(height: 2) }
    }
    // Each row is draggable and a drop target (reorder before / into a folder).
    .draggable(node.id.uuidString) {
      TreeRow(icon: node.isFolder ? "folder" : node.icon, title: node.name)
        .frame(width: 180).background(UI.panel)
    }
    .dropDestination(for: String.self) { items, _ in
      dropTarget = nil
      guard let id = items.first.flatMap({ UUID(uuidString: $0) }) else { return false }
      model.move(id, target: node.id, into: node.isFolder)
      return true
    } isTargeted: { over in
      dropTarget = over ? node.id : (dropTarget == node.id ? nil : dropTarget)
    }
    .contextMenu { rowMenu(node) }
  }

  private func renameRow(_ node: TreeNode, depth: Int) -> some View {
    HStack(spacing: 5) {
      Image(systemName: node.isFolder ? "folder" : node.icon).font(.system(size: 12))
        .foregroundStyle(UI.accent2).frame(width: 16)
      TextField("Name", text: Binding(
        get: { TreeModel.find(node.id, in: model.nodes)?.name ?? node.name },
        set: { newName in TreeModel.mutate(node.id, in: &model.nodes) { $0.name = newName } }))
        .textFieldStyle(.plain).font(.system(size: 12))
        .onSubmit { model.renaming = nil }
      Button { model.renaming = nil } label: {
        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(UI.accent)
      }.buttonStyle(.plain)
    }
    .padding(.leading, CGFloat(depth) * 15 + 10).padding(.trailing, 12).frame(height: 28)
  }

  @ViewBuilder private func rowMenu(_ node: TreeNode) -> some View {
    Button("Rename") { model.selection = [node.id]; model.renaming = node.id }
    if node.isFolder { Button("New Folder Inside") { model.move(model.newFolder().id, intoFolder: node.id) } }
    if model.selection.count > 1 {
      Button("Group Selection") { model.groupSelection() }
    }
    Divider()
    Button("Delete", role: .destructive) {
      model.delete(model.selection.contains(node.id) ? model.selection : [node.id])
    }
  }

  private var actionBar: some View {
    HStack(spacing: 8) {
      Button { model.addFolder() } label: {
        Label("New Folder", systemImage: "folder.badge.plus").font(.system(size: 11.5))
      }.buttonStyle(.plain).foregroundStyle(UI.text2)
      if model.selection.count > 1 {
        Button { model.groupSelection() } label: {
          Label("Group", systemImage: "square.stack.3d.up").font(.system(size: 11.5))
        }.buttonStyle(.plain).foregroundStyle(UI.text2)
      }
      Spacer()
      if !model.selection.isEmpty {
        Button { model.delete(model.selection) } label: {
          Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(UI.danger)
        }.buttonStyle(.plain).help("Delete selection")
      }
    }.padding(10)
  }

  private func activate(_ node: TreeNode) {
    model.selection = [node.id]
    if !node.isFolder { onActivate(node) }
  }
}

extension TreeModel {
  /// Make + append a folder and return it (used by "New Folder Inside").
  @discardableResult func newFolder(named name: String = "New Folder") -> TreeNode {
    let folder = TreeNode(name: name, icon: "folder", isFolder: true)
    nodes.append(folder)
    return folder
  }
}
