import SwiftUI

struct HardwareWorkspaceView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top, spacing: 16) {
          statusCard
          safetyCard
          mappingCard
        }
        driverLog
      }
      .padding(24)
      .frame(maxWidth: 1100)
      .frame(maxWidth: .infinity)
    }
    .background(StudioPalette.canvas)
  }

  private var statusCard: some View {
    HardwareCard(title: "Driver Connection", systemImage: "cable.connector") {
      HardwareStatusRow(title: "State", value: "Offline", tint: .secondary)
      HardwareStatusRow(title: "Drivers", value: "0 configured")
      HardwareStatusRow(title: "Transport", value: "Unavailable")
      Divider()
      Button("Connect Driver", systemImage: "powerplug") {}
        .buttonStyle(StudioPrimaryButtonStyle())
        .disabled(true)
        .help("Studio transport integration is not wired yet")
    }
  }

  private var safetyCard: some View {
    HardwareCard(title: "Safety", systemImage: "lock.shield") {
      HardwareStatusRow(title: "Master Live", value: "Disarmed", tint: .secondary)
      HardwareStatusRow(title: "Failsafe", value: "No active session")
      HardwareStatusRow(title: "Heartbeat", value: "Not running")
      Divider()
      Label("Connecting will never arm outputs automatically.", systemImage: "info.circle")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var mappingCard: some View {
    HardwareCard(title: "Output Mapping", systemImage: "arrow.triangle.branch") {
      HardwareStatusRow(title: "Mapped DOFs", value: "0")
      HardwareStatusRow(title: "Servo Channels", value: "0")
      HardwareStatusRow(title: "Other Effectors", value: "0")
      Divider()
      Button("Configure Mappings", systemImage: "slider.horizontal.3") {}
        .buttonStyle(.bordered)
        .disabled(true)
        .help("Mappings follow the typed mate/DOF contract")
    }
  }

  private var driverLog: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Label("Driver Log", systemImage: "terminal")
          .font(.headline)
        Spacer()
        TextField("Search messages", text: .constant(""))
          .textFieldStyle(.roundedBorder)
          .frame(width: 220)
          .disabled(true)
        Menu("Levels", systemImage: "line.3.horizontal.decrease.circle") {
          Text("Info")
          Text("Incoming")
          Text("Outgoing")
          Text("Warnings")
          Text("Errors")
        }
        .disabled(true)
        Button("Freeze", systemImage: "pause") {}
          .disabled(true)
        Button("Export", systemImage: "square.and.arrow.up") {}
          .disabled(true)
      }
      .padding(12)

      Divider()

      ContentUnavailableView(
        "No Driver Messages",
        systemImage: "terminal",
        description: Text("Incoming, outgoing, warning, and error traffic will appear here.")
      )
      .frame(minHeight: 220)
    }
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }
}

private struct HardwareCard<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(title, systemImage: systemImage)
        .font(.headline)
      content()
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }
}

private struct HardwareStatusRow: View {
  let title: String
  let value: String
  var tint: Color = .primary

  var body: some View {
    HStack {
      Text(title)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .foregroundStyle(tint)
    }
    .font(.callout)
  }
}
