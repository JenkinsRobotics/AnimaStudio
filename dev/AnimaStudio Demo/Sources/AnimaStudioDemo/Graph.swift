// Node-graph + servo-track components used by the Show and Hardware workspaces,
// extracted so the UI Kit shows the REAL widgets, not lookalikes.
import SwiftUI

// A graph node card (Show scene nodes, Hardware controller/servo nodes) with
// connector dots and a selection state.
struct GraphNode: View {
  let title: String
  let icon: String
  let sub: String
  let tint: Color
  var width: CGFloat = 140
  var big = false
  var selected = false
  var badge: (text: String, on: Bool)? = nil
  var onTap: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: big ? 5 : 6) {
      HStack(spacing: 6) {
        Image(systemName: icon).font(.system(size: big ? 14 : 12)).foregroundStyle(tint)
        Text(title).font(.system(size: big ? 13 : 12, weight: .semibold)).foregroundStyle(UI.text)
      }
      Text(sub).font(.system(size: 10)).foregroundStyle(UI.text3)
      if let badge {
        HStack(spacing: 5) {
          Circle().fill(badge.on ? UI.ok : UI.text3).frame(width: 7, height: 7)
          Text(badge.text).font(.system(size: 9)).foregroundStyle(UI.text3)
        }.padding(.top, 2)
      }
    }
    .padding(big ? 11 : 12).frame(width: width, alignment: .leading)
    .background(selected ? UI.accent.opacity(0.12) : UI.panel, in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10)
      .stroke(selected ? UI.accent : tint.opacity(0.4), lineWidth: selected ? 2 : 1))
    .overlay(alignment: .leading) { Circle().fill(tint).frame(width: 8, height: 8).offset(x: -4) }
    .overlay(alignment: .trailing) { Circle().fill(tint).frame(width: 8, height: 8).offset(x: 4) }
    .contentShape(RoundedRectangle(cornerRadius: 10))
    .onTapGesture { onTap() }
  }
}

// A live servo channel row — the Hardware "timeline" track (channel, name,
// position bar, angle readout, armed dot).
struct ServoTrack: View {
  let name: String
  let channel: Int
  let degrees: Double
  let fraction: Double
  var selected = false
  var armed = false
  var onTap: () -> Void = {}

  var body: some View {
    HStack(spacing: 12) {
      Text("CH\(channel)").font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundStyle(UI.text3).frame(width: 34)
      Text(name).font(.system(size: 12.5, weight: selected ? .semibold : .regular))
        .foregroundStyle(selected ? UI.accent : UI.text).frame(width: 82, alignment: .leading)
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(UI.panelHi).frame(height: 8)
          Capsule().fill(LinearGradient(colors: [UI.accent2, UI.accent], startPoint: .leading, endPoint: .trailing))
            .frame(width: geo.size.width * fraction, height: 8)
          Circle().fill(.white).frame(width: 13, height: 13)
            .overlay(Circle().stroke(UI.accent, lineWidth: 2))
            .offset(x: geo.size.width * fraction - 6.5)
        }
      }.frame(height: 14)
      Text("\(Int(degrees))°").font(.system(size: 12, design: .monospaced)).foregroundStyle(UI.text)
        .frame(width: 40, alignment: .trailing)
      Circle().fill(armed ? UI.ok : UI.text3).frame(width: 7, height: 7)
    }
    .padding(.horizontal, 14).padding(.vertical, 11)
    .background(selected ? UI.accent.opacity(0.08) : .clear)
    .overlay(alignment: .leading) { if selected { Rectangle().fill(UI.accent).frame(width: 2) } }
    .contentShape(Rectangle())
    .onTapGesture { onTap() }
  }
}
