import AnimaCAD
import AppKit
import RealityKitViewport
import SwiftUI

enum StudioHomeSection: String, CaseIterable, Identifiable, Sendable {
  case getStarted = "Get Started"
  case recents = "Recent Projects"
  case characters = "Characters"
  case library = "Character Library"

  var id: Self { self }

  var systemImage: String {
    switch self {
    case .getStarted: "star"
    case .recents: "clock"
    case .characters: "person.crop.square"
    case .library: "books.vertical"
    }
  }

  var subtitle: String {
    switch self {
    case .getStarted: "Purpose-built Anima workspaces"
    case .recents: "Projects you have opened"
    case .characters: "Characters belong to an open project"
    case .library: "Published, reusable characters"
    }
  }
}

enum StudioStartArchetype: String, CaseIterable, Identifiable, Sendable {
  case hardwareCharacter = "Hardware Character"
  case digitalCharacter = "Digital Character"
  case showControl = "Show Control"

  var id: Self { self }

  var detail: String {
    switch self {
    case .hardwareCharacter: "Rigid components, mates, servos, and motion"
    case .digitalCharacter: "Digital avatars, faces, and expressions"
    case .showControl: "Audio, screens, LEDs, cues, and events"
    }
  }

  var systemImage: String {
    switch self {
    case .hardwareCharacter: "figure.wave"
    case .digitalCharacter: "person.crop.square"
    case .showControl: "lightbulb.led.wide"
    }
  }

  var destination: StudioWorkspaceKind {
    switch self {
    case .hardwareCharacter, .digitalCharacter: .assets
    case .showControl: .show
    }
  }

  var isPreview: Bool { self == .digitalCharacter }
}

struct StudioHomeView: View {
  let recentProjects: [RecentProjectSummary]
  let createProject: (StudioWorkspaceKind) -> Void
  let openProject: () -> Void
  let openRecentProject: (RecentProjectSummary) -> Void
  let removeRecentProject: (RecentProjectSummary.ID) -> Void
  let refreshProjects: () -> [RecentProjectSummary]
  let toggleTheme: () -> Void

  @State private var section = StudioHomeSection.getStarted
  @State private var visibleRecents: [RecentProjectSummary]
  @AppStorage(StudioPreferenceKey.showsStatusBar) private var showsStatusBar = true
  @AppStorage(StudioPreferenceKey.cadRenderBackend) private var cadRenderBackendRawValue =
    CADRenderBackend.realityKit.rawValue
  @AppStorage(StudioPreferenceKey.viewportAppearance) private var viewportAppearanceRawValue =
    PreviewAppearance.midnight.rawValue
  @AppStorage(StudioPreferenceKey.cadThemeName) private var cadThemeName = "Studio Blue"

  init(
    recentProjects: [RecentProjectSummary],
    createProject: @escaping (StudioWorkspaceKind) -> Void,
    openProject: @escaping () -> Void,
    openRecentProject: @escaping (RecentProjectSummary) -> Void,
    removeRecentProject: @escaping (RecentProjectSummary.ID) -> Void,
    refreshProjects: @escaping () -> [RecentProjectSummary],
    toggleTheme: @escaping () -> Void
  ) {
    self.recentProjects = recentProjects
    self.createProject = createProject
    self.openProject = openProject
    self.openRecentProject = openRecentProject
    self.removeRecentProject = removeRecentProject
    self.refreshProjects = refreshProjects
    self.toggleTheme = toggleTheme
    _visibleRecents = State(initialValue: recentProjects)
  }

  var body: some View {
    VStack(spacing: 0) {
      StudioHomeDocumentBar(
        createProject: { createProject(.assets) },
        openProject: openProject,
        toggleTheme: toggleTheme
      )

      HStack(alignment: .top, spacing: 0) {
        leftColumn
        Divider().overlay(StudioPalette.border)
        middleColumn
        Divider().overlay(StudioPalette.border)
        rightColumn
      }
      .frame(maxHeight: .infinity, alignment: .top)

      if showsStatusBar {
        StudioStatusBar(
          workspaceTitle: "Home",
          rendererName: preferredRenderer.title,
          themeName: preferredThemeName,
          kernelVersion: CADGeometryKernel.version
        )
      }
    }
    .background(StudioPalette.canvas)
    .foregroundStyle(.white)
    .onAppear { visibleRecents = refreshProjects() }
    .onChange(of: recentProjects) { _, projects in visibleRecents = projects }
  }

  private var leftColumn: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(spacing: 8) {
        projectAction(
          "New Studio Project",
          systemImage: "doc.badge.plus",
          filled: true
        ) { createProject(.assets) }
        projectAction(
          "Open A Project",
          systemImage: "folder",
          filled: false,
          action: openProject
        )
      }

      VStack(spacing: 2) {
        ForEach(StudioHomeSection.allCases) { item in
          Button {
            section = item
          } label: {
            HStack(spacing: 9) {
              Image(systemName: item.systemImage)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 16)
              Text(item.rawValue)
                .font(.system(size: 12, weight: section == item ? .semibold : .regular))
              Spacer(minLength: 0)
            }
            .foregroundStyle(section == item ? Color.white : StudioPalette.muted)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
              section == item ? StudioPalette.panelInset : Color.clear,
              in: RoundedRectangle(cornerRadius: 8)
            )
          }
          .buttonStyle(.plain)
        }
      }

      HStack {
        Text("Recent")
          .font(.system(size: 12, weight: .semibold))
        Spacer()
        Text(visibleRecents.isEmpty ? "SAMPLES" : "\(visibleRecents.count) RECENT")
          .font(.system(size: 9, weight: .semibold))
          .tracking(0.5)
          .foregroundStyle(StudioPalette.muted)
      }

      ScrollView {
        LazyVStack(spacing: 8) {
          if visibleRecents.isEmpty {
            ForEach(Self.sampleRecents) { sample in
              compactRecentRow(sample, isSample: true, action: {})
            }
          } else {
            ForEach(visibleRecents) { project in
              compactRecentRow(project, isSample: false) {
                openRecentProject(project)
              }
              .contextMenu {
                Button(
                  "Remove from Recents",
                  systemImage: "clock.badge.xmark",
                  role: .destructive
                ) {
                  removeRecentProject(project.id)
                  visibleRecents.removeAll { $0.id == project.id }
                }
              }
            }
          }
        }
      }

      Spacer(minLength: 0)
    }
    .padding(22)
    .frame(width: 330, alignment: .leading)
  }

  private var middleColumn: some View {
    VStack(alignment: .leading, spacing: 16) {
      columnHeader(section.rawValue, section.subtitle)
      ScrollView {
        sectionContent
          .frame(maxWidth: .infinity, alignment: .topLeading)
      }
      Spacer(minLength: 0)
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder private var sectionContent: some View {
    switch section {
    case .getStarted:
      VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 7) {
          Text("Welcome back")
            .font(.system(size: 13))
            .foregroundStyle(StudioPalette.muted)
          Text("What are we bringing to life today?")
            .font(.system(size: 26, weight: .semibold))
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
          ForEach(StudioStartArchetype.allCases) { archetype in
            archetypeCard(archetype)
          }
        }
      }
    case .recents:
      if visibleRecents.isEmpty {
        honestEmptyState(
          "No recent projects yet",
          detail: "Create a Studio project and it will appear here.",
          systemImage: "clock.arrow.circlepath"
        )
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 12)], spacing: 12) {
          ForEach(visibleRecents) { project in
            RecentProjectCard(
              project: project,
              open: { openRecentProject(project) },
              remove: {
                removeRecentProject(project.id)
                visibleRecents.removeAll { $0.id == project.id }
              }
            )
          }
        }
      }
    case .characters:
      honestEmptyState(
        "Open a project to view its characters",
        detail: "Characters are self-contained project assets, not Home-screen mock data.",
        systemImage: "person.crop.square"
      )
    case .library:
      honestEmptyState(
        "Character Library is hidden for production testing",
        detail:
          "Reusable library storage is preserved and can be enabled after the core flow is proven.",
        systemImage: "books.vertical"
      )
    }
  }

  private var rightColumn: some View {
    VStack(alignment: .leading, spacing: 16) {
      columnHeader("Open & Connected", "One format, many embodiments")

      Link(destination: URL(string: "https://github.com/JenkinsRobotics/AnimaStudio")!) {
        resourceRow("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
      }
      Link(destination: URL(string: "https://docs.bottango.com/")!) {
        resourceRow("Workflow Reference", systemImage: "doc.text")
      }

      Divider().overlay(StudioPalette.border).padding(.vertical, 4)
      factRow("3D", "RealityKit + native Metal CAD")
      factRow("{ }", "Open Anima formats")
      factRow("~", "Hardware-neutral motion")
      Divider().overlay(StudioPalette.border).padding(.vertical, 4)

      Text("LEARN")
        .font(.system(size: 9, weight: .bold))
        .tracking(0.6)
        .foregroundStyle(StudioPalette.muted)
      learnLink("Tutorials", systemImage: "graduationcap", url: "https://docs.bottango.com/")
      learnLink(
        "Project Roadmap",
        systemImage: "arrow.triangle.branch",
        url: "https://github.com/JenkinsRobotics/AnimaStudio"
      )
      learnLink(
        "Source & Issues",
        systemImage: "ladybug",
        url: "https://github.com/JenkinsRobotics/AnimaStudio/issues"
      )

      Spacer(minLength: 0)
      Text("Anima Studio 0.1.0")
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(StudioPalette.muted)
    }
    .padding(22)
    .frame(width: 310, alignment: .leading)
  }

  private func projectAction(
    _ title: String,
    systemImage: String,
    filled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.system(size: 13, weight: .semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .frame(height: 42)
        .foregroundStyle(filled ? Color.white : StudioPalette.accent)
        .background(
          filled ? StudioPalette.accent : StudioPalette.panel,
          in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 10)
            .stroke(filled ? StudioPalette.accent : StudioPalette.border, lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
  }

  private func compactRecentRow(
    _ project: RecentProjectSummary,
    isSample: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 11) {
        ZStack {
          RoundedRectangle(cornerRadius: 9).fill(StudioPalette.panelInset)
          if let thumbnail = project.thumbnailPath.flatMap(NSImage.init(contentsOfFile:)) {
            Image(nsImage: thumbnail).resizable().scaledToFit().padding(3)
          } else {
            Image(systemName: project.thumbnailKind.systemImage)
              .font(.system(size: 17))
              .foregroundStyle(StudioPalette.semanticPart)
          }
        }
        .frame(width: 40, height: 40)

        VStack(alignment: .leading, spacing: 2) {
          Text(project.displayName)
            .font(.system(size: 12.5, weight: .semibold))
            .lineLimit(1)
          Text(isSample ? "Representative project" : relativeDate(project.lastOpenedAt))
            .font(.system(size: 10))
            .foregroundStyle(StudioPalette.muted)
        }
        Spacer(minLength: 8)
        Text(project.revisionLabel)
          .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
          .foregroundStyle(StudioPalette.muted)
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 6))
          .overlay(RoundedRectangle(cornerRadius: 6).stroke(StudioPalette.border))
      }
      .padding(9)
      .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 11))
      .overlay(RoundedRectangle(cornerRadius: 11).stroke(StudioPalette.border))
    }
    .buttonStyle(.plain)
    .disabled(isSample)
  }

  private func archetypeCard(_ archetype: StudioStartArchetype) -> some View {
    Button {
      createProject(archetype.destination)
    } label: {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: archetype.systemImage)
            .font(.system(size: 24, weight: .light))
            .foregroundStyle(StudioPalette.accent)
          Spacer()
          if archetype.isPreview {
            Text("PREVIEW")
              .font(.system(size: 8.5, weight: .bold))
              .tracking(0.6)
              .foregroundStyle(StudioPalette.joint)
              .padding(.horizontal, 7)
              .padding(.vertical, 3)
              .background(StudioPalette.joint.opacity(0.12), in: Capsule())
          }
        }
        Text(archetype.rawValue.uppercased())
          .font(.system(size: 13, weight: .semibold))
          .tracking(0.5)
        Text(archetype.detail)
          .font(.system(size: 11))
          .foregroundStyle(StudioPalette.muted)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
        Label("Create Project", systemImage: "arrow.right")
          .font(.system(size: 10.5, weight: .semibold))
          .foregroundStyle(StudioPalette.accent)
      }
      .padding(16)
      .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
      .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudioPalette.border))
    }
    .buttonStyle(.plain)
  }

  private func honestEmptyState(
    _ title: String,
    detail: String,
    systemImage: String
  ) -> some View {
    ContentUnavailableView(title, systemImage: systemImage, description: Text(detail))
      .frame(maxWidth: .infinity, minHeight: 320)
  }

  private func columnHeader(_ title: String, _ subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title.uppercased())
        .font(.system(size: 15, weight: .bold))
        .tracking(0.6)
      Text(subtitle)
        .font(.system(size: 11))
        .foregroundStyle(StudioPalette.muted)
    }
  }

  private func resourceRow(_ title: String, systemImage: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: systemImage).frame(width: 18)
      Text(title).font(.system(size: 12, weight: .medium))
      Spacer(minLength: 0)
    }
    .foregroundStyle(Color.white)
    .padding(.horizontal, 14)
    .frame(height: 42)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudioPalette.border))
  }

  private func factRow(_ glyph: String, _ text: String) -> some View {
    HStack(spacing: 10) {
      Text(glyph)
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundStyle(StudioPalette.accent)
        .frame(width: 22, alignment: .leading)
      Text(text).font(.system(size: 11.5)).foregroundStyle(StudioPalette.muted)
    }
  }

  private func learnLink(_ title: String, systemImage: String, url: String) -> some View {
    Link(destination: URL(string: url)!) {
      HStack(spacing: 9) {
        Image(systemName: systemImage).frame(width: 16)
        Text(title).font(.system(size: 12))
        Spacer(minLength: 0)
        Image(systemName: "arrow.up.right.square").font(.system(size: 9))
      }
      .foregroundStyle(StudioPalette.muted)
      .padding(.horizontal, 9)
      .padding(.vertical, 6)
    }
  }

  private func relativeDate(_ date: Date) -> String {
    date.formatted(.relative(presentation: .named)).capitalized
  }

  private var preferredRenderer: CADRenderBackend {
    CADRenderBackend(rawValue: cadRenderBackendRawValue) ?? .realityKit
  }

  private var preferredThemeName: String {
    if preferredRenderer == .realityKit {
      return (PreviewAppearance(rawValue: viewportAppearanceRawValue) ?? .midnight).title
    }
    return cadThemeName
  }

  private static let sampleRecents: [RecentProjectSummary] = [
    RecentProjectSummary(
      displayName: "Robot Arm Assembly",
      lastOpenedAt: Date().addingTimeInterval(-3_600),
      revisionNumber: 12,
      thumbnailKind: .character
    ),
    RecentProjectSummary(
      displayName: "Stage Character",
      lastOpenedAt: Date().addingTimeInterval(-86_400),
      revisionNumber: 3,
      thumbnailKind: .show
    ),
    RecentProjectSummary(
      displayName: "Gripper Study",
      lastOpenedAt: Date().addingTimeInterval(-172_800),
      revisionNumber: 7,
      thumbnailKind: .rig
    ),
  ]
}
