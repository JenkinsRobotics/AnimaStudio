import SwiftUI

// MARK: - Show / scene sequencing + node graph + media

struct ShowWorkspace: View {
  @State private var selectedNode: String? = "Clip"
  private var layout: LayoutState { LayoutState.shared }
  var body: some View {
    VStack(spacing: 0) {
      if layout.ribbonDocked {
        ToolRibbon(groups: showTools)
        Divider().overlay(UI.stroke)
      }
      FloatingWorkspace(leftWidth: 210, rightWidth: 260, edgeToEdge: true, rightSelected: selectedNode != nil) {
      // Left — scene list
      Panel(title: "Scenes", systemImage: "rectangle.3.group") {
        ScrollView {
          VStack(spacing: 0) {
            Row(icon: "play.rectangle", label: "Intro", detail: "0:12", tint: UI.warn, selected: true)
            Row(icon: "play.rectangle", label: "Greeting", detail: "0:30")
            Row(icon: "play.rectangle", label: "Idle loop", detail: "∞")
            Row(icon: "play.rectangle", label: "Roar", detail: "0:08")
            Row(icon: "play.rectangle", label: "Goodbye", detail: "0:15")
          }.padding(.vertical, 4)
        }
        Divider().overlay(UI.stroke)
        Button {} label: {
          HStack { Image(systemName: "plus"); Text("Add scene") }
            .font(.system(size: 12, weight: .medium)).foregroundStyle(UI.warn)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
        }.buttonStyle(.plain)
      }
    } center: {
      // Center — node graph (plain edge-to-edge canvas) with floating chrome
      ZStack(alignment: .bottom) {
        ZStack {
          UI.inset
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.spring(response: 0.3)) { selectedNode = nil } }
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
        CenterTray(items: [
          TrayItem("plus", "Scene"),
          TrayItem("sensor.tag.radiowaves.forward", "Trigger"),
          TrayItem("speaker.wave.2", "Audio"),
          TrayItem("play.tv", "Video"),
          TrayItem("list.number", "Sequence"),
        ])
        .padding(.bottom, 18)
      }
      .overlay(alignment: .top) {
        if !layout.ribbonDocked { ToolRibbon(groups: showTools).padding(.top, 16) }
      }
    } right: {
      // Right — controls for the selected node (auto-hides when nothing selected)
      Panel(title: selectedNode.map { "\($0) · node" } ?? "No selection",
        systemImage: "slider.horizontal.3") {
        VStack(alignment: .leading, spacing: 9) {
          nodeControls(selectedNode ?? "Clip")
          Spacer()
        }
        .padding(14)
      }
      }
    }
  }

  // Show tool catalog — nodes · output · edit.
  private var showTools: [RibbonGroup] {
    [
      RibbonGroup("Nodes", "rectangle.3.group", .orange, [
        RibbonTool("rectangle.3.group", "Scene"),
        RibbonTool("sensor.tag.radiowaves.forward", "Trigger"),
        RibbonTool("waveform.path", "Clip"),
      ]),
      RibbonGroup("Output", "cable.connector.horizontal", .blue, [
        RibbonTool("speaker.wave.2", "Audio"), RibbonTool("play.tv", "Video"),
        RibbonTool("light.max", "Light"),
      ]),
      RibbonGroup("Edit", "cursorarrow", .teal, [
        RibbonTool("cursorarrow", "Select"), RibbonTool("list.number", "Sequence"),
      ]),
    ]
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
      onTap: { withAnimation(.spring(response: 0.3)) { selectedNode = title } })
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

// MARK: - Hardware / live servo control + calibration (Bottango's home turf)

struct HardwareWorkspace: View {
  @State private var armed = false
  @State private var selectedHW: String? = "Knee"   // the controller node, or a servo
  private let controller = "Teensy 4.1"
  let channels: [(String, Int, Double, Double)] = [
    ("Hip", 0, 42, 0.62), ("Knee", 1, 88, 0.78), ("Ankle", 2, 12, 0.40),
    ("Neck pan", 3, 95, 0.53), ("Neck tilt", 4, 60, 0.47), ("Jaw", 5, 25, 0.30),
  ]
  private var isController: Bool { selectedHW == controller }
  private var layout: LayoutState { LayoutState.shared }

  // Hardware tool catalog — wire · tune.
  private var hardwareTools: [RibbonGroup] {
    [
      RibbonGroup("Wire", "link", .green, [
        RibbonTool("link", "Bind"), RibbonTool("bolt.fill", "Arm"),
        RibbonTool("house", "Home"),
      ]),
      RibbonGroup("Tune", "wrench.and.screwdriver", .orange, [
        RibbonTool("wrench.and.screwdriver", "Calibrate"), RibbonTool("play", "Test"),
        RibbonTool("waveform.path.ecg", "Monitor"),
      ]),
    ]
  }

  var body: some View {
    VStack(spacing: 0) {
      if layout.ribbonDocked {
        ToolRibbon(groups: hardwareTools)
        Divider().overlay(UI.stroke)
      }
      // Top — Show-style: hardware list · robot preview · contextual inspector
      FloatingWorkspace(leftWidth: 220, rightWidth: 262, edgeToEdge: true,
        rightSelected: selectedHW != nil) {
        Panel(title: "Hardware", systemImage: "cpu") {
          ScrollView {
            VStack(spacing: 0) {
              Row(icon: "cpu", label: controller, detail: "USB", tint: UI.ok, selected: isController)
                .onTapGesture { select(controller) }
              ForEach(channels, id: \.0) { ch in
                Row(icon: "slider.horizontal.3", label: ch.0, detail: "CH\(ch.1)", indent: 14,
                  tint: UI.accent2, selected: selectedHW == ch.0)
                  .onTapGesture { select(ch.0) }
              }
            }.padding(.vertical, 4)
          }
        }
      } center: {
        VStack(spacing: 0) {
        ZStack(alignment: .bottom) {
          ZStack {
            UI.inset
              .contentShape(Rectangle())
              .onTapGesture { deselect() }
            GeometryReader { geo in
              Path { p in
                let step: CGFloat = 24
                var x: CGFloat = 0
                while x < geo.size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: geo.size.height)); x += step }
                var y: CGFloat = 0
                while y < geo.size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y)); y += step }
              }.stroke(UI.stageGrid, lineWidth: 1)
            }
            .allowsHitTesting(false)
            // Hardware node graph — the controller wired to each servo node.
            HStack(alignment: .top, spacing: 40) {
              hwNode(controller, "cpu", "USB · Wire v0", UI.ok, big: true)
              LazyVGrid(
                columns: [GridItem(.fixed(140), spacing: 12), GridItem(.fixed(140), spacing: 12)],
                alignment: .leading, spacing: 12
              ) {
                ForEach(channels, id: \.0) { ch in
                  hwNode(ch.0, "slider.horizontal.3", "CH\(ch.1) · \(Int(ch.2))°", UI.accent2)
                }
              }.frame(width: 292)
            }
            .padding(22)
            .background(UI.panel.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(UI.strokeHi, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
          }
          CenterTray(items: [
            TrayItem("link", "Bind"), TrayItem("bolt.fill", "Arm"),
            TrayItem("wrench.and.screwdriver", "Calibrate"),
            TrayItem("play", "Test"), TrayItem("house", "Home"),
          ])
          .padding(.bottom, 18)
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .top) {
          if !layout.ribbonDocked { ToolRibbon(groups: hardwareTools).padding(.top, 16) }
        }
        // Servo timeline lives in the center column so docked sidebars span full-height.
        servoTimeline.frame(height: 210).padding(12)
        }
      } right: {
        // Contextual: Controller state (node) or Calibrate state (servo)
        if isController { controllerInspector } else { calibrateInspector(selectedHW ?? "Knee") }
      }
    }
  }

  private func select(_ x: String) { withAnimation(.spring(response: 0.3)) { selectedHW = x } }
  private func deselect() { withAnimation(.spring(response: 0.3)) { selectedHW = nil } }

  // ---- bottom: servo "timeline" ---------------------------------------------
  var servoTimeline: some View {
    Panel(title: "Servos", systemImage: "slider.horizontal.below.rectangle") {
      ScrollView {
        VStack(spacing: 0) {
          ForEach(channels, id: \.0) { ch in
            servoTrack(ch.0, ch.1, ch.2, ch.3)
            Divider().overlay(UI.stroke.opacity(0.5))
          }
        }
      }
    }
  }

  func servoTrack(_ name: String, _ ch: Int, _ deg: Double, _ frac: Double) -> some View {
    ServoTrack(name: name, channel: ch, degrees: deg, fraction: frac,
      selected: selectedHW == name, armed: armed, onTap: { select(name) })
  }

  // ---- center: a hardware node (controller or servo) ------------------------
  func hwNode(_ title: String, _ icon: String, _ sub: String, _ tint: Color, big: Bool = false) -> some View {
    GraphNode(title: title, icon: icon, sub: sub, tint: tint, width: big ? 150 : 140, big: big,
      selected: selectedHW == title,
      badge: big ? (armed ? "Armed" : "Disarmed", armed) : nil,
      onTap: { select(title) })
  }

  // ---- right: controller node state -----------------------------------------
  var controllerInspector: some View {
    Panel(title: "\(controller) · controller", systemImage: "cpu") {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 10) {
          ZStack {
            Circle().fill(UI.ok.opacity(0.15)).frame(width: 42, height: 42)
            Image(systemName: "cpu.fill").foregroundStyle(UI.ok)
          }
          VStack(alignment: .leading, spacing: 2) {
            Text(controller).font(.system(size: 13, weight: .semibold)).foregroundStyle(UI.text)
            Text("USB · /dev/tty.usb").font(.system(size: 10)).foregroundStyle(UI.text3)
          }
        }
        VStack(spacing: 9) {
          Field(label: "Firmware", value: "v0.3.1")
          Field(label: "Protocol", value: "Wire v0")
          Field(label: "Rate", value: "50", unit: "Hz")
          Field(label: "Latency", value: "3.1", unit: "ms")
          Field(label: "Bus load", value: "38", unit: "%")
        }
        Divider().overlay(UI.stroke)
        Button { armed.toggle() } label: {
          HStack {
            Image(systemName: armed ? "bolt.fill" : "bolt.slash.fill")
            Text(armed ? "ARMED — live" : "DISARMED").font(.system(size: 13, weight: .bold))
          }
          .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
          .background(armed ? UI.danger : UI.panelHi, in: RoundedRectangle(cornerRadius: 10))
          .overlay(RoundedRectangle(cornerRadius: 10).stroke(armed ? UI.danger : UI.strokeHi, lineWidth: 1))
        }.buttonStyle(.plain)
        Text(armed ? "Motion is being sent to hardware." : "Safe. Servos hold last position.")
          .font(.system(size: 10)).foregroundStyle(armed ? UI.danger : UI.text3)
        Spacer()
      }
      .padding(14)
    }
  }

  // ---- right: per-servo calibrate state --------------------------------------
  func calibrateInspector(_ servo: String) -> some View {
    Panel(title: "Calibrate · \(servo)", systemImage: "wrench.and.screwdriver") {
      VStack(alignment: .leading, spacing: 14) {
        Text("MAP RANGE").font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(UI.text3)
        VStack(spacing: 9) {
          Field(label: "Model min", value: "−5", unit: "°")
          Field(label: "Model max", value: "140", unit: "°")
          Field(label: "µs min", value: "980", unit: "µs")
          Field(label: "µs max", value: "2000", unit: "µs")
        }
        calibBar
        Divider().overlay(UI.stroke)
        HStack(spacing: 8) {
          Pill(icon: "arrow.counterclockwise", label: "Invert")
          Pill(icon: "target", label: "Center")
        }
        Field(label: "Trim", value: "+2.0", unit: "°")
        Field(label: "Ease limit", value: "180", unit: "°/s")
        HStack(spacing: 6) {
          Image(systemName: "info.circle").foregroundStyle(UI.text3).font(.system(size: 11))
          Text("Trim per-unit; real servos drift a few %.").font(.system(size: 10)).foregroundStyle(UI.text3)
        }
        Spacer()
      }
      .padding(14)
    }
  }

  var calibBar: some View {
    VStack(spacing: 5) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(UI.panelHi).frame(height: 8)
          Capsule().fill(UI.accent2).frame(width: geo.size.width * 0.6, height: 8)
            .offset(x: geo.size.width * 0.1)
          ForEach([0.1, 0.7], id: \.self) { pos in
            Rectangle().fill(.white).frame(width: 2, height: 16).offset(x: geo.size.width * pos)
          }
        }
      }.frame(height: 16)
      HStack {
        Text("980µs").font(.system(size: 9)).foregroundStyle(UI.text3)
        Spacer()
        Text("2000µs").font(.system(size: 9)).foregroundStyle(UI.text3)
      }
    }
  }
}
