// The dope-sheet timeline — transport, ruler, and keyframe tracks. Renders REAL
// tracks/keys and drives playback; also the UI Kit's timeline specimen.
import SwiftUI

struct DopeSheetTimeline: View {
  var tracks: [TimelineTrack]
  var progress: Double                 // playhead, 0...1
  var duration: Double = 8
  var isPlaying = false
  var onScrub: (Double) -> Void = { _ in }
  var onTogglePlay: () -> Void = {}
  var onRewind: () -> Void = {}
  var onAddKey: () -> Void = {}

  private var clock: String {
    let t = progress * duration
    return String(format: "%02d:%04.1f / %02d:%04.1f",
      Int(t) / 60, t.truncatingRemainder(dividingBy: 60),
      Int(duration) / 60, duration.truncatingRemainder(dividingBy: 60))
  }

  var body: some View {
    Panel {
      VStack(spacing: 0) {
        // transport
        HStack(spacing: 12) {
          HStack(spacing: 10) {
            transport("backward.end.fill") { onRewind() }
            transport(isPlaying ? "pause.fill" : "play.fill", big: true) { onTogglePlay() }
            transport("forward.end.fill") { onScrub(1) }
          }
          Divider().frame(height: 18).overlay(UI.stroke)
          Text(clock).font(.system(size: 12, design: .monospaced)).foregroundStyle(UI.text)
          Spacer()
          Button(action: onAddKey) { Pill(icon: "plus", label: "Key", tint: UI.warn) }
            .buttonStyle(.plain)
          Text("\(tracks.count) tracks").font(.system(size: 11)).foregroundStyle(UI.text3)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        Divider().overlay(UI.stroke)

        // ruler — click/drag to scrub
        HStack(spacing: 0) {
          Text("CHANNELS").font(.system(size: 9.5, weight: .semibold)).tracking(0.5)
            .foregroundStyle(UI.text3).frame(width: 120, alignment: .leading).padding(.leading, 14)
          GeometryReader { geo in
            ZStack(alignment: .leading) {
              HStack(spacing: 0) {
                ForEach(0..<12) { i in
                  Text("\(i)").font(.system(size: 9, design: .monospaced)).foregroundStyle(UI.text3)
                    .frame(width: geo.size.width / 12, alignment: .leading)
                }
              }
              Rectangle().fill(UI.warn).frame(width: 1.5)
                .offset(x: geo.size.width * progress)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
              onScrub(Double(g.location.x / max(geo.size.width, 1)))
            })
          }.frame(height: 20)
        }
        .padding(.vertical, 6).background(UI.panel.opacity(0.5))
        Divider().overlay(UI.stroke)

        // tracks
        ScrollView {
          VStack(spacing: 0) {
            if tracks.isEmpty {
              Text("No mates yet — author mates in Rig to get animation tracks.")
                .font(.system(size: 10.5)).foregroundStyle(UI.text3)
                .frame(maxWidth: .infinity).padding(.vertical, 22)
            }
            ForEach(tracks) { track in
              trackRow(track)
              Divider().overlay(UI.stroke.opacity(0.5))
            }
          }
        }
      }
    }
  }

  private func trackRow(_ track: TimelineTrack) -> some View {
    HStack(spacing: 0) {
      HStack(spacing: 7) {
        Circle().fill(track.color).frame(width: 7, height: 7)
        Text(track.name).font(.system(size: 12)).foregroundStyle(UI.text).lineLimit(1)
        Spacer()
        Text("\(track.keys.count)").font(.system(size: 9.5, design: .monospaced))
          .foregroundStyle(UI.text3)
      }
      .frame(width: 120).padding(.horizontal, 14)
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Rectangle().fill(track.color.opacity(0.10)).frame(height: 26)
          ForEach(Array(track.keys.enumerated()), id: \.offset) { _, pos in
            Diamond().fill(track.color).frame(width: 9, height: 9)
              .offset(x: geo.size.width * pos - 4.5)
          }
          Rectangle().fill(UI.warn).frame(width: 1.5).offset(x: geo.size.width * progress)
        }
      }.frame(height: 34)
    }
  }

  private func transport(_ icon: String, big: Bool = false, _ action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: icon).font(.system(size: big ? 15 : 12))
        .foregroundStyle(big ? .white : UI.text2)
        .frame(width: big ? 34 : 26, height: big ? 34 : 26)
        .background(big ? UI.accent : UI.panelHi, in: Circle())
    }.buttonStyle(.plain)
  }
}
