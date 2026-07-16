import SwiftUI

enum UIDevTemplateCategory: String, CaseIterable, Identifiable, Sendable {
  case windowsAndWorkspaces
  case timelines
  case inspectors
  case panelsAndTools
  case dialogsAndPopovers
  case controls
  case statusAndFeedback

  var id: Self { self }

  var title: String {
    switch self {
    case .windowsAndWorkspaces: "Windows & Workspaces"
    case .timelines: "Timelines & Editors"
    case .inspectors: "Inspectors"
    case .panelsAndTools: "Panels & Tools"
    case .dialogsAndPopovers: "Dialogs, Menus & Popovers"
    case .controls: "Buttons & Inputs"
    case .statusAndFeedback: "Status & Empty States"
    }
  }

  var detail: String {
    switch self {
    case .windowsAndWorkspaces:
      "Primary app regions shown at the proportions operators actually use."
    case .timelines:
      "Horizontal editing surfaces reserve width for time and track relationships."
    case .inspectors:
      "Narrow, task-focused property surfaces with explicit values and actions."
    case .panelsAndTools:
      "Persistent and temporary instruments, including rig-specific interaction tools."
    case .dialogsAndPopovers:
      "Contextual and blocking decisions shown together for wording and density review."
    case .controls:
      "The shared action, selection, field, picker, and viewport-control vocabulary."
    case .statusAndFeedback:
      "Loading, unavailable, empty, and success states remain informative and honest."
    }
  }

  var systemImage: String {
    switch self {
    case .windowsAndWorkspaces: "macwindow.on.rectangle"
    case .timelines: "timeline.selection"
    case .inspectors: "sidebar.right"
    case .panelsAndTools: "wrench.and.screwdriver"
    case .dialogsAndPopovers: "rectangle.on.rectangle.angled"
    case .controls: "switch.2"
    case .statusAndFeedback: "info.circle"
    }
  }

  var minimumCardWidth: CGFloat {
    switch self {
    case .windowsAndWorkspaces, .timelines: 430
    case .inspectors, .panelsAndTools: 330
    case .dialogsAndPopovers, .controls, .statusAndFeedback: 300
    }
  }

  var maximumCardWidth: CGFloat {
    switch self {
    case .windowsAndWorkspaces, .timelines: 590
    case .inspectors, .panelsAndTools: 450
    case .dialogsAndPopovers, .controls, .statusAndFeedback: 410
    }
  }
}

enum UIDevTemplateID: String, CaseIterable, Identifiable, Sendable {
  case recentProjects
  case layeredIconList
  case notificationPopup
  case layoutStyleControls
  case navigator
  case workspace3D
  case agent
  case animationTimeline
  case showTimeline
  case componentInspector
  case appearanceInspector
  case mateEditor
  case creationPalette
  case triadManipulator
  case hardwarePanel
  case floatingTool
  case alert
  case confirmation
  case popover
  case contextMenu
  case actionButtons
  case inputFields
  case viewportControls
  case emptyState
  case progressAndStatus

  var id: Self { self }
}

struct UIDevTemplateDescriptor: Identifiable, Equatable, Sendable {
  let id: UIDevTemplateID
  let title: String
  let detail: String
  let category: UIDevTemplateCategory
  let idealWidth: Int
  let idealHeight: Int
  let previewHeight: CGFloat
  let systemImage: String

  var idealSizeLabel: String {
    "IDEAL \(idealWidth) × \(idealHeight)"
  }
}

enum UIDevTemplateMatrixCatalog {
  static let templates: [UIDevTemplateDescriptor] = [
    descriptor(
      .recentProjects, "Recent Projects", "Start-screen project history and revisions.",
      .windowsAndWorkspaces, 440, 250, 230, "clock.arrow.circlepath"),
    descriptor(
      .navigator, "Project Navigator", "Component tree, groups, mates, and assets.",
      .windowsAndWorkspaces, 320, 520, 360, "sidebar.left"),
    descriptor(
      .workspace3D, "3D Workspace", "Primary model viewport and camera HUD.",
      .windowsAndWorkspaces, 720, 520, 360, "view.3d"),
    descriptor(
      .agent, "Anima Agent", "Docked assistant; never a floating default.",
      .windowsAndWorkspaces, 360, 560, 410, "sparkles"),

    descriptor(
      .animationTimeline, "Animation Timeline", "Tracks, playhead, keys, and transport.",
      .timelines, 760, 280, 250, "timeline.selection"),
    descriptor(
      .showTimeline, "Show Timeline", "Audio, video, event, and character tracks.",
      .timelines, 760, 300, 250, "music.note.list"),

    descriptor(
      .componentInspector, "Component Inspector", "Transform, identity, and ownership.",
      .inspectors, 340, 520, 390, "slider.horizontal.3"),
    descriptor(
      .appearanceInspector, "Appearance", "Palette, RGB, opacity, and quality.",
      .inspectors, 340, 520, 390, "paintpalette"),
    descriptor(
      .mateEditor, "Mate Editor", "Shared eight-kind mate configuration panel.",
      .inspectors, 350, 540, 390, "link.badge.plus"),

    descriptor(
      .creationPalette, "Rig Creation Palette", "Components, mates, motors, media, and events.",
      .panelsAndTools, 760, 130, 230, "shippingbox.and.arrow.backward"),
    descriptor(
      .triadManipulator, "Triad Manipulator", "Translation, rotation, and plane handles.",
      .panelsAndTools, 440, 440, 390, "move.3d"),
    descriptor(
      .layeredIconList, "Layered Icon List", "Dense hierarchy, tags, states, and type icons.",
      .panelsAndTools, 380, 680, 520, "list.bullet.indent"),
    descriptor(
      .hardwarePanel, "Hardware Monitor", "Connection, safety, channel, and output state.",
      .panelsAndTools, 360, 460, 360, "cable.connector"),
    descriptor(
      .floatingTool, "Detached Tool", "The one intentional floating utility pattern.",
      .panelsAndTools, 360, 420, 360, "macwindow.badge.plus"),

    descriptor(
      .alert, "Information Alert", "Short, blocking information with one safe exit.",
      .dialogsAndPopovers, 340, 170, 190, "exclamationmark.bubble"),
    descriptor(
      .confirmation, "Confirmation Dialog", "Consequential action, object name, and Cancel.",
      .dialogsAndPopovers, 380, 220, 220, "trash"),
    descriptor(
      .popover, "Graphics Popover", "Task-local settings anchored to their trigger.",
      .dialogsAndPopovers, 300, 250, 260, "bubble.left"),
    descriptor(
      .contextMenu, "Component Menu", "Grouped CAD-style commands and destructive tail.",
      .dialogsAndPopovers, 290, 410, 370, "filemenu.and.selection"),
    descriptor(
      .notificationPopup, "Notification Popup", "Dismissible announcement with supporting rows.",
      .dialogsAndPopovers, 340, 430, 430, "bell.badge"),

    descriptor(
      .actionButtons, "Action Buttons", "Primary, secondary, quiet, destructive, and states.",
      .controls, 360, 230, 240, "button.programmable"),
    descriptor(
      .inputFields, "Fields & Inputs", "Text, number, search, picker, toggle, and readout.",
      .controls, 380, 360, 340, "character.cursor.ibeam"),
    descriptor(
      .viewportControls, "Viewport Controls", "View cube, axes, render menu, and camera actions.",
      .controls, 360, 300, 300, "cube.transparent"),
    descriptor(
      .layoutStyleControls, "Layout & Style Controls",
      "Layout, border, spacing, and background inspector groups.",
      .controls, 980, 620, 520, "rectangle.3.group.bubble"),

    descriptor(
      .emptyState, "Empty Workspace", "A clear next action when no rig content exists.",
      .statusAndFeedback, 420, 260, 270, "square.dashed"),
    descriptor(
      .progressAndStatus, "Progress & Status",
      "Success, loading, unavailable, and safety feedback.",
      .statusAndFeedback, 380, 280, 290, "checkmark.circle"),
  ]

  static func templates(in category: UIDevTemplateCategory) -> [UIDevTemplateDescriptor] {
    templates.filter { $0.category == category }
  }

  private static func descriptor(
    _ id: UIDevTemplateID,
    _ title: String,
    _ detail: String,
    _ category: UIDevTemplateCategory,
    _ idealWidth: Int,
    _ idealHeight: Int,
    _ previewHeight: CGFloat,
    _ systemImage: String
  ) -> UIDevTemplateDescriptor {
    UIDevTemplateDescriptor(
      id: id,
      title: title,
      detail: detail,
      category: category,
      idealWidth: idealWidth,
      idealHeight: idealHeight,
      previewHeight: previewHeight,
      systemImage: systemImage
    )
  }
}

struct UIDevTemplateMatrixView: View {
  let selectSection: (UIDevSection) -> Void
  let showAgentPanel: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 34) {
        boardHeader
        ForEach(UIDevTemplateCategory.allCases) { category in
          templateSection(category)
        }
      }
      .padding(26)
      .frame(maxWidth: 1_520, alignment: .topLeading)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .background(StudioPalette.canvas)
  }

  private var boardHeader: some View {
    HStack(alignment: .top, spacing: 18) {
      VStack(alignment: .leading, spacing: 7) {
        Label("ANIMA STUDIO · UI SPECIMEN BOARD", systemImage: "rectangle.3.group.fill")
          .font(.caption.weight(.bold))
          .tracking(1.1)
          .foregroundStyle(StudioPalette.accent)
        Text("Every current surface, together")
          .font(.title2.weight(.bold))
        Text(
          "Review proportions, content density, states, wording, and visual hierarchy here. Focused labs remain available for interaction tuning."
        )
        .font(.callout)
        .foregroundStyle(StudioPalette.muted)
        .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 20)
      VStack(alignment: .trailing, spacing: 5) {
        Text("\(UIDevTemplateMatrixCatalog.templates.count) TEMPLATES")
          .font(.caption.monospaced().weight(.bold))
        Text("\(UIDevTemplateCategory.allCases.count) SECTIONS")
          .font(.caption2.monospaced())
          .foregroundStyle(StudioPalette.muted)
        Text("Shared components update live")
          .font(.caption2)
          .foregroundStyle(StudioPalette.semanticPart)
      }
      .padding(12)
      .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 10))
    }
    .padding(18)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }

  private func templateSection(_ category: UIDevTemplateCategory) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Image(systemName: category.systemImage)
          .foregroundStyle(StudioPalette.accent)
        Text(category.title)
          .font(.title3.weight(.bold))
        Text(category.detail)
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
        Spacer()
        Text("\(UIDevTemplateMatrixCatalog.templates(in: category).count)")
          .font(.caption.monospaced().weight(.bold))
          .foregroundStyle(StudioPalette.muted)
      }

      LazyVGrid(
        columns: [
          GridItem(
            .adaptive(
              minimum: category.minimumCardWidth,
              maximum: category.maximumCardWidth
            ),
            spacing: 18,
            alignment: .top
          )
        ],
        alignment: .leading,
        spacing: 18
      ) {
        ForEach(UIDevTemplateMatrixCatalog.templates(in: category)) { descriptor in
          templateCard(descriptor)
        }
      }
    }
  }

  private func templateCard(_ descriptor: UIDevTemplateDescriptor) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        Image(systemName: descriptor.systemImage)
          .foregroundStyle(StudioPalette.accent)
          .frame(width: 20)
        VStack(alignment: .leading, spacing: 2) {
          Text(descriptor.title)
            .font(.callout.weight(.bold))
          Text(descriptor.detail)
            .font(.caption2)
            .foregroundStyle(StudioPalette.muted)
            .lineLimit(2)
        }
        Spacer(minLength: 8)
        Text(descriptor.idealSizeLabel)
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(12)
      .background(StudioPalette.chrome)

      Divider()

      specimen(for: descriptor.id)
        .frame(maxWidth: .infinity, minHeight: descriptor.previewHeight, alignment: .top)
        .padding(12)
        .background(StudioPalette.panelInset.opacity(0.46))
    }
    .clipShape(RoundedRectangle(cornerRadius: 13))
    .overlay {
      RoundedRectangle(cornerRadius: 13)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
  }

  @ViewBuilder
  private func specimen(for id: UIDevTemplateID) -> some View {
    switch id {
    case .recentProjects: recentProjectsTemplate
    case .layeredIconList:
      UIDevReferenceWidgetSpecimen(kind: .layeredIconList)
    case .notificationPopup:
      UIDevReferenceWidgetSpecimen(kind: .notificationPopup)
    case .layoutStyleControls:
      scaledLab(designSize: CGSize(width: 980, height: 620)) {
        UIDevReferenceWidgetSpecimen(kind: .layoutStyleControls)
      }
    case .navigator: navigatorTemplate
    case .workspace3D: workspaceTemplate
    case .agent: agentTemplate
    case .animationTimeline: timelineTemplate(showMode: false)
    case .showTimeline: timelineTemplate(showMode: true)
    case .componentInspector: componentInspectorTemplate
    case .appearanceInspector: appearanceTemplate
    case .mateEditor:
      scaledLab(designSize: CGSize(width: 720, height: 610)) {
        UIDevMateEditorLab()
      }
    case .creationPalette: creationPaletteTemplate
    case .triadManipulator:
      scaledLab(designSize: CGSize(width: 760, height: 700)) {
        UIDevTriadManipulatorLab()
      }
    case .hardwarePanel: hardwareTemplate
    case .floatingTool: floatingToolTemplate
    case .alert: alertTemplate
    case .confirmation: confirmationTemplate
    case .popover: popoverTemplate
    case .contextMenu: contextMenuTemplate
    case .actionButtons: actionButtonsTemplate
    case .inputFields: inputTemplate
    case .viewportControls: viewportControlsTemplate
    case .emptyState: emptyStateTemplate
    case .progressAndStatus: statusTemplate
    }
  }

  private var recentProjectsTemplate: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Label("RECENT PROJECTS", systemImage: "clock.arrow.circlepath")
          .font(.caption2.weight(.bold))
          .foregroundStyle(StudioPalette.muted)
        Spacer()
        Text("2 RECENT")
          .font(.caption2.monospaced())
          .foregroundStyle(StudioPalette.muted)
      }
      ForEach(Self.recentProjectSamples) { project in
        RecentProjectCard(project: project)
      }
    }
  }

  private var navigatorTemplate: some View {
    VStack(spacing: 0) {
      StudioPanelHeader(title: "Components", detail: "UI Dev Sample Rig", systemImage: "cube")
      Divider()
      VStack(alignment: .leading, spacing: 4) {
        treeRow("Base", image: "cube", indent: 0)
        treeRow("Head Assembly", image: "folder.fill", indent: 0, selected: true)
        treeRow("Torso", image: "cube", indent: 1)
        treeRow("Head", image: "sphere", indent: 1)
        Divider().padding(.vertical, 5)
        Text("MATES")
          .font(.caption2.weight(.bold))
          .foregroundStyle(StudioPalette.muted)
        treeRow("Head Yaw", image: "link", indent: 0)
        treeRow("Base Fastened", image: "link", indent: 0)
        Divider().padding(.vertical, 5)
        Text("ASSETS")
          .font(.caption2.weight(.bold))
          .foregroundStyle(StudioPalette.muted)
        treeRow("robot.usdz", image: "shippingbox", indent: 0)
        Spacer(minLength: 0)
        HStack {
          Button("Add Group", systemImage: "folder.badge.plus") {}
          Button("More", systemImage: "ellipsis") {}
        }
        .labelStyle(.iconOnly)
        .buttonStyle(StudioIconButtonStyle())
      }
      .padding(10)
    }
    .frame(maxWidth: 330, minHeight: 340)
    .studioPanelSurface()
    .frame(maxWidth: .infinity)
  }

  private var workspaceTemplate: some View {
    ZStack(alignment: .topTrailing) {
      Canvas { context, size in
        let spacing: CGFloat = 22
        var grid = Path()
        for x in stride(from: CGFloat.zero, through: size.width, by: spacing) {
          grid.move(to: CGPoint(x: x, y: 0))
          grid.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: CGFloat.zero, through: size.height, by: spacing) {
          grid.move(to: CGPoint(x: 0, y: y))
          grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(grid, with: .color(.white.opacity(0.07)), lineWidth: 0.5)

        let body = CGRect(
          x: size.width * 0.34,
          y: size.height * 0.31,
          width: size.width * 0.30,
          height: size.height * 0.34
        )
        context.fill(
          Path(roundedRect: body, cornerRadius: 20),
          with: .linearGradient(
            Gradient(colors: [StudioPalette.semanticPart, StudioPalette.accent]),
            startPoint: body.origin,
            endPoint: CGPoint(x: body.maxX, y: body.maxY)
          )
        )
        context.stroke(
          Path(roundedRect: body.insetBy(dx: -3, dy: -3), cornerRadius: 22),
          with: .color(.orange),
          lineWidth: 2
        )
      }
      .background(
        LinearGradient(
          colors: [StudioPalette.canvas, Color.black.opacity(0.86)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )

      VStack(spacing: 5) {
        Text("TOP")
          .font(.system(size: 9, weight: .bold))
        HStack(spacing: 4) {
          Text("FRONT")
          Text("RIGHT")
        }
        .font(.system(size: 8, weight: .semibold))
      }
      .foregroundStyle(.primary)
      .padding(9)
      .background(StudioPalette.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 9))
      .overlay {
        RoundedRectangle(cornerRadius: 9).stroke(StudioPalette.border, lineWidth: 1)
      }
      .padding(10)

      HStack {
        Label("X", systemImage: "arrow.right")
          .foregroundStyle(.red)
        Label("Y", systemImage: "arrow.up")
          .foregroundStyle(.green)
        Label("Z", systemImage: "arrow.up.right")
          .foregroundStyle(.blue)
        Spacer()
        Button("Home", systemImage: "house") {}
        Button("Display", systemImage: "cube") {}
      }
      .font(.caption2.weight(.bold))
      .labelStyle(.iconOnly)
      .buttonStyle(StudioIconButtonStyle())
      .padding(10)
      .frame(maxHeight: .infinity, alignment: .bottom)
    }
    .frame(minHeight: 335)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10).stroke(StudioPalette.border, lineWidth: 1)
    }
  }

  private var agentTemplate: some View {
    StudioAgentPanelView(close: {})
      .frame(width: 360, height: 390)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10).stroke(StudioPalette.border, lineWidth: 1)
      }
      .frame(maxWidth: .infinity)
      .onTapGesture(count: 2, perform: showAgentPanel)
  }

  private func timelineTemplate(showMode: Bool) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 9) {
        Button("Jump to start", systemImage: "backward.end.fill") {}
        Button("Play", systemImage: "play.fill") {}
        Button("Jump to end", systemImage: "forward.end.fill") {}
        Text(showMode ? "00:01:12.08" : "00:00:02.000")
          .font(.caption.monospaced().weight(.bold))
        Spacer()
        Button("Add Track", systemImage: "plus") {}
      }
      .labelStyle(.iconOnly)
      .buttonStyle(StudioIconButtonStyle())
      .padding(8)
      .background(StudioPalette.chrome)
      Divider()
      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 0) {
          timelineTrack(showMode ? "AUDIO" : "Head Yaw", color: StudioPalette.accent)
          timelineTrack(showMode ? "CHARACTER" : "Jaw", color: StudioPalette.semanticPart)
          timelineTrack(showMode ? "EVENTS" : "Eyes", color: StudioPalette.joint)
        }
        .frame(width: 130)
        Divider()
        Canvas { context, size in
          let rows = 3
          for row in 0..<rows {
            let y = CGFloat(row) * size.height / CGFloat(rows)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(.white.opacity(0.10)), lineWidth: 1)
          }
          for step in 0...8 {
            let x = CGFloat(step) * size.width / 8
            var marker = Path()
            marker.move(to: CGPoint(x: x, y: 0))
            marker.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(marker, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
          }
          let keyColor = showMode ? StudioPalette.hardware : StudioPalette.accent
          for point in [
            CGPoint(x: 0.18, y: 0.17), CGPoint(x: 0.48, y: 0.50), CGPoint(x: 0.76, y: 0.83),
          ] {
            let rect = CGRect(
              x: size.width * point.x - 5,
              y: size.height * point.y - 5,
              width: 10,
              height: 10
            )
            context.fill(Path(rect), with: .color(keyColor))
          }
          let playheadX = size.width * 0.58
          var playhead = Path()
          playhead.move(to: CGPoint(x: playheadX, y: 0))
          playhead.addLine(to: CGPoint(x: playheadX, y: size.height))
          context.stroke(playhead, with: .color(.red), lineWidth: 1.5)
        }
      }
    }
    .frame(minHeight: 220)
    .background(StudioPalette.panel)
    .clipShape(RoundedRectangle(cornerRadius: 9))
    .overlay {
      RoundedRectangle(cornerRadius: 9).stroke(StudioPalette.border, lineWidth: 1)
    }
  }

  private var componentInspectorTemplate: some View {
    inspectorShell(title: "Component", systemImage: "cube") {
      StudioTextFieldRow(title: "Name", text: .constant("Head Assembly"))
      StudioReadoutRow(title: "Proxy Shape", value: "Imported Model")
      Divider()
      inspectorValue("Position X", "0.000 m")
      inspectorValue("Position Y", "1.450 m")
      inspectorValue("Position Z", "0.000 m")
      inspectorValue("Rotation", "0°, 0°, 0°")
      Toggle("Visible", isOn: .constant(true))
      Button("Frame Selection", systemImage: "viewfinder") {}
        .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: true))
    }
  }

  private var appearanceTemplate: some View {
    inspectorShell(title: "Appearance", systemImage: "paintpalette") {
      Picker("Mode", selection: .constant("Palette")) {
        Text("Palette").tag("Palette")
        Text("Mixer").tag("Mixer")
      }
      .pickerStyle(.segmented)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4)
      {
        ForEach(Self.appearanceColors.indices, id: \.self) { index in
          RoundedRectangle(cornerRadius: 3)
            .fill(Self.appearanceColors[index])
            .frame(height: 24)
            .overlay {
              if index == 11 {
                Image(systemName: "checkmark")
                  .font(.caption2.bold())
                  .foregroundStyle(.white)
              }
            }
        }
      }
      StudioTextFieldRow(title: "Hex", text: .constant("#9DCFED"))
      StudioReadoutRow(title: "RGB", value: "157 · 207 · 237")
      StudioReadoutRow(title: "Opacity", value: "100", unit: "%")
      StudioPickerRow(title: "Tessellation", selection: .constant("Auto")) {
        Text("Auto").tag("Auto")
        Text("High").tag("High")
      }
    }
  }

  private var creationPaletteTemplate: some View {
    VStack(alignment: .leading, spacing: 12) {
      creationGroup(
        "Structures", color: StudioPalette.semanticPart,
        tools: ["Box", "Cylinder", "Sphere", "Point"])
      creationGroup(
        "Mates", color: StudioPalette.joint, tools: ["Fastened", "Slider", "Revolute", "Ball"])
      HStack(spacing: 8) {
        creationGroup("Motors", color: StudioPalette.hardware, tools: ["Servo", "Stepper"])
        creationGroup("Media", color: StudioPalette.sourceModel, tools: ["Video", "3D Model"])
      }
      .opacity(0.48)
    }
  }

  private var hardwareTemplate: some View {
    inspectorShell(title: "Hardware", systemImage: "cable.connector") {
      statusRow("Connection", value: "Offline", color: .secondary)
      statusRow("Master Live", value: "Disarmed", color: StudioPalette.hardware)
      statusRow("Driver", value: "No Driver", color: .secondary)
      Divider()
      StudioPickerRow(title: "Device", selection: .constant("None")) {
        Text("No devices").tag("None")
      }
      StudioReadoutRow(title: "Channels", value: "0")
      StudioReadoutRow(title: "Heartbeat", value: "—")
      Button("Connect Device", systemImage: "link") {}
        .buttonStyle(StudioButtonStyle(role: .primary, expandsHorizontally: true))
        .disabled(true)
      Button("Emergency Stop", systemImage: "stop.fill") {}
        .buttonStyle(StudioButtonStyle(role: .destructive, expandsHorizontally: true))
    }
  }

  private var floatingToolTemplate: some View {
    UIDevFloatingPanelTemplateView()
      .frame(width: 340, height: 340)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10).stroke(StudioPalette.border, lineWidth: 1)
      }
      .frame(maxWidth: .infinity)
  }

  private var alertTemplate: some View {
    dialogShell(title: "Model Could Not Be Imported", systemImage: "exclamationmark.triangle") {
      Text("The selected file is not a supported USD, USDZ, or RealityKit model.")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      HStack {
        Spacer()
        Button("OK") {}
          .buttonStyle(StudioButtonStyle(role: .primary, expandsHorizontally: false))
      }
    }
  }

  private var confirmationTemplate: some View {
    dialogShell(title: "Remove Head Yaw?", systemImage: "trash") {
      Text("The mate and its animation tracks will be removed. This cannot be undone yet.")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      HStack {
        Spacer()
        Button("Cancel") {}
          .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: false))
        Button("Remove Mate") {}
          .buttonStyle(StudioButtonStyle(role: .destructive, expandsHorizontally: false))
      }
    }
  }

  private var popoverTemplate: some View {
    VStack(alignment: .leading, spacing: 12) {
      StudioSectionHeader(
        title: "Graphics Options",
        detail: "Viewport display",
        systemImage: "display"
      )
      Divider()
      Toggle("Shaded with edges", isOn: .constant(true))
      Toggle("Hidden edges visible", isOn: .constant(false))
      Toggle("Tangent edges visible", isOn: .constant(true))
      StudioPickerRow(title: "Lighting", selection: .constant("Balanced")) {
        Text("Balanced").tag("Balanced")
      }
      Button("Graphics Preferences…") {}
        .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: true))
    }
    .frame(maxWidth: 290)
    .studioPopupSurface()
    .frame(maxWidth: .infinity)
  }

  private var contextMenuTemplate: some View {
    VStack(alignment: .leading, spacing: 2) {
      menuRow("Properties", "info.circle")
      menuRow("Appearance…", "paintpalette")
      Divider()
      menuRow("Hide Component", "eye.slash")
      menuRow("Isolate", "scope")
      menuRow("Make Transparent", "circle.dotted")
      Divider()
      menuRow("Frame Selection", "viewfinder")
      menuRow("View Normal To", "square.3.layers.3d")
      Divider()
      menuRow("Lock Component", "lock")
      menuRow("Move to Group", "folder")
      Divider()
      menuRow("Delete Component", "trash", destructive: true)
    }
    .padding(7)
    .frame(maxWidth: 275)
    .background(StudioPalette.panel)
    .clipShape(RoundedRectangle(cornerRadius: 9))
    .overlay {
      RoundedRectangle(cornerRadius: 9).stroke(StudioPalette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.34), radius: 12, y: 5)
    .frame(maxWidth: .infinity)
  }

  private var actionButtonsTemplate: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button("Create Mate", systemImage: "plus") {}
        .buttonStyle(StudioButtonStyle(role: .primary, expandsHorizontally: true))
      Button("Preview Motion", systemImage: "play") {}
        .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: true))
      HStack {
        Button("Quiet") {}
          .buttonStyle(StudioButtonStyle(role: .quiet))
        Button("Remove", systemImage: "trash") {}
          .buttonStyle(StudioButtonStyle(role: .destructive))
      }
      HStack {
        Button("Selected", systemImage: "checkmark") {}
          .labelStyle(.iconOnly)
          .buttonStyle(StudioIconButtonStyle(isSelected: true))
        Button("Default", systemImage: "slider.horizontal.3") {}
          .labelStyle(.iconOnly)
          .buttonStyle(StudioIconButtonStyle())
        Button("Unavailable", systemImage: "lock") {}
          .buttonStyle(StudioButtonStyle(role: .secondary))
          .disabled(true)
      }
    }
  }

  private var inputTemplate: some View {
    VStack(alignment: .leading, spacing: 13) {
      StudioTextFieldRow(title: "Display Name", text: .constant("Head Pan"))
      StudioNumberFieldRow(title: "Angle", value: .constant(42), unit: "deg")
      StudioSearchField(prompt: "Filter components", text: .constant(""))
      StudioPickerRow(title: "Units", selection: .constant("Degrees")) {
        Text("Degrees").tag("Degrees")
        Text("Radians").tag("Radians")
      }
      Toggle("Show reference planes", isOn: .constant(true))
      StudioReadoutRow(title: "Evaluated Angle", value: "0.733", unit: "rad")
    }
  }

  private var viewportControlsTemplate: some View {
    VStack(spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(StudioPalette.canvas)
        VStack(spacing: 5) {
          Text("TOP")
          HStack(spacing: 7) {
            Text("FRONT")
            Text("RIGHT")
          }
        }
        .font(.caption2.weight(.bold))
        .padding(18)
        .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 9))
        .rotation3DEffect(.degrees(-12), axis: (x: 1, y: -1, z: 0))
        VStack {
          Spacer()
          HStack {
            Text("Y").foregroundStyle(.green)
            Text("Z").foregroundStyle(.blue)
            Spacer()
            Text("X").foregroundStyle(.red)
          }
          .font(.caption2.bold())
        }
        .padding(12)
      }
      .frame(height: 170)
      HStack {
        Button("Home", systemImage: "house") {}
        Button("Fit", systemImage: "viewfinder") {}
        Button("Display", systemImage: "cube") {}
        Button("Perspective", systemImage: "camera") {}
      }
      .labelStyle(.iconOnly)
      .buttonStyle(StudioIconButtonStyle())
    }
  }

  private var emptyStateTemplate: some View {
    VStack(spacing: 14) {
      Image(systemName: "cube.transparent")
        .font(.system(size: 48, weight: .thin))
        .foregroundStyle(StudioPalette.semanticPart)
      Text("Build the semantic rig")
        .font(.headline)
      Text("Add a component or import a model to begin defining movable structure.")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
        .multilineTextAlignment(.center)
      Button("Add Components", systemImage: "plus") {}
        .buttonStyle(StudioButtonStyle(role: .primary, expandsHorizontally: false))
    }
    .frame(maxWidth: .infinity, minHeight: 245)
  }

  private var statusTemplate: some View {
    VStack(alignment: .leading, spacing: 12) {
      statusBanner("Design profile applied", "checkmark.circle.fill", StudioPalette.semanticPart)
      statusBanner("Reading model hierarchy…", "progress.indicator", StudioPalette.accent) {
        ProgressView().controlSize(.small)
      }
      statusBanner("Hardware output unavailable", "lock.shield", StudioPalette.hardware)
      statusBanner("Project saving requires the document layer", "info.circle", .secondary)
    }
  }

  private func scaledLab<Content: View>(
    designSize: CGSize,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    GeometryReader { proxy in
      let scale = min(proxy.size.width / designSize.width, proxy.size.height / designSize.height)
      content()
        .frame(width: designSize.width, height: designSize.height, alignment: .topLeading)
        .scaleEffect(scale, anchor: .topLeading)
    }
    .frame(minHeight: 370)
    .clipped()
  }

  private func inspectorShell<Content: View>(
    title: String,
    systemImage: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(spacing: 0) {
      StudioPanelHeader(title: title, detail: "Inspector", systemImage: systemImage)
      Divider()
      VStack(alignment: .leading, spacing: 12) {
        content()
      }
      .padding(12)
    }
    .frame(maxWidth: 350)
    .studioPanelSurface()
    .frame(maxWidth: .infinity)
  }

  private func dialogShell<Content: View>(
    title: String,
    systemImage: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 13) {
      Label(title, systemImage: systemImage)
        .font(.headline)
      content()
    }
    .padding(16)
    .frame(maxWidth: 370)
    .background(StudioPalette.panel)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12).stroke(StudioPalette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.30), radius: 14, y: 6)
    .frame(maxWidth: .infinity)
  }

  private func treeRow(
    _ title: String,
    image: String,
    indent: CGFloat,
    selected: Bool = false
  ) -> some View {
    HStack(spacing: 8) {
      Image(systemName: image)
        .foregroundStyle(selected ? .white : StudioPalette.semanticPart)
      Text(title)
      Spacer()
      if selected {
        Image(systemName: "checkmark")
          .font(.caption2.bold())
      }
    }
    .font(.caption)
    .padding(.leading, indent * 18)
    .padding(.horizontal, 8)
    .frame(height: 29)
    .background(selected ? StudioPalette.accent : .clear, in: RoundedRectangle(cornerRadius: 6))
  }

  private func timelineTrack(_ title: String, color: Color) -> some View {
    HStack(spacing: 7) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(title)
        .font(.system(size: 9, weight: .bold))
      Spacer()
    }
    .padding(.horizontal, 9)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(StudioPalette.panelInset)
  }

  private func inspectorValue(_ title: String, _ value: String) -> some View {
    HStack {
      Text(title)
        .foregroundStyle(StudioPalette.muted)
      Spacer()
      Text(value)
        .font(.system(.caption, design: .monospaced))
    }
    .font(.caption)
  }

  private func creationGroup(_ title: String, color: Color, tools: [String]) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title.uppercased())
        .font(.caption2.weight(.bold))
        .foregroundStyle(color)
      HStack(spacing: 8) {
        ForEach(tools, id: \.self) { tool in
          VStack(spacing: 5) {
            Image(systemName: "cube.transparent")
              .font(.title3)
            Text(tool)
              .font(.system(size: 9, weight: .medium))
          }
          .foregroundStyle(color)
          .frame(maxWidth: .infinity)
          .padding(7)
          .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func statusRow(_ title: String, value: String, color: Color) -> some View {
    HStack {
      Text(title)
        .foregroundStyle(StudioPalette.muted)
      Spacer()
      Circle().fill(color).frame(width: 7, height: 7)
      Text(value)
        .fontWeight(.medium)
    }
    .font(.caption)
  }

  private func menuRow(
    _ title: String,
    _ image: String,
    destructive: Bool = false
  ) -> some View {
    HStack(spacing: 9) {
      Image(systemName: image)
        .frame(width: 17)
      Text(title)
      Spacer()
    }
    .font(.caption)
    .foregroundStyle(destructive ? .red : .primary)
    .padding(.horizontal, 8)
    .frame(height: 27)
  }

  private func statusBanner<Accessory: View>(
    _ title: String,
    _ image: String,
    _ color: Color,
    @ViewBuilder accessory: () -> Accessory
  ) -> some View {
    HStack(spacing: 10) {
      Image(systemName: image)
        .foregroundStyle(color)
        .frame(width: 20)
      Text(title)
        .font(.caption.weight(.medium))
      Spacer()
      accessory()
    }
    .padding(11)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 9))
    .overlay {
      RoundedRectangle(cornerRadius: 9).stroke(StudioPalette.border, lineWidth: 1)
    }
  }

  private func statusBanner(_ title: String, _ image: String, _ color: Color) -> some View {
    statusBanner(title, image, color) { EmptyView() }
  }

  private static let recentProjectSamples = [
    RecentProjectSummary(
      id: UUID(uuidString: "B22B0000-0000-4000-8000-000000000001")!,
      displayName: "Jaeger Joint Representation",
      lastOpenedAt: Date(timeIntervalSince1970: 1_782_758_620),
      revisionNumber: 12,
      milestoneName: "Rig foundation",
      thumbnailKind: .character
    ),
    RecentProjectSummary(
      id: UUID(uuidString: "B22B0000-0000-4000-8000-000000000002")!,
      displayName: "MK1 Robot Component",
      lastOpenedAt: Date(timeIntervalSince1970: 1_735_206_480),
      revisionNumber: 38,
      thumbnailKind: .rig
    ),
  ]

  private static let appearanceColors: [Color] = [
    .black, .blue, .red, .white, .gray, .orange, .yellow, .purple,
    Color(red: 0.35, green: 0.35, blue: 0.37),
    Color(red: 0.25, green: 0.48, blue: 0.68),
    Color(red: 0.31, green: 0.66, blue: 0.56),
    Color(red: 0.62, green: 0.81, blue: 0.93),
    Color(red: 0.76, green: 0.35, blue: 0.24),
    Color(red: 0.96, green: 0.62, blue: 0.22),
    Color(red: 0.44, green: 0.31, blue: 0.72),
    Color(red: 0.74, green: 0.35, blue: 0.66),
  ]
}
