import SwiftUI

struct StudioAgentPanelView: View {
  let close: () -> Void

  @State private var selectedMode = AgentMode.chat
  @State private var draft = ""

  var body: some View {
    VStack(spacing: 0) {
      windowHeader
      modeStrip
      Divider()
      conversationStarter
      Spacer(minLength: 18)
      disconnectedStatus
      composer
    }
    .background(StudioPalette.panel)
    .preferredColorScheme(.dark)
  }

  private var windowHeader: some View {
    StudioPanelHeader(
      title: "Anima Agent",
      detail: "Docked Studio assistant concept",
      systemImage: "sparkles"
    ) {
      Label("Prototype", systemImage: "hammer")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(StudioPalette.muted)
      Button("Close Agent", systemImage: "xmark") {
        close()
      }
      .labelStyle(.iconOnly)
      .buttonStyle(StudioIconButtonStyle())
      .help("Close the Agent side panel")
    }
  }

  private var modeStrip: some View {
    HStack(spacing: 8) {
      ForEach(AgentMode.allCases) { mode in
        Button(mode.title, systemImage: mode.systemImage) {
          selectedMode = mode
        }
        .labelStyle(.iconOnly)
        .buttonStyle(StudioIconButtonStyle(isSelected: selectedMode == mode))
        .help(mode.title)
      }
      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(StudioPalette.panel)
  }

  private var conversationStarter: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text(
        "Let’s work in Anima Studio. I can eventually help explain tools, review a rig, and guide an operator through a task."
      )
      .font(.callout)
      .fixedSize(horizontal: false, vertical: true)

      VStack(spacing: 9) {
        suggestion(1, "What can you help me with?")
        suggestion(2, "How do I create a revolute mate?")
        suggestion(3, "Review this workspace layout")
      }
    }
    .padding(16)
  }

  private var disconnectedStatus: some View {
    Label("UI prototype · agent service not connected", systemImage: "link.badge.plus")
      .font(.caption2.weight(.medium))
      .foregroundStyle(StudioPalette.muted)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(StudioPalette.panelInset, in: Capsule())
      .padding(.bottom, 10)
  }

  private var composer: some View {
    HStack(spacing: 8) {
      Button("Voice input", systemImage: "mic") {}
        .labelStyle(.iconOnly)
        .buttonStyle(StudioIconButtonStyle())
        .disabled(true)
        .help("Voice input requires the future agent service")
      TextField("Ask Anima Agent…", text: $draft)
        .textFieldStyle(.plain)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
          RoundedRectangle(cornerRadius: 9)
            .stroke(StudioPalette.border, lineWidth: 1)
        }
      Button("Send", systemImage: "paperplane.fill") {}
        .labelStyle(.iconOnly)
        .buttonStyle(StudioIconButtonStyle(isSelected: !draft.isEmpty))
        .disabled(true)
        .help("Sending requires the future agent service")
    }
    .padding(12)
    .background(StudioPalette.chrome)
  }

  private func suggestion(_ number: Int, _ text: String) -> some View {
    Button {
      draft = text
    } label: {
      HStack(spacing: 9) {
        Text("\(number)")
          .font(.caption2.weight(.bold))
          .frame(width: 20, height: 20)
          .background(StudioPalette.panel, in: Circle())
        Text(text)
          .font(.caption)
        Spacer(minLength: 0)
      }
    }
    .buttonStyle(
      StudioButtonStyle(role: .secondary, density: .regular, expandsHorizontally: true)
    )
  }
}

private enum AgentMode: CaseIterable, Identifiable {
  case voice
  case chat
  case documentation
  case ideas

  var id: Self { self }

  var title: String {
    switch self {
    case .voice: "Voice"
    case .chat: "Chat"
    case .documentation: "Documentation"
    case .ideas: "Ideas"
    }
  }

  var systemImage: String {
    switch self {
    case .voice: "mic"
    case .chat: "bubble.left"
    case .documentation: "book"
    case .ideas: "lightbulb"
    }
  }
}
