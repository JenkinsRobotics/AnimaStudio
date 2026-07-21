import SwiftUI

// MARK: - Demo design-system primitives (additive, namespaced)

struct DemoKitPanelCard<Content: View>: View {
  let title: String
  let subtitle: String
  @ViewBuilder let content: Content

  init(_ title: String, subtitle: String = "", @ViewBuilder content: () -> Content) {
    self.title = title
    self.subtitle = subtitle
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        VStack(alignment: .leading, spacing: 1) {
          Text(title.uppercased()).font(.caption2.weight(.bold)).tracking(0.6)
          if !subtitle.isEmpty {
            Text(subtitle).font(.caption2).foregroundStyle(StudioPalette.muted)
          }
        }
        Spacer()
        Image(systemName: "ellipsis").foregroundStyle(StudioPalette.muted)
      }
      .padding(11)
      Divider().overlay(StudioPalette.border)
      content.padding(11)
    }
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 13))
    .overlay(RoundedRectangle(cornerRadius: 13).stroke(StudioPalette.border))
  }
}

struct DemoKitListRow: View {
  let icon: String
  let title: String
  var detail = ""
  var selected = false
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon).frame(width: 18).foregroundStyle(
        selected ? .white : StudioPalette.accent)
      Text(title).lineLimit(1)
      Spacer()
      Text(detail).font(.caption.monospaced()).foregroundStyle(
        selected ? .white.opacity(0.8) : StudioPalette.muted)
    }
    .font(.caption)
    .padding(.horizontal, 9).frame(height: 30)
    .background(
      selected ? StudioPalette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 7))
  }
}

struct DemoKitPanelAction: View {
  let icon: String
  let label: String
  var body: some View {
    Label(label, systemImage: icon)
      .font(.caption.weight(.medium))
      .foregroundStyle(Color.primary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 8))
  }
}

struct DemoKitRow: View {
  let icon: String
  let label: String
  let value: String
  var body: some View {
    HStack {
      Label(label, systemImage: icon)
      Spacer()
      Text(value).foregroundStyle(StudioPalette.muted)
    }
    .font(.caption).padding(.vertical, 5)
  }
}

struct DemoKitField: View {
  let label: String
  let value: String
  var unit = ""
  var body: some View {
    HStack {
      Text(label).foregroundStyle(StudioPalette.muted)
      Spacer()
      Text(value).monospacedDigit()
      if !unit.isEmpty { Text(unit).foregroundStyle(StudioPalette.muted) }
    }
    .font(.caption).padding(.horizontal, 9).frame(height: 28)
    .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 7))
  }
}

struct DemoKitPanel<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content
  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }
  var body: some View { DemoKitPanelCard(title) { content } }
}

struct DemoKitTreeRow: View {
  let depth: Int
  let icon: String
  let title: String
  var expanded = false
  var body: some View {
    HStack(spacing: 6) {
      Color.clear.frame(width: CGFloat(depth) * 13)
      Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.system(size: 8))
      Image(systemName: icon).foregroundStyle(StudioPalette.accent)
      Text(title)
      Spacer()
      Image(systemName: "eye").foregroundStyle(StudioPalette.muted)
    }.font(.caption).frame(height: 28)
  }
}

struct DemoKitPill: View {
  let text: String
  var tint = StudioPalette.accent
  var body: some View {
    Text(text).font(.caption2.weight(.bold)).foregroundStyle(tint)
      .padding(.horizontal, 8).padding(.vertical, 4).background(tint.opacity(0.15), in: Capsule())
  }
}

struct DemoKitStageChip: View {
  let icon: String
  let title: String
  var selected = false
  var body: some View {
    Label(title, systemImage: icon).font(.caption.weight(.semibold))
      .foregroundStyle(selected ? .white : StudioPalette.muted)
      .padding(.horizontal, 11).frame(height: 30)
      .background(selected ? StudioPalette.accent : Color.clear, in: Capsule())
  }
}

struct DemoKitChipPicker: View {
  @Binding var selection: String
  let values: [String]
  var body: some View {
    HStack(spacing: 5) {
      ForEach(values, id: \.self) { value in
        Button(value) { selection = value }
          .buttonStyle(.plain).font(.caption)
          .padding(.horizontal, 8).padding(.vertical, 5)
          .background(
            selection == value ? StudioPalette.accent : StudioPalette.panelInset, in: Capsule()
          )
          .foregroundStyle(selection == value ? .white : Color.primary)
      }
    }
  }
}

struct DemoKitSegmentedIcons: View {
  let icons: [String]
  @Binding var selection: Int
  var body: some View {
    HStack(spacing: 2) {
      ForEach(icons.indices, id: \.self) { index in
        Button {
          selection = index
        } label: {
          Image(systemName: icons[index]).frame(width: 28, height: 26)
            .background(
              selection == index ? StudioPalette.accent : Color.clear,
              in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain)
      }
    }.padding(3).background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 8))
  }
}

struct DemoKitToggleRow: View {
  let title: String
  @Binding var value: Bool
  var body: some View {
    Toggle(title, isOn: $value).font(.caption).toggleStyle(.switch).controlSize(.mini)
  }
}

struct DemoKitCommandButton: View {
  let icon: String
  let title: String
  var tint = StudioPalette.accent
  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: icon).font(.title3)
      Text(title).font(.caption2)
    }
    .foregroundStyle(tint).frame(width: 64, height: 58)
    .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 10))
  }
}

struct DemoKitToolCluster: View {
  let title: String
  let tools: [(String, String)]
  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        ForEach(Array(tools.enumerated()), id: \.offset) { _, tool in
          DemoKitCommandButton(icon: tool.0, title: tool.1)
        }
      }
      Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(StudioPalette.muted)
    }
  }
}

struct DemoKitCallout: View {
  let title: String
  let detail: String
  var body: some View {
    HStack(alignment: .top, spacing: 9) {
      Image(systemName: "info.circle.fill").foregroundStyle(StudioPalette.accent)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.caption.weight(.semibold))
        Text(detail).font(.caption2).foregroundStyle(StudioPalette.muted)
      }
    }.padding(10).background(
      StudioPalette.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
  }
}

struct DemoKitMetricCard: View {
  let label: String
  let value: String
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(label.uppercased()).font(.caption2).foregroundStyle(StudioPalette.muted)
      Text(value).font(.title3.monospacedDigit().weight(.semibold))
    }
    .padding(11).frame(minWidth: 105, alignment: .leading).background(
      StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 10))
  }
}

struct DemoKitNotificationCard: View {
  var body: some View {
    DemoKitPanelCard("Connect multiple devices", subtitle: "New in v0.2") {
      DemoKitCallout(
        title: "Hardware discovered", detail: "Two controllers are ready to configure.")
    }
  }
}

struct DemoKitDialogCard: View {
  var body: some View {
    DemoKitPanelCard("Delete selected mate?") {
      HStack {
        Spacer()
        Button("Cancel") {}
        Button("Delete", role: .destructive) {}
      }
    }
  }
}

struct DemoKitToast: View {
  let text: String
  var body: some View {
    Label(text, systemImage: "checkmark.circle.fill").font(.caption).padding(10).background(
      .regularMaterial, in: Capsule())
  }
}

struct DemoKitProgressCard: View {
  let progress: Double
  var body: some View {
    DemoKitPanelCard("Importing assembly", subtitle: "Triangulating CAD faces") {
      ProgressView(value: progress)
    }
  }
}
