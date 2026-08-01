import SwiftUI

struct TreeRevealRequest<ID: Hashable>: Equatable {
  var id: ID
  var revision: Int
}

/// One entry in a tree row's right-click menu. Callers describe the action;
/// the tree renders it identically everywhere.
struct TreeContextAction: Identifiable {
  let id = UUID()
  var title: String
  var systemImage: String
  var role: ButtonRole?
  var isEnabled: Bool
  var perform: () -> Void

  init(
    title: String,
    systemImage: String,
    role: ButtonRole? = nil,
    isEnabled: Bool = true,
    perform: @escaping () -> Void
  ) {
    self.title = title
    self.systemImage = systemImage
    self.role = role
    self.isEnabled = isEnabled
    self.perform = perform
  }
}

/// The universal control layer every Studio tree shares: inline rename, delete,
/// and a right-click menu. Selection/drag stay with the existing bindings.
/// A caller supplies only closures onto its own model mutations; when the
/// interaction is `nil` the tree renders as a plain outline (no behavior change
/// for callers that have not adopted it yet).
struct TreeInteraction<Node: TreeNode> {
  /// The current editable name if the node can be renamed, else `nil`.
  var editableName: (Node) -> String?
  /// Commit a rename. The tree validates non-empty before calling.
  var commitRename: (Node, String) -> Void
  /// Delete a set of nodes (⌫ and the menu). `nil` hides the Delete affordance.
  var delete: ((Set<Node.ID>) -> Void)?
  /// Whether the node may be deleted (locked/derived rows return false).
  var canDelete: (Node) -> Bool
  /// The IDs the delete key should act on (usually the shared selection).
  var selectedIDs: () -> Set<Node.ID>
  /// Extra menu entries (Duplicate, Group, Show in viewport, …).
  var extraActions: (Node) -> [TreeContextAction]

  init(
    editableName: @escaping (Node) -> String? = { _ in nil },
    commitRename: @escaping (Node, String) -> Void = { _, _ in },
    delete: ((Set<Node.ID>) -> Void)? = nil,
    canDelete: @escaping (Node) -> Bool = { _ in false },
    selectedIDs: @escaping () -> Set<Node.ID> = { [] },
    extraActions: @escaping (Node) -> [TreeContextAction] = { _ in [] }
  ) {
    self.editableName = editableName
    self.commitRename = commitRename
    self.delete = delete
    self.canDelete = canDelete
    self.selectedIDs = selectedIDs
    self.extraActions = extraActions
  }
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
  let interaction: TreeInteraction<Node>?
  let rowContent: (Node) -> RowContent
  let dragPayload: (Node) -> NavigatorDragPayload?
  let dropBehavior: (Node) -> NavigatorDropBehavior?
  let canDrop: (NavigatorDragPayload, NavigatorDropIntent, Node) -> Bool
  let onDrop: (NavigatorDragPayload, NavigatorDropIntent, Node) -> Bool

  @State private var renamingID: Node.ID?
  @State private var renameText = ""
  @FocusState private var renameFieldFocused: Bool

  init(
    nodes: [Node],
    filterText: String,
    expandedIDs: Binding<Set<Node.ID>>,
    activeDragPayload: Binding<NavigatorDragPayload?>,
    revealRequest: TreeRevealRequest<Node.ID>? = nil,
    interaction: TreeInteraction<Node>? = nil,
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
    self.interaction = interaction
    self.rowContent = rowContent
    self.dragPayload = dragPayload
    self.dropBehavior = dropBehavior
    self.canDrop = canDrop
    self.onDrop = onDrop
  }

  var body: some View {
    ScrollViewReader { proxy in
      // The rows MUST live in a vertical stack. A bare ForEach directly inside
      // ScrollViewReader has no layout container, so every row renders at the
      // same origin and they overlap (visible in the plain-ScrollView callers).
      LazyVStack(spacing: 2) {
        ForEach(rows) { row in
          renderedRow(row)
            .id(row.node.id)
            .tag(row.node.selectionValue)
        }
      }
      .onDeleteCommand(perform: deleteCommand)
      .onChange(of: revealRequest) { _, request in
        guard let request, model.node(id: request.id) != nil else { return }
        expandedIDs.formUnion(model.ancestorIDs(of: request.id))
        withAnimation(.easeInOut(duration: 0.18)) {
          proxy.scrollTo(request.id, anchor: .center)
        }
      }
    }
  }

  private var deleteCommand: (() -> Void)? {
    guard let interaction, interaction.delete != nil else { return nil }
    return { deleteSelection() }
  }

  private func deleteSelection() {
    guard let interaction, let delete = interaction.delete else { return }
    let ids = interaction.selectedIDs()
    let deletable = Set(ids.filter { id in model.node(id: id).map(interaction.canDelete) == true })
    guard !deletable.isEmpty else { return }
    delete(deletable)
  }

  private func beginRename(_ node: Node) {
    guard let name = interaction?.editableName(node) else { return }
    renameText = name
    renamingID = node.id
    renameFieldFocused = true
  }

  private func commitRename(_ node: Node) {
    defer { renamingID = nil }
    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    interaction?.commitRename(node, trimmed)
  }

  @ViewBuilder
  private func contextMenu(for node: Node) -> some View {
    if let interaction {
      if interaction.editableName(node) != nil {
        Button("Rename", systemImage: "pencil") { beginRename(node) }
      }
      ForEach(interaction.extraActions(node)) { action in
        Button(action.title, systemImage: action.systemImage, role: action.role) {
          action.perform()
        }
        .disabled(!action.isEnabled)
      }
      if let delete = interaction.delete, interaction.canDelete(node) {
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
          let selected = interaction.selectedIDs()
          delete(selected.contains(node.id) ? selected : [node.id])
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
  private func rowBody(_ node: Node) -> some View {
    if renamingID == node.id, interaction != nil {
      TextField("Name", text: $renameText)
        .textFieldStyle(.plain)
        .font(.callout)
        .focused($renameFieldFocused)
        .onSubmit { commitRename(node) }
        .onExitCommand { renamingID = nil }
        .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      rowContent(node)
    }
  }

  @ViewBuilder
  private func renderedRow(_ row: TreeFlatRow<Node>) -> some View {
    let base = HStack(spacing: 4) {
      Color.clear.frame(width: CGFloat(row.depth) * 14)
      disclosureButton(for: row.node)
      rowBody(row.node)
    }
    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
    .contentShape(Rectangle())
    .modifier(
      TreeRowInteractionModifier(
        isInteractive: interaction != nil,
        onRename: { beginRename(row.node) },
        menu: { contextMenu(for: row.node) }
      )
    )
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

/// Attaches the shared right-click menu and double-click-to-rename to a tree
/// row, but only when the tree was given an interaction — so non-adopting
/// callers keep their exact previous behavior.
private struct TreeRowInteractionModifier<MenuContent: View>: ViewModifier {
  let isInteractive: Bool
  let onRename: () -> Void
  @ViewBuilder let menu: () -> MenuContent

  func body(content: Content) -> some View {
    if isInteractive {
      content
        .contextMenu { menu() }
        .simultaneousGesture(TapGesture(count: 2).onEnded(onRename))
    } else {
      content
    }
  }
}
