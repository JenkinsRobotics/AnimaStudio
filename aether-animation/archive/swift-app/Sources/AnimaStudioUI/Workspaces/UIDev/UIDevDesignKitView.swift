import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct UIDevDesignKitView: View {
  @Binding var profile: StudioDesignProfile
  let selectSurface: (UIDevSection) -> Void
  let showAgentPanel: () -> Void

  @State private var sampleName = "Head Pan"
  @State private var sampleValue = 42.0
  @State private var sampleSearch = ""
  @State private var sampleMode = "Degrees"
  @State private var sampleToggle = true
  @State private var showsPopover = false
  @State private var showsConfirmation = false
  @State private var statusMessage = "Changes apply across the app and save automatically."

  var body: some View {
    HSplitView {
      designInspector
        .frame(minWidth: 280, idealWidth: 330, maxWidth: 420)
      componentCatalog
        .frame(minWidth: 640)
    }
    .background(StudioPalette.canvas)
    .confirmationDialog(
      "Reset the complete Studio design?",
      isPresented: $showsConfirmation,
      titleVisibility: .visible
    ) {
      Button("Reset to Standard", role: .destructive) {
        profile = .standard
        statusMessage = "Standard design restored and applied."
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Colors, measurements, and panel widths return to the built-in standard preset.")
    }
  }

  private var designInspector: some View {
    VStack(spacing: 0) {
      StudioPanelHeader(
        title: "Design Inspector",
        detail: "Shared app-wide tokens",
        systemImage: "slider.horizontal.3"
      )
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          appliedStatus
          presetSection
          surfaceColors
          semanticColors
          geometryControls
          profileActions
        }
        .padding(14)
      }
    }
    .background(StudioPalette.panel)
  }

  private var appliedStatus: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("APPLIED LIVE", systemImage: "checkmark.circle.fill")
        .font(.caption.weight(.bold))
        .foregroundStyle(StudioPalette.semanticPart)
      Text(statusMessage)
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .studioCardSurface()
  }

  private var presetSection: some View {
    inspectorGroup("Presets", systemImage: "square.stack.3d.up") {
      ForEach(StudioDesignPreset.allCases) { preset in
        Button(preset.title) {
          profile = preset.profile
          statusMessage = "\(preset.title) preset applied and saved."
        }
        .buttonStyle(
          StudioButtonStyle(
            role: profile == preset.profile ? .primary : .secondary,
            density: .compact,
            expandsHorizontally: true
          )
        )
      }
    }
  }

  private var surfaceColors: some View {
    inspectorGroup("Surface Colors", systemImage: "paintpalette") {
      colorRow("Canvas", keyPath: \.canvas)
      colorRow("Document chrome", keyPath: \.documentChrome)
      colorRow("Toolbar chrome", keyPath: \.chrome)
      colorRow("Ribbon", keyPath: \.ribbonChrome)
      colorRow("Panel", keyPath: \.panel)
      colorRow("Panel inset", keyPath: \.panelInset)
      colorRow("Input field", keyPath: \.field)
      metricRow("Muted text", value: metricBinding(\.mutedOpacity), range: 0.35...1)
      metricRow("Border strength", value: metricBinding(\.borderOpacity), range: 0.04...0.5)
    }
  }

  private var semanticColors: some View {
    inspectorGroup("Semantic Colors", systemImage: "swatchpalette") {
      colorRow("Accent", keyPath: \.accent)
      colorRow("Source model", keyPath: \.sourceModel)
      colorRow("Component", keyPath: \.semanticPart)
      colorRow("Mate", keyPath: \.joint)
      colorRow("Hardware", keyPath: \.hardware)
    }
  }

  private var geometryControls: some View {
    inspectorGroup("Geometry & Layout", systemImage: "ruler") {
      metricRow(
        "Document bar",
        value: metricBinding(\.documentBarHeight),
        range: 30...48,
        unit: "pt"
      )
      metricRow(
        "Compact ribbon",
        value: metricBinding(\.compactRibbonHeight),
        range: 44...72,
        unit: "pt"
      )
      metricRow(
        "Full ribbon",
        value: metricBinding(\.fullRibbonHeight),
        range: 92...150,
        unit: "pt"
      )
      metricRow(
        "Panel radius",
        value: metricBinding(\.panelCornerRadius),
        range: 0...28,
        unit: "pt"
      )
      metricRow(
        "Panel padding",
        value: metricBinding(\.panelPadding),
        range: 8...24,
        unit: "pt"
      )
      metricRow(
        "Field height",
        value: metricBinding(\.fieldHeight),
        range: 26...44,
        unit: "pt"
      )
      metricRow(
        "Control radius",
        value: metricBinding(\.controlCornerRadius),
        range: 0...16,
        unit: "pt"
      )
      metricRow(
        "Navigator width",
        value: metricBinding(\.navigatorWidth),
        range: 240...420,
        unit: "pt"
      )
      metricRow(
        "Inspector width",
        value: metricBinding(\.inspectorWidth),
        range: 270...460,
        unit: "pt"
      )
      metricRow(
        "Agent width",
        value: metricBinding(\.agentWidth),
        range: 320...480,
        unit: "pt"
      )
    }
  }

  private var profileActions: some View {
    inspectorGroup("Profile", systemImage: "square.and.arrow.down") {
      Button("Import JSON…", systemImage: "square.and.arrow.down") {
        importProfile()
      }
      .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: true))

      Button("Export JSON…", systemImage: "square.and.arrow.up") {
        exportProfile()
      }
      .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: true))

      Button("Copy JSON", systemImage: "doc.on.doc") {
        copyProfile()
      }
      .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: true))

      Button("Reset Design…", systemImage: "arrow.counterclockwise") {
        showsConfirmation = true
      }
      .buttonStyle(StudioButtonStyle(role: .destructive, expandsHorizontally: true))
    }
  }

  private var componentCatalog: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        StudioSectionHeader(
          title: "Live UI Kit",
          detail: "Edit on the left. Every shared component below and throughout Studio updates.",
          systemImage: "paintbrush.pointed.fill"
        )
        layoutCatalog
        controlCatalog
        fieldCatalog
        menuCatalog
        panelCatalog
      }
      .frame(maxWidth: 1_120, alignment: .leading)
      .padding(22)
      .frame(maxWidth: .infinity, alignment: .top)
    }
  }

  private var layoutCatalog: some View {
    catalogCard(
      title: "Windows & Docked Surfaces",
      detail: "The same left, center, right, bottom, and assistant regions used by the app."
    ) {
      UIDevLayoutMap()
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
        surfaceButton("Navigator", image: "sidebar.left", section: .navigator)
        surfaceButton("Inspector", image: "sidebar.right", section: .inspector)
        surfaceButton(
          "Timeline",
          image: "rectangle.bottomthird.inset.filled",
          section: .timeline
        )
        surfaceButton("3D View", image: "view.3d", section: .workspace3D)
        Button("Agent", systemImage: "sparkles", action: showAgentPanel)
          .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: true))
        Button("Detached", systemImage: "macwindow.badge.plus") {
          UIDevDetachedWindowRegistry.show()
        }
        .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: true))
      }
    }
  }

  private var controlCatalog: some View {
    catalogCard(
      title: "Buttons & States",
      detail: "Primary, secondary, quiet, destructive, selected, and unavailable."
    ) {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
        Button("Primary", systemImage: "checkmark") {}
          .buttonStyle(StudioButtonStyle(role: .primary))
        Button("Secondary", systemImage: "slider.horizontal.3") {}
          .buttonStyle(StudioButtonStyle(role: .secondary))
        Button("Quiet") {}
          .buttonStyle(StudioButtonStyle(role: .quiet))
        Button("Destructive", systemImage: "trash") {}
          .buttonStyle(StudioButtonStyle(role: .destructive))
        Button("Selected", systemImage: "checkmark") {}
          .buttonStyle(StudioIconButtonStyle(isSelected: true))
        Button("Unavailable", systemImage: "lock") {}
          .buttonStyle(StudioButtonStyle(role: .secondary))
          .disabled(true)
      }
    }
  }

  private var fieldCatalog: some View {
    catalogCard(
      title: "Fields & Inputs",
      detail: "Production text, number, search, unit, picker, toggle, and readout controls."
    ) {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: 14) {
        StudioTextFieldRow(title: "Display Name", text: $sampleName)
        StudioNumberFieldRow(title: "Angle", value: $sampleValue, unit: "deg")
        StudioSearchField(prompt: "Filter components", text: $sampleSearch)
        StudioReadoutRow(title: "Evaluated Angle", value: "0.733", unit: "rad")
        StudioPickerRow(title: "Units", selection: $sampleMode) {
          Text("Degrees").tag("Degrees")
          Text("Radians").tag("Radians")
        }
        Toggle("Show reference planes", isOn: $sampleToggle)
          .toggleStyle(.switch)
      }
    }
  }

  private var menuCatalog: some View {
    catalogCard(
      title: "Menus, Popovers & Decisions",
      detail: "Native macOS interaction wrapped in the shared Studio presentation."
    ) {
      HStack(spacing: 12) {
        Menu("Component", systemImage: "chevron.down") {
          Button("New Component", systemImage: "plus") {}
          Button("Duplicate", systemImage: "plus.square.on.square") {}
          Divider()
          Button("Rename…", systemImage: "pencil") {}
          Button("Delete", systemImage: "trash", role: .destructive) {}
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: false))

        Button("Popover", systemImage: "bubble.left") {
          showsPopover.toggle()
        }
        .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: false))
        .popover(isPresented: $showsPopover, arrowEdge: .bottom) {
          VStack(alignment: .leading, spacing: 12) {
            StudioSectionHeader(
              title: "Graphics Options",
              detail: "Shared contextual surface.",
              systemImage: "display"
            )
            Toggle("Shaded with edges", isOn: $sampleToggle)
          }
          .frame(width: 270)
          .studioPopupSurface()
        }
      }
    }
  }

  private var panelCatalog: some View {
    catalogCard(
      title: "Panel Chrome",
      detail: "Headers, inset bodies, spacing, corners, borders, and action placement."
    ) {
      HStack(alignment: .top, spacing: 14) {
        samplePanel(title: "Navigator", image: "sidebar.left")
        samplePanel(title: "Inspector", image: "sidebar.right")
        samplePanel(title: "Anima Agent", image: "sparkles")
      }
    }
  }

  private func inspectorGroup<Content: View>(
    _ title: String,
    systemImage: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: systemImage)
        .font(.caption.weight(.bold))
        .foregroundStyle(StudioPalette.muted)
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .studioCardSurface()
  }

  private func catalogCard<Content: View>(
    title: String,
    detail: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      StudioSectionHeader(title: title, detail: detail)
      Divider()
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .studioCardSurface()
  }

  private func colorRow(
    _ title: String,
    keyPath: WritableKeyPath<StudioDesignProfile, StudioColorToken>
  ) -> some View {
    ColorPicker(title, selection: colorBinding(keyPath), supportsOpacity: false)
      .font(.caption)
  }

  private func metricRow(
    _ title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    unit: String = "%"
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(title)
        Spacer()
        Text(
          unit == "%"
            ? value.wrappedValue.formatted(.number.precision(.fractionLength(2)))
            : "\(Int(value.wrappedValue)) \(unit)"
        )
        .font(.system(.caption2, design: .monospaced))
        .foregroundStyle(StudioPalette.muted)
      }
      .font(.caption)
      Slider(value: value, in: range)
    }
  }

  private func colorBinding(
    _ keyPath: WritableKeyPath<StudioDesignProfile, StudioColorToken>
  ) -> Binding<Color> {
    Binding(
      get: { profile[keyPath: keyPath].color },
      set: { color in
        var updated = profile
        updated[keyPath: keyPath] = StudioColorToken(color: color)
        profile = updated
      }
    )
  }

  private func metricBinding(
    _ keyPath: WritableKeyPath<StudioDesignProfile, Double>
  ) -> Binding<Double> {
    Binding(
      get: { profile[keyPath: keyPath] },
      set: { value in
        var updated = profile
        updated[keyPath: keyPath] = value
        profile = updated
      }
    )
  }

  private func surfaceButton(
    _ title: String,
    image: String,
    section: UIDevSection
  ) -> some View {
    Button(title, systemImage: image) { selectSurface(section) }
      .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: true))
  }

  private func samplePanel(title: String, image: String) -> some View {
    VStack(spacing: 0) {
      StudioPanelHeader(title: title, detail: "Production panel", systemImage: image)
      VStack(alignment: .leading, spacing: 10) {
        StudioReadoutRow(title: "Surface", value: "Shared")
        Button("Apply") {}
          .buttonStyle(StudioButtonStyle(role: .primary))
      }
      .padding(StudioMetrics.panelPadding)
    }
    .frame(maxWidth: .infinity)
    .studioPanelSurface()
  }

  private func copyProfile() {
    guard let data = try? StudioDesignPersistence.encode(profile),
      let json = String(data: data, encoding: .utf8)
    else {
      statusMessage = "The profile could not be encoded."
      return
    }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(json, forType: .string)
    statusMessage = "Design profile copied as JSON."
  }

  private func exportProfile() {
    let panel = NSSavePanel()
    panel.title = "Export Anima Studio Design"
    panel.nameFieldStringValue = "AnimaStudioDesign.json"
    panel.allowedContentTypes = [.json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try StudioDesignPersistence.encode(profile).write(to: url, options: .atomic)
      statusMessage = "Design profile exported to \(url.lastPathComponent)."
    } catch {
      statusMessage = "Export failed: \(error.localizedDescription)"
    }
  }

  private func importProfile() {
    let panel = NSOpenPanel()
    panel.title = "Import Anima Studio Design"
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      profile = try StudioDesignPersistence.decode(Data(contentsOf: url))
      statusMessage = "\(url.lastPathComponent) imported, applied, and saved."
    } catch {
      statusMessage = "Import failed: \(error.localizedDescription)"
    }
  }
}

private struct UIDevLayoutMap: View {
  var body: some View {
    VStack(spacing: 5) {
      HStack(spacing: 5) {
        region("Navigator", image: "sidebar.left", color: StudioPalette.sourceModel)
          .frame(width: 110)
        region("3D View", image: "view.3d", color: StudioPalette.semanticPart)
        region("Inspector", image: "sidebar.right", color: StudioPalette.joint)
          .frame(width: 120)
        region("Agent", image: "sparkles", color: StudioPalette.accent)
          .frame(width: 120)
      }
      region(
        "Timeline / Graph / Show Editor",
        image: "rectangle.bottomthird.inset.filled",
        color: StudioPalette.hardware
      )
      .frame(height: 62)
    }
    .padding(8)
    .background(StudioPalette.canvas, in: RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }

  private func region(_ title: String, image: String, color: Color) -> some View {
    VStack(spacing: 5) {
      Image(systemName: image)
        .foregroundStyle(color)
      Text(title)
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, minHeight: 74)
    .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(color.opacity(0.55), lineWidth: 1)
    }
  }
}
