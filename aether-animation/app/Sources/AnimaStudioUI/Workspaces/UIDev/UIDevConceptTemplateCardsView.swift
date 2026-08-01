import SwiftUI

enum UIDevConceptTemplateKind: String, CaseIterable, Identifiable, Sendable {
  case organizeRig
  case aiWorkspace
  case toolsAndResources
  case importAssembly
  case motionSequence
  case outputStack

  var id: Self { self }

  var title: String {
    switch self {
    case .organizeRig: "Organize Rig Components"
    case .aiWorkspace: "Generate a Node Flow"
    case .toolsAndResources: "Add Tools and Resources"
    case .importAssembly: "Import an Assembly"
    case .motionSequence: "Build a Motion Sequence"
    case .outputStack: "Configure Character Outputs"
    }
  }

  var detail: String {
    switch self {
    case .organizeRig:
      "Start with grouped components, mates, and named control regions."
    case .aiWorkspace:
      "Draft an editable STT, LLM, TTS, and behavior graph from a goal."
    case .toolsAndResources:
      "Add notes, media, reusable actions, plugins, and project references."
    case .importAssembly:
      "Bring in a CAD or DCC model and prepare its hierarchy for rigging."
    case .motionSequence:
      "Create animation tracks, key poses, audio cues, and show events."
    case .outputStack:
      "Plan screens, LED matrices, audio, and safely mapped hardware outputs."
    }
  }

  var actionTitle: String {
    switch self {
    case .organizeRig: "Add Groups"
    case .aiWorkspace: "Generate"
    case .toolsAndResources: "Add"
    case .importAssembly: "Choose Model"
    case .motionSequence: "Create Sequence"
    case .outputStack: "Add Output"
    }
  }

  var systemImage: String {
    switch self {
    case .organizeRig: "folder.badge.plus"
    case .aiWorkspace: "wand.and.sparkles"
    case .toolsAndResources: "wrench.and.screwdriver"
    case .importAssembly: "shippingbox.and.arrow.backward"
    case .motionSequence: "timeline.selection"
    case .outputStack: "cable.connector"
    }
  }
}

struct UIDevConceptTemplateCardsView: View {
  @State private var selectedKind: UIDevConceptTemplateKind = .aiWorkspace
  @State private var statusMessage = "Generate a Node Flow selected"

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text("STARTING POINTS")
            .font(.caption2.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(StudioPalette.accent)
          Text("Choose a workspace template")
            .font(.title3.weight(.bold))
          Text("Reusable cards for onboarding, empty workspaces, and add-content flows.")
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
        Spacer(minLength: 12)
        Label(statusMessage, systemImage: "checkmark.circle")
          .font(.caption.weight(.medium))
          .foregroundStyle(StudioPalette.semanticPart)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(StudioPalette.panelInset, in: Capsule())
          .lineLimit(1)
      }

      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 248, maximum: 310), spacing: 14, alignment: .top)],
        alignment: .leading,
        spacing: 14
      ) {
        ForEach(UIDevConceptTemplateKind.allCases) { kind in
          UIDevConceptTemplateCard(
            kind: kind,
            isSelected: selectedKind == kind,
            select: {
              selectedKind = kind
              statusMessage = "\(kind.title) selected"
            },
            performAction: {
              selectedKind = kind
              statusMessage = "\(kind.actionTitle) is a UI prototype action"
            }
          )
        }
      }
    }
    .padding(18)
    .background(StudioPalette.canvas)
  }
}

private struct UIDevConceptTemplateCard: View {
  let kind: UIDevConceptTemplateKind
  let isSelected: Bool
  let select: () -> Void
  let performAction: () -> Void

  @State private var isHovered = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      UIDevConceptTemplateIllustration(kind: kind, tint: tint)
        .frame(height: 132)

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
          Text(kind.title)
            .font(.callout.weight(.bold))
            .foregroundStyle(.primary)
          Spacer(minLength: 4)
          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(tint)
              .accessibilityLabel("Selected")
          }
        }

        Text(kind.detail)
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)

        Button(kind.actionTitle, systemImage: kind.systemImage, action: performAction)
          .buttonStyle(
            StudioButtonStyle(
              role: isSelected ? .primary : .secondary
            )
          )
          .help("Prototype action for \(kind.title).")
      }
      .padding(15)
    }
    .background(
      isSelected ? tint.opacity(0.08) : StudioPalette.panel,
      in: RoundedRectangle(cornerRadius: 14)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(
          isSelected ? tint : (isHovered ? StudioPalette.muted : StudioPalette.border),
          lineWidth: isSelected ? 1.5 : 1
        )
    }
    .shadow(color: .black.opacity(isHovered ? 0.22 : 0.12), radius: isHovered ? 10 : 5, y: 4)
    .contentShape(RoundedRectangle(cornerRadius: 14))
    .onTapGesture(perform: select)
    .onHover { isHovered = $0 }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(kind.title). \(kind.detail)")
  }

  private var tint: Color {
    switch kind {
    case .organizeRig: StudioPalette.semanticPart
    case .aiWorkspace: StudioPalette.accent
    case .toolsAndResources: StudioPalette.sourceModel
    case .importAssembly: StudioPalette.joint
    case .motionSequence: Color(red: 0.84, green: 0.45, blue: 0.92)
    case .outputStack: StudioPalette.hardware
    }
  }
}

private struct UIDevConceptTemplateIllustration: View {
  let kind: UIDevConceptTemplateKind
  let tint: Color

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [tint.opacity(0.15), StudioPalette.panelInset.opacity(0.24)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      illustration
        .padding(18)
    }
    .overlay(alignment: .topTrailing) {
      Text("CONCEPT")
        .font(.system(size: 8, weight: .bold, design: .monospaced))
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(StudioPalette.panel.opacity(0.82), in: Capsule())
        .padding(9)
    }
    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
  }

  @ViewBuilder
  private var illustration: some View {
    switch kind {
    case .organizeRig:
      VStack(spacing: 6) {
        ForEach(0..<3, id: \.self) { index in
          HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 3)
              .fill(tint.opacity(index == 1 ? 0.9 : 0.32))
              .frame(width: 15, height: 15)
            RoundedRectangle(cornerRadius: 3)
              .fill(StudioPalette.muted.opacity(0.22))
              .frame(width: CGFloat(68 + index * 15), height: 8)
            Spacer()
            Image(systemName: index == 1 ? "plus.circle.fill" : "chevron.right")
              .font(.caption2)
              .foregroundStyle(index == 1 ? tint : StudioPalette.muted)
          }
          .padding(7)
          .background(StudioPalette.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
        }
      }

    case .aiWorkspace:
      ZStack {
        Canvas { context, size in
          var path = Path()
          path.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.62))
          path.addCurve(
            to: CGPoint(x: size.width * 0.78, y: size.height * 0.34),
            control1: CGPoint(x: size.width * 0.44, y: size.height * 0.62),
            control2: CGPoint(x: size.width * 0.55, y: size.height * 0.34)
          )
          context.stroke(path, with: .color(tint.opacity(0.8)), lineWidth: 2)
        }
        HStack {
          conceptMiniNode("TEXT", image: "captions.bubble")
          Spacer()
          conceptMiniNode("VOICE", image: "speaker.wave.2")
        }
      }

    case .toolsAndResources:
      HStack(spacing: 9) {
        conceptResourceTile("Media", image: "photo.on.rectangle")
        conceptResourceTile("Tools", image: "wrench.and.screwdriver")
        conceptResourceTile("Notes", image: "note.text")
      }

    case .importAssembly:
      HStack(spacing: 14) {
        Image(systemName: "cube.transparent")
          .font(.system(size: 42, weight: .light))
          .foregroundStyle(tint)
        Image(systemName: "arrow.right")
          .foregroundStyle(StudioPalette.muted)
        VStack(spacing: 5) {
          Image(systemName: "square.3.layers.3d")
            .font(.title2)
          Text("HIERARCHY")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(tint)
        .padding(12)
        .background(StudioPalette.panel.opacity(0.75), in: RoundedRectangle(cornerRadius: 9))
      }

    case .motionSequence:
      VStack(spacing: 7) {
        ForEach(0..<3, id: \.self) { row in
          GeometryReader { proxy in
            ZStack(alignment: .leading) {
              Capsule().fill(StudioPalette.panel.opacity(0.72)).frame(height: 7)
              Capsule().fill(tint.opacity(0.48)).frame(width: proxy.size.width * 0.72, height: 7)
              ForEach(0..<3, id: \.self) { key in
                Circle()
                  .fill(tint)
                  .frame(width: 9, height: 9)
                  .offset(x: proxy.size.width * CGFloat(key + row + 1) / 6)
              }
            }
          }
          .frame(height: 10)
        }
        HStack {
          Image(systemName: "backward.end.fill")
          Image(systemName: "play.fill")
          Image(systemName: "forward.end.fill")
        }
        .font(.caption2)
        .foregroundStyle(tint)
      }

    case .outputStack:
      HStack(spacing: 8) {
        conceptOutputTile("Audio", image: "speaker.wave.2")
        conceptOutputTile("LED", image: "circle.grid.3x3")
        conceptOutputTile("Motion", image: "figure.walk.motion")
      }
    }
  }

  private func conceptMiniNode(_ label: String, image: String) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Label(label, systemImage: image)
        .font(.system(size: 8, weight: .bold, design: .monospaced))
      RoundedRectangle(cornerRadius: 3)
        .fill(tint.opacity(0.34))
        .frame(width: 62, height: 7)
    }
    .foregroundStyle(tint)
    .padding(10)
    .background(StudioPalette.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 9))
    .overlay { RoundedRectangle(cornerRadius: 9).stroke(tint.opacity(0.45), lineWidth: 1) }
  }

  private func conceptResourceTile(_ label: String, image: String) -> some View {
    VStack(spacing: 7) {
      Image(systemName: image)
        .font(.title3)
        .foregroundStyle(tint)
      Text(label)
        .font(.system(size: 9, weight: .semibold))
    }
    .frame(maxWidth: .infinity, minHeight: 62)
    .background(StudioPalette.panel.opacity(0.76), in: RoundedRectangle(cornerRadius: 8))
  }

  private func conceptOutputTile(_ label: String, image: String) -> some View {
    VStack(spacing: 7) {
      Image(systemName: image)
        .font(.title2)
      Text(label.uppercased())
        .font(.system(size: 8, weight: .bold, design: .monospaced))
    }
    .foregroundStyle(tint)
    .frame(maxWidth: .infinity, minHeight: 66)
    .background(StudioPalette.panel.opacity(0.78), in: RoundedRectangle(cornerRadius: 9))
    .overlay { RoundedRectangle(cornerRadius: 9).stroke(tint.opacity(0.30), lineWidth: 1) }
  }
}
