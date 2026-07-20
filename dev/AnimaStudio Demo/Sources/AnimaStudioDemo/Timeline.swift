// The Animate dope-sheet timeline — transport, ruler, and keyframe tracks.
// Extracted into a reusable component so the UI Kit shows the REAL widget
// (used by AnimateWorkspace), not a lookalike.
import SwiftUI

struct DopeSheetTimeline: View {
  var tracks: [(String, Color)]
  @Binding var playhead: CGFloat

  var body: some View {
    Panel {
      VStack(spacing: 0) {
        // transport
        HStack(spacing: 12) {
          HStack(spacing: 10) {
            transport("backward.end.fill"); transport("backward.fill")
            transport("play.fill", big: true); transport("forward.fill"); transport("forward.end.fill")
          }
          Divider().frame(height: 18).overlay(UI.stroke)
          Text("00:04:12 / 00:12:00").font(.system(size: 12, design: .monospaced)).foregroundStyle(UI.text)
          Spacer()
          Pill(icon: "plus", label: "Key", tint: UI.warn)
          HStack(spacing: 6) {
            Text("24 fps").font(.system(size: 11)).foregroundStyle(UI.text3)
            Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(UI.text3)
          }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        Divider().overlay(UI.stroke)
        // ruler
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
                .offset(x: geo.size.width * playhead)
            }
          }.frame(height: 20)
        }
        .padding(.vertical, 6).background(UI.panel.opacity(0.5))
        Divider().overlay(UI.stroke)
        // tracks
        ScrollView {
          VStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.offset) { idx, t in
              trackRow(name: t.0, tint: t.1, seed: idx)
              Divider().overlay(UI.stroke.opacity(0.5))
            }
          }
        }
      }
    }
  }

  func trackRow(name: String, tint: Color, seed: Int) -> some View {
    HStack(spacing: 0) {
      HStack(spacing: 7) {
        Circle().fill(tint).frame(width: 7, height: 7)
        Text(name).font(.system(size: 12)).foregroundStyle(UI.text)
        Spacer()
        Image(systemName: "eye").font(.system(size: 10)).foregroundStyle(UI.text3)
      }
      .frame(width: 120).padding(.horizontal, 14)
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Rectangle().fill(tint.opacity(0.10)).frame(height: 26)
          ForEach(keyPositions(seed: seed), id: \.self) { pos in
            Diamond().fill(tint).frame(width: 9, height: 9)
              .offset(x: geo.size.width * pos - 4.5)
          }
          Rectangle().fill(UI.warn).frame(width: 1.5).offset(x: geo.size.width * playhead)
        }
      }.frame(height: 34)
    }
  }

  func keyPositions(seed: Int) -> [CGFloat] {
    let base: [CGFloat] = [0.05, 0.22, 0.4, 0.58, 0.78, 0.92]
    let shift = CGFloat(seed) * 0.015
    return base.map { min(0.97, $0 + shift) }
  }

  func transport(_ icon: String, big: Bool = false) -> some View {
    Image(systemName: icon).font(.system(size: big ? 15 : 12))
      .foregroundStyle(big ? .white : UI.text2)
      .frame(width: big ? 34 : 26, height: big ? 34 : 26)
      .background(big ? UI.accent : UI.panelHi, in: Circle())
  }
}
