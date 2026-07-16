import SwiftUI

struct StudioHomeView: View {
  let recentProjects: [RecentProjectSummary]
  let createProject: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        studioColumn
          .frame(maxWidth: .infinity)
        Divider()
        templatesColumn
          .frame(maxWidth: .infinity)
        Divider()
        resourcesColumn
          .frame(maxWidth: .infinity)
      }

      Divider()
      bottomResources
    }
    .padding(18)
    .background(StudioPalette.canvas)
    .foregroundStyle(.white)
  }

  private var studioColumn: some View {
    VStack(alignment: .leading, spacing: 16) {
      homeHeading(
        title: "ANIMA STUDIO",
        subtitle: "Animate digital characters and physical robots."
      )

      homeAction(
        title: "New Studio Project",
        systemImage: "doc.badge.plus",
        action: createProject
      )

      homeAction(
        title: "Open A Project",
        systemImage: "folder",
        isEnabled: false
      ) {}
      .help("Project opening will be enabled by the P0 document layer")

      HStack {
        Text("Recent Projects")
          .font(.headline)
        Spacer()
        Text(recentProjects.isEmpty ? "NONE YET" : "\(recentProjects.count) RECENT")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(.top, 8)

      if recentProjects.isEmpty {
        ContentUnavailableView(
          "No Recent Projects",
          systemImage: "clock.arrow.circlepath",
          description: Text("Create a project to begin the hardware-animation workflow.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 8) {
            ForEach(recentProjects) { project in
              RecentProjectCard(project: project)
            }
          }
          .padding(.vertical, 2)
        }

        Label(
          "Cards record real recency. Reopening is enabled with project documents.",
          systemImage: "info.circle"
        )
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
      }
    }
    .padding(.trailing, 18)
  }

  private var templatesColumn: some View {
    VStack(alignment: .leading, spacing: 16) {
      homeHeading(
        title: "START FROM",
        subtitle: "Purpose-built Anima workspaces"
      )

      templateCard(
        title: "HARDWARE CHARACTER",
        subtitle: "Rigid components, mates, servos, and motion",
        systemImage: "figure.wave"
      )
      templateCard(
        title: "DIGITAL CHARACTER",
        subtitle: "3D avatars, faces, and expressions",
        systemImage: "person.crop.square"
      )
      templateCard(
        title: "SHOW CONTROL",
        subtitle: "Audio, screens, LEDs, and events",
        systemImage: "lightbulb.led.wide"
      )

      Spacer()

      Text("Templates are roadmap previews; New Studio Project opens the working foundation.")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
    }
    .padding(.horizontal, 18)
  }

  private var resourcesColumn: some View {
    VStack(alignment: .leading, spacing: 16) {
      homeHeading(
        title: "OPEN & CONNECTED",
        subtitle: "One format, many embodiments"
      )

      Link(destination: URL(string: "https://github.com/JenkinsRobotics/AnimaStudio")!) {
        resourceButton("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
      }
      Link(destination: URL(string: "https://docs.bottango.com/")!) {
        resourceButton("Workflow Reference", systemImage: "book.pages")
      }

      Divider()

      Label("RealityKit native viewport", systemImage: "view.3d")
      Label("Open Anima formats", systemImage: "doc.text")
      Label("Hardware-neutral motion", systemImage: "waveform.path.ecg")

      Spacer()

      Text("Anima Studio 0.1.0")
        .font(.caption.monospaced())
        .foregroundStyle(StudioPalette.muted)
    }
    .padding(.leading, 18)
  }

  private var bottomResources: some View {
    HStack(spacing: 14) {
      Label("Project documents in progress", systemImage: "shippingbox")
      Divider().frame(height: 18)
      Label("Kinematic preview", systemImage: "figure.walk.motion")
      Divider().frame(height: 18)
      Label("Hardware output safely disabled", systemImage: "powerplug.fill")
      Spacer()
      Text("OPEN SOURCE CHARACTER ANIMATION")
        .font(.caption2.weight(.bold))
        .foregroundStyle(StudioPalette.accent)
    }
    .font(.caption)
    .foregroundStyle(StudioPalette.muted)
    .padding(.horizontal, 4)
    .padding(.top, 14)
  }

  private func homeHeading(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.title2.weight(.light))
        .tracking(2)
      Text(subtitle)
        .font(.callout)
        .foregroundStyle(StudioPalette.muted)
    }
  }

  private func homeAction(
    title: String,
    systemImage: String,
    isEnabled: Bool = true,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.title3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .frame(height: 72)
        .background(StudioPalette.accent, in: RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.42)
  }

  private func templateCard(
    title: String,
    subtitle: String,
    systemImage: String
  ) -> some View {
    HStack(spacing: 14) {
      Image(systemName: systemImage)
        .font(.title2)
        .foregroundStyle(StudioPalette.accent)
        .frame(width: 40)
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline)
          .tracking(1)
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }
      Spacer()
    }
    .padding(14)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12))
  }

  private func resourceButton(_ title: String, systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
      .font(.headline)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .frame(height: 52)
      .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12))
  }
}
