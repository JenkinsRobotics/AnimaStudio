import SwiftUI

// MARK: - Show / scene sequencing + node graph + media

/// Show has no engine-backed model of its own, but its selection and sidebar
/// state still have to survive the float/dock flip that rebuilds the view.
@MainActor @Observable final class ShowModel {
  static let shared = ShowModel()

  var selectedNode: String? = "Clip"
  let showPanels = PanelStackState(
    order: ["Scenes", "Nodes"],
    defaults: [], side: .left)
}

struct ShowWorkspace: View {
  private var show: ShowModel { ShowModel.shared }

  private var selectedNode: String? { show.selectedNode }

  var body: some View {
    // Show is a node graph, not a 3D scene, so the view cube is suppressed.
    WorkspaceScaffold(
      toolGroups: ShowTools.groups,
      toolOverflow: ShowTools.overflow,
      toolArmGroup: ShowTools.armGroup,
      // Scenes list, then Nodes — the graph's own contents get a sidebar home.
      leftTabs: [SidebarTab("Scenes", "rectangle.3.group"),
                 SidebarTab("Nodes", "point.3.connected.trianglepath.dotted")],
      leftPanels: show.showPanels,
    ) {
      center
    } left: { tab in
      if tab == "Scenes" { scenesTab } else { nodesTab }
    } inspector: {
      nodeInspector
    }
  }

  @ViewBuilder private var scenesTab: some View {
    VStack(spacing: 0) {
      Row(icon: "play.rectangle", label: "Intro", detail: "0:12", tint: UI.warn, selected: true)
      Row(icon: "play.rectangle", label: "Greeting", detail: "0:30")
      Row(icon: "play.rectangle", label: "Idle loop", detail: "∞")
      Row(icon: "play.rectangle", label: "Roar", detail: "0:08")
      Row(icon: "play.rectangle", label: "Goodbye", detail: "0:15")
      Divider().overlay(UI.stroke).padding(.top, 4)
      Button {} label: {
        HStack { Image(systemName: "plus"); Text("Add scene") }
          .font(.system(size: 12, weight: .medium)).foregroundStyle(UI.warn)
          .frame(maxWidth: .infinity).padding(.vertical, 10)
      }.buttonStyle(.plain)
    }
  }

  /// The Intro scene's nodes — same set the graph draws, selectable from here.
  @ViewBuilder private var nodesTab: some View {
    VStack(spacing: 0) {
      ForEach([("Trigger", "sensor.tag.radiowaves.forward", "Motion sensor"),
               ("Clip", "waveform.path", "Greeting.anim"),
               ("Servos", "cpu", "6 channels"),
               ("Audio", "speaker.wave.2", "hello.wav"),
               ("Video", "play.tv", "eyes.mov")], id: \.0) { name, icon, detail in
        ListRow(icon: icon, title: name, detail: detail,
          selected: show.selectedNode == name,
          onTap: { withAnimation(.spring(response: 0.3)) { show.selectedNode = name } })
      }
    }
  }

  /// What the View sidebar's Inspector tab shows here — the selected node.
  @ViewBuilder private var nodeInspector: some View {
    if let node = show.selectedNode {
      Text(node.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.6)
        .foregroundStyle(UI.text3)
      nodeControls(node)
    } else {
      Text("No selection").font(.system(size: 11)).foregroundStyle(UI.text3)
        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 18)
    }
  }

  // MARK: Center

  private var center: some View {
    // Node graph (plain edge-to-edge canvas). The scaffold supplies the tool and
    // view sidebars; the tray's node/output ACTIONS now live in ShowTools.
    ZStack {
      UI.inset
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(response: 0.3)) { show.selectedNode = nil } }
      // dotted graph background
      GeometryReader { geo in
        Path { p in
          let step: CGFloat = 24
          var x: CGFloat = 0
          while x < geo.size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: geo.size.height)); x += step }
          var y: CGFloat = 0
          while y < geo.size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y)); y += step }
        }.stroke(UI.stageGrid, lineWidth: 1)
      }
      // The scene's nodes — boxed as a group, not the whole canvas
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 6) {
          Image(systemName: "rectangle.3.group").font(.system(size: 10, weight: .semibold))
            .foregroundStyle(UI.text3)
          Text("Scene · Intro").font(.system(size: 10.5, weight: .semibold)).tracking(0.3)
            .foregroundStyle(UI.text2)
        }
        HStack(spacing: 44) {
          node("Trigger", "sensor.tag.radiowaves.forward", "Motion sensor", UI.ok)
          node("Clip", "waveform.path", "Greeting.anim", UI.accent)
          VStack(spacing: 20) {
            node("Servos", "cpu", "6 channels", UI.accent2, compact: true)
            node("Audio", "speaker.wave.2", "hello.wav", UI.warn, compact: true)
            node("Video", "play.tv", "eyes.mov", UI.warn, compact: true)
          }
        }
      }
      .padding(20)
      .background(UI.panel.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(UI.strokeHi, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
    }
  }

  // The dynamic right-panel controls, different for each node type.
  @ViewBuilder func nodeControls(_ node: String) -> some View {
    switch node {
    case "Trigger":
      Field(label: "Source", value: "Motion")
      Field(label: "Threshold", value: "40", unit: "%")
      Field(label: "Debounce", value: "250", unit: "ms")
      Field(label: "Enabled", value: "Yes")
    case "Clip":
      Field(label: "Clip", value: "Greeting")
      Field(label: "Length", value: "0:30")
      Field(label: "Speed", value: "1.0×")
      Field(label: "Loop", value: "Off")
    case "Servos":
      Field(label: "Bus", value: "PCA9685")
      Field(label: "Channels", value: "6")
      Field(label: "Rate", value: "50", unit: "Hz")
      Field(label: "Armed", value: "Yes")
    case "Audio":
      Field(label: "File", value: "hello.wav")
      Field(label: "Volume", value: "80", unit: "%")
      Field(label: "Output", value: "L / R")
    case "Video":
      Field(label: "File", value: "eyes.mov")
      Field(label: "Loop", value: "On")
      Field(label: "Output", value: "HDMI-1")
    default:
      Field(label: "—", value: "—")
    }
  }

  func node(_ title: String, _ icon: String, _ sub: String, _ tint: Color, compact: Bool = false) -> some View {
    GraphNode(title: title, icon: icon, sub: sub, tint: tint, width: 150,
      selected: selectedNode == title,
      onTap: { withAnimation(.spring(response: 0.3)) { show.selectedNode = title } })
  }

  func bindingRow(_ icon: String, _ name: String, _ detail: String, _ tint: Color, _ status: String, _ statusTint: Color) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon).font(.system(size: 14)).foregroundStyle(tint).frame(width: 20)
      VStack(alignment: .leading, spacing: 2) {
        Text(name).font(.system(size: 12)).foregroundStyle(UI.text)
        Text(detail).font(.system(size: 10)).foregroundStyle(UI.text3)
      }
      Spacer()
      Text(status).font(.system(size: 9.5, weight: .medium)).foregroundStyle(statusTint)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(statusTint.opacity(0.14), in: Capsule())
    }
  }

  func mediaChip(_ name: String, _ icon: String) -> some View {
    HStack(spacing: 5) {
      Image(systemName: icon).font(.system(size: 11)).foregroundStyle(UI.warn)
      Text(name).font(.system(size: 10.5)).foregroundStyle(UI.text2)
    }
    .padding(.horizontal, 9).padding(.vertical, 6)
    .background(UI.panelHi, in: RoundedRectangle(cornerRadius: 7))
  }
}

// MARK: - Show tool catalog

/// Show's tool catalog for the shared ToolSidebar — nodes · output · edit. Every
/// former center-tray ACTION (Scene, Trigger, Audio, Video, Sequence) was already
/// a ribbon tool, so retiring the tray needs no new entries here.
enum ShowTools {
  static let groups: [ToolGroup] = [
    ToolGroup("Nodes", [
      RibbonTool("rectangle.3.group", "Scene"),
      RibbonTool("sensor.tag.radiowaves.forward", "Trigger"),
      RibbonTool("waveform.path", "Clip"),
    ]),
    ToolGroup("Output", [
      RibbonTool("speaker.wave.2", "Audio"), RibbonTool("play.tv", "Video"),
      RibbonTool("light.max", "Light"),
    ]),
    ToolGroup("Edit", [
      RibbonTool("cursorarrow", "Select"), RibbonTool("list.number", "Sequence"),
    ]),
  ]

  static let overflow: [RibbonTool] = []
  static let armGroup = RibbonGroup("Show", "rectangle.3.group", .accentColor, [])
}

// MARK: - Hardware / live servo control bound to the real rig

/// Hardware's tool catalog for the shared ToolSidebar — wire · tune. The center
/// tray's ACTIONS (Arm, Home) were already ribbon tools, so retiring the tray
/// loses nothing.
enum HardwareTools {
  static let groups: [ToolGroup] = [
    ToolGroup("Wire", [
      RibbonTool("link", "Bind"), RibbonTool("bolt.fill", "Arm"), RibbonTool("house", "Home"),
    ]),
    ToolGroup("Tune", [
      RibbonTool("wrench.and.screwdriver", "Calibrate"), RibbonTool("play", "Test"),
      RibbonTool("waveform.path.ecg", "Monitor"),
    ]),
  ]

  static let overflow: [RibbonTool] = []
  static let armGroup = RibbonGroup("Hardware", "cpu", .accentColor, [])
}

struct HardwareWorkspace: View {
  private var hw: HardwareModel { HardwareModel.shared }
  private var rig: RigModel { RigModel.shared }
  private var anim: AnimationModel { AnimationModel.shared }

  var body: some View {
    // Hardware is a wiring graph + servo readout, not a 3D scene, so the view
    // cube is suppressed.
    WorkspaceScaffold(
      toolGroups: HardwareTools.groups,
      toolOverflow: HardwareTools.overflow,
      toolArmGroup: HardwareTools.armGroup,
      leftTabs: [SidebarTab("Controller", "cpu"),
                 SidebarTab("Channels", "slider.horizontal.3")],
      leftPanels: hw.hardwarePanels,
    ) {
      center
    } left: { tab in
      if tab == "Controller" { controllerTab } else { channelsTab }
    } inspector: {
      inspector
    }
    .onAppear { hw.sync() }
    .onChange(of: rig.mates.count) { _, _ in hw.sync() }
  }

  @ViewBuilder private var controllerTab: some View {
    VStack(spacing: 0) {
      Text(hw.armed ? "ARMED" : "DISARMED").font(.system(size: 8.5, weight: .medium)).tracking(0.4)
        .foregroundStyle(hw.armed ? UI.danger : UI.text3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.bottom, 3)
      ListRow(icon: "cpu", title: hw.controllerName, detail: "USB",
        selected: hw.controllerSelected,
        statusColor: hw.armed ? UI.danger : UI.ok,
        onTap: { hw.controllerSelected = true })
    }
  }

  /// Channels bound to the rig's driven mates.
  @ViewBuilder private var channelsTab: some View {
    VStack(spacing: 0) {
      Text("\(hw.channels.count) BOUND").font(.system(size: 8.5, weight: .medium)).tracking(0.4)
        .foregroundStyle(UI.text3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.bottom, 3)
      if hw.channels.isEmpty {
        Text("Author driven mates in Rig — each one binds to a servo channel.")
          .font(.system(size: 10)).foregroundStyle(UI.text3)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity).padding(.vertical, 18).padding(.horizontal, 12)
      }
      ForEach(hw.channels) { channel in
        ListRow(icon: "slider.horizontal.3", title: channel.name,
          detail: "CH\(channel.channel)",
          selected: !hw.controllerSelected && hw.selectedChannelID == channel.id,
          statusColor: hw.armed ? UI.ok : nil,
          onTap: { hw.selectedChannelID = channel.id; hw.controllerSelected = false })
      }
    }
  }

  /// Controller state, or per-servo calibration once a channel is picked.
  @ViewBuilder private var inspector: some View {
    if hw.controllerSelected || hw.selectedChannel == nil {
      controllerInspector
    } else {
      CalibrateInspectorHost()
    }
  }

  // MARK: Center

  private var center: some View {
    VStack(spacing: 0) {
      ZStack {
        UI.inset
        GeometryReader { geo in
          Path { p in
            let step: CGFloat = 24
            var x: CGFloat = 0
            while x < geo.size.width {
              p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: geo.size.height)); x += step
            }
            var y: CGFloat = 0
            while y < geo.size.height {
              p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y)); y += step
            }
          }.stroke(UI.stageGrid, lineWidth: 1)
        }
        .allowsHitTesting(false)
        graph
      }
      .frame(maxHeight: .infinity)
      servoTimeline.frame(height: 210).padding(12)
    }
  }

  // ---- center: controller wired to each bound servo --------------------------
  private var graph: some View {
    HStack(alignment: .top, spacing: 40) {
      GraphNode(title: hw.controllerName, icon: "cpu", sub: "USB · Wire v0",
        tint: hw.armed ? UI.danger : UI.ok, width: 150, big: true,
        selected: hw.controllerSelected,
        badge: (hw.armed ? "Armed" : "Disarmed", hw.armed),
        onTap: { hw.controllerSelected = true })
      if hw.channels.isEmpty {
        Text("No channels bound").font(.system(size: 11)).foregroundStyle(UI.text3)
          .padding(.top, 20)
      } else {
        LazyVGrid(
          columns: [GridItem(.fixed(140), spacing: 12), GridItem(.fixed(140), spacing: 12)],
          alignment: .leading, spacing: 12
        ) {
          ForEach(hw.channels) { channel in
            GraphNode(title: channel.name, icon: "slider.horizontal.3",
              sub: "CH\(channel.channel) · \(Int(hw.degrees(channel)))°",
              tint: UI.accent2, width: 140,
              selected: !hw.controllerSelected && hw.selectedChannelID == channel.id,
              onTap: { hw.selectedChannelID = channel.id; hw.controllerSelected = false })
          }
        }.frame(width: 292)
      }
    }
    .padding(22)
    .background(UI.panel.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(UI.strokeHi, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
  }

  // ---- bottom: live servo positions (driven by animation playback) -----------
  private var servoTimeline: some View {
    PanelCard(title: "Servos", subtitle: anim.isPlaying ? "live · playing" : "live",
      icon: "slider.horizontal.below.rectangle", tint: UI.accent2) {
      ScrollView {
        VStack(spacing: 0) {
          if hw.channels.isEmpty {
            Text("Bound channels appear here once the rig has driven mates.")
              .font(.system(size: 10.5)).foregroundStyle(UI.text3)
              .frame(maxWidth: .infinity).padding(.vertical, 24)
          }
          ForEach(hw.channels) { channel in
            ServoTrack(name: channel.name, channel: channel.channel,
              degrees: hw.degrees(channel), fraction: hw.fraction(channel),
              selected: !hw.controllerSelected && hw.selectedChannelID == channel.id,
              armed: hw.armed,
              onTap: { hw.selectedChannelID = channel.id; hw.controllerSelected = false })
            Divider().overlay(UI.stroke.opacity(0.5))
          }
        }
      }
    }
  }

  // ---- right: controller state ------------------------------------------------
  // No PanelCard here — the View sidebar's Inspector panel already draws the
  // header and chrome this used to supply.
  @ViewBuilder private var controllerInspector: some View {
    Text("\(hw.controllerName) · CONTROLLER").font(.system(size: 8.5, weight: .medium))
      .tracking(0.4).foregroundStyle(hw.armed ? UI.danger : UI.text3)
    PropertyField(label: "Protocol", value: "Wire v0")
    PropertyField(label: "Channels", value: "\(hw.channels.count)")
    PropertyField(label: "Rate", value: "50", unit: "Hz")
    Divider().overlay(UI.stroke)
    Button { withAnimation(.easeInOut(duration: 0.15)) { hw.armed.toggle() } } label: {
      HStack(spacing: 6) {
        Image(systemName: hw.armed ? "bolt.fill" : "bolt.slash.fill")
        Text(hw.armed ? "ARMED — live" : "DISARMED").font(.system(size: 12.5, weight: .bold))
      }
      .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 11)
      .background(hw.armed ? UI.danger : UI.panelHi, in: RoundedRectangle(cornerRadius: 10))
    }.buttonStyle(.plain)
    Text(hw.armed ? "Motion is being sent to hardware." : "Safe. Servos hold last position.")
      .font(.system(size: 10)).foregroundStyle(hw.armed ? UI.danger : UI.text3)
      .fixedSize(horizontal: false, vertical: true)
  }
}

// Per-servo calibration, bound to the real channel + mate. Chrome-free: it is
// hosted by the View sidebar's Inspector panel, which supplies the header.
struct CalibrateInspectorHost: View {
  @Bindable private var hw = HardwareModel.shared

  var body: some View {
    if let index = hw.channels.firstIndex(where: { $0.id == hw.selectedChannelID }) {
      let channel = hw.channels[index]
      VStack(alignment: .leading, spacing: 11) {
        Text("\(channel.name) · CH\(channel.channel)".uppercased())
          .font(.system(size: 8.5, weight: .medium)).tracking(0.4).foregroundStyle(UI.text3)
        PropertyField(label: "Live angle", value: String(format: "%.1f", hw.degrees(channel)), unit: "°")
        PropertyField(label: "Pulse", value: String(format: "%.0f", hw.pulse(channel)), unit: "µs")
        Divider().overlay(UI.stroke)
        StepperField(label: "Trim", value: $hw.channels[index].trimDegrees, step: 1, unit: "°")
        Toggle("Invert direction", isOn: $hw.channels[index].inverted).font(.system(size: 11.5))
        StepperField(label: "Min pulse", value: $hw.channels[index].minPulse, step: 50, unit: "µs")
        StepperField(label: "Max pulse", value: $hw.channels[index].maxPulse, step: 50, unit: "µs")
        Divider().overlay(UI.stroke)
        Button { hw.setDegrees(channel, to: 0) } label: {
          HStack(spacing: 6) { Image(systemName: "house"); Text("Home this servo") }
            .font(.system(size: 11.5, weight: .medium)).foregroundStyle(UI.accent)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(UI.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
      }
    }
  }
}
