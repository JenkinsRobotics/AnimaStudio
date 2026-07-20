import SwiftUI

struct NodesPrototype: View {
  @Bindable var model: PrototypeModel

  var body: some View {
    DockingWorkspace(
      model: model, leftTitle: "Node Library", rightTitle: "Node Inspector",
      leftWidth: 240, rightWidth: 290
    ) {
      PrototypeNodeLibrary()
    } center: {
      PrototypeNodeCanvas().frame(maxWidth: .infinity, maxHeight: .infinity)
    } right: {
      PrototypeNodeInspector()
    }
  }
}

struct PrototypeNodeLibrary: View {
  @Environment(\.prototypeTheme) private var theme

  var body: some View {
    PrototypePanel("Node Library", subtitle: "DRAG TO CANVAS", icon: "square.grid.2x2") {
      VStack(spacing: 2) {
        HStack {
          Image(systemName: "magnifyingglass")
          Text("Search nodes")
        }
        .font(.system(size: 10))
        .foregroundStyle(theme.secondaryText)
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
        .padding(8)

        category(
          "INPUTS",
          nodes: [
            ("Trigger", "bolt", theme.accent), ("Sensor", "sensor", theme.cyan),
            ("Speech to Text", "mic", theme.accent),
          ])
        category(
          "LOGIC",
          nodes: [
            ("If / Else", "arrow.triangle.branch", theme.purple),
            ("Select", "list.number", theme.purple),
            ("Wait", "clock", theme.purple), ("Loop", "repeat", theme.purple),
          ])
        category(
          "AI + MEDIA",
          nodes: [
            ("Language Model", "brain", .pink),
            ("Text to Speech", "speaker.wave.2", .pink),
            ("Memory", "internaldrive", .pink),
          ])
        category(
          "OUTPUTS",
          nodes: [
            ("Play Motion", "figure.walk.motion", theme.green),
            ("Screen Media", "display", theme.green),
            ("Hardware", "cable.connector", theme.green),
          ])
      }
    }
  }

  private func category(_ title: String, nodes: [(String, String, Color)]) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(theme.secondaryText)
        .padding(.horizontal, 10)
        .padding(.top, 6)
      ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
        HStack {
          Image(systemName: node.1).foregroundStyle(node.2).frame(width: 18)
          Text(node.0)
          Spacer()
          Image(systemName: "plus").foregroundStyle(theme.secondaryText)
        }
        .font(.system(size: 10))
        .padding(.horizontal, 10)
        .frame(height: 27)
      }
    }
  }
}

struct PrototypeNodeInspector: View {
  @Environment(\.prototypeTheme) private var theme

  var body: some View {
    VStack(spacing: 8) {
      PrototypePanel("Language Model", subtitle: "SELECTED NODE", icon: "brain") {
        VStack(spacing: 8) {
          PropertyField(label: "Provider", value: "Local / Adapter")
          PropertyField(label: "Model", value: "Character Brain")
          PropertyField(label: "Temperature", value: "0.65")
          PropertyField(label: "Timeout", value: "5.0", unit: "s")
          Toggle("Allow tool calls", isOn: .constant(true)).font(.system(size: 10))
          Toggle("Deterministic fallback", isOn: .constant(true)).font(.system(size: 10))
        }
        .padding(10)
      }

      PrototypePanel(
        "Ports", subtitle: "TYPED CONNECTIONS", icon: "point.3.connected.trianglepath.dotted"
      ) {
        VStack(spacing: 7) {
          PrototypeNodePortRow(direction: "IN", name: "Prompt", type: "String", color: theme.accent)
          PrototypeNodePortRow(direction: "IN", name: "Memory", type: "Context", color: theme.cyan)
          PrototypeNodePortRow(direction: "OUT", name: "Text", type: "String", color: theme.purple)
          PrototypeNodePortRow(direction: "OUT", name: "Action", type: "Event", color: theme.green)
        }
        .padding(10)
      }

      PrototypePanel("Execution", subtitle: "PREVIEW ONLY", icon: "play") {
        HStack {
          LabelPill(text: "IDLE")
          Spacer()
          Button("Run Node") {}
        }
        .padding(10)
      }
    }
  }
}

struct PrototypeNodePortRow: View {
  @Environment(\.prototypeTheme) private var theme
  let direction: String
  let name: String
  let type: String
  let color: Color

  var body: some View {
    HStack {
      Circle().fill(color).frame(width: 8, height: 8)
      Text(direction)
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(theme.secondaryText)
      Text(name).font(.system(size: 10))
      Spacer()
      Text(type).font(.system(size: 8)).foregroundStyle(theme.secondaryText)
    }
  }
}

struct PrototypeNodeCard: View {
  @Environment(\.prototypeTheme) private var theme
  let title: String
  let subtitle: String
  let icon: String
  let color: Color
  let inputs: [String]
  let outputs: [String]
  var selected = false
  var warning = false

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Image(systemName: icon).foregroundStyle(color)
        VStack(alignment: .leading) {
          Text(title).font(.system(size: 11, weight: .semibold))
          Text(subtitle).font(.system(size: 8, weight: .bold)).foregroundStyle(color)
        }
        Spacer()
        if warning {
          Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(theme.orange)
        } else {
          Image(systemName: "ellipsis").foregroundStyle(theme.secondaryText)
        }
      }
      .padding(9)
      .background(theme.raised)

      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 7) {
          ForEach(inputs, id: \.self) { input in
            HStack(spacing: 5) {
              Circle().fill(theme.secondaryText).frame(width: 6, height: 6)
              Text(input)
            }
            .font(.system(size: 8))
            .foregroundStyle(theme.secondaryText)
          }
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 7) {
          ForEach(outputs, id: \.self) { output in
            HStack(spacing: 5) {
              Text(output)
              Circle().fill(color).frame(width: 6, height: 6)
            }
            .font(.system(size: 8))
          }
        }
      }
      .padding(9)
      .frame(minHeight: 48)
    }
    .background(theme.panel)
    .clipShape(RoundedRectangle(cornerRadius: 9))
    .overlay(
      RoundedRectangle(cornerRadius: 9).stroke(
        warning ? theme.orange : (selected ? theme.accent : theme.line),
        lineWidth: selected || warning ? 2 : 1)
    )
    .shadow(
      color: selected ? theme.accent.opacity(0.23) : .black.opacity(0.2),
      radius: selected ? 14 : 5)
  }
}

struct PrototypeNodeCanvas: View {
  @Environment(\.prototypeTheme) private var theme

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Canvas { context, size in
          drawGrid(&context, size: size)
          drawConnection(
            &context, from: CGPoint(x: size.width * 0.24, y: size.height * 0.30),
            to: CGPoint(x: size.width * 0.48, y: size.height * 0.44), color: theme.accent)
          drawConnection(
            &context, from: CGPoint(x: size.width * 0.55, y: size.height * 0.44),
            to: CGPoint(x: size.width * 0.76, y: size.height * 0.29), color: theme.purple)
          drawConnection(
            &context, from: CGPoint(x: size.width * 0.55, y: size.height * 0.48),
            to: CGPoint(x: size.width * 0.76, y: size.height * 0.66), color: theme.green)
        }

        PrototypeNodeCard(
          title: "Guest Arrives", subtitle: "TRIGGER", icon: "sensor", color: theme.accent,
          inputs: [], outputs: ["Event"]
        )
        .frame(width: 170)
        .position(x: proxy.size.width * 0.18, y: proxy.size.height * 0.30)

        PrototypeNodeCard(
          title: "Language Model", subtitle: "AI", icon: "brain", color: theme.purple,
          inputs: ["Prompt", "Memory"], outputs: ["Text", "Action"], selected: true
        )
        .frame(width: 205)
        .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.46)

        PrototypeNodeCard(
          title: "Text to Speech", subtitle: "VOICE", icon: "speaker.wave.2", color: .pink,
          inputs: ["Text"], outputs: ["Audio"]
        )
        .frame(width: 185)
        .position(x: proxy.size.width * 0.81, y: proxy.size.height * 0.29)

        PrototypeNodeCard(
          title: "Play Greeting", subtitle: "MOTION", icon: "figure.wave", color: theme.green,
          inputs: ["Action"], outputs: ["Complete"]
        )
        .frame(width: 185)
        .position(x: proxy.size.width * 0.81, y: proxy.size.height * 0.67)

        canvasControls
      }
      .background(theme.canvas)
    }
  }

  private var canvasControls: some View {
    VStack {
      HStack {
        LabelPill(text: "BEHAVIOR GRAPH · WELCOME")
        Spacer()
        LabelPill(text: "VALID", color: theme.green)
      }
      Spacer()
      HStack {
        Label("100%", systemImage: "minus.magnifyingglass")
        Spacer()
        Label("Auto Layout", systemImage: "wand.and.stars")
      }
      .font(.system(size: 9))
      .foregroundStyle(theme.secondaryText)
    }
    .padding(12)
  }

  private func drawGrid(_ context: inout GraphicsContext, size: CGSize) {
    for x in stride(from: 0.0, through: size.width, by: 22) {
      for y in stride(from: 0.0, through: size.height, by: 22) {
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
          with: .color(theme.secondaryText.opacity(0.24)))
      }
    }
  }

  private func drawConnection(
    _ context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color
  ) {
    var path = Path()
    path.move(to: from)
    path.addCurve(
      to: to, control1: CGPoint(x: from.x + (to.x - from.x) * 0.45, y: from.y),
      control2: CGPoint(x: from.x + (to.x - from.x) * 0.55, y: to.y))
    context.stroke(path, with: .color(color.opacity(0.8)), lineWidth: 2.4)
  }
}
