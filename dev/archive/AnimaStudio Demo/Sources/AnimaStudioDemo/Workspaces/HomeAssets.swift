import AppKit
import GeomKit
import SwiftUI

// MARK: - Home / project launch

enum HomeSection: String, CaseIterable, Identifiable {
  case getStarted = "Get Started"
  case recents = "Recent Projects"
  case characters = "Characters"
  case library = "Character Library"
  var id: String { rawValue }
  var icon: String {
    switch self {
    case .getStarted: return "star"
    case .recents: return "clock"
    case .characters: return "person.crop.square"
    case .library: return "books.vertical"
    }
  }
}

struct HomeWorkspace: View {
  var go: (Workspace) -> Void
  @State private var section: HomeSection = .getStarted
  @State private var search = ""
  @State private var project = ProjectModel.shared
  @State private var model = DemoModel.shared
  @State private var home = HomeState.shared
  @State private var recents = RecentProjects.merged()
  @State private var error: String?
  @State private var studio = StudioProject.shared

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 0) {
        leftColumn
        Divider().overlay(UI.stroke)
        middleColumn
        Divider().overlay(UI.stroke)
        rightColumn
      }
      .frame(maxHeight: .infinity, alignment: .top)
    }
    // Refresh on every appearance — projects created/opened elsewhere (or on a
    // return to Home) must show up without re-launching.
    .onAppear { recents = RecentProjects.merged() }
    .sheet(isPresented: $home.showNewCharacter) {
      NewCharacterDialog { name in project.addCharacter(named: name) }
    }
  }

  // MARK: - Left: identity, project actions, nav, recents

  private var leftColumn: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(spacing: 8) {
        Button { newProject() } label: {
          projectAction("New Studio Project", "doc.badge.plus", filled: true)
        }.buttonStyle(.plain)
        Button { openProject() } label: {
          projectAction("Open A Project", "folder", filled: false)
        }.buttonStyle(.plain)
      }

      VStack(spacing: 2) {
        ForEach(HomeSection.allCases) { item in
          Button { section = item } label: {
            HStack(spacing: 9) {
              Image(systemName: item.icon).font(.system(size: 11, weight: .medium)).frame(width: 16)
              Text(item.rawValue)
                .font(.system(size: 12, weight: section == item ? .semibold : .regular))
              Spacer(minLength: 0)
            }
            .foregroundStyle(section == item ? UI.text : UI.text2)
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(section == item ? UI.panelHi : .clear, in: RoundedRectangle(cornerRadius: 8))
          }.buttonStyle(.plain)
        }
      }

      HStack {
        Text("Recent").font(.system(size: 12, weight: .semibold)).foregroundStyle(UI.text)
        Spacer()
        Text(recents.isEmpty ? "SAMPLES" : "\(recents.count) RECENT")
          .font(.system(size: 9, weight: .semibold)).tracking(0.5).foregroundStyle(UI.text3)
      }
      ScrollView {
        VStack(spacing: 8) {
          if recents.isEmpty {
            // No real projects yet — show representative samples so the panel
            // reads as designed rather than empty.
            ForEach(HomeWorkspace.sampleRecents) { sample in
              recentRow(icon: sample.icon, name: sample.name, subtitle: sample.subtitle,
                version: sample.version, exists: true, action: {})
            }
          } else {
            ForEach(recents) { entry in
              recentRow(
                icon: "cube.transparent", name: entry.name,
                subtitle: entry.exists
                  ? entry.openedAt.formatted(.relative(presentation: .named)).capitalized
                  : "Missing — moved or deleted",
                version: nil, exists: entry.exists, action: { openRecent(entry) }
              )
              .contextMenu {
                Button("Remove from Recents") {
                  RecentProjects.remove(entry.path)
                  recents = RecentProjects.merged()
                }
              }
            }
          }
        }
      }

      if let error {
        Text(error).font(.system(size: 10.5)).foregroundStyle(UI.danger)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
    .padding(22)
    .frame(width: 330, alignment: .leading)
  }

  /// One recent-project row: thumbnail tile, name, relative time, version chip.
  private func recentRow(icon: String, name: String, subtitle: String,
    version: String?, exists: Bool, action: @escaping () -> Void) -> some View
  {
    Button(action: action) {
      HStack(spacing: 11) {
        Image(systemName: icon).font(.system(size: 17))
          .foregroundStyle(exists ? UI.accent2 : UI.text3)
          .frame(width: 40, height: 40)
          .background(UI.panelHi, in: RoundedRectangle(cornerRadius: 9))
        VStack(alignment: .leading, spacing: 2) {
          Text(name).font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(exists ? UI.text : UI.text3).lineLimit(1)
          Text(subtitle).font(.system(size: 10)).foregroundStyle(UI.text3)
        }
        Spacer(minLength: 8)
        if let version {
          Text(version).font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(UI.text2)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(UI.panelHi, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(UI.stroke, lineWidth: 1))
        }
      }
      .padding(9)
      .background(UI.panel, in: RoundedRectangle(cornerRadius: 11))
      .overlay(RoundedRectangle(cornerRadius: 11).stroke(UI.stroke, lineWidth: 1))
    }
    .buttonStyle(.plain)
  }

  /// Representative recents shown until the operator has real projects.
  struct RecentSample: Identifiable {
    let id = UUID()
    var name: String, subtitle: String, version: String, icon: String
  }
  static let sampleRecents: [RecentSample] = [
    RecentSample(name: "Robot Arm Assembly", subtitle: "9:41 AM", version: "V12",
      icon: "figure.walk.motion"),
    RecentSample(name: "Base", subtitle: "Yesterday", version: "V3", icon: "circle.hexagongrid"),
    RecentSample(name: "Gripper", subtitle: "May 12, 2024", version: "V7",
      icon: "hand.pinch"),
  ]

  // MARK: - Middle: the active section

  private var middleColumn: some View {
    VStack(alignment: .leading, spacing: 16) {
      columnHeader(section.rawValue, sectionSubtitle)
      ScrollView { content.frame(maxWidth: .infinity, alignment: .leading) }
      Spacer(minLength: 0)
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var sectionSubtitle: String {
    switch section {
    case .getStarted: return "Purpose-built Anima workspaces"
    case .recents: return "Projects you have opened"
    case .characters: return "Characters in this project"
    case .library: return "Published, reusable characters"
    }
  }

  // MARK: - Right: about

  private var rightColumn: some View {
    VStack(alignment: .leading, spacing: 16) {
      columnHeader("Open & Connected", "One format, many embodiments")
      linkRow("GitHub Repository", "chevron.left.forwardslash.chevron.right")
      linkRow("Workflow Reference", "doc.text")
      Divider().overlay(UI.stroke).padding(.vertical, 4)
      factRow("3D", "RealityKit native viewport")
      factRow("{ }", "Open Anima formats")
      factRow("~", "Hardware-neutral motion")
      Divider().overlay(UI.stroke).padding(.vertical, 4)
      Text("LEARN").font(.system(size: 9, weight: .bold)).tracking(0.6).foregroundStyle(UI.text3)
      learnRow("Tutorials", "graduationcap")
      learnRow("Workflows", "arrow.triangle.branch")
      learnRow("Manual", "book")
      Spacer(minLength: 0)
      Text("Anima Studio Demo 0.1.0")
        .font(.system(size: 10, design: .monospaced)).foregroundStyle(UI.text3)
    }
    .padding(22)
    .frame(width: 310, alignment: .leading)
  }

  private func controlIcon(_ icon: String, _ help: String, _ action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: icon).font(.system(size: 11.5)).foregroundStyle(UI.text2)
        .frame(width: 28, height: 26)
        .background(UI.panelHi, in: RoundedRectangle(cornerRadius: 7))
    }.buttonStyle(.plain).help(help)
  }

  private func learnRow(_ title: String, _ icon: String) -> some View {
    HStack(spacing: 9) {
      Image(systemName: icon).font(.system(size: 11)).frame(width: 16)
      Text(title).font(.system(size: 12))
      Spacer(minLength: 0)
      Image(systemName: "arrow.up.right.square").font(.system(size: 9)).foregroundStyle(UI.text3)
    }
    .foregroundStyle(UI.text2)
    .padding(.horizontal, 9).padding(.vertical, 6)
  }

  private func columnHeader(_ title: String, _ subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title.uppercased()).font(.system(size: 15, weight: .bold)).tracking(0.6)
        .foregroundStyle(UI.text)
      Text(subtitle).font(.system(size: 11)).foregroundStyle(UI.text3)
    }
  }

  private func linkRow(_ title: String, _ icon: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon).font(.system(size: 12)).foregroundStyle(UI.text2).frame(width: 18)
      Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(UI.text)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14).padding(.vertical, 11)
    .background(UI.panel, in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(UI.stroke, lineWidth: 1))
  }

  private func factRow(_ glyph: String, _ text: String) -> some View {
    HStack(spacing: 10) {
      Text(glyph).font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundStyle(UI.accent2).frame(width: 22, alignment: .leading)
      Text(text).font(.system(size: 11.5)).foregroundStyle(UI.text2)
      Spacer(minLength: 0)
    }
  }

  private func openRecent(_ entry: RecentProject) {
    guard entry.exists, StudioProject.isProjectFolder(entry.url) else {
      error = "\(entry.name) is missing — it was moved or deleted."
      return
    }
    do {
      ProjectStore.newProject()
      try studio.open(entry.url)
      ProjectStore.loadCurrentScene()   // reload the project's parts
      recents = RecentProjects.merged()
      error = nil
      go(.character)
    } catch {
      self.error = "Could not open the project — \(error.localizedDescription)"
    }
  }

  @ViewBuilder private var content: some View {
    switch section {
    case .getStarted: getStarted
    case .recents: recentsGrid
    case .characters: charactersGrid
    case .library: libraryGrid
    }
  }

  private var getStarted: some View {
    VStack(alignment: .leading, spacing: 22) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Welcome back").font(.system(size: 13)).foregroundStyle(UI.text3)
        Text("What are we bringing to life today?")
          .font(.system(size: 26, weight: .semibold)).foregroundStyle(UI.text)
      }
      if studio.isOpen {
        HStack(spacing: 14) {
          bigAction("Import model", "cube.transparent", "STEP · STL · OBJ · glTF", UI.accent2) {
            model.importFiles()
          }
          bigAction("New character", "plus.viewfinder", "Start from an empty rig", UI.accent) {
            home.showNewCharacter = true
          }
          bigAction("Open show", "rectangle.3.group", "Sequence + hardware", UI.warn) {
            go(.show)
          }
        }
      }

      if let error {
        Text(error).font(.system(size: 11)).foregroundStyle(UI.danger)
      }

      Text("START FROM").font(.system(size: 10.5, weight: .semibold)).tracking(0.6)
        .foregroundStyle(UI.text3)
      VStack(spacing: 10) {
        ForEach(StartArchetype.allCases) { archetype in
          Button { newProject(archetype: archetype) } label: {
            HStack(spacing: 14) {
              Image(systemName: archetype.icon).font(.system(size: 17))
                .foregroundStyle(archetype.isPreview ? UI.text3 : UI.accent).frame(width: 26)
              VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                  Text(archetype.title.uppercased()).font(.system(size: 12, weight: .bold))
                    .tracking(0.4).foregroundStyle(UI.text)
                  if archetype.isPreview { Badge(text: "preview", tint: UI.warn) }
                }
                Text(archetype.detail).font(.system(size: 10.5)).foregroundStyle(UI.text3)
              }
              Spacer(minLength: 0)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(UI.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(UI.stroke, lineWidth: 1))
          }.buttonStyle(.plain)
        }
      }
      Text("NEXT STEPS").font(.system(size: 10.5, weight: .semibold)).tracking(0.6)
        .foregroundStyle(UI.text3)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
        guideCard("Assemble a character", "Import parts, then place them around the character origin.", UI.accent2) { go(.character) }
        guideCard("Rig it with mates", "Pick two parts and connect them with a revolute or slider.", UI.accent) { go(.rig) }
        guideCard("Animate the rig", "Key mate values on the timeline and press play.", UI.warn) { go(.animate) }
      }
    }
  }

  private var recentsGrid: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
      ForEach(recents) { entry in
        projectCard(entry.name, entry.exists ? "Local project" : "Missing",
          entry.openedAt.formatted(date: .abbreviated, time: .shortened), UI.accent2)
      }
    }
  }

  private var charactersGrid: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
      ForEach(project.characters) { character in
        Button { project.activeCharacterID = character.id; go(.character) } label: {
          projectCard(character.name, "\(character.parts.count) parts",
            "\(character.mates.count) mates · \(character.clips.count) clips", UI.accent)
        }.buttonStyle(.plain)
      }
    }
  }

  private var libraryGrid: some View {
    let files = CharacterLibrary.list()
    return VStack(alignment: .leading, spacing: 12) {
      if files.isEmpty {
        Text("Publish a character from the Character tab to reuse it across projects.")
          .font(.system(size: 11.5)).foregroundStyle(UI.text3)
      }
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
        ForEach(files, id: \.self) { file in
          projectCard(file.deletingPathExtension().lastPathComponent, "Published character",
            "Character Library", UI.warn)
        }
      }
    }
  }

  private func guideCard(_ title: String, _ detail: String, _ tint: Color,
    _ tap: @escaping () -> Void) -> some View
  {
    Button(action: tap) {
      VStack(alignment: .leading, spacing: 7) {
        Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(UI.text)
        Text(detail).font(.system(size: 11)).foregroundStyle(UI.text3)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }
      .padding(14).frame(height: 104, alignment: .topLeading).frame(maxWidth: .infinity, alignment: .leading)
      .background(UI.panel, in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.25), lineWidth: 1))
    }.buttonStyle(.plain)
  }

  private func projectAction(_ title: String, _ icon: String, filled: Bool) -> some View {
    HStack(spacing: 9) {
      Image(systemName: icon).font(.system(size: 12, weight: .medium))
      Text(title).font(.system(size: 12, weight: .semibold))
      Spacer(minLength: 0)
    }
    .foregroundStyle(filled ? .white : UI.accent)
    .padding(.horizontal, 12).padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(filled ? UI.accent : UI.accent.opacity(0.14),
      in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  /// Creates straight into ~/Documents/AnimaStudio — no save panel.
  private func newProject(archetype: StartArchetype = .hardwareCharacter) {
    do {
      ProjectStore.newProject()
      try studio.createInDefaultLocation()
      ProjectStore.autosave()
      recents = RecentProjects.merged()
      error = nil
      go(archetype.workspace)
    } catch {
      self.error = "Could not create the project — \(error.localizedDescription)"
    }
  }

  private func openProject() {
    let panel = NSOpenPanel()
    panel.title = "Open A Project"
    panel.directoryURL = StudioProject.defaultRoot
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    guard StudioProject.isProjectFolder(url) else {
      error = "\(url.lastPathComponent) isn't an Anima Studio project (no project.json)."
      return
    }
    do {
      ProjectStore.newProject()
      try studio.open(url)
      ProjectStore.loadCurrentScene()   // reload the project's parts
      recents = RecentProjects.merged()
      error = nil
      go(.character)
    } catch {
      self.error = "Could not open the project — \(error.localizedDescription)"
    }
  }

  func bigAction(_ title: String, _ icon: String, _ sub: String, _ tint: Color, _ tap: @escaping () -> Void) -> some View {
    Button(action: tap) {
      VStack(alignment: .leading, spacing: 12) {
        Image(systemName: icon).font(.system(size: 22)).foregroundStyle(tint)
        Spacer(minLength: 18)
        Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.text)
        Text(sub).font(.system(size: 11.5)).foregroundStyle(UI.text3)
      }
      .padding(18).frame(height: 140, alignment: .topLeading).frame(maxWidth: .infinity, alignment: .leading)
      .background(UI.panel, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.25), lineWidth: 1))
    }
    .buttonStyle(.plain)
  }

  func projectCard(_ name: String, _ kind: String, _ meta: String, _ tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack {
        LinearGradient(colors: [tint.opacity(0.4), UI.stageBottom],
          startPoint: .topLeading, endPoint: .bottomTrailing)
        Image(systemName: "cube.transparent").font(.system(size: 30)).foregroundStyle(.white.opacity(0.7))
      }
      .frame(height: 92)
      VStack(alignment: .leading, spacing: 3) {
        Text(name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(UI.text).lineLimit(1)
        Text(kind).font(.system(size: 11)).foregroundStyle(UI.text2)
        Text(meta).font(.system(size: 10.5)).foregroundStyle(UI.text3).padding(.top, 2).lineLimit(1)
      }
      .padding(12).frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(UI.panel, in: RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(UI.stroke, lineWidth: 1))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

// MARK: - Assets / import + parts

struct CharacterWorkspace: View {
  @State private var model = DemoModel.shared
  @State private var project = ProjectModel.shared
  @State private var home = HomeState.shared

  var body: some View {
    WorkspaceScaffold(
      toolGroups: CharacterTools.groups,
      toolOverflow: CharacterTools.overflow,
      toolArmGroup: CharacterTools.armGroup,
      leftTabs: [SidebarTab("Characters", "person.crop.square")]
        + CharacterSection.allCases.map { SidebarTab($0.rawValue, $0.icon) },
      leftPanels: model.characterPanels,
      centerTabs: [SidebarTab("3D", "cube"), SidebarTab("Gallery", "square.grid.2x2"),
                   SidebarTab("Table", "list.bullet")],
      centerSelection: Binding(get: { model.centerView }, set: { model.centerView = $0 })
    ) {
      center
    } left: { tab in
      if tab == "Characters" { charactersTab }
      else if let section = CharacterSection(rawValue: tab) { sectionPanel(section) }
    } inspector: {
      partInspector
    }
    // Import/Manage/Prepare tools are immediate actions, not canvas-arm tools.
    // The handler runs at tap time and returns true so the tool never arms.
    .onAppear {
      ToolState.shared.actionHandler = { tool in
        guard CharacterTools.isAction(tool.label) else { return false }
        characterAction(tool.label)
        return true
      }
    }
    .onDisappear { ToolState.shared.actionHandler = nil }
    .sheet(isPresented: $home.showNewCharacter) {
      NewCharacterDialog { name in project.addCharacter(named: name) }
    }
  }

  private func characterAction(_ label: String) {
    switch label {
    case "Character": home.showNewCharacter = true
    case "3D Model": model.importFiles()
    case "Audio", "Video", "Image":
      model.status = "\(label) import — coming soon (\(model.importMode.label.lowercased()))"
    case "Reveal":
      if let url = StudioProject.shared.url { NSWorkspace.shared.open(url) }
      else { model.status = "No project folder to reveal — save the project first." }
    case "Duplicate":
      if let c = project.active { _ = project.addCharacter(named: "\(c.name) Copy") }
    case "Replace": model.importFiles()
    case "Folder", "Units", "Up Axis", "Origin", "Hierarchy", "Validate":
      model.status = "\(label) — prep step (placeholder)"
    default: break
    }
  }

  // MARK: Sidebars

  // The project navigator: a character and everything it contains (parts,
  // source assets, renders, assemblies, scripts, animations).
  @ViewBuilder private var charactersTab: some View {
    VStack(spacing: 0) {
      HStack {
        Text("PROJECT: \(model.projectName.uppercased())")
          .font(.system(size: 10, weight: .semibold)).tracking(0.4).foregroundStyle(UI.text3)
        Spacer()
        Text("V1").font(.system(size: 9, weight: .bold)).foregroundStyle(UI.text2)
          .padding(.horizontal, 7).padding(.vertical, 2).background(UI.panelHi, in: Capsule())
      }.padding(.horizontal, 12).padding(.bottom, 6)

      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(UI.text3)
        TextField("Filter project contents", text: Binding(
          get: { project.projectFilter }, set: { project.projectFilter = $0 }))
          .textFieldStyle(.plain).font(.system(size: 12)).foregroundStyle(UI.text)
      }
      .padding(.horizontal, 10).padding(.vertical, 8)
      .background(UI.panelHi, in: RoundedRectangle(cornerRadius: 8))
      .padding(.horizontal, 10).padding(.bottom, 8)

      Divider().overlay(UI.stroke)

      projectTree
    }
  }

  @ViewBuilder private var projectTree: some View {
    // "Project Characters" group.
    treeRow(icon: "person.2", title: "Project Characters",
      count: filteredCharacters.count, indent: 0, bold: true,
      chevron: project.charactersExpanded) { project.charactersExpanded.toggle() }

    if project.charactersExpanded {
      if filteredCharacters.isEmpty {
        Text(project.characters.isEmpty
          ? "No characters yet — create one to start assembling parts."
          : "No matches.")
          .font(.system(size: 10)).foregroundStyle(UI.text3)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity).padding(.vertical, 14).padding(.horizontal, 16)
      }
      ForEach(filteredCharacters) { character in
        let active = project.activeCharacterID == character.id
        treeRow(icon: "figure.stand", title: character.name, count: nil, indent: 1,
          selected: active, chevron: project.expandedCharacters.contains(character.id),
          trailing: active ? "circle.fill" : nil,
          onChevron: { project.toggleExpanded(character.id) },
          onTap: { project.activeCharacterID = character.id })

        if project.expandedCharacters.contains(character.id) {
          ForEach(CharacterSection.allCases) { section in
            let focused = active && project.focusedFolder == section.rawValue
            treeRow(icon: section.icon, title: section.rawValue,
              count: section.count(character), indent: 2, selected: focused) {
              project.activeCharacterID = character.id
              project.focusedFolder = section.rawValue
              // Open that section's panel in the rail, like clicking its icon.
              if !model.characterPanels.isEnabled(section.rawValue) {
                withAnimation(.easeOut(duration: 0.18)) {
                  model.characterPanels.toggle(section.rawValue)
                }
              }
            }
          }
        }
      }
    }
  }

  // MARK: Section panels — one per character folder, all built from the same
  // list row so every section looks and behaves identically.

  @ViewBuilder private func sectionPanel(_ section: CharacterSection) -> some View {
    if section == .parts {
      partsTab                       // real: model.parts + import + import-mode
    } else {
      genericSection(section)
    }
  }

  @ViewBuilder private func genericSection(_ section: CharacterSection) -> some View {
    let rows = sectionRows(section)
    VStack(spacing: 0) {
      sectionHeader(section, count: rows.count)
      if rows.isEmpty {
        Text("No \(section.rawValue.lowercased()) yet.")
          .font(.system(size: 10)).foregroundStyle(UI.text3)
          .frame(maxWidth: .infinity).padding(.vertical, 16)
      }
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        TreeRow(icon: section.icon, title: row.title, detail: row.detail)
      }
      Divider().overlay(UI.stroke).padding(.top, 4)
      HStack(spacing: 8) {
        PanelAction(icon: "plus", label: "Add") { model.status = "Add \(section.rawValue) (placeholder)" }
        PanelAction(icon: "folder.badge.plus", label: "Folder") {
          model.status = "New folder in \(section.rawValue) (placeholder)"
        }
        Spacer()
      }.padding(10)
    }
  }

  private func sectionHeader(_ section: CharacterSection, count: Int) -> some View {
    Text("\((project.active?.name ?? "—").uppercased()) · \(count) \(section.rawValue.uppercased())")
      .font(.system(size: 8.5, weight: .medium)).tracking(0.4).foregroundStyle(UI.text3)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 3)
  }

  /// The items in a section, as consistent (title, detail) rows.
  private func sectionRows(_ section: CharacterSection) -> [(title: String, detail: String)] {
    guard let c = project.active else { return [] }
    switch section {
    case .parts: return model.parts.map { ($0.name, "\($0.document.faces.count)f") }
    case .sourceAssets: return c.sourceAssets.map { ($0, "source") }
    case .renders: return []
    case .assemblies: return c.groups.map { ($0.name, "group") }
    case .scripts: return c.channels.map { ("Channel \($0.channel)", "servo") }
    case .animations: return c.clips.map { ($0.name, String(format: "%.1fs", $0.duration)) }
    }
  }

  private var filteredCharacters: [Character] {
    let q = project.projectFilter.trimmingCharacters(in: .whitespaces).lowercased()
    guard !q.isEmpty else { return project.characters }
    return project.characters.filter { $0.name.lowercased().contains(q) }
  }


  /// Thin adapter onto the shared TreeRow so the character tree matches every
  /// other browser panel.
  private func treeRow(icon: String, title: String, count: Int?, indent: Int,
    bold: Bool = false, selected: Bool = false, chevron: Bool? = nil,
    trailing: String? = nil, onChevron: (() -> Void)? = nil,
    onTap: (() -> Void)? = nil) -> some View
  {
    TreeRow(depth: indent, icon: icon, title: title, count: count,
      expandable: chevron != nil, expanded: chevron ?? false,
      selected: selected, bold: bold,
      onToggleExpand: onChevron ?? onTap, onTap: onTap)
  }

  @ViewBuilder private var partsTab: some View {
    VStack(spacing: 0) {
      Text(partsSubtitle.uppercased()).font(.system(size: 8.5, weight: .medium)).tracking(0.4)
        .foregroundStyle(UI.text3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.bottom, 3)
      if model.parts.isEmpty {
        Text("Import a STEP file to add parts to this character.")
          .font(.system(size: 10)).foregroundStyle(UI.text3)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity).padding(.vertical, 16).padding(.horizontal, 12)
      } else {
        // Organisable tree — folders, drag-and-drop, group, delete.
        TreeView(model: model.partsTree) { node in
          if let pid = node.payload { model.selectedID = pid }
        }
      }
      Divider().overlay(UI.stroke).padding(.top, 4)
      // How new imports are stored — an option at import time.
      HStack(spacing: 8) {
        Text("NEW IMPORTS").font(.system(size: 8.5, weight: .semibold)).tracking(0.4)
          .foregroundStyle(UI.text3)
        Spacer()
        Picker("", selection: Binding(
          get: { model.importMode }, set: { model.importMode = $0 })) {
          ForEach(AssetImportMode.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented).labelsHidden().fixedSize().controlSize(.small)
      }
      .padding(.horizontal, 10).padding(.top, 6)
      Text(model.importMode.detail).font(.system(size: 9.5)).foregroundStyle(UI.text3)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.bottom, 2)
      HStack(spacing: 8) {
        PanelAction(icon: model.loading ? "hourglass" : "plus", label: "Import Model") {
          model.importFiles()
        }
        Spacer()
      }.padding(10)
    }
  }

  /// What the View sidebar's Inspector tab shows here — the selected part.
  @ViewBuilder private var partInspector: some View {
    if let part = model.selected {
      Field(label: "Source", value: part.name)
      Field(label: "Faces", value: "\(part.document.faces.count)")
      Field(label: "Edges", value: "\(part.document.edges.count)")
      Field(label: "Triangles", value: "\(part.document.triangleCount)")
      Field(label: "Import",
        value: String(format: "%.0f", part.document.metrics.totalMilliseconds), unit: "ms")
      Divider().overlay(UI.stroke)
      Text("STATUS").font(.system(size: 10, weight: .semibold)).tracking(0.6)
        .foregroundStyle(UI.text3)
      statusDot("Geometry OK", UI.ok, "checkmark.circle.fill")
      statusDot("Not rigged", UI.warn, "exclamationmark.triangle.fill")
      Button { model.remove(part.id) } label: {
        HStack(spacing: 6) { Image(systemName: "trash"); Text("Remove") }
          .font(.system(size: 12, weight: .medium)).foregroundStyle(UI.danger)
          .frame(maxWidth: .infinity).padding(.vertical, 8)
          .background(UI.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
      }.buttonStyle(.plain)
    } else {
      Text("Nothing selected").font(.system(size: 11)).foregroundStyle(UI.text3)
        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 18)
    }
  }

  // MARK: Center

  private var center: some View {
    // Two layers: the 3D viewport is FULL-BLEED (reads fine behind panels); the
    // Gallery/Table content sits inside the visible zone (contentInsets) so it
    // never hides under the floating chrome.
    ZStack {
      if let part = model.selected {
        EngineViewport(document: part.document, assetName: part.name)
      } else {
        EmptyStage(status: model.status, importAction: { model.importFiles() })
      }
      if model.centerView != "3D" {
        PartsCenterView(mode: model.centerView)
      }
    }
  }

  private var partsSubtitle: String {
    guard let character = project.active else { return "no character" }
    return "\(character.name) · \(character.parts.count) parts"
  }

  /// Publishes the active character into the shared Character Library.
  private func publish() {
    guard let character = project.active else { return }
    do {
      try CharacterLibrary.publish(character)
      model.status = "Published \(character.name) to the Character Library"
    } catch {
      model.status = "Publish failed — \(error.localizedDescription)"
    }
  }

  func statusDot(_ label: String, _ tint: Color, _ icon: String) -> some View {
    HStack(spacing: 5) {
      Image(systemName: icon).font(.system(size: 10)).foregroundStyle(tint)
      Text(label).font(.system(size: 10.5)).foregroundStyle(UI.text2)
    }
    .padding(.horizontal, 8).padding(.vertical, 5)
    .background(tint.opacity(0.12), in: Capsule())
  }
}

// MARK: - Character tool catalog

/// Character's tool catalog for the shared ToolSidebar — the transform + inspect
/// verbs from the legacy ribbon. The center tray's one ACTION (Import) moves to
/// overflow so retiring the tray loses nothing.
/// A folder inside a character — the single source of truth for the tree, the
/// left-rail tabs, and the section panels, so all three stay consistent.
enum CharacterSection: String, CaseIterable, Identifiable {
  case parts = "Parts", sourceAssets = "Source Assets", renders = "Renders"
  case assemblies = "Assemblies", scripts = "Scripts", animations = "Animations"

  var id: String { rawValue }
  var icon: String {
    switch self {
    case .parts: return "shippingbox"
    case .sourceAssets: return "cube"
    case .renders: return "photo"
    case .assemblies: return "square.stack.3d.up"
    case .scripts: return "curlybraces"
    case .animations: return "waveform.path"
    }
  }
  func count(_ c: Character) -> Int {
    switch self {
    case .parts: return c.parts.count
    case .sourceAssets: return c.sourceAssets.count
    case .renders: return 0
    case .assemblies: return c.groups.count
    case .scripts: return c.channels.count
    case .animations: return c.clips.count
    }
  }
  /// Left-rail tab order: the Characters tree, then a tab per section.
  static var railOrder: [String] { ["Characters"] + allCases.map(\.rawValue) }
}

enum CharacterTools {
  // Import / Manage / Prepare — everything you do to bring a character and its
  // assets into the project. These fire immediately (see characterAction) rather
  // than arming a canvas tool.
  static let actionLabels: Set<String> = [
    "Character", "3D Model", "Audio", "Video", "Image",
    "Replace", "Reveal", "Folder", "Duplicate",
    "Units", "Up Axis", "Origin", "Hierarchy", "Validate",
  ]
  static func isAction(_ label: String) -> Bool { actionLabels.contains(label) }

  static let groups: [ToolGroup] = [
    ToolGroup("Import", icon: "square.and.arrow.down", [
      RibbonTool("person.crop.square", "Character"), RibbonTool("cube", "3D Model"),
      RibbonTool("waveform", "Audio", primary: false),
      RibbonTool("play.rectangle", "Video", primary: false),
      RibbonTool("photo", "Image", primary: false),
    ]),
    ToolGroup("Manage", icon: "slider.horizontal.3", [
      RibbonTool("arrow.triangle.2.circlepath", "Replace"),
      RibbonTool("magnifyingglass", "Reveal"),
      RibbonTool("folder.badge.plus", "Folder", primary: false),
      RibbonTool("square.on.square", "Duplicate", primary: false),
    ]),
    ToolGroup("Prepare", icon: "wrench.and.screwdriver", [
      RibbonTool("ruler", "Units"), RibbonTool("checkmark.seal", "Validate"),
      RibbonTool("arrow.up.to.line", "Up Axis", primary: false),
      RibbonTool("scope", "Origin", primary: false),
      RibbonTool("list.bullet.indent", "Hierarchy", primary: false),
    ]),
  ]

  static let overflow: [RibbonTool] = []
  static let armGroup = RibbonGroup("Character", "person.crop.square", .accentColor, [])
}

// MARK: - Center content: parts as a gallery or a table

/// The Character center in Gallery/Table mode. Lives inside the visible zone —
/// it reads `contentInsets` from the scaffold so it never slides under the
/// floating rails, panels, tool bar, or the bottom switcher.
struct PartsCenterView: View {
  let mode: String
  @Environment(\.contentInsets) private var insets
  private var model: DemoModel { DemoModel.shared }

  var body: some View {
    Group {
      if mode == "Gallery" { gallery } else { table }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(UI.stroke, lineWidth: 1))
    .padding(insets)          // constrained to the visible zone
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text(model.projectName + " · Parts").font(.system(size: 14, weight: .semibold))
        .foregroundStyle(UI.text)
      Text("\(model.parts.count) parts").font(.system(size: 11)).foregroundStyle(UI.text3)
      Spacer()
    }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
  }

  private var gallery: some View {
    VStack(spacing: 0) {
      header
      Divider().overlay(UI.stroke)
      ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
          ForEach(model.parts) { part in
            Button { model.selectedID = part.id } label: { tile(part) }.buttonStyle(.plain)
          }
        }.padding(16)
      }
    }
  }

  private func tile(_ part: ImportedPart) -> some View {
    let sel = model.selectedID == part.id
    return VStack(spacing: 0) {
      ZStack {
        RoundedRectangle(cornerRadius: 8).fill(UI.panelHi)
        Image(systemName: "cube").font(.system(size: 30, weight: .light)).foregroundStyle(UI.text3)
      }
      .frame(height: 104)
      .overlay(alignment: .topTrailing) {
        Text("\(part.document.triangleCount) tris").font(.system(size: 9, design: .monospaced))
          .foregroundStyle(UI.text3).padding(6)
      }
      VStack(alignment: .leading, spacing: 1) {
        Text(part.name).font(.system(size: 12, weight: .medium)).foregroundStyle(UI.text).lineLimit(1)
        Text("\(part.document.faces.count) faces").font(.system(size: 10)).foregroundStyle(UI.text3)
      }
      .frame(maxWidth: .infinity, alignment: .leading).padding(8)
    }
    .background(UI.panel, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
      .stroke(sel ? UI.accent : UI.stroke, lineWidth: sel ? 2 : 1))
  }

  private var table: some View {
    VStack(spacing: 0) {
      header
      Divider().overlay(UI.stroke)
      // Column header.
      tableRow(["PART", "TYPE", "MATERIAL", "FACES", "TRIS", "SIZE (mm)"], header: true, sel: false) { }
      Divider().overlay(UI.stroke)
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(model.parts) { part in
            tableRow([part.name, "Solid body", "—",
                      "\(part.document.faces.count)", "\(part.document.triangleCount)", "—"],
                     header: false, sel: model.selectedID == part.id) {
              model.selectedID = part.id
            }
            Divider().overlay(UI.stroke.opacity(0.5))
          }
        }
      }
    }
  }

  private func tableRow(_ cols: [String], header: Bool, sel: Bool,
    onTap: @escaping () -> Void) -> some View
  {
    HStack(spacing: 0) {
      cell(cols[0], width: nil, header: header, strong: !header)
      cell(cols[1], width: 120, header: header)
      cell(cols[2], width: 120, header: header)
      cell(cols[3], width: 80, header: header, mono: !header, trailing: true)
      cell(cols[4], width: 96, header: header, mono: !header, trailing: true)
      cell(cols[5], width: 130, header: header)
    }
    .padding(.horizontal, 16).padding(.vertical, header ? 8 : 9)
    .background(sel ? UI.accent.opacity(0.16) : .clear)
    .contentShape(Rectangle())
    .onTapGesture { onTap() }
  }

  private func cell(_ text: String, width: CGFloat?, header: Bool,
    strong: Bool = false, mono: Bool = false, trailing: Bool = false) -> some View
  {
    Text(text)
      .font(.system(size: header ? 9.5 : 12,
        weight: header ? .semibold : (strong ? .medium : .regular),
        design: mono ? .monospaced : .default))
      .tracking(header ? 0.5 : 0)
      .foregroundStyle(header ? UI.text3 : (strong ? UI.text : UI.text2))
      .lineLimit(1)
      .frame(width: width, alignment: trailing ? .trailing : .leading)
      .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
  }
}
