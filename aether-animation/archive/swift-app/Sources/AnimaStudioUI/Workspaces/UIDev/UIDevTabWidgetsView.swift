import SwiftUI

enum UIDevPreviewTheme: String, CaseIterable, Identifiable, Sendable {
  case light
  case dark

  var id: Self { self }

  var title: String { rawValue.capitalized }

  var systemImage: String {
    switch self {
    case .light: "sun.max.fill"
    case .dark: "moon.fill"
    }
  }

  var background: Color {
    switch self {
    case .light: Color(red: 0.92, green: 0.91, blue: 0.93)
    case .dark: Color(red: 0.12, green: 0.10, blue: 0.13)
    }
  }

  var control: Color {
    switch self {
    case .light: .white.opacity(0.86)
    case .dark: Color(red: 0.22, green: 0.19, blue: 0.23)
    }
  }

  var foreground: Color {
    switch self {
    case .light: Color(red: 0.12, green: 0.11, blue: 0.13)
    case .dark: .white
    }
  }
}

struct UIDevCompactTabPanelWidget: View {
  @State private var theme: UIDevPreviewTheme = .dark
  @State private var selectedAction = "query"
  @State private var queryCount = 0

  var body: some View {
    VStack(spacing: 12) {
      commandButton(
        id: "query",
        title: "New Query",
        shortcut: "⌘N",
        systemImage: "plus",
        isPrimary: true
      ) {
        selectedAction = "query"
        queryCount += 1
      }

      commandButton(
        id: "settings",
        title: "Settings",
        shortcut: "⌘S",
        systemImage: "gearshape.fill",
        isPrimary: false
      ) {
        selectedAction = "settings"
      }

      HStack(spacing: 4) {
        ForEach(UIDevPreviewTheme.allCases) { option in
          Button {
            withAnimation(.easeOut(duration: 0.16)) {
              theme = option
            }
          } label: {
            Label(option.title, systemImage: option.systemImage)
              .font(.callout.weight(.semibold))
              .frame(maxWidth: .infinity)
              .frame(height: 34)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .foregroundStyle(theme.foreground)
          .background(
            theme == option ? theme.control : Color.clear,
            in: RoundedRectangle(cornerRadius: 7)
          )
          .accessibilityAddTraits(theme == option ? .isSelected : [])
        }
      }
      .padding(4)
      .background(theme.control.opacity(0.72), in: RoundedRectangle(cornerRadius: 9))

      Text(queryCount == 0 ? "Commands are interactive" : "Created query \(queryCount)")
        .font(.caption2.monospaced())
        .foregroundStyle(theme.foreground.opacity(0.58))
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(14)
    .frame(maxWidth: 330)
    .background(theme.background, in: RoundedRectangle(cornerRadius: 13))
    .overlay {
      RoundedRectangle(cornerRadius: 13)
        .stroke(Color.white.opacity(theme == .dark ? 0.12 : 0.65), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
    .animation(.easeOut(duration: 0.16), value: theme)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Compact action and theme panel prototype")
  }

  private func commandButton(
    id: String,
    title: String,
    shortcut: String,
    systemImage: String,
    isPrimary: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Image(systemName: systemImage)
          .frame(width: 18)
        Spacer()
        Text(shortcut)
          .font(.caption.monospaced())
          .opacity(0.5)
      }
      .overlay {
        Text(title)
          .font(.callout.weight(.semibold))
      }
      .padding(.horizontal, 12)
      .frame(height: 39)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(isPrimary ? Color.white : theme.foreground)
    .background(
      isPrimary ? StudioPalette.accent : theme.control,
      in: RoundedRectangle(cornerRadius: 8)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(
          selectedAction == id ? Color.white.opacity(isPrimary ? 0.34 : 0.2) : Color.clear,
          lineWidth: 1
        )
    }
    .shadow(color: .black.opacity(isPrimary ? 0.16 : 0.08), radius: 3, y: 2)
    .accessibilityLabel("\(title), shortcut \(shortcut)")
  }
}

struct UIDevDocumentTab: Identifiable, Equatable, Sendable {
  let id: String
  var title: String

  static let samples = [
    UIDevDocumentTab(id: "addresses", title: "db1_addresses"),
    UIDevDocumentTab(id: "archive", title: "db1_archive"),
    UIDevDocumentTab(id: "books", title: "db1_books"),
    UIDevDocumentTab(id: "urgent", title: "db1_urgent"),
  ]
}

struct UIDevDocumentTabStripWidget: View {
  @State private var tabs = UIDevDocumentTab.samples
  @State private var selectedID = UIDevDocumentTab.samples[0].id
  @State private var nextUntitledNumber = 1
  @State private var hoveredID: String?

  var body: some View {
    HStack(spacing: 0) {
      trafficLights
        .frame(width: 124)

      Divider()
        .overlay(Color.white.opacity(0.05))

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 0) {
          ForEach(tabs) { tab in
            documentTab(tab)
          }

          Button(action: addTab) {
            Image(systemName: "plus")
              .font(.system(size: 13, weight: .medium))
              .frame(width: 46, height: 48)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .foregroundStyle(Color.white.opacity(0.62))
          .help("New tab")
          .accessibilityLabel("New document tab")
        }
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 54)
    .background(
      LinearGradient(
        colors: [
          Color(red: 0.10, green: 0.08, blue: 0.11),
          Color(red: 0.05, green: 0.14, blue: 0.19),
        ],
        startPoint: .leading,
        endPoint: .trailing
      ),
      in: RoundedRectangle(cornerRadius: 12)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.white.opacity(0.10), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.24), radius: 9, y: 4)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Multi-document tab strip prototype")
  }

  private var trafficLights: some View {
    HStack(spacing: 9) {
      Circle().fill(Color(red: 1.0, green: 0.32, blue: 0.30))
        .frame(width: 12, height: 12)
      Circle().fill(Color(red: 1.0, green: 0.75, blue: 0.20))
        .frame(width: 12, height: 12)
      Circle().fill(Color(red: 0.23, green: 0.78, blue: 0.35))
        .frame(width: 12, height: 12)
    }
    .frame(width: 50)
    .padding(.horizontal, 20)
    .accessibilityHidden(true)
  }

  private func documentTab(_ tab: UIDevDocumentTab) -> some View {
    let isSelected = selectedID == tab.id
    let isHovered = hoveredID == tab.id

    return HStack(spacing: 7) {
      Button {
        selectedID = tab.id
      } label: {
        Text(tab.title)
          .font(.system(size: 12, weight: isSelected ? .medium : .regular))
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button {
        closeTab(tab.id)
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .semibold))
          .frame(width: 20, height: 20)
          .background(
            Color.white.opacity(isHovered ? 0.10 : 0),
            in: RoundedRectangle(cornerRadius: 5)
          )
      }
      .buttonStyle(.plain)
      .help("Close \(tab.title)")
      .accessibilityLabel("Close \(tab.title)")
    }
    .foregroundStyle(Color.white.opacity(isSelected ? 0.96 : 0.68))
    .padding(.leading, 15)
    .padding(.trailing, 9)
    .frame(width: 178, height: 48)
    .background(
      isSelected
        ? Color.white.opacity(0.075)
        : Color.white.opacity(isHovered ? 0.035 : 0)
    )
    .overlay(alignment: .trailing) {
      Rectangle()
        .fill(Color.white.opacity(0.12))
        .frame(width: 1, height: 28)
    }
    .overlay(alignment: .top) {
      if isSelected {
        Rectangle()
          .fill(StudioPalette.accent)
          .frame(height: 2)
      }
    }
    .onHover { hovering in
      hoveredID = hovering ? tab.id : nil
    }
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func addTab() {
    let tab = UIDevDocumentTab(
      id: "untitled-\(nextUntitledNumber)",
      title: "untitled_\(nextUntitledNumber)"
    )
    tabs.append(tab)
    selectedID = tab.id
    nextUntitledNumber += 1
  }

  private func closeTab(_ id: String) {
    guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == id }) else { return }
    let wasSelected = selectedID == id
    tabs.remove(at: index)
    if wasSelected {
      selectedID = tabs[min(index, tabs.count - 1)].id
    }
  }
}
