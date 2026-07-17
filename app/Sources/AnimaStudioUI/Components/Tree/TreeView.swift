import SwiftUI

struct TreeRevealRequest<ID: Hashable>: Equatable {
  var id: ID
  var revision: Int
}

/// Reusable tree renderer. Node adapters supply identity, hierarchy, row
/// content, selection values, drag payloads, and drop behavior; the component
/// owns disclosure, filtered ancestor retention, reveal/scroll, and feedback.
struct TreeView<Node: TreeNode, RowContent: View>: View {
  let nodes: [Node]
  let filterText: String
  @Binding var expandedIDs: Set<Node.ID>
  @Binding var activeDragPayload: NavigatorDragPayload?
  let revealRequest: TreeRevealRequest<Node.ID>?
  let rowContent: (Node) -> RowContent
  let dragPayload: (Node) -> NavigatorDragPayload?
  let dropBehavior: (Node) -> NavigatorDropBehavior?
  let canDrop: (NavigatorDragPayload, NavigatorDropIntent, Node) -> Bool
  let onDrop: (NavigatorDragPayload, NavigatorDropIntent, Node) -> Bool

  init(
    nodes: [Node],
    filterText: String,
    expandedIDs: Binding<Set<Node.ID>>,
    activeDragPayload: Binding<NavigatorDragPayload?>,
    revealRequest: TreeRevealRequest<Node.ID>? = nil,
    @ViewBuilder rowContent: @escaping (Node) -> RowContent,
    dragPayload: @escaping (Node) -> NavigatorDragPayload?,
    dropBehavior: @escaping (Node) -> NavigatorDropBehavior?,
    canDrop: @escaping (NavigatorDragPayload, NavigatorDropIntent, Node) -> Bool = {
      _, _, _ in true
    },
    onDrop: @escaping (NavigatorDragPayload, NavigatorDropIntent, Node) -> Bool
  ) {
    self.nodes = nodes
    self.filterText = filterText
    _expandedIDs = expandedIDs
    _activeDragPayload = activeDragPayload
    self.revealRequest = revealRequest
    self.rowContent = rowContent
    self.dragPayload = dragPayload
    self.dropBehavior = dropBehavior
    self.canDrop = canDrop
    self.onDrop = onDrop
  }

  var body: some View {
    ScrollViewReader { proxy in
      ForEach(rows) { row in
        renderedRow(row)
          .id(row.node.id)
          .tag(row.node.selectionValue)
      }
      .onChange(of: revealRequest) { _, request in
        guard let request, model.node(id: request.id) != nil else { return }
        expandedIDs.formUnion(model.ancestorIDs(of: request.id))
        withAnimation(.easeInOut(duration: 0.18)) {
          proxy.scrollTo(request.id, anchor: .center)
        }
      }
    }
  }

  private var model: TreeModel<Node> {
    TreeModel(roots: nodes).filtered(by: TreeFilterQuery(filterText))
  }

  private var rows: [TreeFlatRow<Node>] {
    model.flattened(
      expandedIDs: expandedIDs,
      forceExpanded: !TreeFilterQuery(filterText).isEmpty
    )
  }

  @ViewBuilder
  private func renderedRow(_ row: TreeFlatRow<Node>) -> some View {
    let base = HStack(spacing: 4) {
      Color.clear.frame(width: CGFloat(row.depth) * 14)
      disclosureButton(for: row.node)
      rowContent(row.node)
    }
    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
    .contentShape(Rectangle())
    if let payload = dragPayload(row.node), let behavior = dropBehavior(row.node) {
      base
        .navigatorDragSource(payload, activePayload: $activeDragPayload)
        .navigatorDropTarget(
          activePayload: $activeDragPayload,
          behavior: behavior,
          canDrop: { payload, intent in canDrop(payload, intent, row.node) },
          onDrop: { payload, intent in onDrop(payload, intent, row.node) }
        )
    } else if let behavior = dropBehavior(row.node) {
      base.navigatorDropTarget(
        activePayload: $activeDragPayload,
        behavior: behavior,
        canDrop: { payload, intent in canDrop(payload, intent, row.node) },
        onDrop: { payload, intent in onDrop(payload, intent, row.node) }
      )
    } else {
      base
    }
  }

  @ViewBuilder
  private func disclosureButton(for node: Node) -> some View {
    if node.children.isEmpty {
      Color.clear.frame(width: 14, height: 14)
    } else {
      Button {
        if expandedIDs.contains(node.id) {
          expandedIDs.remove(node.id)
        } else {
          expandedIDs.insert(node.id)
        }
      } label: {
        Image(systemName: expandedIDs.contains(node.id) ? "chevron.down" : "chevron.right")
          .font(.system(size: 9, weight: .semibold))
          .frame(width: 14, height: 14)
      }
      .buttonStyle(.plain)
      .disabled(!filterText.isEmpty)
      .accessibilityLabel(expandedIDs.contains(node.id) ? "Collapse" : "Expand")
    }
  }
}
