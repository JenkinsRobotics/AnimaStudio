import SwiftUI

enum UIDevReferenceWidgetKind: String, CaseIterable, Identifiable, Sendable {
  case layeredIconList
  case notificationPopup
  case layoutStyleControls
  case compactTabPanel
  case documentTabStrip
  case materialEditor
  case timelineDesignB
  case conceptTemplateCards

  var id: Self { self }

  var title: String {
    switch self {
    case .layeredIconList: "Layered Icon List"
    case .notificationPopup: "Notification Popup"
    case .layoutStyleControls: "Layout & Style Controls"
    case .compactTabPanel: "Compact Action Panel"
    case .documentTabStrip: "Document Tab Strip"
    case .materialEditor: "Material Editor"
    case .timelineDesignB: "Timeline Design B"
    case .conceptTemplateCards: "Concept Template Cards"
    }
  }

  var detail: String {
    switch self {
    case .layeredIconList:
      "A dense hierarchy with disclosure, selection, tags, state, and type icons."
    case .notificationPopup:
      "A dismissible, focused announcement with compact supporting content."
    case .layoutStyleControls:
      "Composable layout, border, spacing, and background inspector groups."
    case .compactTabPanel:
      "Primary and settings actions with shortcuts plus an immediate theme switch."
    case .documentTabStrip:
      "Selectable, closable project tabs with macOS window context and new-tab control."
    case .materialEditor:
      "A compact surface editor with preview, color, channels, textures, and assignment actions."
    case .timelineDesignB:
      "Multiple timeline views over shared rows, keyframes, playhead, and connected motion data."
    case .conceptTemplateCards:
      "Selectable starting-point cards with illustrations, descriptions, and clear actions."
    }
  }

  var systemImage: String {
    switch self {
    case .layeredIconList: "list.bullet.indent"
    case .notificationPopup: "bell.badge"
    case .layoutStyleControls: "rectangle.3.group.bubble"
    case .compactTabPanel: "rectangle.3.group"
    case .documentTabStrip: "rectangle.split.3x1"
    case .materialEditor: "circle.hexagongrid.fill"
    case .timelineDesignB: "timeline.selection"
    case .conceptTemplateCards: "rectangle.grid.3x2"
    }
  }

  var idealSize: CGSize {
    switch self {
    case .layeredIconList: CGSize(width: 380, height: 680)
    case .notificationPopup: CGSize(width: 340, height: 430)
    case .layoutStyleControls: CGSize(width: 980, height: 620)
    case .compactTabPanel: CGSize(width: 320, height: 190)
    case .documentTabStrip: CGSize(width: 980, height: 88)
    case .materialEditor: CGSize(width: 410, height: 620)
    case .timelineDesignB: CGSize(width: 1_080, height: 560)
    case .conceptTemplateCards: CGSize(width: 1_080, height: 680)
    }
  }
}

struct UIDevReferenceWidgetsView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        StudioSectionHeader(
          title: "Reference Widgets · Pack 01",
          detail:
            "Interactive UI Dev prototypes. Review and approve each pattern before it enters a production workspace.",
          systemImage: "square.stack.3d.up"
        )

        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 430, maximum: 680), alignment: .top)],
          alignment: .leading,
          spacing: 18
        ) {
          referenceCard(.layeredIconList)
          referenceCard(.notificationPopup)
        }

        referenceCard(.layoutStyleControls)

        StudioSectionHeader(
          title: "Reference Widgets · Pack 02 · Tab Views",
          detail:
            "Two interactive tab patterns: a compact command panel and a scalable multi-document strip.",
          systemImage: "rectangle.split.3x1"
        )

        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 430, maximum: 680), alignment: .top)],
          alignment: .leading,
          spacing: 18
        ) {
          referenceCard(.compactTabPanel)
        }

        referenceCard(.documentTabStrip)

        StudioSectionHeader(
          title: "Reference Widgets · Pack 03 · Materials",
          detail:
            "An interactive material-authoring surface for appearance, channel, and assignment workflow review.",
          systemImage: "circle.hexagongrid.fill"
        )

        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 430, maximum: 680), alignment: .top)],
          alignment: .leading,
          spacing: 18
        ) {
          referenceCard(.materialEditor)
        }

        StudioSectionHeader(
          title: "Reference Widgets · Pack 04 · Timeline Design B",
          detail:
            "Three interchangeable timeline presentations over the same editable rows and keyframes.",
          systemImage: "timeline.selection"
        )

        referenceCard(.timelineDesignB)

        StudioSectionHeader(
          title: "Reference Widgets · Pack 05 · Concept Template Cards",
          detail:
            "Reusable starting-point cards for onboarding, empty workspaces, and add-content flows.",
          systemImage: "rectangle.grid.3x2"
        )

        referenceCard(.conceptTemplateCards)
      }
      .frame(maxWidth: 1_440, alignment: .topLeading)
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .background(StudioPalette.canvas)
  }

  private func referenceCard(_ kind: UIDevReferenceWidgetKind) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        Image(systemName: kind.systemImage)
          .foregroundStyle(StudioPalette.accent)
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 2) {
          Text(kind.title)
            .font(.headline)
          Text(kind.detail)
            .font(.caption)
            .foregroundStyle(StudioPalette.muted)
        }
        Spacer(minLength: 12)
        Text("\(Int(kind.idealSize.width)) × \(Int(kind.idealSize.height))")
          .font(.caption2.monospaced().weight(.bold))
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(13)
      .background(StudioPalette.chrome)
      Divider()
      UIDevReferenceWidgetSpecimen(kind: kind)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(StudioPalette.panelInset.opacity(0.38))
    }
    .clipShape(RoundedRectangle(cornerRadius: 13))
    .overlay {
      RoundedRectangle(cornerRadius: 13)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }
}

struct UIDevReferenceWidgetSpecimen: View {
  let kind: UIDevReferenceWidgetKind

  var body: some View {
    switch kind {
    case .layeredIconList:
      UIDevLayeredIconListWidget()
    case .notificationPopup:
      UIDevNotificationPopupWidget()
    case .layoutStyleControls:
      UIDevLayoutStyleControlsWidget()
    case .compactTabPanel:
      UIDevCompactTabPanelWidget()
    case .documentTabStrip:
      UIDevDocumentTabStripWidget()
    case .materialEditor:
      UIDevMaterialWidgetView()
    case .timelineDesignB:
      UIDevTimelineDesignBView()
    case .conceptTemplateCards:
      UIDevConceptTemplateCardsView()
    }
  }
}

private struct UIDevLayeredIconListWidget: View {
  @State private var selectedID = "content"
  @State private var expandedIDs: Set<String> = ["container", "content", "active"]
  @State private var hoveredID: String?

  var body: some View {
    VStack(spacing: 0) {
      StudioPanelHeader(
        title: "Layer Stack",
        detail: "Hierarchy · tags · states",
        systemImage: "square.3.layers.3d"
      )
      Divider()
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 1) {
          ForEach(visibleRows) { row in
            if row.isSectionLabel {
              Text(row.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(StudioPalette.muted)
                .padding(.leading, CGFloat(row.depth) * 20 + 43)
                .padding(.top, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
              layerRow(row)
            }
          }
        }
        .padding(7)
      }
    }
    .frame(maxWidth: 390, minHeight: 540, maxHeight: 660)
    .studioPanelSurface()
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Layered icon list prototype")
  }

  private var visibleRows: [UIDevLayerRow] {
    Self.rows.filter(isVisible)
  }

  private func isVisible(_ row: UIDevLayerRow) -> Bool {
    var parentID = row.parentID
    while let id = parentID {
      guard expandedIDs.contains(id), let parent = Self.rows.first(where: { $0.id == id }) else {
        return false
      }
      parentID = parent.parentID
    }
    return true
  }

  private func layerRow(_ row: UIDevLayerRow) -> some View {
    let isSelected = selectedID == row.id
    let isHovering = hoveredID == row.id

    return HStack(spacing: 6) {
      Color.clear
        .frame(width: CGFloat(row.depth) * 20)

      if row.isExpandable {
        Button {
          toggleExpanded(row.id)
        } label: {
          Image(systemName: expandedIDs.contains(row.id) ? "chevron.down" : "chevron.right")
            .font(.system(size: 9, weight: .bold))
            .frame(width: 14, height: 22)
        }
        .buttonStyle(.plain)
      } else {
        Color.clear.frame(width: 14)
      }

      Image(systemName: row.systemImage)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(isSelected ? .white : row.tint)
        .frame(width: 16)

      Text(row.title)
        .font(.system(size: 12, weight: row.depth == 0 ? .semibold : .regular))
        .lineLimit(1)

      Spacer(minLength: 6)

      if let tag = row.tag {
        Text(tag)
          .font(.system(size: 8, weight: .bold, design: .rounded))
          .foregroundStyle(isSelected ? .white : tagColor(tag))
          .padding(.horizontal, 4)
          .padding(.vertical, 2)
          .background(
            (isSelected ? Color.white : tagColor(tag)).opacity(isSelected ? 0.16 : 0.10),
            in: RoundedRectangle(cornerRadius: 4)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 4)
              .stroke(isSelected ? Color.white.opacity(0.5) : tagColor(tag), lineWidth: 1)
          }
      }

      ForEach(row.trailingImages, id: \.self) { image in
        Image(systemName: image)
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(isSelected ? .white : StudioPalette.muted)
          .frame(width: 13)
      }
    }
    .padding(.horizontal, 7)
    .frame(height: 29)
    .contentShape(Rectangle())
    .background(
      isSelected
        ? StudioPalette.accent
        : isHovering ? StudioPalette.panelInset : Color.clear,
      in: RoundedRectangle(cornerRadius: 6)
    )
    .onTapGesture {
      selectedID = row.id
    }
    .onHover { isInside in
      hoveredID = isInside ? row.id : nil
    }
    .accessibilityLabel(row.title)
    .accessibilityValue(isSelected ? "Selected" : "")
  }

  private func toggleExpanded(_ id: String) {
    if expandedIDs.contains(id) {
      expandedIDs.remove(id)
    } else {
      expandedIDs.insert(id)
    }
  }

  private func tagColor(_ tag: String) -> Color {
    switch tag {
    case "NS": .pink
    case "LK": .mint
    case "CA": .purple
    case "SL": .orange
    case "A": .green
    case "M": .gray
    case "R": .red
    default: StudioPalette.accent
    }
  }

  private static let rows: [UIDevLayerRow] = [
    UIDevLayerRow(
      id: "root", title: "Root Layer", systemImage: "square.grid.3x3", depth: 0,
      tag: "NS", trailingImages: ["lock"]),
    UIDevLayerRow(
      id: "container", title: "container", systemImage: "square.dashed", depth: 0,
      isExpandable: true, trailingImages: ["snowflake"]),
    UIDevLayerRow(
      id: "halo1", title: "halo-tint-shape", systemImage: "square.resize", depth: 1,
      parentID: "container", tag: "LK", trailingImages: ["cube"]),
    UIDevLayerRow(
      id: "halo2", title: "halo2-tint-shape", systemImage: "square.resize", depth: 1,
      parentID: "container", tag: "CA", trailingImages: ["cube"]),
    UIDevLayerRow(
      id: "mica", title: "mica-layers-wrapper", systemImage: "scope", depth: 1,
      parentID: "container", isExpandable: true, trailingImages: ["diamond"]),
    UIDevLayerRow(
      id: "tinted", title: "CATintedImage", systemImage: "photo", depth: 1,
      parentID: "container"),
    UIDevLayerRow(
      id: "capture", title: "NSCGSWindow capture background", systemImage: "square.stack", depth: 1,
      parentID: "container", tag: "SL"),
    UIDevLayerRow(
      id: "content", title: "NSWindow content layer", systemImage: "macwindow", depth: 1,
      parentID: "container", isExpandable: true, trailingImages: ["bolt.fill", "diamond.fill"]),
    UIDevLayerRow(
      id: "active", title: "active", systemImage: "diamond.lefthalf.filled", depth: 2,
      parentID: "content", isExpandable: true, trailingImages: ["arrow.forward.circle"]),
    UIDevLayerRow(
      id: "elements", title: "Elements", systemImage: "", depth: 3, parentID: "active",
      isSectionLabel: true),
    UIDevLayerRow(
      id: "scale", title: "transform.scale.xy", systemImage: "diamond.fill", depth: 3,
      parentID: "active", tag: "A", trailingImages: ["arrow.forward.circle"]),
    UIDevLayerRow(
      id: "opacity", title: "opacity", systemImage: "diamond.fill", depth: 3,
      parentID: "active", tag: "M", trailingImages: ["arrow.forward.circle"]),
    UIDevLayerRow(
      id: "blur", title: "filters.gaussianBlur.inputRadius", systemImage: "diamond.fill", depth: 3,
      parentID: "active", tag: "M", trailingImages: ["arrow.forward.circle"]),
    UIDevLayerRow(
      id: "animation", title: "animation-1", systemImage: "circle.dotted", depth: 3,
      parentID: "active", tag: "R", trailingImages: ["arrow.forward.circle"]),
    UIDevLayerRow(
      id: "calayer", title: "CALayer", systemImage: "square.dashed", depth: 3,
      parentID: "active", tag: "A", trailingImages: ["arrow.forward.circle"]),
    UIDevLayerRow(
      id: "transitions", title: "Transitions", systemImage: "", depth: 3, parentID: "active",
      isSectionLabel: true),
    UIDevLayerRow(
      id: "enter", title: "* → active", systemImage: "chevron.compact.right", depth: 3,
      parentID: "active", trailingImages: ["arrow.forward.circle"]),
    UIDevLayerRow(
      id: "exit", title: "active → *", systemImage: "chevron.compact.left", depth: 3,
      parentID: "active", trailingImages: ["arrow.forward.circle"]),
    UIDevLayerRow(
      id: "dark", title: "tmp-dark", systemImage: "diamond.lefthalf.filled", depth: 2,
      parentID: "content", isExpandable: true),
    UIDevLayerRow(
      id: "click", title: "click", systemImage: "bolt.fill", depth: 2,
      parentID: "content", isExpandable: true, trailingImages: ["arrow.forward.circle"]),
  ]
}

private struct UIDevLayerRow: Identifiable {
  let id: String
  let title: String
  let systemImage: String
  let depth: Int
  var parentID: String?
  var isExpandable = false
  var isSectionLabel = false
  var tag: String?
  var trailingImages: [String] = []
  var tint = StudioPalette.muted
}

private struct UIDevNotificationPopupWidget: View {
  @State private var isDismissed = false
  @State private var primaryDevice = "pca"

  var body: some View {
    Group {
      if isDismissed {
        VStack(spacing: 12) {
          Image(systemName: "bell.slash")
            .font(.title)
            .foregroundStyle(StudioPalette.muted)
          Text("Notification dismissed")
            .font(.headline)
          Button("Restore Preview", systemImage: "arrow.counterclockwise") {
            withAnimation(.easeInOut(duration: 0.18)) {
              isDismissed = false
            }
          }
          .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: false))
        }
        .frame(width: 340, height: 410)
        .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 15))
      } else {
        notificationCard
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
    }
    .frame(maxWidth: .infinity)
  }

  private var notificationCard: some View {
    ZStack {
      VStack(spacing: 0) {
        HStack {
          Spacer()
          Button("Dismiss", systemImage: "xmark") {
            withAnimation(.easeInOut(duration: 0.18)) {
              isDismissed = true
            }
          }
          .labelStyle(.iconOnly)
          .buttonStyle(StudioIconButtonStyle())
          .help("Dismiss notification")
        }
        .padding(.horizontal, 10)
        .padding(.top, 9)

        Text("New in v0.1.5")
          .font(.caption2.weight(.semibold))
          .padding(.horizontal, 9)
          .padding(.vertical, 4)
          .background(StudioPalette.accent.opacity(0.85), in: Capsule())

        Text("Connect multiple controllers")
          .font(.title3.weight(.bold))
          .padding(.top, 14)

        Text(
          "Route one character across multiple output devices. Choose a primary controller for live testing while keeping the remaining buses visible."
        )
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 24)
        .padding(.top, 7)

        Text("You can change this later in Hardware settings.")
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
          .padding(.top, 7)

        VStack(alignment: .leading, spacing: 0) {
          Text("OUTPUT DEVICES")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(StudioPalette.muted)
            .padding(.horizontal, 10)
            .frame(height: 31, alignment: .leading)
          Divider()
          deviceRow(
            id: "pca", title: "PCA9685 · Stage Left", detail: "Primary · 12 channels",
            image: "memorychip")
          Divider()
          deviceRow(
            id: "dynamixel", title: "DYNAMIXEL Bus", detail: "6 devices · ready",
            image: "cable.connector")
        }
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .stroke(StudioPalette.border, lineWidth: 1)
        }
        .padding(14)
      }

      decorativeGem
        .offset(x: 160, y: 116)
      decorativeGem
        .scaleEffect(0.72)
        .offset(x: -166, y: 148)
    }
    .frame(width: 340, height: 410)
    .background(
      LinearGradient(
        colors: [Color(red: 0.08, green: 0.09, blue: 0.11), StudioPalette.panel],
        startPoint: .top,
        endPoint: .bottom
      ),
      in: RoundedRectangle(cornerRadius: 15)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 15)
        .stroke(Color.white.opacity(0.20), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
  }

  private func deviceRow(id: String, title: String, detail: String, image: String) -> some View {
    Button {
      primaryDevice = id
    } label: {
      HStack(spacing: 9) {
        Image(systemName: image)
          .font(.caption)
          .foregroundStyle(id == primaryDevice ? .white : StudioPalette.accent)
          .frame(width: 25, height: 25)
          .background(StudioPalette.accent.opacity(0.25), in: Circle())
        VStack(alignment: .leading, spacing: 1) {
          Text(title)
            .font(.caption.weight(.medium))
          Text(detail)
            .font(.system(size: 9))
            .foregroundStyle(id == primaryDevice ? Color.white.opacity(0.76) : StudioPalette.muted)
        }
        Spacer(minLength: 8)
        Image(systemName: id == primaryDevice ? "star.fill" : "star")
          .foregroundStyle(id == primaryDevice ? .yellow : StudioPalette.muted)
          .frame(width: 25, height: 25)
          .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
      }
      .padding(.horizontal, 9)
      .frame(height: 50)
      .background(id == primaryDevice ? StudioPalette.accent.opacity(0.34) : Color.clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var decorativeGem: some View {
    Image(systemName: "diamond.inset.filled")
      .font(.system(size: 42, weight: .light))
      .foregroundStyle(
        LinearGradient(
          colors: [.cyan, .blue, .purple, .white],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .rotationEffect(.degrees(18))
      .shadow(color: .blue.opacity(0.65), radius: 10)
      .allowsHitTesting(false)
  }
}

private struct UIDevLayoutStyleControlsWidget: View {
  @State private var displayMode = UIDevDisplayMode.grid
  @State private var cornerMode = UIDevCornerMode.all
  @State private var cornerRadius = 8.0
  @State private var borderWidth = 1.0
  @State private var borderStyle = UIDevBorderStyle.solid
  @State private var margin = 16.0
  @State private var horizontalPadding = 8.0
  @State private var verticalPadding = 4.0
  @State private var backgroundMode = UIDevBackgroundMode.gradient
  @State private var clipping = "None"

  var body: some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(minimum: 280), alignment: .top),
        GridItem(.flexible(minimum: 280), alignment: .top),
      ],
      alignment: .leading,
      spacing: 18
    ) {
      layoutPanel
      borderPanel
      spacingPanel
      backgroundPanel
    }
  }

  private var layoutPanel: some View {
    widgetPanel("Layout", systemImage: "rectangle.3.group") {
      HStack {
        StudioFieldLabel(title: "Display")
        Spacer()
        HStack(spacing: 3) {
          ForEach(UIDevDisplayMode.allCases) { mode in
            Button(mode.title, systemImage: mode.systemImage) {
              displayMode = mode
            }
            .labelStyle(.iconOnly)
            .buttonStyle(StudioIconButtonStyle(isSelected: displayMode == mode))
            .help(mode.title)
          }
        }
      }
      layoutPreview
    }
  }

  private var borderPanel: some View {
    widgetPanel("Borders", systemImage: "square.dashed") {
      HStack {
        StudioFieldLabel(title: "Radius")
        Spacer()
        HStack(spacing: 4) {
          ForEach(UIDevCornerMode.allCases) { mode in
            Button(mode.title, systemImage: mode.systemImage) {
              cornerMode = mode
            }
            .labelStyle(.iconOnly)
            .buttonStyle(StudioIconButtonStyle(isSelected: cornerMode == mode))
            .help(mode.title)
          }
        }
        TextField("Radius", value: $cornerRadius, format: .number.precision(.fractionLength(0)))
          .textFieldStyle(.roundedBorder)
          .frame(width: 54)
        Text("PX")
          .font(.caption2.weight(.bold))
      }

      cornerDiagram

      StudioNumberFieldRow(title: "Width", value: $borderWidth, unit: "px")

      HStack {
        StudioFieldLabel(title: "Style")
        Spacer()
        Picker("Style", selection: $borderStyle) {
          ForEach(UIDevBorderStyle.allCases) { style in
            Text(style.title).tag(style)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 190)
      }

      HStack {
        StudioFieldLabel(title: "Color")
        Spacer()
        RoundedRectangle(cornerRadius: 4)
          .fill(StudioPalette.muted)
          .frame(width: 24, height: 22)
        Text("Muted Border")
          .font(.caption)
      }
    }
  }

  private var spacingPanel: some View {
    widgetPanel("Spacing", systemImage: "arrow.up.left.and.arrow.down.right") {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(StudioPalette.accent.opacity(0.06))
          .overlay {
            RoundedRectangle(cornerRadius: 8)
              .stroke(StudioPalette.accent.opacity(0.28), style: StrokeStyle(dash: [4, 3]))
          }
        VStack(spacing: 7) {
          Text("MARGIN")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(StudioPalette.muted)
          spacingBadge($margin)
          ZStack {
            RoundedRectangle(cornerRadius: 5)
              .fill(StudioPalette.panel)
              .overlay {
                RoundedRectangle(cornerRadius: 5)
                  .stroke(StudioPalette.border, lineWidth: 1)
              }
            VStack(spacing: 7) {
              Text("PADDING")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(StudioPalette.muted)
              spacingBadge($verticalPadding)
              HStack {
                spacingBadge($horizontalPadding)
                RoundedRectangle(cornerRadius: 4)
                  .fill(StudioPalette.canvas)
                  .frame(width: 82, height: 62)
                spacingBadge($horizontalPadding)
              }
              spacingBadge($verticalPadding)
            }
            .padding(10)
          }
          .padding(.horizontal, 22)
          .padding(.bottom, 18)
        }
        .padding(.top, 10)
      }
      .frame(height: 230)

      Text("Click a value to edit it. Spacing remains explicit on every side.")
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
    }
  }

  private var backgroundPanel: some View {
    widgetPanel("Backgrounds", systemImage: "paintbrush") {
      HStack {
        StudioFieldLabel(title: "Image & Gradient")
        Spacer()
        Button("Add background", systemImage: "plus") {}
          .labelStyle(.iconOnly)
          .buttonStyle(StudioIconButtonStyle())
      }

      Picker("Background", selection: $backgroundMode) {
        ForEach(UIDevBackgroundMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .pickerStyle(.segmented)

      HStack(spacing: 10) {
        RoundedRectangle(cornerRadius: 7)
          .fill(backgroundFill)
          .frame(width: 58, height: 38)
          .overlay {
            RoundedRectangle(cornerRadius: 7)
              .stroke(StudioPalette.border, lineWidth: 1)
          }
        VStack(alignment: .leading, spacing: 2) {
          Text(backgroundMode.title)
            .font(.caption.weight(.semibold))
          Text("Live preview swatch")
            .font(.caption2)
            .foregroundStyle(StudioPalette.muted)
        }
        Spacer()
        Image(systemName: "line.3.horizontal.decrease")
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(8)
      .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 8))

      StudioPickerRow(title: "Clipping", selection: $clipping) {
        Text("None").tag("None")
        Text("Content").tag("Content")
        Text("Padding box").tag("Padding box")
      }
    }
  }

  private var layoutPreview: some View {
    HStack(spacing: displayMode == .list ? 5 : 10) {
      ForEach(0..<4, id: \.self) { index in
        RoundedRectangle(cornerRadius: 5)
          .fill(index == 1 ? StudioPalette.accent : StudioPalette.panelInset)
          .frame(
            maxWidth: displayMode == .hidden ? 0 : .infinity,
            minHeight: displayMode == .columns ? CGFloat(44 + index * 9) : 54
          )
          .opacity(displayMode == .hidden ? 0 : 1)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: 88)
    .background(StudioPalette.canvas, in: RoundedRectangle(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8).stroke(StudioPalette.border, lineWidth: 1)
    }
  }

  private var cornerDiagram: some View {
    ZStack {
      RoundedRectangle(cornerRadius: cornerMode == .none ? 0 : cornerRadius)
        .stroke(
          StudioPalette.muted,
          style: StrokeStyle(
            lineWidth: max(borderWidth, 1),
            dash: borderStyle.dashPattern
          )
        )
        .frame(width: 92, height: 68)
      Image(systemName: cornerMode.systemImage)
        .foregroundStyle(StudioPalette.accent)
    }
    .frame(maxWidth: .infinity, minHeight: 92)
  }

  private var backgroundFill: AnyShapeStyle {
    switch backgroundMode {
    case .solid:
      AnyShapeStyle(StudioPalette.accent)
    case .gradient:
      AnyShapeStyle(
        LinearGradient(
          colors: [.pink, .orange, .yellow],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    case .image:
      AnyShapeStyle(
        LinearGradient(
          colors: [StudioPalette.sourceModel, StudioPalette.semanticPart],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
    }
  }

  private func widgetPanel<Content: View>(
    _ title: String,
    systemImage: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(title, systemImage: systemImage)
        .font(.headline)
      Divider()
      content()
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.14), radius: 7, y: 3)
  }

  private func spacingBadge(_ value: Binding<Double>) -> some View {
    TextField("Spacing", value: value, format: .number.precision(.fractionLength(0)))
      .textFieldStyle(.plain)
      .font(.caption.monospaced().weight(.semibold))
      .multilineTextAlignment(.center)
      .frame(width: 34, height: 27)
      .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 6))
      .overlay {
        RoundedRectangle(cornerRadius: 6)
          .stroke(StudioPalette.accent.opacity(0.55), lineWidth: 1)
      }
  }
}

private enum UIDevDisplayMode: String, CaseIterable, Identifiable {
  case grid
  case list
  case columns
  case hidden

  var id: Self { self }

  var title: String {
    switch self {
    case .grid: "Grid"
    case .list: "List"
    case .columns: "Columns"
    case .hidden: "Hidden"
    }
  }

  var systemImage: String {
    switch self {
    case .grid: "square.grid.2x2"
    case .list: "rectangle.grid.1x2"
    case .columns: "rectangle.split.3x1"
    case .hidden: "eye.slash"
    }
  }
}

private enum UIDevCornerMode: String, CaseIterable, Identifiable {
  case all
  case independent
  case none

  var id: Self { self }

  var title: String {
    switch self {
    case .all: "All corners"
    case .independent: "Independent corners"
    case .none: "Square corners"
    }
  }

  var systemImage: String {
    switch self {
    case .all: "square"
    case .independent: "viewfinder"
    case .none: "square.dashed"
    }
  }
}

private enum UIDevBorderStyle: String, CaseIterable, Identifiable {
  case none
  case solid
  case dashed
  case dotted

  var id: Self { self }

  var title: String {
    switch self {
    case .none: "×"
    case .solid: "—"
    case .dashed: "--"
    case .dotted: "···"
    }
  }

  var dashPattern: [CGFloat] {
    switch self {
    case .none: [0, 100]
    case .solid: []
    case .dashed: [8, 5]
    case .dotted: [2, 4]
    }
  }
}

private enum UIDevBackgroundMode: String, CaseIterable, Identifiable {
  case solid
  case gradient
  case image

  var id: Self { self }

  var title: String {
    switch self {
    case .solid: "Solid"
    case .gradient: "Gradient"
    case .image: "Image"
    }
  }
}
