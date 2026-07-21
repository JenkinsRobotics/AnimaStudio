// One canonical row for every file-tree / browser panel — the character tree,
// parts, bodies, mates, documents, the Design browser. Fusion-browser layout:
//   [disclosure chevron] [visibility eye] [type icon] [name] ........ [count]
// Every list uses this so they stay visually and behaviourally identical; only
// the data differs.
import SwiftUI

struct TreeRow: View {
  var depth: Int = 0
  var icon: String
  var title: String
  /// Trailing count (folders) or short detail (leaf rows). Only one shows.
  var count: Int? = nil
  var detail: String? = nil

  var expandable: Bool = false
  var expanded: Bool = false
  var selected: Bool = false
  /// Dimmed like Fusion's reference planes / inactive rows.
  var muted: Bool = false
  var bold: Bool = false

  /// Visibility eye — shown only when a toggle is provided.
  var visible: Bool = true
  var onToggleVisible: (() -> Void)? = nil

  var onToggleExpand: (() -> Void)? = nil
  var onTap: (() -> Void)? = nil

  @State private var hovering = false

  private var tint: Color { selected ? UI.accent : (muted ? UI.text3 : UI.accent2) }

  var body: some View {
    HStack(spacing: 5) {
      // Disclosure chevron (reserves space even when not expandable, for alignment).
      Group {
        if expandable {
          Button { (onToggleExpand ?? onTap ?? {})() } label: {
            Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
              .foregroundStyle(UI.text3).rotationEffect(.degrees(expanded ? 90 : 0))
          }.buttonStyle(.plain)
        }
      }
      .frame(width: 12)

      // Visibility eye (optional).
      if let onToggleVisible {
        Button { onToggleVisible() } label: {
          Image(systemName: visible ? "eye" : "eye.slash")
            .font(.system(size: 10))
            .foregroundStyle(visible ? UI.text3 : UI.text3.opacity(0.45))
        }
        .buttonStyle(.plain)
        .frame(width: 16)
        .opacity(visible || hovering || selected ? 1 : 0.55)
      }

      Image(systemName: icon).font(.system(size: 12))
        .foregroundStyle(muted ? UI.text3 : tint).frame(width: 16)

      Text(title)
        .font(.system(size: 12, weight: bold || selected ? .semibold : .regular))
        .foregroundStyle(muted ? UI.text3 : (selected ? UI.text : UI.text2))
        .lineLimit(1)

      Spacer(minLength: 6)

      if let count {
        Text("\(count)").font(.system(size: 11)).foregroundStyle(UI.text3)
      } else if let detail {
        Text(detail).font(.system(size: 10)).foregroundStyle(UI.text3)
      }
    }
    .padding(.leading, CGFloat(depth) * 15 + 10).padding(.trailing, 12)
    .frame(height: 28)
    .background(selected ? UI.accent.opacity(0.16) : (hovering ? UI.text.opacity(0.04) : .clear))
    .overlay(alignment: .leading) {
      if selected { Rectangle().fill(UI.accent).frame(width: 2) }
    }
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
    .onTapGesture { (onTap ?? {})() }
  }
}
