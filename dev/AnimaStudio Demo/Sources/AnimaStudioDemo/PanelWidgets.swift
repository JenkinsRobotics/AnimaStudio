// Panel + list-row widgets ported from CodexUI (PrototypePanel / PrototypeRow),
// restyled with our UI.* tokens. PanelCard adds the icon badge, subtitle, and
// overflow menu our plain Panel lacks; ListRow uses solid-accent selection.
import SwiftUI

struct PanelCard<Content: View>: View {
  let title: String
  var subtitle: String? = nil
  var icon: String? = nil
  var tint: Color = UI.accent
  var onMenu: (() -> Void)? = nil
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 9) {
        if let icon {
          Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(tint)
            .frame(width: 26, height: 26)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
        }
        VStack(alignment: .leading, spacing: 1) {
          Text(title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.4)
            .foregroundStyle(UI.text)
          if let subtitle {
            Text(subtitle.uppercased()).font(.system(size: 8.5, weight: .medium)).tracking(0.4)
              .foregroundStyle(UI.text3)
          }
        }
        Spacer(minLength: 6)
        Button { onMenu?() } label: {
          Image(systemName: "ellipsis").font(.system(size: 11, weight: .semibold))
            .foregroundStyle(UI.text2)
            .frame(width: 26, height: 22)
            .background(UI.panelHi, in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain)
      }
      .padding(.horizontal, 12).frame(height: subtitle == nil ? 44 : 54)
      Divider().overlay(UI.stroke)
      content()
    }
    .background(UI.panel)
    .clipShape(RoundedRectangle(cornerRadius: UI.radius, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: UI.radius, style: .continuous).stroke(UI.stroke, lineWidth: 1))
  }
}

// List row with solid-accent selection, optional indent, trailing detail and
// status dot. (CodexUI PrototypeRow.)
struct ListRow: View {
  let icon: String
  let title: String
  var detail: String? = nil
  var level: Int = 0
  var selected = false
  var statusColor: Color? = nil
  var onTap: () -> Void = {}

  var body: some View {
    HStack(spacing: 8) {
      if level > 0 { Color.clear.frame(width: CGFloat(level) * 13, height: 1) }
      Image(systemName: icon).font(.system(size: 10.5, weight: .medium)).frame(width: 17)
        .foregroundStyle(selected ? .white : UI.text2)
      Text(title).font(.system(size: 11.5, weight: selected ? .semibold : .regular)).lineLimit(1)
        .foregroundStyle(selected ? .white : UI.text)
      Spacer(minLength: 6)
      if let detail {
        Text(detail).font(.system(size: 9.5, design: .rounded))
          .foregroundStyle(selected ? .white.opacity(0.85) : UI.text3)
      }
      if let statusColor { Circle().fill(statusColor).frame(width: 6, height: 6) }
    }
    .padding(.horizontal, 11).padding(.vertical, 8)
    .background(selected ? UI.accent : .clear)
    .contentShape(Rectangle())
    .onTapGesture { onTap() }
  }
}

// Small footer action button used under panel lists ("+ Clip", duplicate…).
struct PanelAction: View {
  var icon: String? = nil
  var label: String? = nil
  var action: () -> Void = {}
  var body: some View {
    Button(action: action) {
      HStack(spacing: 5) {
        if let icon { Image(systemName: icon).font(.system(size: 10.5, weight: .semibold)) }
        if let label { Text(label).font(.system(size: 11, weight: .medium)) }
      }
      .foregroundStyle(UI.text)
      .padding(.horizontal, label == nil ? 8 : 11).frame(height: 28)
      .background(UI.panelHi, in: RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(UI.stroke, lineWidth: 1))
    }.buttonStyle(.plain)
  }
}
