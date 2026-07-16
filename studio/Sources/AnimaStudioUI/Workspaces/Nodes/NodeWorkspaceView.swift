import SwiftUI

struct NodeWorkspaceView: View {
  @State private var graph = NodeCanvasDraftGraph.sample
  @State private var selectedNodeID = NodeCanvasDraftGraph.sample.nodes.first?.id
  @State private var paletteSearch = ""
  @State private var activeTool = "Select"
  @State private var zoom = 0.85
  @State private var showsGrid = true
  @State private var statusMessage = "Sample scene graph · UI draft"

  var body: some View {
    VStack(spacing: 0) {
      graphToolbar
      Divider()
      HStack(spacing: 0) {
        nodePalette
          .frame(width: 230)
        Divider()
        NodeCanvasView(
          graph: $graph,
          selectedNodeID: $selectedNodeID,
          zoom: zoom,
          showsGrid: showsGrid,
          statusMessage: $statusMessage
        )
        Divider()
        nodeInspector
          .frame(width: 300)
      }
      Divider()
      timelineConcept
        .frame(height: 128)
    }
    .background(StudioPalette.canvas)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Nodes logic planning workspace")
  }

  private var graphToolbar: some View {
    HStack(spacing: 8) {
      Picker("Tool", selection: $activeTool) {
        Label("Select", systemImage: "cursorarrow").tag("Select")
        Label("Hand", systemImage: "hand.draw").tag("Hand")
        Label("Connect", systemImage: "point.3.connected.trianglepath.dotted").tag("Connect")
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(width: 220)
      .onChange(of: activeTool) { _, newValue in
        statusMessage =
          switch newValue {
          case "Hand": "Hand selected · drag the scrollbars to navigate"
          case "Connect":
            "Connect preview selected · edge authoring follows the scene graph contract"
          default: "Select nodes to inspect or move them"
          }
      }

      Divider().frame(height: 20)

      Button("Frame All", systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
        zoom = 0.85
        statusMessage = "Framed the complete sample graph"
      }
      .buttonStyle(.borderless)

      Button {
        showsGrid.toggle()
      } label: {
        Label(showsGrid ? "Hide Grid" : "Show Grid", systemImage: "grid")
      }
      .buttonStyle(.borderless)

      Button("Validate", systemImage: validationIcon) {
        statusMessage = validationSummary
      }
      .buttonStyle(.borderless)

      Divider().frame(height: 20)

      Button {
        changeZoom(by: -0.1)
      } label: {
        Image(systemName: "minus")
      }
      .buttonStyle(StudioIconButtonStyle())

      Text("\(Int((zoom * 100).rounded()))%")
        .font(.caption.monospaced().weight(.bold))
        .frame(width: 42)

      Button {
        changeZoom(by: 0.1)
      } label: {
        Image(systemName: "plus")
      }
      .buttonStyle(StudioIconButtonStyle())

      Spacer()

      Text(statusMessage)
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
        .lineLimit(1)

      Button("Delete", systemImage: "trash") {
        deleteSelectedNode()
      }
      .buttonStyle(StudioButtonStyle(role: .destructive, density: .compact))
      .disabled(selectedNodeID == nil)

      Button("Reset Sample", systemImage: "arrow.counterclockwise") {
        graph = .sample
        selectedNodeID = graph.nodes.first?.id
        statusMessage = "Restored the sample scene graph"
      }
      .buttonStyle(StudioButtonStyle(role: .secondary, density: .compact))
    }
    .padding(.horizontal, 12)
    .frame(height: 44)
    .background(StudioPalette.chrome)
  }

  private var nodePalette: some View {
    VStack(alignment: .leading, spacing: 0) {
      StudioPanelHeader(
        title: "Node Library",
        detail: "Scene actions",
        systemImage: "square.grid.2x2"
      )
      Divider()
      StudioSearchField(prompt: "Find a node", text: $paletteSearch)
        .padding(10)
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          ForEach(NodeCanvasDraftFamily.allCases) { family in
            let kinds = filteredKinds(in: family)
            if !kinds.isEmpty {
              VStack(alignment: .leading, spacing: 5) {
                Text(family.title.uppercased())
                  .font(.system(size: 9, weight: .bold, design: .monospaced))
                  .foregroundStyle(StudioPalette.muted)
                ForEach(kinds) { kind in
                  Button {
                    addNode(kind)
                  } label: {
                    HStack(spacing: 8) {
                      Image(systemName: kind.systemImage)
                        .foregroundStyle(nodeColor(kind))
                        .frame(width: 18)
                      VStack(alignment: .leading, spacing: 1) {
                        Text(kind.title)
                          .font(.caption.weight(.semibold))
                        if !kind.isRuntimeAvailable {
                          Text("Concept")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(StudioPalette.muted)
                        }
                      }
                      Spacer()
                      Image(systemName: "plus")
                        .font(.caption2)
                        .foregroundStyle(StudioPalette.muted)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: kind.isRuntimeAvailable ? 30 : 37)
                    .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 6))
                  }
                  .buttonStyle(.plain)
                  .help(kind.availabilityDetail)
                }
              }
            }
          }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
      }
    }
    .background(StudioPalette.panel)
  }

  private var nodeInspector: some View {
    VStack(alignment: .leading, spacing: 0) {
      StudioPanelHeader(
        title: "Node Inspector",
        detail: selectedNode?.kind.family.title ?? "Nothing selected",
        systemImage: "slider.horizontal.3"
      )
      Divider()
      if let node = selectedNode {
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Label(node.kind.title, systemImage: node.kind.systemImage)
                .font(.callout.weight(.bold))
                .foregroundStyle(nodeColor(node.kind))
              Spacer()
              Text(node.kind.isRuntimeAvailable ? "SCENE V1" : "CONCEPT")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(
                  node.kind.isRuntimeAvailable ? StudioPalette.semanticPart : StudioPalette.muted
                )
            }

            StudioTextFieldRow(title: "Name", text: selectedTitleBinding)

            if node.properties.isEmpty {
              Text("This flow node has no editable parameters.")
                .font(.caption)
                .foregroundStyle(StudioPalette.muted)
                .padding(.vertical, 8)
            } else {
              ForEach(node.properties.keys.sorted(), id: \.self) { key in
                StudioReadoutRow(title: key, value: node.properties[key] ?? "")
              }
            }

            Divider()

            inspectorPortSection("INPUTS", ports: node.kind.inputPorts, isOutput: false)
            inspectorPortSection("OUTPUTS", ports: node.kind.outputPorts, isOutput: true)

            Divider()

            Label(
              node.kind.availabilityDetail,
              systemImage: node.kind.isRuntimeAvailable
                ? "checkmark.circle.fill" : "clock.badge.exclamationmark"
            )
            .font(.caption)
            .foregroundStyle(
              node.kind.isRuntimeAvailable ? StudioPalette.semanticPart : StudioPalette.muted
            )
          }
          .padding(12)
        }
      } else {
        ContentUnavailableView(
          "Select a Node",
          systemImage: "cursorarrow.click",
          description: Text("Choose a node on the canvas to inspect its parameters and ports.")
        )
      }
    }
    .background(StudioPalette.panel)
  }

  private var timelineConcept: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Label("SCENE TIMELINE", systemImage: "timeline.selection")
          .font(.caption.weight(.bold))
        Text("Graph and timeline are two views of the same scene")
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
        Spacer()
        Button("Jump to Start", systemImage: "backward.end.fill") {}
        Button("Play", systemImage: "play.fill") {}
        Button("Jump to End", systemImage: "forward.end.fill") {}
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .padding(.horizontal, 10)
      .frame(height: 30)
      .background(StudioPalette.chrome)
      Divider()
      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 0) {
          timelineRowLabel("Greeting Motion", color: StudioPalette.accent)
          timelineRowLabel("Hold Pose", color: StudioPalette.joint)
          timelineRowLabel("Lights On", color: StudioPalette.hardware)
        }
        .frame(width: 180)
        Divider()
        Canvas { context, size in
          for tick in 0...12 {
            let x = CGFloat(tick) * size.width / 12
            var grid = Path()
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(grid, with: .color(.white.opacity(0.065)), lineWidth: 1)
          }
          let bars: [(CGRect, Color)] = [
            (
              CGRect(x: size.width * 0.05, y: 8, width: size.width * 0.38, height: 18),
              StudioPalette.accent
            ),
            (
              CGRect(x: size.width * 0.44, y: 34, width: size.width * 0.28, height: 18),
              StudioPalette.joint
            ),
            (
              CGRect(x: size.width * 0.44, y: 60, width: size.width * 0.18, height: 18),
              StudioPalette.hardware
            ),
          ]
          for (rect, color) in bars {
            context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(color.opacity(0.7)))
          }
          var playhead = Path()
          let x = size.width * 0.44
          playhead.move(to: CGPoint(x: x, y: 0))
          playhead.addLine(to: CGPoint(x: x, y: size.height))
          context.stroke(playhead, with: .color(StudioPalette.accent), lineWidth: 2)
        }
        .background(Color.black.opacity(0.14))
      }
    }
  }

  private var selectedNode: NodeCanvasDraftNode? {
    graph.nodes.first { $0.id == selectedNodeID }
  }

  private var selectedTitleBinding: Binding<String> {
    Binding(
      get: { selectedNode?.title ?? "" },
      set: { newValue in
        guard let selectedNodeID,
          let index = graph.nodes.firstIndex(where: { $0.id == selectedNodeID })
        else { return }
        graph.nodes[index].title = newValue
      }
    )
  }

  private var validationSummary: String {
    let messages = graph.validationMessages
    return messages.isEmpty ? "Graph structure is valid" : "\(messages.count) validation note(s)"
  }

  private var validationIcon: String {
    graph.validationMessages.isEmpty ? "checkmark.shield.fill" : "exclamationmark.triangle"
  }

  private func addNode(_ kind: NodeCanvasDraftKind) {
    let offset = CGFloat(graph.nodes.count % 5) * 26
    selectedNodeID = graph.addNode(
      kind: kind,
      position: CGPoint(x: 560 + offset, y: 180 + offset)
    )
    statusMessage =
      kind.isRuntimeAvailable
      ? "Added \(kind.title); connect it when the graph contract lands"
      : "Added \(kind.title) concept; no runtime provider is connected"
  }

  private func deleteSelectedNode() {
    guard let selectedNodeID else { return }
    graph.removeNode(id: selectedNodeID)
    self.selectedNodeID = nil
    statusMessage = "Removed node and its attached connections"
  }

  private func changeZoom(by delta: Double) {
    zoom = min(max(zoom + delta, 0.5), 1.25)
  }

  private func filteredKinds(in family: NodeCanvasDraftFamily) -> [NodeCanvasDraftKind] {
    let candidates = NodeCanvasDraftKind.allCases.filter { $0.family == family }
    guard !paletteSearch.isEmpty else { return candidates }
    return candidates.filter { $0.title.localizedCaseInsensitiveContains(paletteSearch) }
  }

  private func inspectorPortSection(
    _ title: String,
    ports: [String],
    isOutput: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(StudioPalette.muted)
      if ports.isEmpty {
        Text("None")
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
      } else {
        ForEach(ports, id: \.self) { port in
          HStack {
            if !isOutput { portDot(data: port != "FLOW") }
            Text(port).font(.caption2.monospaced())
            Spacer()
            if isOutput { portDot(data: port != "FLOW") }
          }
        }
      }
    }
  }

  private func portDot(data: Bool) -> some View {
    Circle()
      .fill(data ? StudioPalette.joint : Color.white)
      .frame(width: 8, height: 8)
      .overlay { Circle().stroke(Color.black.opacity(0.45), lineWidth: 1) }
  }

  private func timelineRowLabel(_ title: String, color: Color) -> some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(title).lineLimit(1)
      Spacer()
    }
    .font(.caption2)
    .padding(.horizontal, 8)
    .frame(height: 27)
    .background(StudioPalette.panelInset)
  }

  private func nodeColor(_ kind: NodeCanvasDraftKind) -> Color {
    switch kind.family {
    case .flow: StudioPalette.accent
    case .performance: StudioPalette.semanticPart
    case .timing: StudioPalette.joint
    case .events: StudioPalette.hardware
    case .inputs: Color(red: 0.35, green: 0.72, blue: 0.96)
    case .voiceAI: Color(red: 0.72, green: 0.48, blue: 0.96)
    case .outputs: Color(red: 0.98, green: 0.55, blue: 0.24)
    }
  }
}
