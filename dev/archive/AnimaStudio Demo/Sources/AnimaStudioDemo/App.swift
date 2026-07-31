// ClaudeUI — the app shell. A workspace walkthrough for a CAD-animatronic tool.
// Reference-only mockup: Onshape tree/mates + Shapr3D restraint + Bottango
// timeline/hardware + Codex-bench chrome. No engine, no persistence.
import AppKit
import GeomKit
import SwiftUI

/// A transparent AppKit layer that gives our custom (hidden-title-bar) header
/// the standard window behaviours: drag to move, double-click to zoom/minimise
/// per the user's macOS preference. Sits behind the header's controls, so the
/// buttons still receive their own clicks; only the empty areas act on it.
struct WindowControlArea: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView { WindowControlNSView() }
  func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowControlNSView: NSView {
  override func mouseDown(with event: NSEvent) {
    guard let window else { return super.mouseDown(with: event) }
    if event.clickCount == 2 {
      switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
      case "Minimize": window.miniaturize(nil)
      case "None": break
      default: window.zoom(nil)          // "Maximize" (default)
      }
    } else {
      window.performDrag(with: event)     // native title-bar drag
    }
  }
}

enum Workspace: String, CaseIterable, Identifiable {
  case home = "Home"
  case character = "Character"
  case design = "Design"
  case rig = "Rig"
  case animate = "Animate"
  case show = "Show"
  case hardware = "Hardware"
  case uiKit = "UI Kit"
  var id: String { rawValue }
  var icon: String {
    switch self {
    case .home: return "square.grid.2x2"
    case .character: return "figure.stand"
    case .design: return "square.on.square"
    case .rig: return "point.3.connected.trianglepath.dotted"
    case .animate: return "waveform.path"
    case .show: return "rectangle.3.group"
    case .hardware: return "cpu"
    case .uiKit: return "square.grid.3x3.fill"
    }
  }
  // The directed pipeline order (downstream stages gate on upstream ones).
  var stageIndex: Int { Workspace.pipeline.firstIndex(of: self) ?? 0 }
  // Design is hidden for now — its tools moved to Rig. Keep the case so the
  // sandbox can be re-enabled by adding `.design` back here.
  static let pipeline: [Workspace] = [.character, .rig, .animate, .show, .hardware, .uiKit]
}

@main
struct ClaudeUIApp: App {
  init() {
    // `AnimaStudioDemo --selftest` runs the headless engine checks and exits.
    if CommandLine.arguments.contains("--selftest") { SelfTest.runAndExit() }
  }

  var body: some Scene {
    WindowGroup("AnimaStudio Demo") {
      Shell(initial: .home)
        .frame(minWidth: 1180, minHeight: 740)
    }
    .windowStyle(.hiddenTitleBar)
    // Resizable above the content's minimum — otherwise SwiftUI can pin the
    // window to its content size and the edge resize affordance disappears.
    .windowResizability(.contentMinSize)
    .defaultSize(width: 1360, height: 860)

    // Mac-standard preferences window (⌘,)
    Settings { SettingsWindow() }
  }
}

struct Shell: View {
  var initial: Workspace = .character
  @State private var current: Workspace = .character

  var body: some View {
    VStack(spacing: 0) {
      TopBar(current: $current)
      Divider().overlay(UI.stroke)
      Group {
        switch current {
        case .home: HomeWorkspace(go: { current = $0 })
        case .character: CharacterWorkspace()
        case .design: DesignWorkspace()
        case .rig: RigWorkspace()
        case .animate: AnimateWorkspace()
        case .show: ShowWorkspace()
        case .hardware: HardwareWorkspace()
        case .uiKit: UIKitWorkspace()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      if LayoutState.shared.showStatusBar {
        Divider().overlay(UI.stroke)
        StatusBar(current: current)
      }
    }
    .onAppear { current = initial }
    .background(UI.bg)
    .overlay { importOverlay }
    .preferredColorScheme(ThemeState.shared.resolvedScheme)
  }

  /// Shown while a STEP import is running so the app never looks frozen.
  @ViewBuilder private var importOverlay: some View {
    let model = DemoModel.shared
    if model.loading {
      ZStack {
        Color.black.opacity(0.28).ignoresSafeArea()
        ProgressCard(
          title: "Importing model",
          detail: model.importingName,
          progress: model.importProgress,
          countText: model.importTotal > 0
            ? "\(model.importDone) of \(model.importTotal)" : nil)
      }
      .transition(.opacity)
    }
  }
}

// Bottom footer — app identity + live context on the left, render state on the
// right. Toggleable in Settings ▸ General. (CodexUI's status-bar idiom.)
struct StatusBar: View {
  var current: Workspace
  private var render: RenderState { RenderState.shared }
  private var model: DemoModel { DemoModel.shared }

  var body: some View {
    HStack(spacing: 12) {
      HStack(spacing: 5) {
        Circle().fill(UI.accent).frame(width: 6, height: 6)
        Text("Anima Studio").fontWeight(.semibold).foregroundStyle(UI.text2)
      }
      bar
      Text(current.rawValue)
      if let part = model.selected {
        bar
        Label("\(part.name) · \(part.document.triangleCount) tris", systemImage: "cube")
          .labelStyle(.titleAndIcon)
      }
      Spacer()
      Label(render.engine.rawValue, systemImage: "cpu")
      bar
      Text(render.theme.name)
      bar
      Text("OCCT \(GeomKernel.version)")
    }
    .font(.system(size: 9))
    .foregroundStyle(UI.text3)
    .padding(.horizontal, 12).frame(height: 24)
    .background(UI.panel.opacity(0.6))
  }

  private var bar: some View { Rectangle().fill(UI.stroke).frame(width: 1, height: 12) }
}

struct TopBar: View {
  @Binding var current: Workspace
  @Environment(\.openSettings) private var openSettings
  @State private var showStatus = false
  private var theme: ThemeState { ThemeState.shared }

  var body: some View {
    GeometryReader { geo in
      // Progressive collapse: the header must never let the centred tabs
      // collide with the side clusters.
      let width = geo.size.width
      let collapseIcons = width < 1320        // file icons -> overflow menu
      let compactTabs = width < 1060          // tabs -> icon only
      let compactRight = width < 880          // Live/Preview -> icons

      Group {
        if current == .home {
          homeHeader
        } else {
          // Side clusters hug their edges; the tabs are an overlay so they
          // center on the WINDOW, not on the leftover space between clusters.
          HStack(spacing: 10) {
            HStack(spacing: 10) {
              brand(compact: collapseIcons)
              if collapseIcons { overflowMenu } else { fileIcons }
            }
            .fixedSize()

            Spacer(minLength: 8)

            globalActions(compact: compactRight).fixedSize()
          }
          .overlay { pipelineTabs(compact: compactTabs) }
        }
      }
      .padding(.horizontal, 14)
      .frame(width: width, height: 54)
    }
    .frame(height: 54)
    .frame(maxWidth: .infinity)
    // Behind the controls: the header acts like a title bar — drag to move,
    // double-click to zoom (the hidden title bar can't do this itself).
    .background(WindowControlArea())
    .background(UI.panel.opacity(0.6))
  }

  /// Home gets its own chrome: identity on the left, project controls on the
  /// right. No workspace name, Live, or Preview — there's nothing open to run.
  private var homeHeader: some View {
    HStack(spacing: 12) {
      Image(systemName: "hexagon.fill").font(.system(size: 16)).foregroundStyle(UI.accent)
      VStack(alignment: .leading, spacing: 1) {
        Text("Anima Studio").font(.system(size: 14, weight: .semibold)).foregroundStyle(UI.text)
        Text("Animate digital characters and physical robots.")
          .font(.system(size: 10)).foregroundStyle(UI.text3).lineLimit(1)
      }
      Spacer(minLength: 8)
      HStack(spacing: 7) {
        headerIcon("plus", "New character") { HomeState.shared.showNewCharacter = true }
        headerIcon("square.and.arrow.down", "Import model") { DemoModel.shared.importFiles() }
        headerIcon("folder", "Open a project") { ProjectStore.open() }
        headerIcon("square.and.arrow.up", "Save") { ProjectStore.save() }
        Divider().frame(height: 16).overlay(UI.stroke)
        Button { withAnimation(.easeInOut(duration: 0.15)) { theme.toggleLightDark() } } label: {
          Image(systemName: theme.isDark ? "sun.max" : "moon").font(.system(size: 12))
            .foregroundStyle(UI.text2)
            .frame(width: 28, height: 24).background(UI.panel, in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain).help("Toggle light / dark")
        headerIcon("gearshape", "Settings") { openSettings() }
      }
      .fixedSize()
    }
  }

  private func headerIcon(_ icon: String, _ help: String, _ action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: icon).font(.system(size: 12)).foregroundStyle(UI.text2)
        .frame(width: 28, height: 24).background(UI.panel, in: RoundedRectangle(cornerRadius: 6))
    }.buttonStyle(.plain).help(help)
  }

  // MARK: - Header clusters

  private func brand(compact: Bool) -> some View {
    HStack(spacing: 9) {
      Button { withAnimation(.easeInOut(duration: 0.16)) { current = .home } } label: {
        Image(systemName: current == .home ? "house.fill" : "house")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(current == .home ? .white : UI.accent)
          .frame(width: 28, height: 24)
          .background(current == .home ? UI.accent : UI.accent.opacity(0.14),
            in: RoundedRectangle(cornerRadius: 7))
      }.buttonStyle(.plain).help("Home")
      Text(DemoModel.shared.projectName)
        .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(UI.text)
        .lineLimit(1).truncationMode(.tail)
        .fixedSize(horizontal: true, vertical: false)
      if !compact {
        HStack(spacing: 4) {
          Image(systemName: "checkmark.circle.fill").font(.system(size: 8, weight: .bold))
            .foregroundStyle(UI.ok)
          Text("SAVED").font(.system(size: 8.5, weight: .bold)).tracking(0.7).foregroundStyle(UI.ok)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(UI.ok.opacity(0.12), in: Capsule())
        .fixedSize()
      }
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private var fileIcons: some View {
    HStack(spacing: 8) {
      Divider().frame(height: 16).overlay(UI.stroke)
      projectMenu
      Button { ProjectStore.save() } label: {
        Image(systemName: "square.and.arrow.down").font(.system(size: 12)).foregroundStyle(UI.text2)
          .frame(width: 28, height: 24).background(UI.panel, in: RoundedRectangle(cornerRadius: 6))
      }.buttonStyle(.plain).help("Save (⌘S)")
      Divider().frame(height: 16).overlay(UI.stroke)
      toolIcon("arrow.uturn.backward")
      toolIcon("arrow.uturn.forward")
      Divider().frame(height: 16).overlay(UI.stroke)
      Button { withAnimation(.easeInOut(duration: 0.15)) { theme.toggleLightDark() } } label: {
        Image(systemName: theme.isDark ? "sun.max" : "moon")
          .font(.system(size: 12)).foregroundStyle(UI.text2)
          .frame(width: 28, height: 24).background(UI.panel, in: RoundedRectangle(cornerRadius: 6))
      }.buttonStyle(.plain).help("Toggle light / dark")
      Button { openSettings() } label: {
        Image(systemName: "gearshape").font(.system(size: 12)).foregroundStyle(UI.text2)
          .frame(width: 28, height: 24).background(UI.panel, in: RoundedRectangle(cornerRadius: 6))
      }.buttonStyle(.plain).help("Settings (⌘,)")
    }
    .fixedSize()
  }

  /// Everything from `fileIcons`, folded into one menu when space is tight.
  private var overflowMenu: some View {
    Menu {
      Button("New Project", systemImage: "doc.badge.plus") { ProjectStore.newProject() }
      Button("Open…", systemImage: "folder") { ProjectStore.open() }
      Button("Save", systemImage: "square.and.arrow.down") { ProjectStore.save() }
      Button("Import Model…", systemImage: "cube.transparent") { DemoModel.shared.importFiles() }
      Divider()
      Button("Undo", systemImage: "arrow.uturn.backward") {}
      Button("Redo", systemImage: "arrow.uturn.forward") {}
      Divider()
      Button(theme.isDark ? "Light Appearance" : "Dark Appearance",
        systemImage: theme.isDark ? "sun.max" : "moon") {
        withAnimation(.easeInOut(duration: 0.15)) { theme.toggleLightDark() }
      }
      Button("Settings…", systemImage: "gearshape") { openSettings() }
      Divider()
      Button("Close Project", systemImage: "xmark.circle") {
        ProjectStore.newProject()
        StudioProject.shared.close()
      }
    } label: {
      Image(systemName: "line.3.horizontal").font(.system(size: 13)).foregroundStyle(UI.text2)
        .frame(width: 28, height: 24).background(UI.panel, in: RoundedRectangle(cornerRadius: 6))
    }
    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    .help("File, edit, and settings")
  }

  private func globalActions(compact: Bool) -> some View {
    HStack(spacing: 8) {
      Button { showStatus.toggle() } label: {
        HStack(spacing: 6) {
          Circle().fill(UI.ok).frame(width: 7, height: 7)
          if !compact {
            Text("Live").font(.system(size: 11, weight: .medium)).foregroundStyle(UI.text2)
            Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
              .foregroundStyle(UI.text3)
          }
        }
        .padding(.horizontal, compact ? 8 : 10).padding(.vertical, 6)
        .background(UI.panel, in: Capsule()).overlay(Capsule().stroke(UI.stroke, lineWidth: 1))
      }
      .buttonStyle(.plain).help("System status & outputs")
      .popover(isPresented: $showStatus, arrowEdge: .bottom) { SystemStatusView() }

      Button {} label: {
        if compact {
          Image(systemName: "play.fill").font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 24).background(UI.accent, in: Capsule())
        } else {
          Pill(icon: "play.fill", label: "Preview", active: true)
        }
      }.buttonStyle(.plain)

      Divider().frame(height: 16).overlay(UI.stroke)
      layoutMenu
    }
    .fixedSize()
  }

  private func pipelineTabs(compact: Bool) -> some View {
    HStack(spacing: 2) {
      ForEach(Workspace.pipeline) { stage in
        Button { withAnimation(.easeInOut(duration: 0.16)) { current = stage } } label: {
          StageChip(stage: stage, active: current == stage, compact: compact)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(4).background(UI.panelHi, in: Capsule())
    .overlay(Capsule().stroke(UI.stroke, lineWidth: 1))
    .fixedSize()
  }

  // Studio layout toggle — click cycles Floating → Docked → Canvas; the menu
  // picks a preset directly. Flips every panel + ribbon at once.
  private var layoutMenu: some View {
    let layout = LayoutState.shared
    return Menu {
      ForEach(LayoutPreset.allCases) { p in
        Button {
          withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { layout.apply(p) }
        } label: {
          Label(p.label, systemImage: layout.detectedPreset == p ? "checkmark" : p.icon)
        }
      }
    } label: {
      Image(systemName: layout.detectedPreset?.icon ?? "square.on.square.dashed")
        .font(.system(size: 12)).foregroundStyle(UI.text2)
        .frame(width: 28, height: 24)
        .background(UI.panel, in: RoundedRectangle(cornerRadius: 6))
    } primaryAction: {
      withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { layout.cyclePreset() }
    }
    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    .help("Layout: \(layout.layoutLabel) — click to cycle")
  }

  // Project actions dropdown (CodexUI's file menu). Import is wired to the real
  // importer; the rest are placeholders until persistence lands.
  private var projectMenu: some View {
    Menu {
      Button("New Project", systemImage: "doc.badge.plus") { ProjectStore.newProject() }
      Button("Open…", systemImage: "folder") { ProjectStore.open() }
      Divider()
      Button("Save", systemImage: "square.and.arrow.down") { ProjectStore.save() }
      Button("Save As…", systemImage: "square.and.arrow.down.on.square") { ProjectStore.saveAs() }
      Divider()
      Button("Import Model…", systemImage: "cube.transparent") {
        DemoModel.shared.importFiles()
      }
      Divider()
      Button("Close Project", systemImage: "xmark.circle") {
        ProjectStore.newProject()
        StudioProject.shared.close()
      }
    } label: {
      Image(systemName: "doc").font(.system(size: 12)).foregroundStyle(UI.text2)
        .frame(width: 28, height: 24).background(UI.panel, in: RoundedRectangle(cornerRadius: 6))
    }
    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    .help("Project")
  }

  func toolIcon(_ name: String) -> some View {
    Image(systemName: name).font(.system(size: 12)).foregroundStyle(UI.text2)
      .frame(width: 28, height: 24).background(UI.panel, in: RoundedRectangle(cornerRadius: 6))
  }

}

struct StageChip: View {
  var stage: Workspace
  var active: Bool
  var compact = false
  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: stage.icon).font(.system(size: 12, weight: .medium))
      if !compact { Text(stage.rawValue).font(.system(size: 12.5, weight: .medium)) }
    }
    .foregroundStyle(active ? .white : UI.text2)
    .help(stage.rawValue)
    .padding(.horizontal, compact ? 9 : 13).padding(.vertical, 7)
    .background(active ? UI.accent : .clear, in: Capsule())
    .contentShape(Capsule())
  }
}

// System status / outputs — the old Show "Outputs" panel, now a global popover
// off the top-bar "Live" indicator. Shows every output binding + its state.
struct SystemStatusView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 7) {
        Image(systemName: "cable.connector.horizontal").font(.system(size: 11, weight: .semibold))
          .foregroundStyle(UI.text2)
        Text("OUTPUTS").font(.system(size: 10.5, weight: .semibold)).tracking(0.6)
          .foregroundStyle(UI.text2)
      }
      outputRow("cpu", "Servo bus", "PCA9685 · 6ch", UI.accent2, "Armed", UI.ok)
      outputRow("speaker.wave.2", "Audio", "Built-in · L/R", UI.warn, "Ready", UI.ok)
      outputRow("play.tv", "Video wall", "HDMI-1", UI.warn, "Ready", UI.ok)
      outputRow("light.max", "DMX lights", "8 fixtures", UI.accent, "Offline", UI.text3)
      Divider().overlay(UI.stroke)
      Text("MEDIA").font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(UI.text3)
      HStack(spacing: 8) {
        mediaChip("hello.wav", "waveform")
        mediaChip("eyes.mov", "film")
      }
    }
    .padding(16)
    .frame(width: 300)
  }

  func outputRow(_ icon: String, _ name: String, _ detail: String, _ tint: Color,
    _ status: String, _ statusTint: Color) -> some View {
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
