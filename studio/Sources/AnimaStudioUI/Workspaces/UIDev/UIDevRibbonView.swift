import SwiftUI

struct UIDevRibbonView: View {
  @Binding var selectedSection: UIDevSection
  let openAgentWindow: () -> Void

  var body: some View {
    ScrollView(.horizontal) {
      HStack(alignment: .center, spacing: 0) {
        CreationToolGroup(
          title: "Windows",
          systemImage: "macwindow.on.rectangle",
          tint: StudioPalette.accent,
          detail: "1 live · 3 gallery"
        ) {
          CreationToolButton(
            title: "Agent",
            systemImage: "sparkles",
            tint: StudioPalette.accent,
            help: "Open the Anima Agent utility-window prototype.",
            action: openAgentWindow
          )
          .keyboardShortcut("a", modifiers: [.command, .shift])
          sectionButton(.panels, title: "Panels", systemImage: "sidebar.left")
          sectionButton(.dialogs, title: "Dialogs", systemImage: "rectangle.on.rectangle.angled")
          sectionButton(.popovers, title: "Popovers", systemImage: "bubble.left")
        }

        CreationToolGroup(
          title: "Controls",
          systemImage: "switch.2",
          tint: StudioPalette.semanticPart,
          detail: "Interactive standards"
        ) {
          sectionButton(.buttons, title: "Buttons", systemImage: "button.programmable")
          sectionButton(.inputs, title: "Inputs", systemImage: "character.cursor.ibeam")
          sectionButton(.menus, title: "Menus", systemImage: "filemenu.and.selection")
        }

        CreationToolGroup(
          title: "Foundations",
          systemImage: "paintpalette",
          tint: StudioPalette.joint,
          detail: "Shared source of truth"
        ) {
          sectionButton(.overview, title: "Overview", systemImage: "square.grid.2x2")
          sectionButton(.tokens, title: "Tokens", systemImage: "swatchpalette")
        }
      }
      .padding(.vertical, 8)
    }
    .scrollIndicators(.hidden)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("UI Dev workspace tools")
  }

  private func sectionButton(
    _ section: UIDevSection,
    title: String,
    systemImage: String
  ) -> some View {
    CreationToolButton(
      title: title,
      systemImage: systemImage,
      tint: tint(for: section),
      isSelected: selectedSection == section,
      help: section.purpose
    ) {
      selectedSection = section
    }
  }

  private func tint(for section: UIDevSection) -> Color {
    switch section {
    case .overview, .panels, .dialogs, .popovers: StudioPalette.accent
    case .buttons, .inputs, .menus: StudioPalette.semanticPart
    case .tokens: StudioPalette.joint
    }
  }
}
