import SwiftUI

// MARK: - Rig / mates + DOF (Onshape-style joint authoring)

struct RigWorkspace: View {
  private var rig: RigModel { RigModel.shared }
  private var model: DemoModel { DemoModel.shared }
  private var layout: LayoutState { LayoutState.shared }

  var body: some View {
    VStack(spacing: 0) {
      // Docked → the legacy full ribbon spans the top, above the panels.
      if layout.ribbonDocked {
        ToolRibbon(groups: rigTools)
        Divider().overlay(UI.stroke)
      }
      FloatingWorkspace(leftWidth: 262, rightWidth: 272, edgeToEdge: true,
        rightSelected: rig.selectedMate != nil) {
        // Left — the REAL assembly tree from the imported STEP, plus authored mates
        ScrollView {
          VStack(spacing: 10) {
            PanelCard(title: "Structure", subtitle: structureSubtitle,
              icon: "cube.transparent", tint: UI.accent2) {
              if rig.partRows.isEmpty {
                emptyHint("No model imported", "Import a STEP file in Assets to rig it.")
              } else {
                VStack(spacing: 0) {
                  ForEach(rig.partRows) { row in
                    ListRow(icon: "cube", title: row.name, detail: "\(row.faceCount)f",
                      level: row.depth, selected: rig.selectedParts.contains(row.id),
                      onTap: { rig.togglePart(row.id, extending: true) })
                  }
                }.padding(.vertical, 4)
              }
            }
            PanelCard(title: "Mates", subtitle: "\(rig.mates.count) authored",
              icon: "point.3.connected.trianglepath.dotted", tint: UI.accent) {
              VStack(spacing: 0) {
                ForEach(rig.mates) { mate in
                  ListRow(icon: mate.type.icon, title: mate.name,
                    detail: "\(rig.partName(mate.parent)) → \(rig.partName(mate.child))",
                    selected: rig.selectedMateID == mate.id,
                    onTap: { rig.selectedMateID = mate.id })
                }
              }.padding(.vertical, 4)
              Divider().overlay(UI.stroke)
              mateCreator
            }
          }
        }
      } center: {
        // Center — the REAL imported model (falls back to an import prompt)
        ZStack {
          if let part = model.selected {
            EngineViewport(document: part.document)
          } else {
            EmptyStage(status: "Import a model in Assets, then rig it here.",
              importAction: { model.importFiles() })
          }
          if !layout.ribbonDocked {
            ToolRibbon(groups: rigTools).padding(.top, 16)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          }
          CenterTray(items: [
            TrayItem("cube", "Display") {
              VStack(alignment: .leading, spacing: 10) {
                Text("DISPLAY").font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(UI.text3)
                HStack(spacing: 8) {
                  Pill(icon: "square.grid.3x3", label: "Shaded", active: true)
                  Pill(icon: "cube", label: "Wireframe")
                }
              }.padding(14).frame(width: 240)
            },
            TrayItem("sun.max", "Environment") { EnvironmentPanel() },
            TrayItem("viewfinder", "Fit"),
          ])
          .padding(.bottom, 18)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
      } right: {
        // Right — live inspector for the selected mate (edits the real rig)
        MateInspector()
      }
    }
  }

  private var structureSubtitle: String {
    guard let part = model.selected else { return "no model" }
    let picked = rig.selectedParts.count
    return picked > 0 ? "\(part.name) · \(picked) selected" : "\(part.name) · \(rig.partRows.count) parts"
  }

  // Mate authoring — pick two parts in the tree, then choose a mate type.
  private var mateCreator: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(rig.selectedParts.count >= 2
        ? "Create a mate between the 2 selected parts"
        : "Select two parts above to create a mate")
        .font(.system(size: 9.5)).foregroundStyle(UI.text3)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 5) {
        ForEach(MateType.allCases) { type in
          Button { withAnimation(.easeInOut(duration: 0.15)) { rig.addMate(type) } } label: {
            Image(systemName: type.icon).font(.system(size: 12))
              .foregroundStyle(rig.selectedParts.count >= 2 ? UI.accent : UI.text3)
              .frame(width: 30, height: 26)
              .background(UI.panelHi, in: RoundedRectangle(cornerRadius: 7))
          }
          .buttonStyle(.plain)
          .disabled(rig.selectedParts.count < 2)
          .help(type.label)
        }
      }
    }
    .padding(10)
  }

  private func emptyHint(_ title: String, _ detail: String) -> some View {
    VStack(spacing: 6) {
      Image(systemName: "tray").font(.system(size: 20)).foregroundStyle(UI.text3)
      Text(title).font(.system(size: 11.5, weight: .medium)).foregroundStyle(UI.text2)
      Text(detail).font(.system(size: 10)).foregroundStyle(UI.text3)
        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity).padding(.vertical, 26).padding(.horizontal, 14)
  }

  // Rig tool catalog — the four ribbon groups from the legacy design.
  private let rigTools: [RibbonGroup] = [
    RibbonGroup("Structure", "cube.transparent", .teal, [
      RibbonTool("cube", "Box"), RibbonTool("cylinder", "Cylinder"),
      RibbonTool("circle.hexagongrid", "Sphere"), RibbonTool("scope", "Locator"),
    ]),
    RibbonGroup("Mates", "point.3.connected.trianglepath.dotted", .purple, [
      RibbonTool("link", "Fastened"), RibbonTool("circle.circle", "Revolute"),
      RibbonTool("arrow.up.and.down", "Slider"), RibbonTool("cylinder.split.1x2", "Cylindrical"),
      RibbonTool("square.stack.3d.up", "Planar"), RibbonTool("circle.grid.2x2", "Ball"),
    ]),
    RibbonGroup("Relations", "gearshape.2", .orange, [
      RibbonTool("gearshape.2", "Gear"), RibbonTool("arrow.left.arrow.right", "Rack"),
      RibbonTool("tornado", "Screw"), RibbonTool("equal", "Linear"),
    ]),
    RibbonGroup("Inspect", "magnifyingglass", .blue, [
      RibbonTool("ruler", "Measure"), RibbonTool("square.dashed", "Section"),
      RibbonTool("gauge.with.needle", "Limits"),
    ]),
  ]

  var dofSlider: some View {
    VStack(spacing: 4) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(UI.panelHi).frame(height: 6)
          Capsule().fill(UI.accent).frame(width: geo.size.width * 0.32, height: 6)
          Circle().fill(.white).frame(width: 14, height: 14)
            .overlay(Circle().stroke(UI.accent, lineWidth: 3))
            .offset(x: geo.size.width * 0.32 - 7)
        }
      }.frame(height: 16)
      HStack {
        Text("−5°").font(.system(size: 9)).foregroundStyle(UI.text3)
        Spacer()
        Text("140°").font(.system(size: 9)).foregroundStyle(UI.text3)
      }
    }
  }

  func mateIcon(_ type: String) -> String {
    switch type {
    case "revolute": return "arrow.clockwise"
    case "ball": return "circle.circle"
    case "slider": return "arrow.left.and.right"
    default: return "link"
    }
  }
}

// Mate inspector — a plain sidebar panel. Whether it floats or docks is handled
// universally by FloatingWorkspace (the dock control lives on the sidebar).
struct ContextInspector: View {
  var mate: String = "Knee"
  var type: String = "revolute"
  @State private var limit: CGFloat = 0.32

  var body: some View {
    Panel(title: "\(mate) · \(type.capitalized)", systemImage: "slider.horizontal.3") {
      VStack(alignment: .leading, spacing: 12) {
        row("Axis", "Z")
        row("Angle", "42.0°")
        Text("LIMITS").font(.system(size: 9.5, weight: .semibold)).tracking(0.6)
          .foregroundStyle(UI.text3).padding(.top, 2)
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(UI.panelHi).frame(height: 6)
            Capsule().fill(UI.accent).frame(width: geo.size.width * limit, height: 6)
            Circle().fill(.white).frame(width: 15, height: 15)
              .overlay(Circle().stroke(UI.accent, lineWidth: 3))
              .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
              .offset(x: geo.size.width * limit - 7.5)
          }
        }.frame(height: 16)
        HStack(spacing: 8) { numBox("Min", "−5°"); numBox("Max", "140°") }
        Spacer(minLength: 0)
      }
      .padding(14)
    }
  }

  private func row(_ k: String, _ v: String) -> some View {
    HStack {
      Text(k).font(.system(size: 12)).foregroundStyle(UI.text2)
      Spacer()
      Text(v).font(.system(size: 12.5, weight: .medium, design: .rounded)).foregroundStyle(UI.text)
    }
  }

  private func numBox(_ k: String, _ v: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(k).font(.system(size: 9.5)).foregroundStyle(UI.text3)
      Text(v).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(UI.text)
    }
    .padding(.horizontal, 11).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
    .background(UI.panelHi, in: RoundedRectangle(cornerRadius: 9))
    .overlay(RoundedRectangle(cornerRadius: 9).stroke(UI.stroke, lineWidth: 1))
  }
}

// MARK: - Animate / timeline (Bottango-style dope sheet + curves)

struct AnimateWorkspace: View {
  @State private var playhead: CGFloat = 0.36
  @State private var selectedClip = "Greeting"
  let tracks: [(String, Color)] = [
    ("Hip", UI.accent), ("Knee", UI.accent), ("Ankle", UI.accent2),
    ("Neck", UI.accent2), ("Jaw", UI.warn),
  ]
  private var layout: LayoutState { LayoutState.shared }

  var body: some View {
    VStack(spacing: 0) {
      if layout.ribbonDocked {
        ToolRibbon(groups: animateTools)
        Divider().overlay(UI.stroke)
      }
      FloatingWorkspace(leftWidth: 250, rightWidth: 250, edgeToEdge: true, rightSelected: true) {
        // Left — the scene/clip library and blend layers
        ScrollView {
          VStack(spacing: 10) {
            PanelCard(title: "Animation Clips", subtitle: "Atlas · \(clips.count) clips",
              icon: "film.stack", tint: UI.accent) {
              VStack(spacing: 0) {
                ForEach(clips, id: \.0) { clip in
                  ListRow(icon: "play.rectangle", title: clip.0, detail: clip.1,
                    selected: selectedClip == clip.0,
                    onTap: { withAnimation(.easeInOut(duration: 0.15)) { selectedClip = clip.0 } })
                }
              }.padding(.vertical, 4)
              Divider().overlay(UI.stroke)
              HStack(spacing: 8) {
                PanelAction(icon: "plus", label: "Clip")
                PanelAction(icon: "doc.on.doc")
                Spacer()
              }.padding(10)
            }
            PanelCard(title: "Layers", subtitle: "Motion blending",
              icon: "square.3.layers.3d", tint: UI.accent2) {
              VStack(spacing: 0) {
                ForEach(layers, id: \.0) { layer in
                  ListRow(icon: layer.1, title: layer.0, detail: layer.2, statusColor: layer.3)
                }
              }.padding(.vertical, 4)
            }
          }
        }
      } center: {
        VStack(spacing: 0) {
          ZStack(alignment: .bottom) {
            ViewportMock()
            CenterTray(items: [
              TrayItem("diamond.fill", "Key"),
              TrayItem("record.circle", "Record"),
              TrayItem("waveform.path.ecg", "Ease"),
              TrayItem("arrow.triangle.2.circlepath", "Loop"),
              TrayItem("square.on.square.dashed", "Ghost"),
            ])
            .padding(.bottom, 16)
          }
          .overlay(alignment: .top) {
            if !layout.ribbonDocked { ToolRibbon(groups: animateTools).padding(.top, 16) }
          }
          .frame(maxHeight: .infinity)

          // Timeline lives in the center column so docked sidebars span full height.
          DopeSheetTimeline(tracks: tracks, playhead: $playhead)
            .frame(height: 268)
            .padding(12)
        }
      } right: {
        CurveCard()
      }
    }
  }

  let clips: [(String, String)] = [
    ("Greeting", "8.0 s"), ("Idle Breathing", "12.0 s"), ("Curious Look", "4.5 s"),
    ("Point Left", "3.2 s"), ("Point Right", "3.2 s"), ("Shutdown", "6.0 s"),
  ]
  let layers: [(String, String, String, Color?)] = [
    ("Base Motion", "circle.fill", "100%", UI.ok),
    ("Face + Eyes", "circle.lefthalf.filled", "100%", .purple),
    ("Live Puppet", "circle", "0%", nil),
  ]

  // Animate tool catalog — keys + edit.
  private var animateTools: [RibbonGroup] {
    [
      RibbonGroup("Keys", "diamond", .orange, [
        RibbonTool("diamond", "Key"), RibbonTool("waveform.path.ecg", "Curve"),
        RibbonTool("waveform.path", "Ease"),
      ]),
      RibbonGroup("Edit", "cursorarrow", .teal, [
        RibbonTool("cursorarrow", "Select"), RibbonTool("square.on.square.dashed", "Ghost"),
        RibbonTool("arrow.left.and.right", "Mirror"),
      ]),
    ]
  }

}

struct Diamond: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
    p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.midY))
    p.closeSubpath(); return p
  }
}

// Floating curve editor card — the Animate "Curve · Knee" widget, now floating
// over the render view (ShaprUI-style) instead of a docked side panel.
struct CurveCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: "waveform.path.ecg").font(.system(size: 12, weight: .semibold))
          .foregroundStyle(UI.accent)
        Text("Curve · Knee").font(.system(size: 13, weight: .semibold)).foregroundStyle(UI.text)
        Spacer()
        Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(UI.text3)
      }
      .padding(.horizontal, 14).padding(.vertical, 11)
      Divider().overlay(UI.stroke)
      VStack(alignment: .leading, spacing: 12) {
        curveEditor
        HStack(spacing: 9) {
          Field(label: "Interp", value: "Bézier")
          Field(label: "Frame", value: "43")
        }
        Field(label: "Value", value: "42.0", unit: "°")
        Field(label: "Ease", value: "In / Out")
      }
      .padding(14)
    }
    .frame(width: 250)
    .background(UI.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(UI.stroke, lineWidth: 1))
    .shadow(color: .black.opacity(0.22), radius: 22, x: 0, y: 12)
    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
  }

  var curveEditor: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8).fill(UI.inset)
      GeometryReader { geo in
        Path { p in
          p.move(to: CGPoint(x: 0, y: geo.size.height * 0.8))
          p.addCurve(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.25),
            control1: CGPoint(x: geo.size.width * 0.4, y: geo.size.height * 0.9),
            control2: CGPoint(x: geo.size.width * 0.6, y: geo.size.height * 0.1))
        }.stroke(UI.accent, lineWidth: 2)
        ForEach([CGPoint(x: 0, y: 0.8), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 1, y: 0.25)], id: \.self.x) { pt in
          Circle().fill(.white).frame(width: 8, height: 8)
            .overlay(Circle().stroke(UI.accent, lineWidth: 2))
            .position(x: geo.size.width * pt.x, y: geo.size.height * pt.y)
        }
      }.padding(10)
    }
    .frame(height: 108)
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(UI.stroke, lineWidth: 1))
  }
}
