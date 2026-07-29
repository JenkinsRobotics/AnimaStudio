import AnimaCADViewport
import AnimaCoreClient
import AnimaModel
import SwiftUI

/// The CAD-style assembly tree for the 3D Modeling tab. It is sourced directly
/// from the loaded engine data (`engineParts`, `engineMates`, `componentGroups`)
/// — the same authoritative list the Assets tab shows — so it can never render
/// empty while a character is loaded. It presents the full assembly: reference
/// geometry, parts (with ground/hidden state), sub-assembly groups, and mates.
struct AssemblyTreeView: View {
  @Bindable var workspace: StudioWorkspaceModel
  let deleteParts: (Set<PartID>) -> Void

  @State private var expanded: Set<String> = ["ref", "mates"]
  @State private var hoveredID: String?
  @State private var filterText = ""

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 1) {
          ForEach(visibleRows) { row in
            rowView(row)
          }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
      }
      Divider()
      toolbar
    }
    .background(StudioPalette.panel)
  }

  // MARK: Header

  private var header: some View {
    VStack(spacing: 8) {
      HStack(spacing: 7) {
        Image(systemName: "cube.box")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(StudioPalette.accent)
        Text("Items")
          .font(.system(size: 11, weight: .semibold))
          .tracking(0.4)
        Spacer()
        Text("\(workspace.engineParts.count)")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      HStack(spacing: 6) {
        Image(systemName: "line.3.horizontal.decrease")
          .font(.caption2)
          .foregroundStyle(.secondary)
        TextField("All Items", text: $filterText)
          .textFieldStyle(.plain)
          .font(.callout)
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 9))
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(.horizontal, 9)
      .frame(height: 28)
      .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 6))
      .overlay(RoundedRectangle(cornerRadius: 6).stroke(StudioPalette.border))
    }
    .padding(.horizontal, StudioMetrics.panelPadding)
    .padding(.vertical, 10)
    .background(StudioPalette.panelInset.opacity(0.52))
  }

  // MARK: Toolbar

  private var toolbar: some View {
    HStack(spacing: 4) {
      Button {
        _ = workspace.createComponentGroup()
      } label: {
        Image(systemName: "folder.badge.plus")
          .frame(width: 28, height: 24)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("Group selected parts into a sub-assembly")
      .disabled(workspace.selectedComponentIDs.isEmpty)

      Spacer()

      Menu {
        Button("Show All", systemImage: "eye") { workspace.showAllComponents() }
        Button("Expand All", systemImage: "chevron.down") { expandAll() }
        Button("Collapse All", systemImage: "chevron.right") { expanded.removeAll() }
      } label: {
        Image(systemName: "ellipsis.circle")
          .frame(width: 28, height: 24)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .menuIndicator(.hidden)
    }
    .foregroundStyle(.secondary)
    .padding(.horizontal, 8)
    .frame(height: 34)
    .background(StudioPalette.panelInset.opacity(0.4))
  }

  // MARK: Rows

  @ViewBuilder
  private func rowView(_ row: FlatRow) -> some View {
    let item = row.item
    let isSelected =
      item.partID.map { workspace.selectedComponentIDs.contains($0) }
      ?? item.groupID.map { workspace.selection.contains(.componentGroup($0)) }
      ?? false
    let isHidden = isItemHidden(item)
    HStack(spacing: 5) {
      Color.clear.frame(width: CGFloat(row.depth) * 13)
      disclosure(item)
      Image(systemName: item.systemImage)
        .font(.system(size: 11))
        .frame(width: 16)
        .foregroundStyle(iconColor(item, hidden: isHidden, selected: isSelected))
      Text(item.title)
        .font(.callout.weight(item.kind == .section ? .semibold : .regular))
        .foregroundStyle(isHidden ? Color.secondary.opacity(0.6) : .primary)
        .lineLimit(1)
      if item.isGrounded {
        Image(systemName: "pin.fill")
          .font(.system(size: 8))
          .foregroundStyle(StudioPalette.hardware)
      }
      Spacer(minLength: 4)
      if item.canToggleVisibility, hoveredID == item.id || isHidden {
        Button {
          toggleVisibility(item)
        } label: {
          Image(systemName: isHidden ? "eye.slash" : "eye")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 6)
    .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
    .background(
      isSelected ? StudioPalette.accent.opacity(0.22) : Color.clear,
      in: RoundedRectangle(cornerRadius: 5)
    )
    .contentShape(Rectangle())
    .onHover { hoveredID = $0 ? item.id : (hoveredID == item.id ? nil : hoveredID) }
    .onTapGesture { select(item) }
    .contextMenu { contextMenu(item) }
  }

  @ViewBuilder
  private func disclosure(_ item: AssemblyItem) -> some View {
    if item.children.isEmpty {
      Color.clear.frame(width: 12, height: 12)
    } else {
      Button {
        if expanded.contains(item.id) { expanded.remove(item.id) } else { expanded.insert(item.id) }
      } label: {
        Image(systemName: expanded.contains(item.id) ? "chevron.down" : "chevron.right")
          .font(.system(size: 8, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 12, height: 12)
      }
      .buttonStyle(.plain)
    }
  }

  @ViewBuilder
  private func contextMenu(_ item: AssemblyItem) -> some View {
    if let partID = item.partID {
      Button("Rename…", systemImage: "pencil") { beginRename(partID) }
      Button("Group Selection", systemImage: "folder.badge.plus") {
        _ = workspace.createComponentGroup()
      }
      .disabled(workspace.selectedComponentIDs.isEmpty)
      Divider()
      Button(
        isItemHidden(item) ? "Show" : "Hide", systemImage: isItemHidden(item) ? "eye" : "eye.slash"
      ) {
        toggleVisibility(item)
      }
      Button(
        workspace.isolatedComponentID == partID ? "Exit Isolation" : "Isolate",
        systemImage: "cube"
      ) {
        workspace.isolatedComponentID = workspace.isolatedComponentID == partID ? nil : partID
      }
      Button(
        item.isGrounded ? "Unground" : "Ground", systemImage: item.isGrounded ? "pin.slash" : "pin"
      ) {
        Task { await workspace.togglePartGrounded(partID) }
      }
      Divider()
      Button("Delete", systemImage: "trash", role: .destructive) {
        deleteParts(
          workspace.selectedComponentIDs.contains(partID)
            ? Set(workspace.selectedComponentIDs) : [partID])
      }
    } else if item.kind == .group, let groupID = item.groupID {
      Button("Rename Sub-assembly…", systemImage: "pencil") { beginGroupRename(groupID) }
      Button(
        isItemHidden(item) ? "Show Sub-assembly" : "Hide Sub-assembly",
        systemImage: isItemHidden(item) ? "eye" : "eye.slash"
      ) {
        toggleVisibility(item)
      }
      Button(
        item.isGrounded ? "Unground Sub-assembly" : "Ground Sub-assembly",
        systemImage: item.isGrounded ? "pin.slash" : "pin"
      ) {
        Task { await workspace.toggleComponentGroupGrounded(groupID) }
      }
      Menu("Move into Sub-assembly", systemImage: "folder.badge.plus") {
        ForEach(workspace.componentGroups.filter { $0.id != groupID }) { parent in
          Button(parent.displayName) {
            _ = workspace.nestComponentGroup(groupID, in: parent.id)
            expanded.insert("group:\(parent.id)")
          }
        }
      }
      Button("Move to Top Level", systemImage: "arrow.up.to.line") {
        _ = workspace.nestComponentGroup(groupID, in: nil)
      }
      .disabled(workspace.componentGroup(id: groupID)?.parentGroupID == nil)
      Divider()
      Button("Ungroup", systemImage: "folder.badge.minus", role: .destructive) {
        workspace.dissolveComponentGroup(id: groupID)
      }
    }
  }

  // MARK: Interaction

  private func select(_ item: AssemblyItem) {
    if let partID = item.partID {
      workspace.selectPart(id: partID, extendingSelection: false)
    } else if let groupID = item.groupID {
      workspace.selection = [.componentGroup(groupID)]
      expanded.insert(item.id)
    } else if !item.children.isEmpty {
      if expanded.contains(item.id) {
        expanded.remove(item.id)
      } else {
        expanded.insert(item.id)
      }
    }
  }

  private func toggleVisibility(_ item: AssemblyItem) {
    if let groupID = item.groupID {
      workspace.setComponentGroupHidden(groupID, hidden: !workspace.isComponentGroupHidden(groupID))
    } else if let partID = item.partID {
      workspace.toggleComponentVisibility(partID)
    } else {
      guard let geometry = item.referenceGeometry else { return }
      workspace.toggleCADReferenceGeometry(geometry)
    }
  }

  private func isItemHidden(_ item: AssemblyItem) -> Bool {
    if let groupID = item.groupID {
      return workspace.isComponentGroupHidden(groupID)
    }
    if let partID = item.partID {
      return workspace.isComponentHidden(partID)
    }
    guard let geometry = item.referenceGeometry else { return false }
    return !workspace.cadReferenceGeometryVisibility.contains(geometry)
  }

  private func beginRename(_ partID: PartID) {
    workspace.selectPart(id: partID, extendingSelection: false)
    workspace.requestNavigatorReveal(.part(partID))
  }

  private func beginGroupRename(_ groupID: UUID) {
    // Reuse the model's rename entry point; the navigator alert handles input.
    workspace.requestNavigatorReveal(.componentGroup(groupID))
  }

  private func expandAll() {
    expanded = Set(allRows(items).map(\.item.id))
  }

  private func iconColor(_ item: AssemblyItem, hidden: Bool, selected: Bool) -> Color {
    if hidden { return .secondary.opacity(0.5) }
    if selected { return StudioPalette.accent }
    switch item.kind {
    case .part: return StudioPalette.sourceModel
    case .group, .section: return .secondary
    case .mate: return StudioPalette.hardware
    case .origin, .plane: return .secondary
    }
  }

  // MARK: Model → items

  private var items: [AssemblyItem] {
    var roots: [AssemblyItem] = []

    roots.append(
      AssemblyItem(
        id: "ref", kind: .section, title: "Reference Geometry", systemImage: "scale.3d",
        children: [
          AssemblyItem(
            id: "ref.origin", kind: .origin, title: "Origin", systemImage: "circle.circle",
            referenceGeometry: .origin, canToggleVisibility: true),
          AssemblyItem(
            id: "ref.front", kind: .plane, title: "Front Plane",
            systemImage: "square.dashed", referenceGeometry: .frontPlane,
            canToggleVisibility: true),
          AssemblyItem(
            id: "ref.top", kind: .plane, title: "Top Plane",
            systemImage: "square.dashed", referenceGeometry: .topPlane,
            canToggleVisibility: true),
          AssemblyItem(
            id: "ref.right", kind: .plane, title: "Right Plane",
            systemImage: "square.dashed", referenceGeometry: .rightPlane,
            canToggleVisibility: true),
        ]))

    let groupedIDs = Set(workspace.componentGroups.flatMap(\.componentIDs))
    roots.append(contentsOf: workspace.rootComponentGroups.map(groupItem))

    for enginePart in workspace.engineParts {
      guard let partID = workspace.partID(forEngineName: enginePart.name),
        !groupedIDs.contains(partID)
      else { continue }
      roots.append(partItem(enginePart, id: partID))
    }

    if !workspace.engineMates.isEmpty {
      roots.append(
        AssemblyItem(
          id: "mates", kind: .section, title: "Mates", systemImage: "link",
          children: workspace.engineMates.map { mate in
            AssemblyItem(
              id: "mate:\(mate.selectionKey)", kind: .mate,
              title: mate.id.isEmpty ? mate.name : mate.id,
              subtitle: mateTypeLabel(mate.type), systemImage: "link")
          }))
    }

    return roots
  }

  private func groupItem(_ group: NavigatorComponentGroup) -> AssemblyItem {
    let childGroups = workspace.childComponentGroups(of: group.id).map(groupItem)
    let childParts = group.componentIDs.compactMap(partItem(for:))
    return AssemblyItem(
      id: "group:\(group.id)",
      kind: .group,
      title: group.displayName,
      systemImage: "shippingbox",
      isGrounded: workspace.isComponentGroupGrounded(group.id),
      isLocked: workspace.isComponentGroupLocked(group.id),
      groupID: group.id,
      canToggleVisibility: true,
      children: childGroups + childParts)
  }

  private func partItem(for id: PartID) -> AssemblyItem? {
    guard let enginePart = workspace.enginePart(for: id) else { return nil }
    return partItem(enginePart, id: id)
  }

  private func partItem(_ enginePart: AnimaCorePartSummary, id: PartID) -> AssemblyItem {
    AssemblyItem(
      id: "part:\(id.rawValue.uuidString)", kind: .part, title: enginePart.name,
      systemImage: "cube",
      isGrounded: enginePart.isGrounded,
      isLocked: workspace.isComponentLocked(id),
      partID: id,
      canToggleVisibility: true)
  }

  private func mateTypeLabel(_ raw: String) -> String {
    raw.replacingOccurrences(of: "_", with: " ").capitalized
  }

  // MARK: Flatten (with filter)

  private struct FlatRow: Identifiable {
    let item: AssemblyItem
    let depth: Int
    var id: String { item.id }
  }

  private var visibleRows: [FlatRow] {
    let needle = filterText.trimmingCharacters(in: .whitespaces).lowercased()
    let source = needle.isEmpty ? items : items.compactMap { filtered($0, needle: needle) }
    return flatten(source, depth: 0, forceExpanded: !needle.isEmpty)
  }

  private func filtered(_ item: AssemblyItem, needle: String) -> AssemblyItem? {
    let keptChildren = item.children.compactMap { filtered($0, needle: needle) }
    if item.title.lowercased().contains(needle) || !keptChildren.isEmpty {
      var copy = item
      copy.children = keptChildren
      return copy
    }
    return nil
  }

  private func flatten(_ items: [AssemblyItem], depth: Int, forceExpanded: Bool) -> [FlatRow] {
    items.flatMap { item -> [FlatRow] in
      var rows = [FlatRow(item: item, depth: depth)]
      if !item.children.isEmpty, forceExpanded || expanded.contains(item.id) {
        rows.append(
          contentsOf: flatten(item.children, depth: depth + 1, forceExpanded: forceExpanded))
      }
      return rows
    }
  }

  private func allRows(_ items: [AssemblyItem]) -> [FlatRow] {
    items.flatMap { [FlatRow(item: $0, depth: 0)] + allRows($0.children) }
  }
}

struct AssemblyItem: Identifiable, Equatable {
  enum Kind: Equatable { case section, origin, plane, part, group, mate }

  let id: String
  let kind: Kind
  var title: String
  var subtitle: String? = nil
  var systemImage: String
  var isGrounded: Bool = false
  var isLocked: Bool = false
  var partID: PartID? = nil
  var groupID: UUID? = nil
  var referenceGeometry: CADReferenceGeometry? = nil
  var canToggleVisibility: Bool = false
  var children: [AssemblyItem] = []
}
