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
      HStack(spacing: 0) {
        trackHeaders
          .frame(width: 190)
        Divider()
        trackCanvas
      }
    }
    .background(.bar)
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
    .frame(height: 38)
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
  }

  private var trackCanvas: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width, 1)
      ZStack(alignment: .topLeading) {
        ruler(width: width)

        Rectangle()
          .fill(Color.secondary.opacity(0.08))
          .frame(height: 52)
          .offset(y: 29)

        ForEach(Array(keyframes.enumerated()), id: \.offset) { _, keyframe in
          Circle()
            .fill(.orange)
            .stroke(.white.opacity(0.8), lineWidth: 1)
            .frame(width: 10, height: 10)
            .position(
              x: xPosition(for: keyframe.timeSeconds, width: width),
              y: 55
            )
        }

        Rectangle()
          .fill(.red)
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
        .fill(Color.secondary.opacity(0.05))
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
