import SwiftUI

struct UIDevVariantBoardSpecimenView: View {
  let id: UIDevWindowVariantID
  let cardWidth: CGFloat

  @ViewBuilder
  var body: some View {
    switch id {
    case .documentChrome: documentChromePreview
    case .workspaceRibbon: workspaceRibbonPreview(compact: false)
    case .compactWorkspaceChrome: workspaceRibbonPreview(compact: true)
    case .navigatorEmpty: navigatorPreview(populated: false)
    case .navigatorHierarchy: navigatorPreview(populated: true)
    case .agentDocked: agentPreview
    case .componentInspector: inspectorPreview(kind: .component)
    case .mateInspector: inspectorPreview(kind: .mate)
    case .appearanceInspector: inspectorPreview(kind: .appearance)
    case .hardwareInspector: inspectorPreview(kind: .hardware)
    case .dopeSheetTimeline: timelinePreview(kind: .dopeSheet)
    case .motionCurveTimeline: timelinePreview(kind: .curves)
    case .showControlTimeline: timelinePreview(kind: .show)
    case .emptyTimeline: timelinePreview(kind: .empty)
    case .commandToolbar: toolbarPreview(state: .defaultState)
    case .selectionToolbar: toolbarPreview(state: .selected)
    case .disabledToolbar: toolbarPreview(state: .disabled)
    case .verticalToolRail: verticalToolRailPreview
    case .informationDialog: dialogPreview(destructive: false)
    case .confirmationDialog: dialogPreview(destructive: true)
    case .graphicsPopover: graphicsPopoverPreview
    case .componentContextMenu: contextMenuPreview
    case .emptyWorkspace: statusPreview(kind: .empty)
    case .processingStatus: statusPreview(kind: .working)
    case .connectedStatus: statusPreview(kind: .connected)
    case .emergencyStatus: statusPreview(kind: .emergency)
    }
  }

  private var documentChromePreview: some View {
    HStack(spacing: 8) {
      Image(systemName: "house.fill")
      Image(systemName: "square.grid.2x2")
      Image(systemName: "doc")
      Divider().frame(height: 18)
      Image(systemName: "square.and.arrow.down")
      Image(systemName: "arrow.uturn.backward")
      Spacer()
      Label("Untitled Character", systemImage: "cube.fill")
        .font(.caption.weight(.semibold))
      Spacer()
      Label("No Driver", systemImage: "circle.fill")
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
      Text("MASTER LIVE")
        .font(.system(size: 8, weight: .bold))
      Toggle("", isOn: .constant(false)).labelsHidden().toggleStyle(.switch)
    }
    .font(.caption)
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, minHeight: 44)
    .background(StudioPalette.documentChrome)
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private func workspaceRibbonPreview(compact: Bool) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Label("RIG", systemImage: "point.3.connected.trianglepath.dotted")
          .font(.caption.weight(.bold))
        Divider().frame(height: 18)
        ForEach(["Structures", "Mates", "Motors", "Media"], id: \.self) { title in
          Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(title == "Structures" ? StudioPalette.semanticPart : .secondary)
        }
        Spacer()
        Image(systemName: compact ? "chevron.down" : "chevron.up")
      }
      .padding(.horizontal, 10)
      .frame(height: 32)
      .background(StudioPalette.chrome)

      if !compact {
        Divider()
        HStack(spacing: 8) {
          miniTool("Box", "cube", StudioPalette.semanticPart)
          miniTool("Cylinder", "cylinder", StudioPalette.semanticPart)
          miniTool("Fastened", "link", StudioPalette.joint)
          miniTool("Revolute", "rotate.3d", StudioPalette.joint)
          miniTool("Servo", "capsule", StudioPalette.hardware, disabled: true)
          Spacer()
        }
        .padding(9)
      }
    }
    .background(StudioPalette.ribbonChrome)
    .clipShape(RoundedRectangle(cornerRadius: 7))
    .overlay { RoundedRectangle(cornerRadius: 7).stroke(StudioPalette.border, lineWidth: 1) }
  }

  private func navigatorPreview(populated: Bool) -> some View {
    panelShell(title: "Components", systemImage: "cube") {
      if populated {
        VStack(alignment: .leading, spacing: 7) {
          treeRow("Untitled Character", "shippingbox", level: 0)
          treeRow("Head Assembly", "folder.fill", level: 1, selected: true)
          treeRow("Head", "sphere", level: 2)
          treeRow("Jaw", "cube", level: 2)
          Text("MATES").font(.caption2.bold()).foregroundStyle(StudioPalette.muted)
          treeRow("Head Yaw", "link", level: 1)
          Text("ASSETS").font(.caption2.bold()).foregroundStyle(StudioPalette.muted)
          treeRow("robot.usdz", "shippingbox", level: 1)
        }
      } else {
        VStack(spacing: 9) {
          Image(systemName: "cube.transparent")
            .font(.title)
            .foregroundStyle(StudioPalette.muted)
          Text("No components yet").font(.caption.weight(.semibold))
          Button("Add Component", systemImage: "plus") {}
            .buttonStyle(StudioButtonStyle(role: .primary, density: .compact))
        }
        .frame(maxWidth: .infinity, minHeight: 150)
      }
    }
  }

  private var agentPreview: some View {
    panelShell(title: "Anima Agent", systemImage: "sparkles") {
      VStack(alignment: .leading, spacing: 9) {
        HStack(spacing: 8) {
          ForEach(["mic", "bubble.left", "book", "lightbulb"], id: \.self) { image in
            Image(systemName: image).frame(maxWidth: .infinity)
          }
        }
        Text("I can help inspect the rig, explain controls, and draft animation changes.")
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
        ForEach(["What is selected?", "Explain this mate", "Draft a motion"], id: \.self) {
          prompt in
          Text(prompt)
            .font(.caption2)
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 12))
        }
        Spacer(minLength: 10)
        HStack {
          Text("Ask Anima…").foregroundStyle(StudioPalette.muted)
          Spacer()
          Image(systemName: "paperplane.fill")
        }
        .font(.caption2)
        .padding(8)
        .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  private enum InspectorKind { case component, mate, appearance, hardware }

  private func inspectorPreview(kind: InspectorKind) -> some View {
    let title: String =
      switch kind {
      case .component: "Component"
      case .mate: "Mate"
      case .appearance: "Appearance"
      case .hardware: "Hardware"
      }
    let image: String =
      switch kind {
      case .component: "cube"
      case .mate: "link"
      case .appearance: "paintpalette"
      case .hardware: "cable.connector"
      }

    return panelShell(title: title, systemImage: image) {
      VStack(alignment: .leading, spacing: 8) {
        switch kind {
        case .component:
          miniField("Name", "Head Assembly")
          miniField("Position", "0.00  1.45  0.00 m")
          miniField("Rotation", "0°  0°  0°")
          Toggle("Visible", isOn: .constant(true)).toggleStyle(.switch)
        case .mate:
          miniField("Type", "Revolute")
          miniField("Connector A", "Head · center")
          miniField("Connector B", "Torso · top")
          miniField("Rotation", "0 deg")
          Toggle("Limits", isOn: .constant(true)).toggleStyle(.switch)
        case .appearance:
          HStack(spacing: 4) {
            ForEach([Color.red, .orange, .yellow, .green, .blue, .purple], id: \.self) { color in
              color.frame(maxWidth: .infinity, minHeight: 18).clipShape(
                RoundedRectangle(cornerRadius: 2))
            }
          }
          miniField("Hex", "#9DCFED")
          miniField("Opacity", "100 %")
          miniField("Quality", "Auto")
        case .hardware:
          statusLine("Driver", "No Driver", .secondary)
          statusLine("Master Live", "Disarmed", StudioPalette.hardware)
          miniField("Device", "None")
          miniField("Heartbeat", "—")
          Button("Connect Device", systemImage: "link") {}
            .buttonStyle(StudioButtonStyle(role: .primary, density: .compact))
            .disabled(true)
        }
      }
    }
  }

  private enum TimelineKind { case dopeSheet, curves, show, empty }

  private func timelinePreview(kind: TimelineKind) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        Image(systemName: "backward.end.fill")
        Image(systemName: "play.fill")
        Image(systemName: "forward.end.fill")
        Spacer()
        Text(kind == .show ? "00:01:12.08" : "F072 / F240")
          .font(.system(size: 8, weight: .bold, design: .monospaced))
      }
      .font(.system(size: 8))
      .padding(.horizontal, 8)
      .frame(height: 25)
      .background(StudioPalette.chrome)

      Divider()

      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 0) {
          timelineLabel("Summary")
          if kind != .empty {
            ForEach(timelineRows(for: kind), id: \.self) { timelineLabel($0) }
          }
        }
        .frame(width: max(cardWidth * 0.30, 74))

        Divider()

        Canvas { context, size in
          for tick in 0...12 {
            let x = CGFloat(tick) * size.width / 12
            var grid = Path()
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(grid, with: .color(.white.opacity(0.07)), lineWidth: 1)
          }

          guard kind != .empty else { return }
          let points = [
            CGPoint(x: size.width * 0.14, y: size.height * 0.25),
            CGPoint(x: size.width * 0.45, y: size.height * 0.62),
            CGPoint(x: size.width * 0.78, y: size.height * 0.36),
          ]
          var motion = Path()
          motion.move(to: points[0])
          if kind == .curves {
            motion.addCurve(
              to: points[1], control1: CGPoint(x: points[0].x + 25, y: points[0].y),
              control2: CGPoint(x: points[1].x - 25, y: points[1].y))
            motion.addCurve(
              to: points[2], control1: CGPoint(x: points[1].x + 25, y: points[1].y),
              control2: CGPoint(x: points[2].x - 25, y: points[2].y))
          } else {
            motion.addLines(Array(points.dropFirst()))
          }
          context.stroke(motion, with: .color(StudioPalette.accent), lineWidth: 1.5)
          for point in points {
            let marker = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
            context.fill(Path(marker), with: .color(StudioPalette.accent))
          }
          let playheadX = size.width * 0.32
          var playhead = Path()
          playhead.move(to: CGPoint(x: playheadX, y: 0))
          playhead.addLine(to: CGPoint(x: playheadX, y: size.height))
          context.stroke(playhead, with: .color(.blue), lineWidth: 1.5)
        }
        .background(Color.black.opacity(0.14))
      }

      if kind == .empty {
        Button("Add First Track", systemImage: "plus") {}
          .buttonStyle(StudioButtonStyle(role: .primary, density: .compact))
          .padding(8)
      }
    }
    .background(StudioPalette.panel)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay { RoundedRectangle(cornerRadius: 6).stroke(StudioPalette.border, lineWidth: 1) }
  }

  private enum ToolbarState { case defaultState, selected, disabled }

  private func toolbarPreview(state: ToolbarState) -> some View {
    HStack(spacing: 6) {
      ForEach(
        [("Move", "move.3d"), ("Rotate", "rotate.3d"), ("Mate", "link"), ("Key", "diamond")],
        id: \.0
      ) { title, image in
        VStack(spacing: 4) {
          Image(systemName: image)
          Text(title).font(.system(size: 8))
        }
        .foregroundStyle(state == .disabled ? StudioPalette.muted : Color.primary)
        .padding(7)
        .background(
          state == .selected && title == "Rotate"
            ? StudioPalette.accent.opacity(0.28) : Color.clear,
          in: RoundedRectangle(cornerRadius: 5)
        )
        .opacity(state == .disabled ? 0.42 : 1)
      }
      Divider().frame(height: 30)
      miniTool(
        "Display", "cube.transparent", StudioPalette.sourceModel, disabled: state == .disabled)
      Spacer()
    }
    .padding(7)
    .background(StudioPalette.chrome, in: RoundedRectangle(cornerRadius: 7))
    .overlay { RoundedRectangle(cornerRadius: 7).stroke(StudioPalette.border, lineWidth: 1) }
  }

  private var verticalToolRailPreview: some View {
    VStack(spacing: 8) {
      ForEach(
        ["cursorarrow", "move.3d", "rotate.3d", "cube", "link", "paintpalette", "gearshape"],
        id: \.self
      ) { image in
        Image(systemName: image)
          .frame(width: 26, height: 26)
          .background(
            image == "link" ? StudioPalette.accent.opacity(0.25) : StudioPalette.panelInset,
            in: RoundedRectangle(cornerRadius: 5)
          )
      }
    }
    .padding(8)
    .background(StudioPalette.chrome, in: RoundedRectangle(cornerRadius: 7))
    .overlay { RoundedRectangle(cornerRadius: 7).stroke(StudioPalette.border, lineWidth: 1) }
  }

  private func dialogPreview(destructive: Bool) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(
        destructive ? "Remove Head Yaw?" : "Model Could Not Be Imported",
        systemImage: destructive ? "trash" : "info.circle"
      )
      .font(.caption.weight(.bold))
      Text(
        destructive
          ? "The mate and its animation tracks will be removed."
          : "Choose a supported USD, USDZ, or RealityKit model."
      )
      .font(.caption2)
      .foregroundStyle(StudioPalette.muted)
      HStack {
        Spacer()
        if destructive {
          Button("Cancel") {}.buttonStyle(StudioButtonStyle(role: .secondary, density: .compact))
        }
        Button(destructive ? "Remove" : "OK") {}
          .buttonStyle(
            StudioButtonStyle(role: destructive ? .destructive : .primary, density: .compact)
          )
      }
    }
    .padding(12)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 9))
    .overlay { RoundedRectangle(cornerRadius: 9).stroke(StudioPalette.border, lineWidth: 1) }
  }

  private var graphicsPopoverPreview: some View {
    panelShell(title: "Graphics", systemImage: "cube.transparent") {
      VStack(alignment: .leading, spacing: 8) {
        miniField("Projection", "Perspective")
        miniField("Surface", "Shaded with Edges")
        miniField("Lighting", "Studio")
        Toggle("Shadows", isOn: .constant(true)).toggleStyle(.switch)
        Toggle("Reflections", isOn: .constant(true)).toggleStyle(.switch)
      }
    }
  }

  private var contextMenuPreview: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(
        [
          "Properties", "Show Mates", "Hide Component", "Isolate…", "Make Transparent…",
          "Zoom to Selection", "Edit Appearance…", "Delete Component",
        ],
        id: \.self
      ) { command in
        if command == "Hide Component" || command == "Zoom to Selection"
          || command == "Delete Component"
        {
          Divider()
        }
        Text(command)
          .font(.caption2)
          .foregroundStyle(command == "Delete Component" ? Color.red : Color.primary)
          .padding(.horizontal, 9)
          .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
      }
    }
    .padding(.vertical, 5)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 8))
    .overlay { RoundedRectangle(cornerRadius: 8).stroke(StudioPalette.border, lineWidth: 1) }
  }

  private enum StatusKind { case empty, working, connected, emergency }

  private func statusPreview(kind: StatusKind) -> some View {
    let presentation: (title: String, detail: String, image: String, color: Color) =
      switch kind {
      case .empty:
        (
          "Start building the rig", "Add a component or import an existing model.",
          "cube.transparent", StudioPalette.muted
        )
      case .working:
        (
          "Importing robot.usdz", "Resolving model hierarchy and materials…",
          "arrow.triangle.2.circlepath", StudioPalette.accent
        )
      case .connected:
        (
          "Hardware connected", "Controller heartbeat is healthy.", "checkmark.circle.fill",
          StudioPalette.semanticPart
        )
      case .emergency:
        ("EMERGENCY STOP", "Motion output is disabled until reset.", "stop.fill", Color.red)
      }

    return VStack(spacing: 9) {
      Image(systemName: presentation.image)
        .font(.title2)
        .foregroundStyle(presentation.color)
      Text(presentation.title)
        .font(.caption.weight(.bold))
      Text(presentation.detail)
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
        .multilineTextAlignment(.center)
      if kind == .working {
        ProgressView(value: 0.62).progressViewStyle(.linear)
      } else if kind == .emergency {
        Button("Reset E-Stop") {}
          .buttonStyle(StudioButtonStyle(role: .destructive, density: .compact))
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 120)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 9))
    .overlay {
      RoundedRectangle(cornerRadius: 9)
        .stroke(
          kind == .emergency ? Color.red : StudioPalette.border,
          lineWidth: kind == .emergency ? 2 : 1)
    }
  }

  private func panelShell<Content: View>(
    title: String,
    systemImage: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(spacing: 0) {
      HStack {
        Label(title, systemImage: systemImage).font(.caption.weight(.bold))
        Spacer()
        Image(systemName: "ellipsis")
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(.horizontal, 9)
      .frame(height: 30)
      .background(StudioPalette.chrome)
      Divider()
      content()
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .background(StudioPalette.panel)
    .clipShape(RoundedRectangle(cornerRadius: 7))
    .overlay { RoundedRectangle(cornerRadius: 7).stroke(StudioPalette.border, lineWidth: 1) }
  }

  private func miniTool(
    _ title: String,
    _ image: String,
    _ color: Color,
    disabled: Bool = false
  ) -> some View {
    VStack(spacing: 3) {
      Image(systemName: image).foregroundStyle(color)
      Text(title).font(.system(size: 7))
    }
    .padding(5)
    .opacity(disabled ? 0.35 : 1)
  }

  private func treeRow(
    _ title: String,
    _ image: String,
    level: Int,
    selected: Bool = false
  ) -> some View {
    HStack(spacing: 6) {
      Image(systemName: image).foregroundStyle(StudioPalette.semanticPart)
      Text(title).lineLimit(1)
      Spacer()
    }
    .font(.caption2)
    .padding(.leading, CGFloat(level) * 12)
    .padding(.horizontal, 6)
    .frame(height: 24)
    .background(selected ? StudioPalette.accent.opacity(0.28) : Color.clear)
    .clipShape(RoundedRectangle(cornerRadius: 4))
  }

  private func miniField(_ title: String, _ value: String) -> some View {
    HStack {
      Text(title).foregroundStyle(StudioPalette.muted)
      Spacer()
      Text(value).lineLimit(1)
    }
    .font(.caption2)
    .padding(.horizontal, 7)
    .frame(height: 25)
    .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 5))
  }

  private func statusLine(_ title: String, _ value: String, _ color: Color) -> some View {
    HStack {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(title).font(.caption2)
      Spacer()
      Text(value).font(.caption2.weight(.semibold)).foregroundStyle(color)
    }
  }

  private func timelineLabel(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 8))
      .lineLimit(1)
      .padding(.horizontal, 6)
      .frame(maxWidth: .infinity, minHeight: 25, alignment: .leading)
      .background(StudioPalette.panelInset)
  }

  private func timelineRows(for kind: TimelineKind) -> [String] {
    switch kind {
    case .show: ["Audio", "Character", "Events"]
    case .dopeSheet, .curves: ["Head Yaw", "Jaw", "Eyes"]
    case .empty: []
    }
  }

}
