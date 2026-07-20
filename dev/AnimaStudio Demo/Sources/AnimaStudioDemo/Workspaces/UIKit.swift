// UI Kit — a scrollable gallery of every component we've built, grouped and laid
// out flat (nothing locked to its workspace position). The living design system.
import GeomKit
import SwiftUI

struct UIKitWorkspace: View {
  @State private var telemetry = LiveTelemetry()
  @State private var demoSlider = 0.4
  @State private var demoSeg = 0
  @State private var demoToggle = true
  @State private var demoChip = "24 fps"
  @State private var demoTab = 0
  @State private var demoSearch = ""
  @State private var demoStepper = 45.0
  @State private var demoInspectorTab = 0
  private let cols = [GridItem(.adaptive(minimum: 300), spacing: 16)]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 30) {
        VStack(alignment: .leading, spacing: 6) {
          Text("UI Kit").font(.system(size: 28, weight: .semibold)).foregroundStyle(UI.text)
          Text("Every component in Anima Studio, laid out flat. Theme-aware — switch themes to preview.")
            .font(.system(size: 12.5)).foregroundStyle(UI.text3)
        }.padding(.top, 4)

        section("Buttons & Pills") {
          specimen("Pill · active") { Pill(icon: "play.fill", label: "Preview", active: true) }
          specimen("Pill · idle") { Pill(icon: "cube", label: "Wireframe") }
          specimen("Pill · tints") {
            HStack(spacing: 8) {
              Pill(label: "Key", active: true, tint: UI.warn)
              Pill(label: "Loop", tint: UI.accent2)
            }
          }
          specimen("Stage chips") {
            HStack(spacing: 4) {
              StageChip(stage: .rig, active: true); StageChip(stage: .show, active: false)
            }
          }
        }

        section("Rows & Fields") {
          specimen("Row · plain") { Row(icon: "cube", label: "Femur", detail: "12f", tint: UI.accent2) }
          specimen("Row · selected + controls") {
            Row(icon: "point.3.connected.trianglepath.dotted", label: "Knee", detail: "revolute",
              tint: UI.accent, selected: true, controls: true)
          }
          specimen("Fields") {
            VStack(spacing: 8) {
              Field(label: "Axis", value: "Z")
              Field(label: "Angle", value: "42.0", unit: "°")
              Field(label: "Triangles", value: "18,204")
            }
          }
        }

        section("Panels & Toolbars") {
          specimen("Panel") {
            Panel(title: "Models", systemImage: "cube.transparent") {
              VStack(spacing: 0) {
                Row(icon: "cube", label: "Wheel", detail: "3f", tint: UI.accent2)
                Row(icon: "cube", label: "Tire", detail: "1f", tint: UI.accent2)
              }.padding(.vertical, 4)
            }.frame(height: 150)
          }
          specimen("Center tray") {
            CenterTray(items: [
              TrayItem("plus", "Import"),
              TrayItem("cube", "Display") { Text("Display").padding() },
              TrayItem("viewfinder", "Fit"),
            ])
          }
          specimen("Tool ribbon · floating") { ToolRibbon(groups: Self.sampleRibbon) }
        }

        section("Contextual Widgets") {
          specimen("Context inspector") { ContextInspector(mate: "Knee", type: "revolute") }
          specimen("Curve card") { CurveCard() }
          specimen("Environment") { EnvironmentPanel() }
          specimen("Performance HUD") {
            PerformanceHUD(engine: .realityKit, telemetry: telemetry, document: nil, onClose: {})
          }
          specimen("System status") { SystemStatusView() }
        }

        // Timeline is full-width (rendered outside the grid) to show its true size.
        VStack(alignment: .leading, spacing: 14) {
          Text("TIMELINE & GRAPH").font(.system(size: 11, weight: .semibold)).tracking(0.7)
            .foregroundStyle(UI.text3)
          specimen("Dope-sheet timeline · full width") {
            DopeSheetTimeline(
              tracks: [("Hip", UI.accent), ("Knee", UI.accent), ("Ankle", UI.accent2), ("Jaw", UI.warn)],
              playhead: .constant(0.36)
            ).frame(height: 230)
          }
          LazyVGrid(columns: cols, alignment: .leading, spacing: 16) {
            specimen("Graph node") {
              HStack(spacing: 20) {
                GraphNode(title: "Clip", icon: "waveform.path", sub: "Greeting.anim", tint: UI.accent, selected: true)
                GraphNode(title: "Servos", icon: "cpu", sub: "6 channels", tint: UI.accent2)
              }
            }
            specimen("Servo track") {
              VStack(spacing: 0) {
                ServoTrack(name: "Knee", channel: 2, degrees: 42, fraction: 0.55, selected: true, armed: true)
                ServoTrack(name: "Jaw", channel: 4, degrees: 12, fraction: 0.2, armed: true)
              }
            }
          }
        }

        section("Panels & Lists") {
          specimen("Panel card · icon badge + subtitle + menu") {
            PanelCard(title: "Animation Clips", subtitle: "Atlas · 6 clips",
              icon: "film.stack", tint: UI.accent) {
              VStack(spacing: 0) {
                ListRow(icon: "play.rectangle", title: "Greeting", detail: "8.0 s", selected: true)
                ListRow(icon: "play.rectangle", title: "Idle Breathing", detail: "12.0 s")
                ListRow(icon: "play.rectangle", title: "Curious Look", detail: "4.5 s")
              }.padding(.vertical, 4)
              Divider().overlay(UI.stroke)
              HStack(spacing: 8) {
                PanelAction(icon: "plus", label: "Clip"); PanelAction(icon: "doc.on.doc"); Spacer()
              }.padding(10)
            }
          }
          specimen("List rows · states") {
            VStack(spacing: 0) {
              ListRow(icon: "circle.fill", title: "Base Motion", detail: "100%", statusColor: UI.ok)
              ListRow(icon: "circle.lefthalf.filled", title: "Face + Eyes", detail: "100%", statusColor: .purple)
              ListRow(icon: "circle", title: "Live Puppet", detail: "0%")
              ListRow(icon: "scope", title: "Nested child", detail: "—", level: 1)
            }
          }
          specimen("Panel actions") {
            HStack(spacing: 8) {
              PanelAction(icon: "plus", label: "Clip"); PanelAction(icon: "doc.on.doc")
              PanelAction(label: "Rename")
            }
          }
        }

        section("Node Graph") {
          specimen("Typed logic nodes") {
            VStack(spacing: 10) {
              LogicNode(title: "Proximity Sensor", subtitle: "input", icon: "sensor",
                color: UI.accent2, outputs: ["Distance", "Triggered"])
              LogicNode(title: "If / Else", subtitle: "logic", icon: "arrow.triangle.branch",
                color: .purple, inputs: ["Condition"], outputs: ["True", "False"])
            }
          }
          specimen("Node states · selected / warning") {
            VStack(spacing: 10) {
              LogicNode(title: "Language Model", subtitle: "ai + media", icon: "brain",
                color: .pink, inputs: ["Prompt", "Memory"], outputs: ["Text", "Action"], selected: true)
              LogicNode(title: "Servo Output", subtitle: "hardware", icon: "cable.connector",
                color: UI.ok, inputs: ["Target"], outputs: ["Complete"], warning: true)
            }
          }
          specimen("Node library") {
            VStack(spacing: 2) {
              NodeLibraryRow(title: "Trigger", category: "input", icon: "sensor.tag.radiowaves.forward", color: UI.ok)
              NodeLibraryRow(title: "Clip", category: "motion", icon: "waveform.path", color: UI.accent)
              NodeLibraryRow(title: "Servo Bus", category: "hardware", icon: "cpu", color: UI.accent2)
            }
          }
        }

        section("Inputs") {
          specimen("Search field") { SearchField(text: $demoSearch) }
          specimen("Stepper field") {
            StepperField(label: "Angle", value: $demoStepper, step: 1, unit: "°")
          }
          specimen("Inspector tabs") {
            InspectorTabs(tabs: ["Properties", "Appearance", "Output"], selection: $demoInspectorTab)
          }
          specimen("Axis gizmo") {
            ZStack { UI.viewportBottom; AxisGizmo() }
              .frame(height: 90).clipShape(RoundedRectangle(cornerRadius: 10))
          }
        }

        section("Dialogs, Inspectors & Feedback") {
          specimen("Property fields") {
            VStack(spacing: 8) {
              PropertyField(label: "Position X", value: "125.00", unit: "mm")
              PropertyField(label: "Rotation Z", value: "45.0", unit: "deg")
            }
          }
          specimen("Command buttons") {
            HStack(spacing: 8) {
              CommandButton(icon: "cursorarrow", active: true); CommandButton(icon: "move.3d")
              CommandButton(icon: "rotate.3d"); CommandButton(icon: "ruler")
            }
          }
          specimen("Notification card") {
            NotificationCard(title: "Character validated",
              message: "14 parts, 11 mates, 3 relations ready to animate.", action: "View report")
          }
          specimen("Document tabs") {
            DocumentTabs(tabs: ["Rex.anima", "Museum.show", "Lobby"], selection: $demoTab)
          }
          specimen("Mate dialog") {
            DialogCard(title: "Revolute 4", subtitle: "Mate", icon: "link") {
              PropertyField(label: "Type", value: "Revolute")
              PropertyField(label: "Connector A", value: "Neck.Top")
              PropertyField(label: "Angle", value: "0.0", unit: "deg")
            }
          }
        }

        section("Overlays & Shapes") {
          specimen("Radial menu") { RadialMenu(onDismiss: {}).frame(width: 210, height: 210).clipped() }
          specimen("Shapes") {
            HStack(spacing: 18) {
              Diamond().fill(UI.accent).frame(width: 22, height: 22)
              Triangle().fill(UI.accent2).frame(width: 22, height: 22)
            }
          }
          specimen("Color tokens") { swatches }
        }

        section("Viewport") {
          specimen("Viewport mock") {
            ViewportMock(showGizmo: true, selected: true).frame(height: 220)
              .clipShape(RoundedRectangle(cornerRadius: 10))
          }.gridCellColumns(2)
          specimen("Perspective grid") {
            ZStack { UI.viewportBottom; PerspectiveGrid() }
              .frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 10))
          }
        }

        section("Kit Widgets · ready for use") {
          specimen("Badges") {
            HStack(spacing: 6) {
              Badge(text: "Armed", tint: UI.ok); Badge(text: "Offline", tint: UI.text3)
              Badge(text: "Live", tint: UI.accent2)
            }
          }
          specimen("Metric card") {
            MetricCard(title: "Triangles", value: "18,204", caption: "1 part · 3 faces", tint: UI.accent2)
          }
          specimen("Labeled slider") { LabeledSlider(label: "Roughness", value: $demoSlider) }
          specimen("Segmented icons") {
            SegmentedIcons(items: [
              ("cursorarrow", "Select"), ("rectangle.dashed", "Box"), ("lasso", "Lasso"),
            ], selection: $demoSeg)
          }
          specimen("Tool cluster") {
            ToolCluster(tools: [
              ("cursorarrow", "Select"), ("rectangle.dashed", "Box"),
              ("lasso", "Lasso"), ("scope", "Center"),
            ])
          }
          specimen("Chip picker") {
            ChipPicker(options: ["12 fps", "24 fps", "30 fps", "60 fps"], selection: $demoChip)
          }
          specimen("Toast") { Toast(message: "STEP imported · 3 parts", tint: UI.ok) }
          specimen("Callout") {
            Callout(title: "Kinematic preview",
              message: "Physics is deferred — motion is evaluated, not simulated.")
          }
          specimen("Toggle row") { ToggleRow(label: "Show edges", isOn: $demoToggle) }
          specimen("Progress bar") {
            VStack(spacing: 8) { ProgressBar(value: 0.62); ProgressBar(value: 0.28, tint: UI.warn) }
          }
        }

        section("Chrome") {
          specimen("Status bar") { StatusBar(current: .rig) }.gridCellColumns(2)
        }
      }
      .padding(28).frame(maxWidth: 1120, alignment: .leading).frame(maxWidth: .infinity)
    }
  }

  // MARK: - Section / specimen scaffolding

  private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.7)
        .foregroundStyle(UI.text3)
      LazyVGrid(columns: cols, alignment: .leading, spacing: 16) { content() }
    }
  }

  private func specimen<V: View>(_ label: String, @ViewBuilder _ view: () -> V) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      view()
      Text(label).font(.system(size: 10.5, weight: .medium)).foregroundStyle(UI.text3)
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
    .background(UI.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(UI.stroke, lineWidth: 1))
  }

  private var swatches: some View {
    let tokens: [(String, Color)] = [
      ("accent", UI.accent), ("accent2", UI.accent2), ("warn", UI.warn),
      ("ok", UI.ok), ("danger", UI.danger), ("panelHi", UI.panelHi),
    ]
    return LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
      ForEach(tokens, id: \.0) { name, color in
        VStack(spacing: 4) {
          RoundedRectangle(cornerRadius: 7).fill(color).frame(height: 28)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(UI.stroke, lineWidth: 1))
          Text(name).font(.system(size: 8)).foregroundStyle(UI.text3)
        }
      }
    }
  }

  static let sampleRibbon: [RibbonGroup] = [
    RibbonGroup("Structure", "cube.transparent", .teal, [
      RibbonTool("cube", "Box"), RibbonTool("cylinder", "Cylinder"),
    ]),
    RibbonGroup("Mates", "point.3.connected.trianglepath.dotted", .purple, [
      RibbonTool("link", "Fastened"), RibbonTool("circle.circle", "Revolute"),
    ]),
    RibbonGroup("Inspect", "magnifyingglass", .blue, [RibbonTool("ruler", "Measure")]),
  ]
}
