import SwiftUI

struct ShowTimelineView: View {
  @Bindable var workspace: StudioWorkspaceModel

  private let tracks = [
    ShowTrack(title: "Characters", systemImage: "figure.wave", tint: .purple),
    ShowTrack(title: "Audio", systemImage: "waveform", tint: .green),
    ShowTrack(title: "Screens & LEDs", systemImage: "display", tint: .cyan),
    ShowTrack(title: "Events", systemImage: "bolt.fill", tint: .orange),
  ]

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      HStack(spacing: 0) {
        trackHeaders
          .frame(width: 220)
        Divider()
        trackCanvas
      }
    }
    .background(Color.black.opacity(0.92))
  }

  private var header: some View {
    HStack(spacing: 12) {
      Label("SHOW TIMELINE", systemImage: "sparkles.rectangle.stack")
        .font(.caption.weight(.bold))
        .tracking(0.8)
        .foregroundStyle(StudioPalette.accent)
      Divider().frame(height: 18)
      Text("Untitled Show")
        .fontWeight(.semibold)
      Text("Scene document not created")
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      Button("Add Cue", systemImage: "plus") {}
        .disabled(true)
        .help("Cue authoring arrives with scene documents")
      Text("00:00:00.000")
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 14)
    .frame(height: 42)
    .background(StudioPalette.chrome)
  }

  private var trackHeaders: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("SHOW TRACKS")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(height: 28)
      Divider()
      ForEach(tracks) { track in
        Label(track.title, systemImage: track.systemImage)
          .foregroundStyle(track.tint)
          .frame(maxWidth: .infinity, alignment: .leading)
          .frame(height: 38)
      }
      Spacer()
    }
    .padding(.horizontal, 12)
    .background(StudioPalette.panelInset)
  }

  private var trackCanvas: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width, 1)
      ZStack(alignment: .topLeading) {
        Rectangle()
          .fill(StudioPalette.panelInset)
          .frame(height: 28)

        ForEach(0...10, id: \.self) { second in
          let x = CGFloat(second) / 10 * width
          Rectangle()
            .fill(Color.white.opacity(second.isMultiple(of: 5) ? 0.16 : 0.07))
            .frame(width: 1)
            .offset(x: x, y: 28)
          Text("\(second)s")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .position(x: x, y: 13)
        }

        VStack(spacing: 0) {
          Spacer().frame(height: 29)
          ForEach(tracks) { _ in
            Rectangle()
              .fill(StudioPalette.panel.opacity(0.44))
              .frame(height: 38)
              .overlay(alignment: .leading) {
                Text("No cues")
                  .font(.caption2)
                  .foregroundStyle(.tertiary)
                  .padding(.leading, 12)
              }
            Divider()
          }
        }

        Rectangle()
          .fill(StudioPalette.accent)
          .frame(width: 1.5)
          .offset(x: 0, y: 0)
      }
    }
  }
}

private struct ShowTrack: Identifiable {
  let title: String
  let systemImage: String
  let tint: Color

  var id: String { title }
}
