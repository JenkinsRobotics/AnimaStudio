import SwiftUI

/// A left-sidebar panel scoped to a single character collection (Parts, Source
/// Assets, Renders, Assemblies, Scripts, Animations). The "Characters" rail tab
/// still shows the full character profile; each collection rail tab opens only
/// its own file list through this view.
struct AssetCollectionSidebarPanel: View {
  let collection: AssetBuilderCollection
  let items: [AssetBuilderListItem]

  @State private var filterText = ""
  @State private var showSearch = false

  private var filtered: [AssetBuilderListItem] {
    guard !filterText.isEmpty else { return items }
    return items.filter {
      $0.title.localizedCaseInsensitiveContains(filterText)
        || $0.detail.localizedCaseInsensitiveContains(filterText)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      if showSearch { searchField }
      Divider()
      if filtered.isEmpty {
        emptyState
      } else {
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(filtered) { item in row(item) }
          }
          .padding(8)
        }
      }
    }
    .background(StudioPalette.panel)
  }

  private var header: some View {
    HStack(spacing: 7) {
      Image(systemName: collection.systemImage)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(StudioPalette.accent)
        .frame(width: 16)
      Text(collection.title.uppercased())
        .font(.system(size: 10.5, weight: .semibold))
        .tracking(0.6)
        .lineLimit(1)
      if !items.isEmpty {
        Text("\(items.count)")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 5)
          .padding(.vertical, 1)
          .background(StudioPalette.field, in: Capsule())
      }
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
      .help("Search \(collection.title)")
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

  private func row(_ item: AssetBuilderListItem) -> some View {
    HStack(spacing: 8) {
      Image(systemName: item.systemImage)
        .font(.caption)
        .frame(width: 16)
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 1) {
        Text(item.title).font(.callout).lineLimit(1)
        if !item.detail.isEmpty {
          Text(item.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      Spacer(minLength: 6)
      if !item.badge.isEmpty {
        Text(item.badge)
          .font(.system(size: 8.5, weight: .semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 5)
          .padding(.vertical, 1)
          .background(StudioPalette.field, in: Capsule())
      }
    }
    .padding(.horizontal, 8)
    .frame(minHeight: 30, alignment: .leading)
    .contentShape(Rectangle())
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: collection.systemImage)
        .font(.title2)
        .foregroundStyle(.secondary)
      Text("No \(collection.title.lowercased()) yet")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(24)
  }
}
