import SwiftUI

/// Selection rail and context actions retained from the retired Codex Spatial
/// exploration. They now live in the shared UI Kit instead of a second app.
struct SpatialSelectionToolsSpecimen: View {
  @Environment(\.prototypeTheme) private var theme
  @State private var selectedTool = "Select"
  @State private var selectedAction = "Value"

  private let tools = ["Select", "Cue", "Trigger", "Monitor", "Hardware", "Stop", "More"]
  private let actions = ["Value", "Bezier", "Copy", "Mirror", "Delete"]

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      VStack(spacing: 3) {
        ForEach(tools, id: \.self) { tool in
          Button {
            selectedTool = tool
          } label: {
            VStack(spacing: 2) {
              Image(systemName: toolIcon(tool)).font(.system(size: 12, weight: .semibold))
              Text(tool).font(.system(size: 7, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(selectedTool == tool ? Color.white : theme.secondaryText)
            .frame(width: 46, height: 36)
            .background(
              selectedTool == tool ? toolColor(tool) : .clear,
              in: RoundedRectangle(cornerRadius: 7)
            )
          }
          .buttonStyle(.plain)
        }
      }
      .padding(5)
      .background(theme.raised, in: RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.line))

      VStack(spacing: 0) {
        HStack(spacing: 7) {
          Image(systemName: "cursorarrow.rays")
            .foregroundStyle(theme.cyan)
          VStack(alignment: .leading, spacing: 1) {
            Text("Selected: Head Pan").font(.system(size: 10, weight: .semibold))
            Text("KEYFRAME").font(.system(size: 7, weight: .bold))
              .foregroundStyle(theme.secondaryText)
          }
          Spacer()
          Image(systemName: "ellipsis").foregroundStyle(theme.secondaryText)
        }
        .padding(.horizontal, 9).frame(height: 40)
        Divider().overlay(theme.line)
        VStack(spacing: 2) {
          ForEach(actions, id: \.self) { action in
            Button {
              selectedAction = action
            } label: {
              HStack(spacing: 8) {
                Image(systemName: actionIcon(action))
                  .foregroundStyle(action == "Delete" ? theme.orange : theme.cyan)
                  .frame(width: 15)
                Text(action).font(.system(size: 9, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.system(size: 7)).foregroundStyle(theme.secondaryText)
              }
              .padding(.horizontal, 9).frame(height: 29)
              .background(
                selectedAction == action ? theme.accent.opacity(0.16) : .clear,
                in: RoundedRectangle(cornerRadius: 5)
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(6)
      }
      .frame(width: 186)
      .background(theme.raised, in: RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.line))
    }
    .fixedSize(horizontal: true, vertical: false)
  }

  private func toolIcon(_ tool: String) -> String {
    switch tool {
    case "Select": "cursorarrow"
    case "Cue": "flag.fill"
    case "Trigger": "bolt.fill"
    case "Monitor": "waveform.path.ecg.rectangle"
    case "Hardware": "cable.connector"
    case "Stop": "stop.fill"
    default: "ellipsis"
    }
  }

  private func toolColor(_ tool: String) -> Color {
    switch tool {
    case "Cue", "Trigger": theme.orange
    case "Monitor", "Hardware": theme.green
    case "Stop": .red
    default: theme.accent
    }
  }

  private func actionIcon(_ action: String) -> String {
    switch action {
    case "Bezier": "point.bottomleft.forward.to.point.topright.scurvepath"
    case "Copy": "doc.on.doc"
    case "Mirror": "arrow.left.and.right.righttriangle.left.righttriangle.right"
    case "Delete": "trash"
    default: "diamond.fill"
    }
  }
}

/// A representative floating right-side stack: hierarchy, selection-adaptive
/// mate controls, and live hardware health.
struct SpatialContextStackSpecimen: View {
  @Environment(\.prototypeTheme) private var theme

  var body: some View {
    VStack(spacing: 8) {
      PrototypePanel("Items", subtitle: "CHARACTER HIERARCHY", icon: "list.bullet.indent") {
        VStack(spacing: 2) {
          HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
            Text("Filter items").foregroundStyle(theme.secondaryText)
            Spacer()
          }
          .font(.system(size: 9)).padding(.horizontal, 8).frame(height: 27)
          .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
          contextRow(
            "Atlas", icon: "person.crop.rectangle.stack", detail: "12", color: theme.orange)
          contextRow("Base", icon: "cube.fill", level: 1)
          contextRow("Torso", icon: "cube.fill", level: 1)
          contextRow(
            "Head Pan", icon: "rotate.3d", detail: "+22°", level: 2, selected: true,
            color: theme.purple)
          contextRow("Head Tilt", icon: "rotate.3d", detail: "-8°", level: 2, color: theme.cyan)
          contextRow("Jaw", icon: "link", level: 2, color: theme.orange)
          contextRow("Dialogue.wav", icon: "speaker.wave.2.fill", detail: "8.0 s", color: .pink)
          contextRow(
            "LED Face", icon: "rectangle.stack.fill", detail: "32 × 16", color: theme.green)
        }
        .padding(7)
      }

      PrototypePanel("Head Pan", subtitle: "REVOLUTE MATE", icon: "slider.horizontal.3") {
        VStack(spacing: 6) {
          PropertyField(label: "Angle", value: "+22.0", unit: "deg")
          PropertyField(label: "Minimum", value: "-90.0", unit: "deg")
          PropertyField(label: "Maximum", value: "+90.0", unit: "deg")
          HStack {
            Text("Output").foregroundStyle(theme.secondaryText)
            Spacer()
            LabelPill(text: "SERVO 01", color: theme.purple)
          }
          .font(.system(size: 9))
          HStack(spacing: 6) {
            Button("Add keyframe") {}
            Button("Center") {}
          }
          .font(.system(size: 8)).buttonStyle(.bordered)
        }
        .padding(8)
      }

      PrototypePanel("Hardware", subtitle: "LIVE OUTPUT", icon: "cable.connector") {
        VStack(spacing: 5) {
          hardwareRow("Servo Controller", route: "USB")
          hardwareRow("LED Matrix", route: "Wi-Fi")
          hardwareRow("Stage Audio", route: "Local")
          HStack(spacing: 6) {
            Circle().fill(theme.orange).frame(width: 6, height: 6)
            Text("Output armed, not streaming")
            Spacer()
          }
          .font(.system(size: 8)).foregroundStyle(theme.secondaryText)
        }
        .padding(8)
      }
    }
  }

  private func contextRow(
    _ title: String, icon: String, detail: String = "", level: Int = 0,
    selected: Bool = false, color: Color? = nil
  ) -> some View {
    HStack(spacing: 7) {
      Color.clear.frame(width: CGFloat(level * 11), height: 1)
      Image(systemName: icon)
        .foregroundStyle(selected ? Color.white : (color ?? theme.secondaryText))
        .frame(width: 15)
      Text(title).lineLimit(1)
      Spacer()
      if !detail.isEmpty {
        Text(detail).font(.system(size: 8)).foregroundStyle(selected ? .white : theme.secondaryText)
      }
    }
    .font(.system(size: 9, weight: selected ? .semibold : .regular))
    .padding(.horizontal, 8).frame(height: 26)
    .background(
      selected ? theme.accent.opacity(0.86) : .clear,
      in: RoundedRectangle(cornerRadius: 5)
    )
  }

  private func hardwareRow(_ name: String, route: String) -> some View {
    HStack {
      Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.green)
      Text(name)
      Spacer()
      Text(route).foregroundStyle(theme.secondaryText)
    }
    .font(.system(size: 8)).frame(height: 19)
  }
}

/// Full-width timeline specimen. Unlike side cards, it intentionally spans the
/// visible matrix width because timelines are primary center content.
struct SpatialTimelineSpecimen: View {
  @Environment(\.prototypeTheme) private var theme

  var body: some View {
    PrototypePanel(
      "Live Follow Timeline", subtitle: "TRACKS + KEYS + AUDIO", icon: "timeline.selection"
    ) {
      VStack(spacing: 0) {
        HStack(spacing: 10) {
          Image(systemName: "backward.end.fill")
          Image(systemName: "play.fill")
          Image(systemName: "forward.end.fill")
          Text("00:02:10").font(.system(size: 9, weight: .medium, design: .monospaced))
          Divider().frame(height: 17)
          LabelPill(text: "LIVE FOLLOW", color: theme.green)
          Spacer()
          Text("Graph")
          Text("+ Track")
          Label("8.0 s", systemImage: "clock")
        }
        .font(.system(size: 9)).padding(.horizontal, 11).frame(height: 32)
        .background(theme.raised)
        HStack(spacing: 0) {
          VStack(spacing: 0) {
            trackLabel("Head Pan", icon: "rotate.3d", color: theme.purple, selected: true)
            trackLabel("Head Tilt", icon: "rotate.3d", color: theme.cyan)
            trackLabel("Jaw", icon: "link", color: theme.orange)
            trackLabel("Dialogue", icon: "waveform", color: .pink)
          }
          .frame(width: 135)
          Canvas { context, size in
            drawTracks(context: &context, size: size)
          }
        }
        .frame(height: 128)
      }
    }
  }

  private func trackLabel(_ title: String, icon: String, color: Color, selected: Bool = false)
    -> some View
  {
    HStack(spacing: 7) {
      Image(systemName: icon).foregroundStyle(color)
      Text(title)
      Spacer()
      Image(systemName: "eye")
    }
    .font(.system(size: 9)).padding(.horizontal, 9)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(selected ? theme.accent.opacity(0.13) : .clear)
  }

  private func drawTracks(context: inout GraphicsContext, size: CGSize) {
    let rowHeight = size.height / 4
    for row in 0..<4 {
      context.fill(
        Path(CGRect(x: 0, y: CGFloat(row) * rowHeight, width: size.width, height: rowHeight)),
        with: .color(row.isMultiple(of: 2) ? theme.raised.opacity(0.52) : theme.panel.opacity(0.62))
      )
    }
    for second in 0...8 {
      let x = CGFloat(second) / 8 * size.width
      var line = Path()
      line.move(to: CGPoint(x: x, y: 0))
      line.addLine(to: CGPoint(x: x, y: size.height))
      context.stroke(line, with: .color(theme.line), lineWidth: 0.7)
    }

    let keys: [(Double, Int, Color)] = [
      (0, 0, theme.purple), (2.4, 0, theme.purple), (5.2, 0, theme.purple),
      (8, 0, theme.purple), (0, 1, theme.cyan), (3.1, 1, theme.cyan),
      (6.8, 1, theme.cyan), (0.6, 2, theme.orange), (2.8, 2, theme.orange),
      (4.4, 2, theme.orange),
    ]
    for key in keys {
      let x = CGFloat(key.0 / 8) * size.width
      let y = (CGFloat(key.1) + 0.5) * rowHeight
      context.fill(
        Path(roundedRect: CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7), cornerRadius: 1),
        with: .color(key.2)
      )
    }

    let waveY = size.height * 0.875
    var wave = Path()
    wave.move(to: CGPoint(x: 0, y: waveY))
    for sample in 0...160 {
      wave.addLine(
        to: CGPoint(
          x: CGFloat(sample) / 160 * size.width,
          y: waveY + CGFloat(sin(Double(sample) * 0.38) * 7)
        )
      )
    }
    context.stroke(wave, with: .color(.pink.opacity(0.82)), lineWidth: 1)
    let playhead = CGFloat(2.4 / 8) * size.width
    context.fill(
      Path(CGRect(x: playhead, y: 0, width: 1.5, height: size.height)),
      with: .color(theme.accent)
    )
  }
}
