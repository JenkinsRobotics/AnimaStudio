import CodexUICore
import SwiftUI

struct UIKitPrototype: View {
  @Environment(\.prototypeTheme) private var theme
  @Bindable var model: PrototypeModel
  @State private var demoSlider = 0.62
  @State private var demoMode = 1
  @State private var demoToggle = true
  private let columns = [GridItem(.adaptive(minimum: 300), spacing: 16)]

  var body: some View {
    specimenGallery
      .padding(.top, floatingRibbonTopClearance)
      .padding(.bottom, floatingRibbonBottomClearance)
      .animation(.spring(response: 0.32, dampingFraction: 0.9), value: model.ribbonPlacement)
      .animation(.spring(response: 0.32, dampingFraction: 0.9), value: model.floatingRibbonEdge)
  }

  private var specimenGallery: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 30) {
        galleryHeader

        section("Buttons & Controls") {
          specimen("Buttons, pills, and states") { controlsSpecimen }
          specimen("Interactive input controls") { interactiveControlsSpecimen }
          specimen("Document and inspector tabs") { tabsSpecimen }
        }

        section("Rows & Fields") {
          specimen("Hierarchy rows and states") { panelSpecimen }
          specimen("Numeric property inspector") { inspectorSpecimen }
        }

        section("Panels & Dialogs") {
          specimen("Mate authoring dialog") { mateDialogSpecimen }
          specimen("Non-blocking notification") { notificationSpecimen }
          specimen("Panel anatomy") { panelAnatomySpecimen }
        }

        section("Appearance & Layout") {
          specimen("Material controls") { materialSpecimen }
          specimen("Theme color tokens") { themeTokensSpecimen }
          specimen("Live shell layout contract") { layoutContractSpecimen }
        }

        wideSection("App Chrome") {
          specimen("Centered workspace navigator") {
            WorkspaceStageTabs(model: model, compact: false)
              .allowsHitTesting(false)
              .frame(maxWidth: .infinity)
          }
          specimen("Adaptive workspace tool ribbon · follows current layout state") {
            AdaptiveRibbon(model: model, workspace: .uiKit)
              .allowsHitTesting(false)
              .frame(maxWidth: .infinity)
          }
        }

        section("Contextual Animatronic Widgets") {
          specimen("Selection rail and adaptive actions") { SpatialSelectionToolsSpecimen() }
          specimen("Hierarchy, mate, and hardware stack") { SpatialContextStackSpecimen() }
        }

        section("Nodes") {
          specimen("Node types and selection states") { nodeVariantsSpecimen }
          specimen("Searchable categorized node library") {
            PrototypeNodeLibrary()
          }
          specimen("Selected-node inspector and typed ports") {
            PrototypeNodeInspector()
          }
        }

        wideSection("Node Canvas") {
          specimen("Connected behavior graph, canvas status, zoom, and auto layout") {
            PrototypeNodeCanvas()
              .frame(height: 380)
          }
        }

        section("Diagnostics & Status") {
          specimen("Viewport performance HUD") {
            ViewportPerformanceHUD(viewportMode: "UI Kit viewport")
          }
          specimen("Metric card") {
            MetricCard(
              title: "Triangles", value: "18,204", caption: "1 part · 3 face groups",
              color: theme.cyan)
          }
          specimen("Command icon button states") { commandButtonSpecimen }
        }

        wideSection("Timelines") {
          specimen("Production dope-sheet timeline") {
            TimelinePrototype(selectedTime: $model.selectedTime)
              .frame(height: 255)
          }
          specimen("Full-width Live Follow timeline") { SpatialTimelineSpecimen() }
        }

        wideSection("Viewport") {
          specimen("Viewport mock with selection and camera chrome") {
            MockViewport(mode: "UI KIT VIEWPORT", selected: "Head Pan Assembly")
              .frame(height: 260)
              .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          }
        }

        wideSection("Settings") {
          specimen("Native appearance, layout, and behavior settings") {
            PrototypeSettingsView(model: model)
          }
        }

        wideSection("Coverage") {
          specimen("Reusable component coverage · update this inventory with every new UI asset") {
            coverageSpecimen
          }
        }
      }
      .padding(28)
      .frame(maxWidth: 1_180, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
  }

  private var galleryHeader: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("UI Kit")
        .font(.system(size: 28, weight: .semibold))
      Text(
        "Every CodexUI component laid out flat as a living design system. Theme-aware, interactive, and ready for workspace review."
      )
      .font(.system(size: 12.5))
      .foregroundStyle(theme.secondaryText)
    }
    .padding(.top, 4)
  }

  private func section<Content: View>(
    _ title: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionTitle(title)
      LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
        content()
      }
    }
  }

  private func wideSection<Content: View>(
    _ title: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionTitle(title)
      content()
    }
  }

  private func sectionTitle(_ title: String) -> some View {
    Text(title.uppercased())
      .font(.system(size: 11, weight: .semibold))
      .tracking(0.7)
      .foregroundStyle(theme.secondaryText)
  }

  private func specimen<Content: View>(
    _ label: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      content()
      Text(label)
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(theme.secondaryText)
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
  }

  private var floatingRibbonTopClearance: CGFloat {
    model.ribbonPlacement == .floating && model.floatingRibbonEdge == .top ? 74 : 0
  }

  private var floatingRibbonBottomClearance: CGFloat {
    model.ribbonPlacement == .floating && model.floatingRibbonEdge == .bottom ? 74 : 0
  }

  private var interactiveControlsSpecimen: some View {
    PrototypePanel("Inputs", subtitle: "INTERACTIVE STATES", icon: "slider.horizontal.3") {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("Roughness").font(.system(size: 10))
          Spacer()
          Text(String(format: "%.2f", demoSlider))
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(theme.secondaryText)
        }
        Slider(value: $demoSlider)
        Picker("View", selection: $demoMode) {
          Text("Table").tag(0)
          Text("Grid").tag(1)
          Text("Canvas").tag(2)
        }
        .pickerStyle(.segmented)
        Toggle("Show edges", isOn: $demoToggle)
          .font(.system(size: 10))
        ProgressView(value: demoSlider)
      }
      .padding(10)
    }
  }

  private var panelAnatomySpecimen: some View {
    PrototypePanel("Panel Anatomy", subtitle: "STANDARD CHROME", icon: "square.dashed") {
      VStack(alignment: .leading, spacing: 8) {
        Label("Title + context", systemImage: "text.alignleft")
        Label("Shared placement authority", systemImage: "macwindow")
        Label("Canvas edge restore", systemImage: "eye.slash")
        Label("Floating material + shadow", systemImage: "shadow")
      }
      .font(.system(size: 10))
      .padding(10)
    }
  }

  private var layoutContractSpecimen: some View {
    PrototypePanel("Panel Layout", subtitle: "LIVE SHELL CONTRACT", icon: "rectangle.split.3x1") {
      VStack(spacing: 9) {
        PropertyField(label: "Left panel", value: model.leftPanelPlacement.label)
        PropertyField(label: "Right panel", value: model.rightPanelPlacement.label)
        PropertyField(label: "Tool ribbon", value: model.ribbonPlacement.label)
        Picker(
          "Preset",
          selection: Binding(
            get: { model.detectedLayoutPreset ?? .studio },
            set: { model.applyLayoutPreset($0) }
          )
        ) {
          ForEach(WorkspaceLayoutPreset.allCases) { preset in
            Text(preset.label).tag(preset)
          }
        }
        .pickerStyle(.segmented)
        Text("One browser, inspector, and ribbon contract serves every workspace.")
          .font(.system(size: 9))
          .foregroundStyle(theme.secondaryText)
      }
      .padding(10)
    }
  }

  private var themeTokensSpecimen: some View {
    let tokens: [(String, Color)] = [
      ("canvas", theme.canvas), ("panel", theme.panel), ("raised", theme.raised),
      ("inset", theme.inset), ("accent", theme.accent), ("teal", theme.cyan),
      ("indigo", theme.purple), ("warning", theme.orange), ("success", theme.green),
      ("danger", theme.danger),
    ]
    return PrototypePanel("Color Tokens", subtitle: "CURRENT THEME", icon: "swatchpalette") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 8)], spacing: 8) {
        ForEach(tokens, id: \.0) { name, color in
          VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6).fill(color).frame(height: 29)
              .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.line))
            Text(name).font(.system(size: 8)).foregroundStyle(theme.secondaryText)
          }
        }
      }
      .padding(10)
    }
  }

  private var commandButtonSpecimen: some View {
    HStack(spacing: 8) {
      Button {
      } label: {
        Image(systemName: "house")
      }
      .buttonStyle(ChromeIconButtonStyle())
      Button {
      } label: {
        Image(systemName: "gearshape")
      }
      .buttonStyle(ChromeIconButtonStyle(active: true))
      Button {
      } label: {
        Image(systemName: "trash")
      }
      .buttonStyle(ChromeIconButtonStyle())
      .disabled(true)
      LabelPill(text: "READY", color: theme.green)
    }
    .padding(10)
  }

  private var coverageSpecimen: some View {
    PrototypePanel(
      "Component Coverage",
      subtitle: "\(UIKitAssetCatalog.all.count) OF \(UIKitAssetCatalog.all.count) SHOWN",
      icon: "checkmark.seal"
    ) {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 6)], spacing: 6) {
        ForEach(UIKitAssetCatalog.all) { asset in
          HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.green)
            VStack(alignment: .leading, spacing: 1) {
              Text(asset.id).font(.system(size: 9.5, weight: .medium))
              Text("\(asset.section) · \(asset.specimen)")
                .font(.system(size: 8)).foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 4)
          }
          .padding(.horizontal, 8).frame(height: 34)
          .background(theme.raised.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
        }
      }
      .padding(10)
    }
  }

  private var panelSpecimen: some View {
    PrototypePanel("Tree Panel", subtitle: "DISCLOSURE + STATES", icon: "list.bullet.indent") {
      VStack(spacing: 2) {
        PrototypeRow(icon: "folder.fill", title: "Head Assembly", detail: "5", selected: true)
        PrototypeRow(icon: "cube", title: "Head Pan", level: 1, statusColor: .green)
        PrototypeRow(icon: "lock.fill", title: "Tilt Yoke", level: 1)
        PrototypeRow(icon: "eye.slash", title: "Jaw", detail: "Hidden", level: 1)
        PrototypeRow(icon: "link", title: "Jaw Hinge", detail: "Revolute", level: 1)
      }.padding(7)
    }
  }

  private var inspectorSpecimen: some View {
    PrototypePanel("Inspector", subtitle: "NUMERIC FIELDS", icon: "sidebar.right") {
      VStack(spacing: 8) {
        PropertyField(label: "Position X", value: "125.00", unit: "mm")
        PropertyField(label: "Position Y", value: "0.00", unit: "mm")
        PropertyField(label: "Rotation Z", value: "45.0", unit: "deg")
        Toggle("Grounded", isOn: .constant(false)).font(.system(size: 10))
        HStack {
          Button("Cancel") {}
          Spacer()
          Button("Apply") {}.buttonStyle(.borderedProminent)
        }
      }.padding(10)
    }
  }

  private var controlsSpecimen: some View {
    PrototypePanel(
      "Controls", subtitle: "NORMAL · HOVER · ACTIVE · DISABLED", icon: "button.programmable"
    ) {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Button("Primary") {}.buttonStyle(.borderedProminent)
          Button("Secondary") {}
          Button("Disabled") {}.disabled(true)
        }
        HStack {
          LabelPill(text: "READY", color: .green)
          LabelPill(text: "WARNING", color: .orange)
          LabelPill(text: "OFFLINE")
        }
        Picker("Mode", selection: .constant(1)) {
          Text("Table").tag(0)
          Text("Grid").tag(1)
          Text("Canvas").tag(2)
        }.pickerStyle(.segmented)
        Slider(value: .constant(0.62))
        ProgressView(value: 0.72)
      }.padding(10)
    }
  }

  private var mateDialogSpecimen: some View {
    PrototypePanel("Mate Dialog", subtitle: "DOCKED TOOL WINDOW", icon: "link") {
      VStack(spacing: 8) {
        HStack {
          Text("Revolute 4").font(.system(size: 11, weight: .semibold))
          Spacer()
          Button("✓") {}.buttonStyle(.borderedProminent).tint(.green)
          Button("×") {}
        }
        PropertyField(label: "Type", value: "Revolute")
        PropertyField(label: "Connector A", value: "Neck.Top")
        PropertyField(label: "Connector B", value: "Head.Origin")
        Toggle("Offset", isOn: .constant(true)).font(.system(size: 10))
        PropertyField(label: "Angle", value: "0.0", unit: "deg")
      }.padding(10)
    }
  }

  private var notificationSpecimen: some View {
    PrototypePanel("Notification", subtitle: "NON-BLOCKING STATUS", icon: "bell") {
      VStack(spacing: 10) {
        HStack(alignment: .top) {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
          VStack(alignment: .leading, spacing: 3) {
            Text("Character validated").font(.system(size: 11, weight: .semibold))
            Text("14 parts, 11 mates, and 3 relations are ready to animate.").font(.system(size: 9))
              .foregroundStyle(.secondary)
          }
          Spacer()
          Image(systemName: "xmark")
        }
        Divider()
        HStack {
          Button("View report") {}
          Spacer()
          Text("Just now").font(.system(size: 8)).foregroundStyle(.secondary)
        }
      }.padding(11)
    }
  }

  private var materialSpecimen: some View {
    PrototypePanel("Appearance", subtitle: "RENDERER-LOCAL", icon: "paintpalette") {
      HStack(spacing: 12) {
        Circle().fill(
          RadialGradient(
            colors: [.white, .gray, .black], center: .topLeading, startRadius: 2, endRadius: 45)
        ).frame(width: 76, height: 76)
        VStack(spacing: 7) {
          PropertyField(label: "Finish", value: "Satin")
          PropertyField(label: "Roughness", value: "0.42")
          PropertyField(label: "Metallic", value: "0.18")
          HStack {
            ForEach([Color.red, .orange, .yellow, .green, .blue, .purple], id: \.self) {
              $0.frame(width: 19, height: 19).clipShape(RoundedRectangle(cornerRadius: 3))
            }
          }
        }
      }.padding(11)
    }
  }

  private var tabsSpecimen: some View {
    PrototypePanel("Tabs", subtitle: "DOCUMENT + INSPECTOR", icon: "rectangle.split.3x1") {
      VStack(spacing: 10) {
        HStack(spacing: 0) {
          tab("Atlas Rig", selected: true)
          tab("Greeting.anim", selected: false)
          tab("Museum.show", selected: false)
          Button {
          } label: {
            Image(systemName: "plus")
          }.frame(width: 30)
        }
        HStack {
          Label("Properties", systemImage: "slider.horizontal.3")
          Spacer()
          Label("Appearance", systemImage: "paintpalette")
          Spacer()
          Label("Output", systemImage: "cable.connector")
        }.font(.system(size: 9)).padding(8).background(
          .black.opacity(0.13), in: RoundedRectangle(cornerRadius: 5))
      }.padding(10)
    }
  }

  private func tab(_ text: String, selected: Bool) -> some View {
    HStack {
      Text(text)
      Image(systemName: "xmark")
    }.font(.system(size: 9)).padding(.horizontal, 10).frame(height: 29).background(
      selected ? Color.blue.opacity(0.25) : Color.black.opacity(0.10)
    ).overlay(alignment: .bottom) { Rectangle().fill(selected ? .blue : .clear).frame(height: 2) }
  }

  private var nodeVariantsSpecimen: some View {
    VStack(spacing: 10) {
      PrototypeNodeCard(
        title: "Proximity Sensor", subtitle: "INPUT", icon: "sensor", color: theme.cyan,
        inputs: [], outputs: ["Distance", "Triggered"])
      PrototypeNodeCard(
        title: "If / Else", subtitle: "LOGIC", icon: "arrow.triangle.branch",
        color: theme.purple, inputs: ["Condition"], outputs: ["True", "False"])
      PrototypeNodeCard(
        title: "Language Model", subtitle: "AI + MEDIA", icon: "brain", color: .pink,
        inputs: ["Prompt", "Memory"], outputs: ["Text", "Action"], selected: true)
      PrototypeNodeCard(
        title: "Servo Output", subtitle: "HARDWARE", icon: "cable.connector",
        color: theme.green, inputs: ["Target"], outputs: ["Complete"], warning: true)
    }
  }
}
