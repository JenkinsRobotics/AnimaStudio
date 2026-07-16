import SwiftUI

struct NodeCanvasView: View {
  @Binding var graph: NodeCanvasDraftGraph
  @Binding var selectedNodeID: UUID?
  let zoom: Double
  let showsGrid: Bool
  @Binding var statusMessage: String

  @State private var dragOrigins: [UUID: CGPoint] = [:]

  private let baseCanvasSize = CGSize(width: 1_420, height: 820)

  var body: some View {
    ScrollView([.horizontal, .vertical]) {
      ZStack(alignment: .topLeading) {
        canvasBackground
        connectionLayer

        ForEach(graph.nodes) { node in
          NodeCanvasCard(
            node: node,
            isSelected: selectedNodeID == node.id,
            color: nodeColor(node.kind)
          )
          .scaleEffect(zoom)
          .position(
            x: node.position.x * zoom,
            y: node.position.y * zoom
          )
          .onTapGesture {
            selectedNodeID = node.id
            statusMessage = "Selected \(node.title)"
          }
          .gesture(dragGesture(for: node))
        }
      }
      .frame(
        width: baseCanvasSize.width * zoom,
        height: baseCanvasSize.height * zoom,
        alignment: .topLeading
      )
    }
    .background(Color.black.opacity(0.48))
  }

  private var canvasBackground: some View {
    Canvas { context, size in
      guard showsGrid else { return }
      let spacing = max(CGFloat(28 * zoom), 14)
      for x in stride(from: spacing, through: size.width, by: spacing) {
        for y in stride(from: spacing, through: size.height, by: spacing) {
          let dot = CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5)
          context.fill(Path(ellipseIn: dot), with: .color(Color.white.opacity(0.16)))
        }
      }
    }
    .frame(
      width: baseCanvasSize.width * zoom,
      height: baseCanvasSize.height * zoom
    )
    .background(
      LinearGradient(
        colors: [Color.black.opacity(0.72), StudioPalette.canvas.opacity(0.88)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .contentShape(Rectangle())
    .onTapGesture {
      selectedNodeID = nil
      statusMessage = "Canvas selection cleared"
    }
  }

  private var connectionLayer: some View {
    Canvas { context, _ in
      for edge in graph.edges {
        guard let source = graph.nodes.first(where: { $0.id == edge.sourceNodeID }),
          let target = graph.nodes.first(where: { $0.id == edge.targetNodeID })
        else { continue }

        let start = CGPoint(
          x: (source.position.x + 108) * zoom,
          y: source.position.y * zoom
        )
        let end = CGPoint(
          x: (target.position.x - 108) * zoom,
          y: target.position.y * zoom
        )
        let controlOffset = max(abs(end.x - start.x) * 0.48, 60 * zoom)
        var path = Path()
        path.move(to: start)
        path.addCurve(
          to: end,
          control1: CGPoint(x: start.x + controlOffset, y: start.y),
          control2: CGPoint(x: end.x - controlOffset, y: end.y)
        )
        let edgeColor = edge.kind == .flow ? StudioPalette.accent : StudioPalette.joint
        context.stroke(
          path,
          with: .color(edgeColor.opacity(0.92)),
          style: StrokeStyle(lineWidth: max(2.6 * zoom, 1.4), lineCap: .round)
        )

        let sourceDot = CGRect(
          x: start.x - 4 * zoom,
          y: start.y - 4 * zoom,
          width: 8 * zoom,
          height: 8 * zoom
        )
        let targetDot = CGRect(
          x: end.x - 4 * zoom,
          y: end.y - 4 * zoom,
          width: 8 * zoom,
          height: 8 * zoom
        )
        context.fill(Path(ellipseIn: sourceDot), with: .color(edgeColor))
        context.fill(Path(ellipseIn: targetDot), with: .color(edgeColor))
      }
    }
    .frame(
      width: baseCanvasSize.width * zoom,
      height: baseCanvasSize.height * zoom
    )
    .allowsHitTesting(false)
  }

  private func dragGesture(for node: NodeCanvasDraftNode) -> some Gesture {
    DragGesture(minimumDistance: 2)
      .onChanged { value in
        if dragOrigins[node.id] == nil {
          dragOrigins[node.id] = node.position
          selectedNodeID = node.id
        }
        guard let origin = dragOrigins[node.id] else { return }
        graph.moveNode(
          id: node.id,
          to: CGPoint(
            x: origin.x + value.translation.width / zoom,
            y: origin.y + value.translation.height / zoom
          )
        )
      }
      .onEnded { _ in
        dragOrigins[node.id] = nil
        statusMessage = "Moved \(node.title)"
      }
  }

  private func nodeColor(_ kind: NodeCanvasDraftKind) -> Color {
    switch kind.family {
    case .flow: StudioPalette.accent
    case .programLogic: Color(red: 0.96, green: 0.70, blue: 0.24)
    case .conditions: Color(red: 0.93, green: 0.39, blue: 0.64)
    case .performance: StudioPalette.semanticPart
    case .timing: StudioPalette.joint
    case .events: StudioPalette.hardware
    case .dataIO: Color(red: 0.28, green: 0.78, blue: 0.62)
    case .background: Color(red: 0.96, green: 0.34, blue: 0.34)
    case .inputs: Color(red: 0.35, green: 0.72, blue: 0.96)
    case .voiceAI: Color(red: 0.72, green: 0.48, blue: 0.96)
    case .outputs: Color(red: 0.98, green: 0.55, blue: 0.24)
    }
  }
}

private struct NodeCanvasCard: View {
  let node: NodeCanvasDraftNode
  let isSelected: Bool
  let color: Color

  var body: some View {
    VStack(spacing: 0) {
      if isSelected {
        selectionToolbar
          .offset(y: -8)
          .padding(.bottom, -8)
      }

      VStack(spacing: 0) {
        nodeHeader
        Divider()
        nodeBody
      }
      .frame(width: 216)
      .background(StudioPalette.panel.opacity(0.97))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? color : StudioPalette.border, lineWidth: isSelected ? 3 : 1)
      }
      .shadow(color: isSelected ? color.opacity(0.35) : .black.opacity(0.30), radius: 12, y: 4)
    }
  }

  private var nodeHeader: some View {
    HStack(spacing: 8) {
      Image(systemName: node.kind.systemImage)
        .foregroundStyle(color)
      VStack(alignment: .leading, spacing: 1) {
        Text(node.title)
          .font(.caption.weight(.bold))
          .lineLimit(1)
        Text(node.kind.family.title.uppercased())
          .font(.system(size: 7.5, weight: .bold, design: .monospaced))
          .foregroundStyle(StudioPalette.muted)
      }
      Spacer(minLength: 4)
      Image(systemName: node.kind.isRuntimeAvailable ? "checkmark.circle.fill" : "lock.fill")
        .font(.caption2)
        .foregroundStyle(
          node.kind.isRuntimeAvailable ? StudioPalette.semanticPart : StudioPalette.muted
        )
      Image(systemName: "ellipsis")
        .foregroundStyle(StudioPalette.muted)
    }
    .padding(.horizontal, 10)
    .frame(height: 42)
    .background(color.opacity(0.10))
  }

  private var nodeBody: some View {
    VStack(spacing: 8) {
      if !node.subtitle.isEmpty {
        Text(node.subtitle)
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      let rowCount = max(node.kind.inputPorts.count, node.kind.outputPorts.count)
      ForEach(0..<rowCount, id: \.self) { index in
        HStack(spacing: 5) {
          if index < node.kind.inputPorts.count {
            portDot(data: node.kind.inputPorts[index] != "FLOW")
            Text(node.kind.inputPorts[index])
              .font(.system(size: 7.5, design: .monospaced))
          }
          Spacer()
          if index < node.kind.outputPorts.count {
            Text(node.kind.outputPorts[index])
              .font(.system(size: 7.5, design: .monospaced))
            portDot(data: node.kind.outputPorts[index] != "FLOW")
          }
        }
      }

      if !node.properties.isEmpty {
        Divider()
        HStack(spacing: 4) {
          ForEach(node.properties.keys.sorted().prefix(3), id: \.self) { key in
            Text(node.properties[key] ?? key)
              .font(.system(size: 7.5))
              .lineLimit(1)
              .padding(.horizontal, 5)
              .padding(.vertical, 3)
              .background(StudioPalette.field, in: Capsule())
          }
          Spacer(minLength: 0)
        }
      }
    }
    .padding(10)
    .frame(minHeight: 86)
  }

  private var selectionToolbar: some View {
    HStack(spacing: 12) {
      Image(systemName: "gearshape")
      Image(systemName: "text.bubble")
      Image(systemName: "arrow.up.right.square")
      Image(systemName: "info.circle")
    }
    .font(.caption)
    .padding(.horizontal, 11)
    .frame(height: 30)
    .background(StudioPalette.chrome, in: RoundedRectangle(cornerRadius: 8))
    .overlay { RoundedRectangle(cornerRadius: 8).stroke(StudioPalette.border, lineWidth: 1) }
  }

  private func portDot(data: Bool) -> some View {
    Circle()
      .fill(data ? StudioPalette.joint : color)
      .frame(width: 8, height: 8)
      .overlay { Circle().stroke(Color.black.opacity(0.55), lineWidth: 1) }
  }
}
