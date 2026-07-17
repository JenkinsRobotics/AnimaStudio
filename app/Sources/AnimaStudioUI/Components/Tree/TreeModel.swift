import Foundation

enum TreeFilterToken: String, CaseIterable, Hashable, Sendable {
  case part
  case mate
  case suppressed
  case grounded
  case hidden
  case locked
}

struct TreeFilterQuery: Equatable, Sendable {
  var terms: [String]
  var tokens: Set<TreeFilterToken>

  init(_ rawValue: String) {
    var terms: [String] = []
    var tokens: Set<TreeFilterToken> = []
    for component in rawValue.split(whereSeparator: \Character.isWhitespace) {
      let value = String(component).lowercased()
      if value.hasPrefix(":"),
        let token = TreeFilterToken(rawValue: String(value.dropFirst()))
      {
        tokens.insert(token)
      } else {
        terms.append(value)
      }
    }
    self.terms = terms
    self.tokens = tokens
  }

  var isEmpty: Bool { terms.isEmpty && tokens.isEmpty }
}

protocol TreeNode: Identifiable, Equatable where ID: Hashable {
  associatedtype SelectionValue: Hashable

  var selectionValue: SelectionValue { get }
  var children: [Self] { get set }
  var filterText: String { get }
  var filterTokens: Set<TreeFilterToken> { get }
  var isLocked: Bool { get }
  var acceptsChildren: Bool { get }
}

enum TreeDropPlacement: Equatable, Sendable {
  case before
  case inside
  case after
}

struct TreeFlatRow<Node: TreeNode>: Identifiable, Equatable {
  var node: Node
  var depth: Int

  var id: Node.ID { node.id }
}

/// Renderer-independent tree operations shared by every Studio navigator.
///
/// SwiftUI only renders the flattened result. Reorder, reparent, grouping,
/// filtering, and cycle/lock validation stay deterministic and unit-testable.
struct TreeModel<Node: TreeNode>: Equatable {
  var roots: [Node]

  func node(id: Node.ID) -> Node? {
    for root in roots {
      if let match = Self.node(id: id, in: root) { return match }
    }
    return nil
  }

  func ancestorIDs(of id: Node.ID) -> [Node.ID] {
    for root in roots {
      if let ancestors = Self.ancestorIDs(of: id, in: root, ancestors: []) {
        return ancestors
      }
    }
    return []
  }

  func flattened(expandedIDs: Set<Node.ID>, forceExpanded: Bool = false) -> [TreeFlatRow<Node>] {
    roots.flatMap {
      Self.flattened(
        $0,
        depth: 0,
        expandedIDs: expandedIDs,
        forceExpanded: forceExpanded
      )
    }
  }

  func filtered(by query: TreeFilterQuery) -> Self {
    guard !query.isEmpty else { return self }
    return Self(roots: roots.compactMap { Self.filtered($0, by: query) })
  }

  func canDrop(
    sourceID: Node.ID,
    onto destinationID: Node.ID,
    placement: TreeDropPlacement
  ) -> Bool {
    guard sourceID != destinationID,
      let source = node(id: sourceID),
      let destination = node(id: destinationID),
      !source.isLocked,
      !destination.isLocked
    else { return false }
    if Self.contains(destinationID, in: source) { return false }
    if placement == .inside && !destination.acceptsChildren { return false }
    return true
  }

  @discardableResult
  mutating func move(
    _ sourceID: Node.ID,
    onto destinationID: Node.ID,
    placement: TreeDropPlacement
  ) -> Bool {
    guard canDrop(sourceID: sourceID, onto: destinationID, placement: placement),
      let source = remove(id: sourceID)
    else { return false }

    let inserted: Bool
    switch placement {
    case .inside:
      inserted = insertInside(source, destinationID: destinationID)
    case .before, .after:
      inserted = insertSibling(
        source,
        destinationID: destinationID,
        after: placement == .after
      )
    }
    if !inserted {
      roots.append(source)
    }
    return inserted
  }

  @discardableResult
  mutating func group(_ nodeIDs: [Node.ID], using group: Node) -> Bool {
    let uniqueIDs = nodeIDs.reduce(into: [Node.ID]()) { result, id in
      if !result.contains(id) { result.append(id) }
    }
    guard uniqueIDs.count >= 2,
      group.acceptsChildren,
      uniqueIDs.allSatisfy({ node(id: $0)?.isLocked == false })
    else { return false }

    var members: [Node] = []
    for id in uniqueIDs {
      guard let member = remove(id: id) else { continue }
      members.append(member)
    }
    guard members.count >= 2 else {
      roots.append(contentsOf: members)
      return false
    }
    var grouped = group
    grouped.children = members
    roots.append(grouped)
    return true
  }

  private mutating func remove(id: Node.ID) -> Node? {
    if let index = roots.firstIndex(where: { $0.id == id }) {
      return roots.remove(at: index)
    }
    for index in roots.indices {
      if let removed = Self.remove(id: id, from: &roots[index]) {
        return removed
      }
    }
    return nil
  }

  private mutating func insertInside(_ source: Node, destinationID: Node.ID) -> Bool {
    for index in roots.indices {
      if roots[index].id == destinationID {
        roots[index].children.append(source)
        return true
      }
      if Self.insertInside(source, destinationID: destinationID, node: &roots[index]) {
        return true
      }
    }
    return false
  }

  private mutating func insertSibling(
    _ source: Node,
    destinationID: Node.ID,
    after: Bool
  ) -> Bool {
    if let index = roots.firstIndex(where: { $0.id == destinationID }) {
      roots.insert(source, at: index + (after ? 1 : 0))
      return true
    }
    for index in roots.indices {
      if Self.insertSibling(
        source,
        destinationID: destinationID,
        after: after,
        node: &roots[index]
      ) {
        return true
      }
    }
    return false
  }

  private static func filtered(_ node: Node, by query: TreeFilterQuery) -> Node? {
    var result = node
    result.children = node.children.compactMap { filtered($0, by: query) }
    let normalized = node.filterText.lowercased()
    let termsMatch = query.terms.allSatisfy(normalized.contains)
    let tokensMatch = query.tokens.isSubset(of: node.filterTokens)
    return (termsMatch && tokensMatch) || !result.children.isEmpty ? result : nil
  }

  private static func node(id: Node.ID, in node: Node) -> Node? {
    if node.id == id { return node }
    for child in node.children {
      if let match = self.node(id: id, in: child) { return match }
    }
    return nil
  }

  private static func ancestorIDs(
    of id: Node.ID,
    in node: Node,
    ancestors: [Node.ID]
  ) -> [Node.ID]? {
    if node.id == id { return ancestors }
    for child in node.children {
      if let result = ancestorIDs(of: id, in: child, ancestors: ancestors + [node.id]) {
        return result
      }
    }
    return nil
  }

  private static func flattened(
    _ node: Node,
    depth: Int,
    expandedIDs: Set<Node.ID>,
    forceExpanded: Bool
  ) -> [TreeFlatRow<Node>] {
    var result = [TreeFlatRow(node: node, depth: depth)]
    if forceExpanded || expandedIDs.contains(node.id) {
      result.append(
        contentsOf: node.children.flatMap {
          flattened(
            $0,
            depth: depth + 1,
            expandedIDs: expandedIDs,
            forceExpanded: forceExpanded
          )
        }
      )
    }
    return result
  }

  private static func contains(_ id: Node.ID, in node: Node) -> Bool {
    node.id == id || node.children.contains { contains(id, in: $0) }
  }

  private static func remove(id: Node.ID, from node: inout Node) -> Node? {
    if let index = node.children.firstIndex(where: { $0.id == id }) {
      return node.children.remove(at: index)
    }
    for index in node.children.indices {
      if let removed = remove(id: id, from: &node.children[index]) { return removed }
    }
    return nil
  }

  private static func insertInside(
    _ source: Node,
    destinationID: Node.ID,
    node: inout Node
  ) -> Bool {
    for index in node.children.indices {
      if node.children[index].id == destinationID {
        node.children[index].children.append(source)
        return true
      }
      if insertInside(source, destinationID: destinationID, node: &node.children[index]) {
        return true
      }
    }
    return false
  }

  private static func insertSibling(
    _ source: Node,
    destinationID: Node.ID,
    after: Bool,
    node: inout Node
  ) -> Bool {
    if let index = node.children.firstIndex(where: { $0.id == destinationID }) {
      node.children.insert(source, at: index + (after ? 1 : 0))
      return true
    }
    for index in node.children.indices {
      if insertSibling(
        source,
        destinationID: destinationID,
        after: after,
        node: &node.children[index]
      ) {
        return true
      }
    }
    return false
  }
}
