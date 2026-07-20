// Reusable widget library — components ported/adapted from CodexUI (and a few
// new ones), styled with our UI.* tokens. Not wired into the main app yet; they
// live here (and in the UI Kit gallery) ready for future use.
import SwiftUI

// Status badge — text in a tinted capsule. (CodexUI LabelPill.)
struct Badge: View {
  let text: String
  var tint: Color = UI.text3
  var body: some View {
    Text(text.uppercased())
      .font(.system(size: 8.5, weight: .semibold)).tracking(0.5)
      .foregroundStyle(tint)
      .padding(.horizontal, 7).padding(.vertical, 3)
      .background(tint.opacity(0.14), in: Capsule())
      .overlay(Capsule().stroke(tint.opacity(0.28), lineWidth: 1))
  }
}

// KPI / metric card — label, big value, caption. (CodexUI MetricCard.)
struct MetricCard: View {
  let title: String
  let value: String
  var caption: String? = nil
  var tint: Color = UI.accent
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.5).foregroundStyle(tint)
      Text(value).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(UI.text)
      if let caption { Text(caption).font(.system(size: 9.5)).foregroundStyle(UI.text3) }
    }
    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
    .background(UI.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(UI.stroke, lineWidth: 1))
  }
}

// Labeled slider row — label + slider + monospaced readout.
struct LabeledSlider: View {
  let label: String
  @Binding var value: Double
  var range: ClosedRange<Double> = 0...1
  var unit: String = ""
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(label).font(.system(size: 11)).foregroundStyle(UI.text2)
        Spacer()
        Text(String(format: "%.2f", value) + unit)
          .font(.system(size: 10, design: .monospaced)).foregroundStyle(UI.text3)
      }
      Slider(value: $value, in: range).tint(UI.accent)
    }
  }
}

// Segmented icon control — theme-styled, single select.
struct SegmentedIcons: View {
  let items: [(icon: String, help: String)]
  @Binding var selection: Int
  var body: some View {
    HStack(spacing: 2) {
      ForEach(Array(items.enumerated()), id: \.offset) { i, item in
        Button { selection = i } label: {
          Image(systemName: item.icon).font(.system(size: 12, weight: .medium))
            .foregroundStyle(selection == i ? .white : UI.text2)
            .frame(width: 30, height: 26)
            .background(selection == i ? UI.accent : .clear, in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).help(item.help)
      }
    }
    .padding(3).background(UI.panelHi, in: RoundedRectangle(cornerRadius: 9))
    .overlay(RoundedRectangle(cornerRadius: 9).stroke(UI.stroke, lineWidth: 1))
  }
}

// Icon tool cluster — vertical/horizontal group of labeled tool buttons
// (e.g. selection tools). Inspired by CodexUI's spatial selection specimen.
struct ToolCluster: View {
  let tools: [(icon: String, label: String)]
  var axis: Axis = .vertical
  @State private var selected = 0
  var body: some View {
    let layout = axis == .vertical
      ? AnyLayout(VStackLayout(spacing: 3)) : AnyLayout(HStackLayout(spacing: 3))
    layout {
      ForEach(Array(tools.enumerated()), id: \.offset) { i, t in
        Button { selected = i } label: {
          VStack(spacing: 2) {
            Image(systemName: t.icon).font(.system(size: 14, weight: .medium))
            Text(t.label).font(.system(size: 8, weight: .medium))
          }
          .foregroundStyle(selected == i ? UI.accent : UI.text2)
          .frame(width: 52, height: 42)
          .background(selected == i ? UI.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).help(t.label)
      }
    }
    .padding(5).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(UI.stroke, lineWidth: 1))
  }
}

// Inline notification / toast banner.
struct Toast: View {
  var icon: String = "info.circle.fill"
  let message: String
  var tint: Color = UI.accent
  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: icon).font(.system(size: 12)).foregroundStyle(tint)
      Text(message).font(.system(size: 11.5)).foregroundStyle(UI.text)
      Spacer(minLength: 8)
    }
    .padding(.horizontal, 12).padding(.vertical, 9)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.35), lineWidth: 1))
    .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
  }
}

// Info callout box — icon + title + message.
struct Callout: View {
  var icon: String = "lightbulb"
  let title: String
  let message: String
  var tint: Color = UI.accent2
  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: icon).font(.system(size: 13)).foregroundStyle(tint).frame(width: 18)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(UI.text)
        Text(message).font(.system(size: 11)).foregroundStyle(UI.text2)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
    .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.28), lineWidth: 1))
  }
}

// Labeled toggle row.
struct ToggleRow: View {
  let label: String
  @Binding var isOn: Bool
  var body: some View {
    HStack {
      Text(label).font(.system(size: 11.5)).foregroundStyle(UI.text2)
      Spacer()
      Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(UI.accent)
    }
  }
}

// Determinate progress bar.
struct ProgressBar: View {
  var value: Double   // 0...1
  var tint: Color = UI.accent
  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(UI.panelHi)
        Capsule().fill(tint).frame(width: geo.size.width * max(0, min(1, value)))
      }
    }.frame(height: 6)
  }
}

// Boxed numeric property field — label + value + unit in a bordered box
// (Onshape-style input). Distinct from Field, which is a plain row. (CodexUI PropertyField.)
struct PropertyField: View {
  let label: String
  var value: String
  var unit: String? = nil
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label).font(.system(size: 9.5)).foregroundStyle(UI.text3)
      HStack {
        Text(value).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(UI.text)
        Spacer(minLength: 8)
        if let unit { Text(unit).font(.system(size: 9.5)).foregroundStyle(UI.text3) }
      }
      .padding(.horizontal, 10).padding(.vertical, 7)
      .background(UI.inset, in: RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(UI.stroke, lineWidth: 1))
    }
  }
}

// Icon command button with an active state. (CodexUI ChromeIconButtonStyle.)
struct CommandButton: View {
  let icon: String
  var active = false
  var action: () -> Void = {}
  var body: some View {
    Button(action: action) {
      Image(systemName: icon).font(.system(size: 12))
        .foregroundStyle(active ? UI.accent : UI.text2)
        .frame(width: 28, height: 24)
        .background(active ? UI.accent.opacity(0.14) : UI.panel, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(active ? UI.accent.opacity(0.4) : .clear, lineWidth: 1))
    }.buttonStyle(.plain)
  }
}

// Rich non-blocking notification — icon, title, message, action + timestamp, dismiss.
struct NotificationCard: View {
  var icon = "checkmark.circle.fill"
  let title: String
  let message: String
  var action: String? = nil
  var timestamp = "Just now"
  var tint: Color = UI.ok
  var onDismiss: () -> Void = {}
  var body: some View {
    VStack(spacing: 10) {
      HStack(alignment: .top, spacing: 9) {
        Image(systemName: icon).font(.system(size: 13)).foregroundStyle(tint)
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(UI.text)
          Text(message).font(.system(size: 10)).foregroundStyle(UI.text3)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Button(action: onDismiss) {
          Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(UI.text3)
        }.buttonStyle(.plain)
      }
      Divider().overlay(UI.stroke)
      HStack {
        if let action {
          Text(action).font(.system(size: 10.5, weight: .medium)).foregroundStyle(UI.accent)
        }
        Spacer()
        Text(timestamp).font(.system(size: 8.5)).foregroundStyle(UI.text3)
      }
    }
    .padding(12).frame(width: 260)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(UI.stroke, lineWidth: 1))
    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
  }
}

// Modal dialog card — header, content, and Cancel/Confirm actions. (CodexUI mate dialog.)
struct DialogCard<Content: View>: View {
  let title: String
  var subtitle: String? = nil
  var icon: String? = nil
  var confirmLabel = "Create"
  var onCancel: () -> Void = {}
  var onConfirm: () -> Void = {}
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        if let icon {
          Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(UI.accent)
        }
        VStack(alignment: .leading, spacing: 1) {
          Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(UI.text)
          if let subtitle {
            Text(subtitle.uppercased()).font(.system(size: 8.5, weight: .semibold)).tracking(0.5)
              .foregroundStyle(UI.text3)
          }
        }
        Spacer()
      }
      .padding(.horizontal, 14).padding(.vertical, 11)
      Divider().overlay(UI.stroke)
      VStack(alignment: .leading, spacing: 9) { content() }.padding(14)
      Divider().overlay(UI.stroke)
      HStack(spacing: 8) {
        Spacer()
        Button(action: onCancel) {
          Text("Cancel").font(.system(size: 12)).foregroundStyle(UI.text2)
            .padding(.horizontal, 14).padding(.vertical, 7).background(UI.panelHi, in: Capsule())
        }.buttonStyle(.plain)
        Button(action: onConfirm) {
          Text(confirmLabel).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 7).background(UI.accent, in: Capsule())
        }.buttonStyle(.plain)
      }
      .padding(14)
    }
    .frame(width: 300)
    .background(UI.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(UI.stroke, lineWidth: 1))
    .shadow(color: .black.opacity(0.28), radius: 26, y: 12)
  }
}

// Closable document tab strip with an active underline.
struct DocumentTabs: View {
  let tabs: [String]
  @Binding var selection: Int
  var body: some View {
    HStack(spacing: 2) {
      ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
        Button { selection = i } label: {
          HStack(spacing: 7) {
            Text(t).font(.system(size: 11, weight: selection == i ? .semibold : .regular))
            Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(UI.text3)
          }
          .foregroundStyle(selection == i ? UI.text : UI.text2)
          .padding(.horizontal, 12).frame(height: 30)
          .background(selection == i ? UI.panelHi : .clear)
          .overlay(alignment: .bottom) { Rectangle().fill(selection == i ? UI.accent : .clear).frame(height: 2) }
        }.buttonStyle(.plain)
      }
    }
    .background(UI.panel.opacity(0.5))
  }
}

// Segmented value chip strip — quick-pick options (e.g. FPS, units).
struct ChipPicker: View {
  let options: [String]
  @Binding var selection: String
  var body: some View {
    HStack(spacing: 6) {
      ForEach(options, id: \.self) { opt in
        Button { selection = opt } label: {
          Text(opt).font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(selection == opt ? .white : UI.text2)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(selection == opt ? UI.accent : UI.panelHi, in: Capsule())
        }.buttonStyle(.plain)
      }
    }
  }
}
