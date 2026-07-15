import SwiftUI

struct UIDevRibbonView: View {
  @Binding var selectedSection: UIDevSection
  let toggleAgentPanel: () -> Void

  var body: some View {
    ScrollView(.horizontal) {
      HStack(alignment: .center, spacing: 0) {
        CreationToolGroup(
          title: "App Surfaces",
          systemImage: "macwindow.on.rectangle",
          tint: StudioPalette.accent,
          detail: "5 docked · 1 detached"
        ) {
          CreationToolButton(
            title: "Agent",
            systemImage: "sparkles",
            tint: StudioPalette.accent,
            help: "Toggle the Anima Agent side panel inside the UI Dev workspace.",
            action: toggleAgentPanel
          )
          .keyboardShortcut("a", modifiers: [.command, .shift])
          sectionButton(.navigator, title: "Navigator", systemImage: "sidebar.left")
          sectionButton(.inspector, title: "Inspector", systemImage: "sidebar.right")
          sectionButton(
            .timeline,
            title: "Timeline",
            systemImage: "rectangle.bottomthird.inset.filled"
          )
          sectionButton(.workspace3D, title: "3D View", systemImage: "view.3d")
          CreationToolButton(
            title: UIDevDetachedWindowDescriptor.title,
            systemImage: UIDevDetachedWindowDescriptor.systemImage,
            tint: StudioPalette.sourceModel,
            help: "Open the one explicit detached floating-window template."
          ) {
            UIDevDetachedWindowRegistry.show()
          }
        }

        CreationToolGroup(
          title: "Interaction Labs",
          systemImage: "cursorarrow.motionlines",
          tint: StudioPalette.joint,
          detail: "Rig UI"
        ) {
          sectionButton(.mateEditor, title: "Mate Editor", systemImage: "link.badge.plus")
          sectionButton(.triadManipulator, title: "Triad", systemImage: "move.3d")
        }

        CreationToolGroup(
          title: "Patterns",
          systemImage: "rectangle.3.group",
          tint: StudioPalette.sourceModel,
          detail: "Gallery"
        ) {
          sectionButton(.panels, title: "Panels", systemImage: "macwindow.on.rectangle")
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
    case .overview, .navigator, .inspector, .timeline, .panels, .dialogs, .popovers:
      StudioPalette.accent
    case .workspace3D: StudioPalette.semanticPart
    case .buttons, .inputs, .menus: StudioPalette.semanticPart
    case .mateEditor, .triadManipulator, .tokens: StudioPalette.joint
    }
  }
}
