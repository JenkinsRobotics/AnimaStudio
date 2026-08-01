import AnimaEvaluation
import AnimaModel
import Foundation

enum NavigatorTreeNodeID: Hashable {
  case component(PartID)
  case group(UUID)
  case mate(String)
  case relation(String)

  var persistenceKey: String {
    switch self {
    case .component(let id): "part:\(id.rawValue.uuidString)"
    case .group(let id): "group:\(id.uuidString)"
    case .mate(let id): "mate:\(id)"
    case .relation(let id): "relation:\(id)"
    }
  }
}

struct NavigatorTreeNode: TreeNode {
  var id: NavigatorTreeNodeID
  var selectionValue: NavigatorItem
  var title: String
  var role: NavigatorNodeRole
  var detail: String?
  var states: [NavigatorRowState]
  var children: [NavigatorTreeNode]
  var filterTokens: Set<TreeFilterToken>
  var isLocked: Bool
  var acceptsChildren: Bool
  var payload: NavigatorDragPayload?
  var behavior: NavigatorDropBehavior?

  var filterText: String {
    ([title, detail].compactMap { $0 } + filterTokens.map(\.rawValue))
      .joined(separator: " ")
  }
}
