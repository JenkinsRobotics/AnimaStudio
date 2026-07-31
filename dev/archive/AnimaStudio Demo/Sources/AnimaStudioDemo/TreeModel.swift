// A reusable tree: folders + leaves with the universal operations every browser
// panel needs — create folder, group a selection, delete, drag-and-drop move /
// reorder, rename, visibility. One model, one view (TreeView), so Parts, Bodies,
// Mates, Documents … all behave identically; only the seeded data differs.
import SwiftUI

struct TreeNode: Identifiable, Equatable, Codable {
  let id: UUID
  var name: String
  var icon: String
  var detail: String?
  var isFolder: Bool
  var children: [TreeNode]
  var visible: Bool
  /// Links a leaf back to a real asset (a part id, mate id, …).
  var payload: UUID?

  init(id: UUID = UUID(), name: String, icon: String, detail: String? = nil,
    isFolder: Bool = false, children: [TreeNode] = [], visible: Bool = true,
    payload: UUID? = nil)
  {
    self.id = id; self.name = name; self.icon = icon; self.detail = detail
    self.isFolder = isFolder; self.children = children; self.visible = visible
    self.payload = payload
  }
}

/// A saved assembly document (assets/assemblies/<name>.animasm) — a reusable
/// sub-assembly of part/assembly references.
struct AssemblyFile: Codable {
  var version = 1
  var name: String
  var nodes: [TreeNode]
}

@MainActor @Observable final class TreeModel {
  var nodes: [TreeNode]
  var selection: Set<UUID> = []
  var expanded: Set<UUID> = []
  var renaming: UUID?

  init(nodes: [TreeNode] = []) { self.nodes = nodes }

  // MARK: Operations

  func addFolder(named name: String = "New Folder") {
    let folder = TreeNode(name: name, icon: "folder", isFolder: true)
    nodes.append(folder)
    expanded.insert(folder.id)
    selection = [folder.id]
    renaming = folder.id
  }

  /// Wrap the current selection in a new folder.
  func groupSelection(named name: String = "New Group") {
    let picked = Self.collect(selection, from: nodes)
    guard picked.count >= 1 else { return }
    var remaining = Self.removing(selection, from: nodes)
    let folder = TreeNode(name: name, icon: "folder", isFolder: true, children: picked)
    remaining.append(folder)
    nodes = remaining
    expanded.insert(folder.id)
    selection = [folder.id]
    renaming = folder.id
  }

  func delete(_ ids: Set<UUID>) {
    nodes = Self.removing(ids, from: nodes)
    selection.subtract(ids)
    expanded.subtract(ids)
  }

  func rename(_ id: UUID, to name: String) {
    Self.mutate(id, in: &nodes) { $0.name = name.isEmpty ? $0.name : name }
    renaming = nil
  }

  func toggleExpanded(_ id: UUID) {
    if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
  }

  func toggleVisible(_ id: UUID) {
    Self.mutate(id, in: &nodes) { $0.visible.toggle() }
  }

  /// Drag-and-drop: move `dragged` next to `target` (before it) or, if `target`
  /// is a folder and `into` is true, inside it. Rejects dropping a folder into
  /// its own descendant.
  func move(_ dragged: UUID, target: UUID, into: Bool) {
    guard dragged != target, !Self.isDescendant(target, of: dragged, in: nodes) else { return }
    guard let node = Self.find(dragged, in: nodes) else { return }
    var tree = Self.removing([dragged], from: nodes)
    if into, let t = Self.find(target, in: tree), t.isFolder {
      Self.mutate(target, in: &tree) { $0.children.append(node) }
      expanded.insert(target)
    } else {
      tree = Self.insert(node, before: target, in: tree)
      if !Self.contains(node.id, in: tree) { tree.append(node) }   // safety
    }
    nodes = tree
  }

  /// Drop onto empty space / a folder header → append to that container.
  func move(_ dragged: UUID, intoFolder folderID: UUID?) {
    guard let node = Self.find(dragged, in: nodes) else { return }
    var tree = Self.removing([dragged], from: nodes)
    if let folderID, folderID != dragged,
      !Self.isDescendant(folderID, of: dragged, in: nodes) {
      Self.mutate(folderID, in: &tree) { $0.children.append(node) }
      expanded.insert(folderID)
    } else {
      tree.append(node)
    }
    nodes = tree
  }

  // MARK: Recursive helpers

  static func find(_ id: UUID, in nodes: [TreeNode]) -> TreeNode? {
    for n in nodes {
      if n.id == id { return n }
      if let hit = find(id, in: n.children) { return hit }
    }
    return nil
  }

  static func removing(_ ids: Set<UUID>, from nodes: [TreeNode]) -> [TreeNode] {
    nodes.compactMap { node in
      guard !ids.contains(node.id) else { return nil }
      var copy = node
      copy.children = removing(ids, from: node.children)
      return copy
    }
  }

  /// Nodes matching `ids`, taken from wherever they sit (used by grouping).
  static func collect(_ ids: Set<UUID>, from nodes: [TreeNode]) -> [TreeNode] {
    var out: [TreeNode] = []
    for n in nodes {
      if ids.contains(n.id) { out.append(n) }
      else { out.append(contentsOf: collect(ids, from: n.children)) }
    }
    return out
  }

  static func insert(_ node: TreeNode, before target: UUID, in nodes: [TreeNode]) -> [TreeNode] {
    var result: [TreeNode] = []
    for var n in nodes {
      if n.id == target { result.append(node) }
      n.children = insert(node, before: target, in: n.children)
      result.append(n)
    }
    return result
  }

  static func contains(_ id: UUID, in nodes: [TreeNode]) -> Bool {
    nodes.contains { $0.id == id || contains(id, in: $0.children) }
  }

  static func isDescendant(_ id: UUID, of ancestor: UUID, in nodes: [TreeNode]) -> Bool {
    guard let a = find(ancestor, in: nodes) else { return false }
    return contains(id, in: a.children)
  }

  static func mutate(_ id: UUID, in nodes: inout [TreeNode], _ change: (inout TreeNode) -> Void) {
    for i in nodes.indices {
      if nodes[i].id == id { change(&nodes[i]); return }
      mutate(id, in: &nodes[i].children, change)
    }
  }
}
