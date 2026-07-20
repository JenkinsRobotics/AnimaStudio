import SwiftUI

struct TimelinePrototype: View {
  @Environment(\.prototypeTheme) private var theme
  @Binding var selectedTime: Double
  var showAudio = true

  private let tracks = ["Head Pan", "Head Tilt", "Jaw", "Eyes", "Left Arm", "Right Arm"]

  var body: some View {
    VStack(spacing: 0) {
      transport
      Divider().overlay(theme.line)
      HStack(spacing: 0) {
        trackLabels
        Divider().overlay(theme.line)
        GeometryReader { proxy in
          ZStack(alignment: .topLeading) {
            Canvas { context, size in
              drawTimeline(context: &context, size: size)
            }
            Rectangle().fill(theme.accent).frame(width: 1.5)
              .offset(x: CGFloat(selectedTime / 8) * proxy.size.width)
            Circle().fill(theme.accent).frame(width: 9, height: 9)
              .offset(x: CGFloat(selectedTime / 8) * proxy.size.width - 4, y: 1)
          }
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0).onChanged { value in
              selectedTime = min(max(Double(value.location.x / max(proxy.size.width, 1)) * 8, 0), 8)
            })
        }
      }
    }
    .background(theme.panel)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.line))
  }

  private var transport: some View {
    HStack(spacing: 13) {
      Menu("Playback") {
        Button("Loop") {}
        Button("Ping Pong") {}
      }
      .menuStyle(.borderlessButton).frame(width: 72)
      Button {
      } label: {
        Image(systemName: "backward.end.fill")
      }
      Button {
      } label: {
        Image(systemName: "backward.fill")
      }
      Button {
      } label: {
        Image(systemName: "play.fill")
      }
      Button {
      } label: {
        Image(systemName: "forward.fill")
      }
      Button {
      } label: {
        Image(systemName: "forward.end.fill")
      }
      Divider().frame(height: 20)
      Text(
        String(
          format: "%02d:%02d.%02d", Int(selectedTime) / 60, Int(selectedTime) % 60,
          Int(selectedTime * 100) % 100)
      )
      .font(.system(size: 10, weight: .medium, design: .monospaced))
      Spacer()
      Label("24 fps", systemImage: "film")
      Text("0.0 s — 8.0 s")
    }
    .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(theme.secondaryText)
    .padding(.horizontal, 11).frame(height: 34).background(theme.raised)
  }

  private var trackLabels: some View {
    VStack(spacing: 0) {
      ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
        HStack(spacing: 7) {
          Image(systemName: index < 4 ? "diamond" : "figure.arms.open")
            .foregroundStyle(index % 2 == 0 ? theme.purple : theme.cyan)
          Text(track).lineLimit(1)
          Spacer()
          Image(systemName: "eye").foregroundStyle(theme.secondaryText)
        }
        .font(.system(size: 9)).padding(.horizontal, 9).frame(height: 27)
        .background(index % 2 == 0 ? theme.raised.opacity(0.35) : .clear)
      }
      if showAudio {
        HStack {
          Image(systemName: "waveform").foregroundStyle(theme.orange)
          Text("Dialogue.wav")
          Spacer()
        }
        .font(.system(size: 9)).padding(.horizontal, 9).frame(height: 32)
      }
    }
    .frame(width: 165)
  }

  private func drawTimeline(context: inout GraphicsContext, size: CGSize) {
    let rowHeight: CGFloat = 27
    for row in 0..<(tracks.count + (showAudio ? 1 : 0)) {
      let y = CGFloat(row) * rowHeight
      context.fill(
        Path(CGRect(x: 0, y: y, width: size.width, height: rowHeight)),
        with: .color(row % 2 == 0 ? theme.raised.opacity(0.25) : .clear))
      var line = Path()
      line.move(to: CGPoint(x: 0, y: y))
      line.addLine(to: CGPoint(x: size.width, y: y))
      context.stroke(line, with: .color(theme.line), lineWidth: 0.5)
    }
    for second in 0...8 {
      let x = CGFloat(second) / 8 * size.width
      var line = Path()
      line.move(to: CGPoint(x: x, y: 0))
      line.addLine(to: CGPoint(x: x, y: size.height))
      context.stroke(
        line, with: .color(theme.line.opacity(second % 2 == 0 ? 1 : 0.55)), lineWidth: 0.7)
      context.draw(
        Text("\(second)s").font(.system(size: 8)).foregroundColor(theme.secondaryText),
        at: CGPoint(x: x + 11, y: 7))
    }
    let keyTimes: [[Double]] = [
      [0, 1.2, 2.4, 4.5, 6.8], [0, 2.0, 3.3, 5.7, 8], [0.6, 1.5, 2.8, 4.2, 6.0],
      [0, 1.1, 2.2, 3.8, 7.4], [0, 2.5, 5.2, 8], [0, 2.5, 5.2, 8],
    ]
    for (row, times) in keyTimes.enumerated() {
      for time in times {
        let x = CGFloat(time / 8) * size.width
        let y = CGFloat(row) * rowHeight + rowHeight / 2
        let rect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
        context.fill(
          Path(roundedRect: rect, cornerRadius: 1),
          with: .color(row % 2 == 0 ? theme.purple : theme.cyan))
      }
    }
    if showAudio {
      let y = CGFloat(tracks.count) * rowHeight + 16
      var wave = Path()
      wave.move(to: CGPoint(x: 0, y: y))
      for sample in 0...180 {
        let x = CGFloat(sample) / 180 * size.width
        let amplitude = sin(Double(sample) * 0.42) * sin(Double(sample) * 0.071) * 9
        wave.addLine(to: CGPoint(x: x, y: y + CGFloat(amplitude)))
      }
      context.stroke(wave, with: .color(theme.orange.opacity(0.8)), lineWidth: 1)
    }
  }
}
