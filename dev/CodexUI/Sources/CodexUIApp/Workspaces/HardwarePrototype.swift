import SwiftUI

struct HardwarePrototype: View {
  @Bindable var model: PrototypeModel

  var body: some View {
    DockingWorkspace(
      model: model, leftTitle: "Hardware Rack", rightTitle: "Safety + Output",
      leftWidth: 250, rightWidth: 300
    ) {
      deviceBrowser
    } center: {
      VStack(spacing: 8) {
        HStack(spacing: 8) {
          MetricCard(
            title: "Devices", value: "3 / 3", caption: "All expected controllers online",
            color: .green)
          MetricCard(title: "Channels", value: "14", caption: "12 servo · 2 screen", color: .blue)
          MetricCard(
            title: "Frame Rate", value: "50 Hz", caption: "Median jitter 0.7 ms", color: .cyan)
          MetricCard(
            title: "Safety", value: "ARMED", caption: "Limits + heartbeat active", color: .orange)
        }
        channelMap.frame(maxHeight: .infinity)
      }
      .avoidsFloatingWorkspacePanels()
    } right: {
      safetyPanel
    }
  }

  private var deviceBrowser: some View {
    PrototypePanel("Hardware Rack", subtitle: "ATLAS · LOCAL NETWORK", icon: "cable.connector") {
      VStack(spacing: 2) {
        HStack {
          Image(systemName: "magnifyingglass")
          Text("Search devices")
        }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 9).frame(
          height: 30
        ).background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 5)).padding(8)
        PrototypeRow(
          icon: "externaldrive.connected.to.line.below", title: "Head Controller", detail: "USB",
          selected: true, statusColor: .green)
        PrototypeRow(
          icon: "point.3.connected.trianglepath.dotted", title: "PCA9685 · 0x40", detail: "12 ch",
          level: 1, statusColor: .green)
        PrototypeRow(
          icon: "externaldrive.connected.to.line.below", title: "Body Controller", detail: "UDP",
          statusColor: .green)
        PrototypeRow(
          icon: "gearshape.2", title: "DYNAMIXEL Bus", detail: "2", level: 1, statusColor: .green)
        PrototypeRow(icon: "display", title: "Chest Display", detail: "LAN", statusColor: .green)
        Divider().padding(.vertical, 5)
        PrototypeRow(icon: "wave.3.right", title: "Discover Devices")
        PrototypeRow(icon: "doc.text.magnifyingglass", title: "Driver Diagnostics")
        Spacer()
        HStack {
          Button("Connect All") {}
          Spacer()
          Button {
          } label: {
            Image(systemName: "arrow.clockwise")
          }
        }.padding(9)
      }
    }
  }

  private var channelMap: some View {
    PrototypePanel(
      "Channel Mapping", subtitle: "SEMANTIC MOTION → PHYSICAL OUTPUT",
      icon: "arrow.triangle.branch"
    ) {
      VStack(spacing: 0) {
        HStack {
          Text("MOTION").frame(maxWidth: .infinity, alignment: .leading)
          Text("DEVICE / CHANNEL").frame(width: 210, alignment: .leading)
          Text("RANGE").frame(width: 150, alignment: .leading)
          Text("LIVE").frame(width: 75)
        }.font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).padding(.horizontal, 12)
          .frame(height: 31).background(.black.opacity(0.12))
        ForEach(Array(channels.enumerated()), id: \.offset) { index, item in
          HStack {
            HStack {
              Circle().fill(item.color).frame(width: 7, height: 7)
              Text(item.motion)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(item.channel).frame(width: 210, alignment: .leading).foregroundStyle(.secondary)
            Text(item.range).font(.system(size: 9, design: .monospaced)).frame(
              width: 150, alignment: .leading)
            HStack {
              Capsule().fill(item.color.opacity(0.25)).frame(width: 52, height: 6).overlay(
                alignment: .leading
              ) { Capsule().fill(item.color).frame(width: 20 + CGFloat(index % 4) * 8, height: 6) }
            }.frame(width: 75)
          }
          .font(.system(size: 10)).padding(.horizontal, 12).frame(height: 39)
          .background(index.isMultiple(of: 2) ? Color.white.opacity(0.018) : .clear)
          .overlay(alignment: .bottom) { Divider().opacity(0.3) }
        }
        Spacer()
      }
    }
  }

  private var safetyPanel: some View {
    VStack(spacing: 8) {
      PrototypePanel(
        "Safety State", subtitle: "AUTHORITATIVE DEVICE LAYER", icon: "shield.checkered"
      ) {
        VStack(spacing: 9) {
          HStack {
            Image(systemName: "checkmark.shield.fill").font(.system(size: 27)).foregroundStyle(
              .green)
            VStack(alignment: .leading) {
              Text("System healthy").font(.system(size: 12, weight: .semibold))
              Text("Heartbeat received 18 ms ago").font(.system(size: 9)).foregroundStyle(
                .secondary)
            }
            Spacer()
          }
          safetyRow("Position limits", "Enforced", .green)
          safetyRow("Velocity limits", "Enforced", .green)
          safetyRow("Acceleration limits", "Preview", .orange)
          safetyRow("Heartbeat failsafe", "250 ms", .green)
          Button("EMERGENCY STOP") {}.buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
        }.padding(10)
      }
      PrototypePanel("Selected Output", subtitle: "HEAD PAN · SERVO 0", icon: "slider.horizontal.3")
      {
        VStack(spacing: 8) {
          PropertyField(label: "Protocol", value: "PWM")
          PropertyField(label: "Minimum", value: "850", unit: "µs")
          PropertyField(label: "Neutral", value: "1500", unit: "µs")
          PropertyField(label: "Maximum", value: "2150", unit: "µs")
          HStack {
            Button("Test -") {}
            Button("Neutral") {}
            Button("Test +") {}
          }
        }.padding(10)
      }
      Spacer(minLength: 0)
    }
  }

  private func safetyRow(_ title: String, _ value: String, _ color: Color) -> some View {
    HStack {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(title).font(.system(size: 10))
      Spacer()
      Text(value).font(.system(size: 9)).foregroundStyle(.secondary)
    }
  }

  private let channels: [(motion: String, channel: String, range: String, color: Color)] = [
    ("Head Pan", "Head Controller · PWM 0", "-75° … +75°", .purple),
    ("Head Tilt", "Head Controller · PWM 1", "-35° … +42°", .cyan),
    ("Jaw", "Head Controller · PWM 2", "0% … 100%", .orange),
    ("Eye Pan", "Head Controller · PWM 3", "-28° … +28°", .blue),
    ("Eye Tilt", "Head Controller · PWM 4", "-18° … +18°", .blue),
    ("Left Shoulder", "Body Controller · ID 1", "-90° … +90°", .green),
    ("Right Shoulder", "Body Controller · ID 2", "-90° … +90°", .green),
    ("Chest Screen", "Chest Display · Layer 0", "RGBA", .pink),
  ]
}
