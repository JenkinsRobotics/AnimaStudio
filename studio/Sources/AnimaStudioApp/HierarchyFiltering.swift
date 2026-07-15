import Foundation
import RealityKitViewport

extension ModelHierarchyNode {
  func filtered(matching query: String) -> ModelHierarchyNode? {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedQuery.isEmpty else { return self }

    if displayName.localizedStandardContains(normalizedQuery) {
      return self
    }

    let matchingChildren = children.compactMap { child in
      child.filtered(matching: normalizedQuery)
    }
    guard !matchingChildren.isEmpty else { return nil }

    return ModelHierarchyNode(id: id, name: name, children: matchingChildren)
  }
}
