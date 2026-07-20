// ClaudeUI — the app shell. A workspace walkthrough for a CAD-animatronic tool.
// Reference-only mockup: Onshape tree/mates + Shapr3D restraint + Bottango
// timeline/hardware + Codex-bench chrome. No engine, no persistence.
import GeomKit
import SwiftUI

enum Workspace: String, CaseIterable, Identifiable {
  case home = "Home"
  case assets = "Assets"
  case rig = "Rig"
  case animate = "Animate"
  case show = "Show"
  case hardware = "Hardware"
  case uiKit = "UI Kit"
  var id: String { rawValue }
  var icon: String {
    switch self {
    case .home: return "square.grid.2x2"
    case .assets: return "cube.transparent"
    case .rig: return "point.3.connected.trianglepath.dotted"
    case .animate: return "waveform.path"
    case .show: return "rectangle.3.group"
    case .hardware: return "cpu"
    case .uiKit: return "square.grid.3x3.fill"
    }
  }
  // The directed pipeline order (downstream stages gate on upstream ones).
  var stageIndex: Int { Workspace.pipeline.firstIndex(of: self) ?? 0 }
  static let pipeline: [Workspace] = [.assets, .rig, .animate, .show, .hardware, .uiKit]
}

@main
struct ClaudeUIApp: App {
  var body: some Scene {
    WindowGroup("AnimaStudio Demo") {
      Shell()
        .frame(minWidth: 1180, minHeight: 740)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1360, height: 860)

    // Mac-standard preferences window (⌘,)
    Settings { SettingsWindow() }
  }
}

struct Shell: View {
  @State private var current: Workspace = .assets

  var body: some View {
    VStack(spacing: 0) {
      TopBar(current: $current)
      Divider().overlay(UI.stroke)
      Group {
        switch current {
        case .home: HomeWorkspace(go: { current = $0 })
        case .assets: AssetsWorkspace()
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
    .background(UI.bg)
    .preferredColorScheme(ThemeState.shared.resolvedScheme)
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
    ZStack {
      // Pipeline stages — absolutely centered in the window, independent of the
      // side clusters' widths.
      pipelineTabs

      HStack(spacing: 14) {
        // Brand + project
        HStack(spacing: 9) {
        Image(systemName: "hexagon.fill").font(.system(size: 16)).foregroundStyle(UI.accent)
          .onTapGesture { current = .home }
        Text("Rex Animatronic").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(UI.text)
        HStack(spacing: 4) {
          Image(systemName: "checkmark.circle.fill").font(.system(size: 8, weight: .bold))
            .foregroundStyle(UI.ok)
          Text("SAVED").font(.system(size: 8.5, weight: .bold)).tracking(0.7).foregroundStyle(UI.ok)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(UI.ok.opacity(0.12), in: Capsule())
      }

      // Standard file/tool icons — left-aligned next to the brand.
      HStack(spacing: 8) {
        Divider().frame(height: 16).overlay(UI.stroke)
        projectMenu
        Button {} label: {
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

        Spacer(minLength: 12)

      // Global actions
      HStack(spacing: 8) {
        Button { showStatus.toggle() } label: {
          HStack(spacing: 6) {
            Circle().fill(UI.ok).frame(width: 7, height: 7)
            Text("Live").font(.system(size: 11, weight: .medium)).foregroundStyle(UI.text2)
            Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)).foregroundStyle(UI.text3)
          }
          .padding(.horizontal, 10).padding(.vertical, 6)
          .background(UI.panel, in: Capsule()).overlay(Capsule().stroke(UI.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("System status & outputs")
        .popover(isPresented: $showStatus, arrowEdge: .bottom) { SystemStatusView() }
        Button {} label: { Pill(icon: "play.fill", label: "Preview", active: true) }
          .buttonStyle(.plain)
        Divider().frame(height: 16).overlay(UI.stroke)
        layoutMenu
      }
      }
    }
    .padding(.horizontal, 16)
    .frame(height: 54)               // fixed so the header is identical on every workspace
    .frame(maxWidth: .infinity)
    .background(UI.panel.opacity(0.6))
  }

  private var pipelineTabs: some View {
    HStack(spacing: 2) {
      ForEach(Workspace.pipeline) { stage in
        Button { withAnimation(.easeInOut(duration: 0.16)) { current = stage } } label: {
          StageChip(stage: stage, active: current == stage)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(4).background(UI.panelHi, in: Capsule())
    .overlay(Capsule().stroke(UI.stroke, lineWidth: 1))
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
      Button("New Project", systemImage: "doc.badge.plus") {}
      Button("Open…", systemImage: "folder") {}
      Divider()
      Button("Save", systemImage: "square.and.arrow.down") {}
      Button("Import Model…", systemImage: "square.and.arrow.down.on.square") {
        DemoModel.shared.importFiles()
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
  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: stage.icon).font(.system(size: 12, weight: .medium))
      Text(stage.rawValue).font(.system(size: 12.5, weight: .medium))
    }
    .foregroundStyle(active ? .white : UI.text2)
    .padding(.horizontal, 13).padding(.vertical, 7)
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
