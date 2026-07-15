import SwiftUI

struct UIDevWorkspaceView: View {
  @Binding var selectedSection: UIDevSection
  let showAgentPanel: () -> Void

  @State private var sampleName = "Head Pan"
  @State private var sampleValue = 42.0
  @State private var sampleSearch = ""
  @State private var sampleMode = "Degrees"
  @State private var sampleToggle = true
  @State private var showsPopover = false
  @State private var showsAlert = false
  @State private var showsConfirmation = false

  var body: some View {
    VStack(spacing: 0) {
      workspaceHeader
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          StudioSectionHeader(
            title: selectedSection.title,
            detail: selectedSection.purpose,
            systemImage: selectedSection.systemImage
          )
          sectionContent
        }
        .frame(maxWidth: 1_080, alignment: .leading)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .top)
      }
    }
    .background(StudioPalette.canvas)
    .alert("Standard Studio Alert", isPresented: $showsAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Alerts are short, specific, and reserved for information that blocks the task.")
    }
    .confirmationDialog(
      "Remove selected mapping?",
      isPresented: $showsConfirmation,
      titleVisibility: .visible
    ) {
      Button("Remove Mapping", role: .destructive) {}
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Destructive decisions name the object and provide a safe Cancel action.")
    }
  }

  private var workspaceHeader: some View {
    HStack(spacing: 12) {
      Image(systemName: UIDevWorkspaceDescriptor.systemImage)
        .font(.title2)
        .foregroundStyle(StudioPalette.accent)
      VStack(alignment: .leading, spacing: 2) {
        Text("LIVING UI STANDARD")
          .font(.caption.weight(.bold))
          .tracking(1.1)
        Text("Change the reusable component first; product surfaces inherit it.")
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
      }
      Spacer()
      Label("Development tool", systemImage: "wrench.and.screwdriver")
        .font(.caption.weight(.medium))
        .foregroundStyle(StudioPalette.muted)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(StudioPalette.panelInset, in: Capsule())
    }
    .padding(.horizontal, 20)
    .frame(height: 58)
    .background(StudioPalette.chrome)
  }

  @ViewBuilder
  private var sectionContent: some View {
    switch selectedSection {
    case .overview: overviewGallery
    case .buttons: buttonGallery
    case .inputs: inputGallery
    case .menus: menuGallery
    case .panels: panelGallery
    case .mateEditor: UIDevMateEditorLab()
    case .triadManipulator: UIDevTriadManipulatorLab()
    case .dialogs: dialogGallery
    case .popovers: popoverGallery
    case .tokens: tokenGallery
    }
  }

  private var overviewGallery: some View {
    LazyVGrid(columns: galleryColumns, spacing: 16) {
      standardCard(
        title: "Native first",
        detail: "Menus, alerts, keyboard focus, and accessibility use macOS behavior by default.",
        systemImage: "macwindow"
      )
      standardCard(
        title: "One visual language",
        detail: "Buttons, fields, panels, popovers, and utility windows share tokens and states.",
        systemImage: "paintbrush.pointed"
      )
      standardCard(
        title: "Honest capability",
        detail:
          "Unavailable commands remain visible only when they explain what dependency is missing.",
        systemImage: "checkmark.shield"
      )
      standardCard(
        title: "Human-readable",
        detail:
          "Plain labels, explicit units, predictable dismissal, and comfortable target sizes.",
        systemImage: "person.crop.circle.badge.checkmark"
      )
    }
  }

  private var buttonGallery: some View {
    VStack(alignment: .leading, spacing: 18) {
      sampleCard(title: "Action hierarchy", detail: "One primary action per decision area.") {
        HStack(spacing: 10) {
          Button("Create Mate", systemImage: "plus") {}
            .buttonStyle(StudioButtonStyle(role: .primary))
          Button("Preview", systemImage: "play") {}
            .buttonStyle(StudioButtonStyle(role: .secondary))
          Button("Cancel") {}
            .buttonStyle(StudioButtonStyle(role: .quiet))
          Button("Remove", systemImage: "trash") {}
            .buttonStyle(StudioButtonStyle(role: .destructive))
        }
      }
      sampleCard(
        title: "State coverage", detail: "Selected and disabled states never rely on color alone."
      ) {
        HStack(spacing: 10) {
          Button("Selected", systemImage: "checkmark") {}
            .buttonStyle(StudioIconButtonStyle(isSelected: true))
            .labelStyle(.iconOnly)
          Button("Default", systemImage: "slider.horizontal.3") {}
            .buttonStyle(StudioIconButtonStyle())
            .labelStyle(.iconOnly)
          Button("Unavailable", systemImage: "lock") {}
            .buttonStyle(StudioButtonStyle(role: .secondary))
            .disabled(true)
            .help("Disabled controls explain the missing requirement.")
        }
      }
    }
  }

  private var inputGallery: some View {
    LazyVGrid(columns: galleryColumns, alignment: .leading, spacing: 16) {
      sampleCard(
        title: "Editable fields", detail: "Labels remain visible; units stay beside values."
      ) {
        VStack(spacing: 14) {
          StudioTextFieldRow(
            title: "Display Name",
            text: $sampleName,
            placeholder: "Component name"
          )
          StudioNumberFieldRow(title: "Angle", value: $sampleValue, unit: "deg")
          StudioPickerRow(title: "Unit", selection: $sampleMode) {
            Text("Degrees").tag("Degrees")
            Text("Radians").tag("Radians")
          }
        }
      }
      sampleCard(
        title: "Search and status", detail: "Search can always be cleared; readouts are selectable."
      ) {
        VStack(spacing: 14) {
          StudioSearchField(prompt: "Filter components", text: $sampleSearch)
          StudioReadoutRow(title: "Evaluated Angle", value: "0.733", unit: "rad")
          Toggle("Show reference planes", isOn: $sampleToggle)
            .toggleStyle(.switch)
        }
      }
    }
  }

  private var menuGallery: some View {
    sampleCard(
      title: "Command menus",
      detail: "Use verbs, group related commands, and keep destructive actions last."
    ) {
      HStack(spacing: 12) {
        Menu {
          Button("New Component", systemImage: "plus") {}
          Button("Duplicate", systemImage: "plus.square.on.square") {}
          Divider()
          Button("Rename…", systemImage: "pencil") {}
          Button("Delete", systemImage: "trash", role: .destructive) {}
        } label: {
          Label("Component", systemImage: "chevron.down")
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(StudioButtonStyle(role: .secondary))

        Picker("Display", selection: $sampleMode) {
          Text("Degrees").tag("Degrees")
          Text("Radians").tag("Radians")
        }
        .pickerStyle(.menu)
        .frame(width: 150)
      }
    }
  }

  private var panelGallery: some View {
    LazyVGrid(columns: galleryColumns, alignment: .leading, spacing: 16) {
      sampleCard(
        title: "Launch real surfaces",
        detail: "The Agent docks in this app; floating tools and full workspaces are explicit."
      ) {
        VStack(spacing: 9) {
          Button("Show Docked Agent", systemImage: "sparkles") {
            showAgentPanel()
          }
          .buttonStyle(StudioButtonStyle(role: .primary, expandsHorizontally: true))

          ForEach(UIDevUtilityWindowKind.allCases) { kind in
            Button("Open \(kind.title)", systemImage: kind.systemImage) {
              UIDevUtilityWindowRegistry.show(kind)
            }
            .buttonStyle(
              StudioButtonStyle(
                role: .secondary,
                expandsHorizontally: true
              )
            )
          }
        }
      }
      UIDevSamplePanel(
        title: "Inspector",
        systemImage: "slider.horizontal.3",
        detail: "Standard panel header, inset body, and explicit close affordance."
      )
      VStack(alignment: .leading, spacing: 12) {
        UIDevSamplePanel(
          title: "Anima Agent",
          systemImage: "sparkles",
          detail: "Persistent assistance stays constrained to the app as a docked side panel."
        )
        Button("Show Agent Side Panel", systemImage: "sidebar.right") {
          showAgentPanel()
        }
        .buttonStyle(StudioButtonStyle(role: .primary, expandsHorizontally: true))
      }
    }
  }

  private var dialogGallery: some View {
    sampleCard(
      title: "Blocking decisions",
      detail: "Dialogs interrupt only for errors or consequential choices."
    ) {
      HStack(spacing: 10) {
        Button("Show Alert") { showsAlert = true }
          .buttonStyle(StudioButtonStyle(role: .secondary))
        Button("Confirm Removal") { showsConfirmation = true }
          .buttonStyle(StudioButtonStyle(role: .destructive))
      }
    }
  }

  private var popoverGallery: some View {
    sampleCard(
      title: "Context without interruption",
      detail: "Popovers belong to their trigger and dismiss without a second workflow."
    ) {
      Button("Graphics Options", systemImage: "slider.horizontal.3") {
        showsPopover.toggle()
      }
      .buttonStyle(StudioButtonStyle(role: .secondary))
      .popover(isPresented: $showsPopover, arrowEdge: .bottom) {
        VStack(alignment: .leading, spacing: 12) {
          StudioSectionHeader(
            title: "Graphics Options",
            detail: "A compact, task-specific popover.",
            systemImage: "display"
          )
          Toggle("Shaded with edges", isOn: $sampleToggle)
          Button("Graphics Preferences…") {}
            .buttonStyle(StudioButtonStyle(role: .secondary, expandsHorizontally: true))
        }
        .frame(width: 260)
        .studioPopupSurface()
      }
    }
  }

  private var tokenGallery: some View {
    VStack(alignment: .leading, spacing: 16) {
      sampleCard(
        title: "Semantic colors", detail: "Use roles, never one-off RGB values in feature views."
      ) {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 10) {
          tokenSwatch("Accent", color: StudioPalette.accent)
          tokenSwatch("Source Model", color: StudioPalette.sourceModel)
          tokenSwatch("Component", color: StudioPalette.semanticPart)
          tokenSwatch("Mate", color: StudioPalette.joint)
          tokenSwatch("Hardware", color: StudioPalette.hardware)
          tokenSwatch("Panel", color: StudioPalette.panel)
        }
      }
      sampleCard(
        title: "Geometry", detail: "Shared dimensions keep dense tools readable and predictable."
      ) {
        HStack(spacing: 20) {
          metric("Field", value: StudioMetrics.fieldHeight)
          metric("Header", value: StudioMetrics.panelHeaderHeight)
          metric("Control radius", value: StudioMetrics.controlCornerRadius)
          metric("Panel padding", value: StudioMetrics.panelPadding)
        }
      }
    }
  }

  private var galleryColumns: [GridItem] {
    [GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)]
  }

  private func sampleCard<Content: View>(
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

  private func standardCard(title: String, detail: String, systemImage: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Image(systemName: systemImage)
        .font(.title2)
        .foregroundStyle(StudioPalette.accent)
      Text(title)
        .font(.headline)
      Text(detail)
        .font(.callout)
        .foregroundStyle(StudioPalette.muted)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
    .studioCardSurface()
  }

  private func tokenSwatch(_ title: String, color: Color) -> some View {
    HStack(spacing: 9) {
      RoundedRectangle(cornerRadius: 6)
        .fill(color)
        .frame(width: 28, height: 28)
      Text(title)
        .font(.caption.weight(.medium))
      Spacer(minLength: 0)
    }
    .padding(8)
    .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 8))
  }

  private func metric(_ title: String, value: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      Text("\(Int(value)) pt")
        .font(.system(.body, design: .monospaced).weight(.semibold))
    }
  }
}

private struct UIDevSamplePanel: View {
  let title: String
  let systemImage: String
  let detail: String

  var body: some View {
    VStack(spacing: 0) {
      WorkspacePanelHeader(title: title, systemImage: systemImage, closeAction: {})
      VStack(alignment: .leading, spacing: 12) {
        Text(detail)
          .font(.callout)
          .foregroundStyle(StudioPalette.muted)
        StudioReadoutRow(title: "Surface", value: "Standard panel")
        HStack {
          Button("Cancel") {}
            .buttonStyle(StudioButtonStyle(role: .quiet))
          Spacer()
          Button("Apply") {}
            .buttonStyle(StudioButtonStyle(role: .primary))
        }
      }
      .padding(StudioMetrics.panelPadding)
      .background(StudioPalette.panel)
    }
    .clipShape(RoundedRectangle(cornerRadius: StudioMetrics.panelCornerRadius))
    .overlay {
      RoundedRectangle(cornerRadius: StudioMetrics.panelCornerRadius)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }
}
