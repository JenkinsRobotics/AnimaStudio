import AnimaCore
import SwiftUI

struct TimelineEditorView: View {
  @Bindable var workspace: StudioWorkspaceModel

  private var clip: AnimationClip { workspace.activeClip }
  private var keyframes: [ScalarKeyframe] {
    clip.jointTracks.first?.keyframes ?? []
  }

  var body: some View {
    VStack(spacing: 0) {
      transport
      Divider()
      editorModeBar
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

  private var transport: some View {
    HStack(spacing: 12) {
      Button(action: workspace.stopPlayback) {
        Image(systemName: "stop.fill")
      }
      .help("Stop")

      Button(action: workspace.togglePlayback) {
        Image(systemName: workspace.isPlaying ? "pause.fill" : "play.fill")
      }
      .keyboardShortcut(.space, modifiers: [])
      .help(workspace.isPlaying ? "Pause" : "Play")

      Divider().frame(height: 18)

      Text(clip.name)
        .fontWeight(.semibold)
      Spacer()
      Text(
        "\(workspace.playheadSeconds.formatted(.number.precision(.fractionLength(2)))) / \(clip.durationSeconds.formatted(.number.precision(.fractionLength(2)))) s"
      )
      .monospacedDigit()
      .foregroundStyle(.secondary)
    }
    .buttonStyle(.borderless)
    .padding(.horizontal)
    .frame(height: 42)
    .background(StudioPalette.chrome)
  }

  private var editorModeBar: some View {
    HStack(spacing: 10) {
      Label("Dope Sheet", systemImage: "diamond.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(StudioPalette.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(StudioPalette.accent.opacity(0.14), in: Capsule())

      Label("Graph", systemImage: "point.3.filled.connected.trianglepath.dotted")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
        .help("Graph editing is the next animation UI slice")

      Spacer()
      Text("AUTO-KEY PLANNED")
        .font(.caption2.weight(.bold))
        .foregroundStyle(StudioPalette.muted)
    }
    .padding(.horizontal, 10)
    .frame(height: 36)
    .background(Color.black.opacity(0.86))
  }

  private var trackHeaders: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("TRACKS")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(height: 28)
      Divider()
      Label("Head Yaw", systemImage: "rotate.3d")
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 52)
      Spacer()
    }
    .padding(.horizontal, 12)
    .background(StudioPalette.panelInset)
  }

  private var trackCanvas: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width, 1)
      ZStack(alignment: .topLeading) {
        ruler(width: width)

        Rectangle()
          .fill(StudioPalette.panel.opacity(0.58))
          .frame(height: 52)
          .offset(y: 29)

        ForEach(Array(keyframes.enumerated()), id: \.offset) { _, keyframe in
          Circle()
            .fill(StudioPalette.accent)
            .stroke(.white.opacity(0.8), lineWidth: 1)
            .frame(width: 10, height: 10)
            .position(
              x: xPosition(for: keyframe.timeSeconds, width: width),
              y: 55
            )
        }

        Rectangle()
          .fill(StudioPalette.accent)
          .frame(width: 1.5)
          .offset(
            x: xPosition(for: workspace.playheadSeconds, width: width),
            y: 0
          )
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            workspace.isPlaying = false
            workspace.playheadSeconds = min(
              max(Double(value.location.x / width) * clip.durationSeconds, 0),
              clip.durationSeconds
            )
          }
      )
    }
  }

  private func ruler(width: CGFloat) -> some View {
    ZStack(alignment: .topLeading) {
      Rectangle()
        .fill(StudioPalette.panelInset)
        .frame(height: 28)
      ForEach(0...Int(clip.durationSeconds), id: \.self) { second in
        Text("\(second)s")
          .font(.caption2.monospacedDigit())
          .foregroundStyle(.secondary)
          .position(
            x: xPosition(for: Double(second), width: width),
            y: 13
          )
      }
    }
  }

  private func xPosition(for seconds: Double, width: CGFloat) -> CGFloat {
    CGFloat(seconds / max(clip.durationSeconds, 0.001)) * width
  }
}
