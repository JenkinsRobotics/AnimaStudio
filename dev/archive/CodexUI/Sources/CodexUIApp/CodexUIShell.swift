import CodexUICore
import SwiftUI

struct CodexUIShell: View {
  @Bindable var model: PrototypeModel
  @State private var showsSystemStatus = false

  var body: some View {
    VStack(spacing: 0) {
      headerBar
      if model.ribbonPlacement == .docked {
        AdaptiveRibbon(model: model, workspace: model.workspace)
      }
      ZStack {
        workspaceContent
          .id(model.workspace)
          .transition(.opacity.combined(with: .scale(scale: 0.995)))
        if model.ribbonPlacement == .floating {
          AdaptiveRibbon(model: model, workspace: model.workspace)
            .padding(model.floatingRibbonEdge == .top ? .top : .bottom, 12)
            .frame(
              maxWidth: .infinity, maxHeight: .infinity,
              alignment: model.floatingRibbonEdge == .top ? .top : .bottom
            )
            .transition(
              .move(edge: model.floatingRibbonEdge == .top ? .top : .bottom)
                .combined(with: .opacity)
            )
        }
      }
      Divider().overlay(model.theme.line)
      statusBar
    }
    .overlay(alignment: .bottom) {
      if model.showsTour {
        walkthroughCard
          .frame(maxWidth: 760)
          .padding(.horizontal, 20)
          .padding(.bottom, walkthroughBottomInset)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .zIndex(20)
      }
    }
    .background(model.theme.canvas)
    .foregroundStyle(model.theme.primaryText)
    .environment(\.prototypeTheme, model.theme)
    .preferredColorScheme(model.theme.preferredColorScheme)
    .animation(.snappy(duration: 0.24), value: model.workspace)
    .animation(.spring(response: 0.3, dampingFraction: 0.9), value: model.showsTour)
  }

  private var headerBar: some View {
    GeometryReader { proxy in
      let compact = proxy.size.width < 1_600
      ZStack {
        WorkspaceStageTabs(model: model, compact: compact)
        HStack(spacing: 10) {
          headerLeft
          Spacer(minLength: compact ? 220 : 500)
          headerRight(compact: compact)
        }
      }
      .padding(.horizontal, 16)
    }
    .frame(height: CGFloat(WorkspaceHeaderMetrics.height))
    .background(model.theme.toolbar)
    .overlay(alignment: .bottom) { Rectangle().fill(model.theme.line).frame(height: 1) }
  }

  private var walkthroughBottomInset: CGFloat {
    model.ribbonPlacement == .floating && model.floatingRibbonEdge == .bottom ? 106 : 38
  }

  private var headerLeft: some View {
    HStack(spacing: 8) {
      projectIdentity
      Rectangle().fill(model.theme.line).frame(width: 1, height: 16)
      SettingsLink {
        Image(systemName: "gearshape")
      }
      .buttonStyle(ChromeIconButtonStyle())
      .help("Appearance and layout settings")
      Rectangle().fill(model.theme.line).frame(width: 1, height: 16)

      Button {
      } label: {
        Image(systemName: "house")
      }
      .buttonStyle(ChromeIconButtonStyle())
      .help("Home")
      fileMenu
      Button {
      } label: {
        Image(systemName: "arrow.uturn.backward")
      }
      .buttonStyle(ChromeIconButtonStyle())
      .help("Undo")
      Button {
      } label: {
        Image(systemName: "arrow.uturn.forward")
      }
      .buttonStyle(ChromeIconButtonStyle())
      .help("Redo")
    }
  }

  private var projectIdentity: some View {
    HStack(spacing: 9) {
      Image(systemName: "cube.fill")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(model.theme.orange)
      Text("Atlas Animatronic")
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1)
      HStack(spacing: 4) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 8, weight: .bold))
        Text("SAVED")
          .font(.system(size: 8.5, weight: .bold))
          .tracking(0.7)
      }
      .foregroundStyle(model.theme.green)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(model.theme.green.opacity(0.12), in: Capsule())
    }
    .padding(.horizontal, 7)
    .help("Open project · Atlas Animatronic · revision 12")
  }

  private var fileMenu: some View {
    Menu {
      Button("New Project", systemImage: "doc.badge.plus") {}
      Button("Open…", systemImage: "folder") {}
      Divider()
      Button("Save", systemImage: "square.and.arrow.down") {}
      Button("Import Model…", systemImage: "square.and.arrow.down.on.square") {}
    } label: {
      Image(systemName: "doc")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(model.theme.iconText)
        .frame(
          width: CGFloat(WorkspaceHeaderMetrics.controlWidth),
          height: CGFloat(WorkspaceHeaderMetrics.controlHeight)
        )
        .background(model.theme.panel, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(model.theme.line))
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .help("Project and file commands")
  }

  private func headerRight(compact: Bool) -> some View {
    HStack(spacing: 8) {
      Button {
        showsSystemStatus.toggle()
      } label: {
        HStack(spacing: 5) {
          Circle().fill(model.theme.green).frame(width: 7, height: 7)
          Text("Live").font(.system(size: 10.5, weight: .semibold))
          Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold))
        }
        .foregroundStyle(model.theme.iconText)
        .padding(.horizontal, 9)
        .frame(height: CGFloat(WorkspaceHeaderMetrics.controlHeight))
        .background(model.theme.panel, in: Capsule())
        .overlay(Capsule().stroke(model.theme.green.opacity(0.38)))
      }
      .buttonStyle(.plain)
      .popover(isPresented: $showsSystemStatus, arrowEdge: .top) {
        headerStatusPopover
      }

      Button {
        model.previewActive.toggle()
      } label: {
        HStack(spacing: 5) {
          Image(systemName: model.previewActive ? "pause.fill" : "play.fill")
            .font(.system(size: 8, weight: .bold))
          if !compact {
            Text("Preview").font(.system(size: 10.5, weight: .semibold))
          }
        }
        .foregroundStyle(model.previewActive ? Color.white : model.theme.iconText)
        .padding(.horizontal, compact ? 8 : 10)
        .frame(height: CGFloat(WorkspaceHeaderMetrics.controlHeight))
        .background(
          model.previewActive ? model.theme.accent : model.theme.panel,
          in: Capsule()
        )
        .overlay(Capsule().stroke(model.previewActive ? model.theme.accent : model.theme.line))
      }
      .buttonStyle(.plain)
      .help(model.previewActive ? "Pause preview" : "Start preview")

      Rectangle().fill(model.theme.line).frame(width: 1, height: 16)
      panelLayoutMenu
      Button {
        model.showsTour.toggle()
      } label: {
        Image(systemName: "questionmark.circle")
      }
      .buttonStyle(ChromeIconButtonStyle(active: model.showsTour))
      .help("Toggle guided walkthrough")
    }
  }

  private var panelLayoutMenu: some View {
    Menu {
      Section("Layout presets") {
        ForEach(WorkspaceLayoutPreset.allCases) { preset in
          Button {
            model.applyLayoutPreset(preset)
          } label: {
            Label(
              preset.label,
              systemImage: model.detectedLayoutPreset == preset ? "checkmark" : layoutIcon(preset)
            )
          }
        }
      }
      Menu("Browser", systemImage: "sidebar.leading") {
        ForEach(PanelPlacement.allCases) { placement in
          placementButton(placement, current: model.leftPanelPlacement) {
            model.leftPanelPlacement = placement
          }
        }
      }
      Menu("Inspector", systemImage: "sidebar.trailing") {
        ForEach(PanelPlacement.allCases) { placement in
          placementButton(placement, current: model.rightPanelPlacement) {
            model.rightPanelPlacement = placement
          }
        }
      }
      Menu("Tool Ribbon", systemImage: "rectangle.tophalf.inset.filled") {
        Button(
          "Docked",
          systemImage: model.ribbonPlacement == .docked
            ? "checkmark" : "rectangle.tophalf.inset.filled"
        ) {
          model.ribbonPlacement = .docked
        }
        Button(
          "Float at Top",
          systemImage: model.ribbonPlacement == .floating && model.floatingRibbonEdge == .top
            ? "checkmark" : "rectangle.tophalf.inset.filled"
        ) {
          model.floatingRibbonEdge = .top
          model.ribbonPlacement = .floating
        }
        Button(
          "Float at Bottom",
          systemImage: model.ribbonPlacement == .floating && model.floatingRibbonEdge == .bottom
            ? "checkmark" : "rectangle.bottomhalf.inset.filled"
        ) {
          model.floatingRibbonEdge = .bottom
          model.ribbonPlacement = .floating
        }
        Button("Hidden", systemImage: model.ribbonPlacement == .hidden ? "checkmark" : "eye.slash")
        {
          model.ribbonPlacement = .hidden
        }
      }
    } label: {
      Image(systemName: currentLayoutIcon)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Color.white)
        .frame(
          width: CGFloat(WorkspaceHeaderMetrics.controlWidth),
          height: CGFloat(WorkspaceHeaderMetrics.controlHeight)
        )
        .background(currentLayoutColor, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(currentLayoutColor.opacity(0.85), lineWidth: 1)
        )
    } primaryAction: {
      model.cycleLayoutPreset()
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .help(
      "\(model.layoutLabel) layout · click to cycle · open menu for individual panel states")
  }

  private var currentLayoutIcon: String {
    guard let preset = model.detectedLayoutPreset else { return "square.grid.2x2" }
    return layoutIcon(preset)
  }

  private var currentLayoutColor: Color {
    switch model.detectedLayoutPreset {
    case .studio: model.theme.cyan
    case .classic: model.theme.purple
    case .canvas: model.theme.orange
    case nil: model.theme.green
    }
  }

  private func placementButton(
    _ placement: PanelPlacement, current: PanelPlacement, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(
        placement.label, systemImage: placement == current ? "checkmark" : placementIcon(placement))
    }
  }

  private func layoutIcon(_ preset: WorkspaceLayoutPreset) -> String {
    switch preset {
    case .studio: "macwindow.on.rectangle"
    case .classic: "rectangle.split.3x1"
    case .canvas: "viewfinder"
    }
  }

  private func placementIcon(_ placement: PanelPlacement) -> String {
    switch placement {
    case .docked: "rectangle.split.3x1"
    case .floating: "macwindow"
    case .hidden: "eye.slash"
    }
  }

  private var headerStatusPopover: some View {
    VStack(alignment: .leading, spacing: 11) {
      Label("Prototype status", systemImage: "waveform.path.ecg")
        .font(.system(size: 11, weight: .semibold))
      Divider()
      statusRow("Engine", value: "Ready", color: model.theme.green)
      statusRow("Hardware driver", value: "Not connected", color: model.theme.secondaryText)
      statusRow("Runtime", value: "Presentation only", color: model.theme.orange)
      Toggle("Master Live", isOn: $model.masterLive)
        .toggleStyle(.switch)
        .controlSize(.mini)
        .font(.system(size: 10, weight: .medium))
      Text("No backend, files, or hardware are changed by CodexUI.")
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(width: 260)
  }

  private func statusRow(_ label: String, value: String, color: Color) -> some View {
    HStack {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(label).font(.system(size: 10))
      Spacer()
      Text(value).font(.system(size: 9, weight: .medium)).foregroundStyle(color)
    }
  }

  @ViewBuilder private var workspaceContent: some View {
    switch model.workspace {
    case .assets: AssetsPrototype(model: model)
    case .rig: RigPrototype(model: model)
    case .animate: AnimatePrototype(model: model)
    case .show: ShowPrototype(model: model)
    case .hardware: HardwarePrototype(model: model)
    case .nodes: NodesPrototype(model: model)
    case .uiKit: UIKitPrototype(model: model)
    }
  }

  private var walkthroughCard: some View {
    HStack(spacing: 12) {
      Image(systemName: model.workspace.systemImage)
        .font(.system(size: 17, weight: .semibold)).foregroundStyle(model.theme.accent)
      VStack(alignment: .leading, spacing: 2) {
        Text("WORKSPACE WALKTHROUGH · \(model.tourProgress)")
          .font(.system(size: 9, weight: .bold)).foregroundStyle(model.theme.accent)
        Text(model.workspace.purpose).font(.system(size: 11)).lineLimit(1)
      }
      Divider().frame(height: 26)
      Button {
        model.previousWorkspace()
      } label: {
        Image(systemName: "chevron.left")
      }
      .buttonStyle(ChromeIconButtonStyle())
      Button("Next") { model.nextWorkspace() }
        .buttonStyle(.borderedProminent).controlSize(.small)
      Button {
        model.showsTour = false
      } label: {
        Image(systemName: "xmark")
      }
      .buttonStyle(ChromeIconButtonStyle())
    }
    .padding(.horizontal, 13).frame(height: 48)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(model.theme.accent.opacity(0.55), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.34), radius: 18, y: 8)
  }

  private var statusBar: some View {
    HStack(spacing: 13) {
      HStack(spacing: 5) {
        Image(systemName: "hexagon.fill")
          .foregroundStyle(model.theme.orange)
        Text("CodexUI")
          .fontWeight(.semibold)
      }
      Rectangle().fill(model.theme.line).frame(width: 1, height: 13)
      Label("Prototype only", systemImage: "paintbrush.pointed")
      Text("No backend · no files are changed")
      Spacer()
      Label("60 FPS", systemImage: "gauge.with.dots.needle.50percent")
      Text("Local SwiftUI")
      Text("⌘[ / ⌘] Workspaces")
    }
    .font(.system(size: 9)).foregroundStyle(model.theme.tertiaryText)
    .padding(.horizontal, 12).frame(height: 25)
    .background(model.theme.toolbar)
  }
}
