import SwiftUI

// MARK: - Rig / mates + DOF (Onshape-style joint authoring)

struct RigWorkspace: View {
  private var rig: RigModel { RigModel.shared }
  private var model: DemoModel { DemoModel.shared }

  var body: some View {
    WorkspaceScaffold(
      toolGroups: RigTools.groups,
      toolOverflow: RigTools.overflow,
      toolArmGroup: RigTools.armGroup,
      leftTabs: [SidebarTab("Structure", "cube.transparent"),
                 SidebarTab("Mates", "point.3.connected.trianglepath.dotted")],
      leftPanels: rig.rigPanels
    ) {
      center
    } left: { tab in
      if tab == "Structure" { structureTab } else { matesTab }
    } inspector: {
      MateInspectorHost()
    }
  }

  /// The REAL assembly tree from the imported STEP.
  @ViewBuilder private var structureTab: some View {
    VStack(spacing: 0) {
      Text(structureSubtitle.uppercased()).font(.system(size: 8.5, weight: .medium)).tracking(0.4)
        .foregroundStyle(UI.text3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.bottom, 3)
      if rig.partRows.isEmpty {
        emptyHint("No model imported", "Import a STEP file in Assets to rig it.")
      } else {
        ForEach(rig.partRows) { row in
          ListRow(icon: "cube", title: row.name, detail: "\(row.faceCount)f",
            level: row.depth, selected: rig.selectedParts.contains(row.id),
            onTap: { rig.togglePart(row.id, extending: true) })
        }
      }
    }
  }

  @ViewBuilder private var matesTab: some View {
    VStack(spacing: 0) {
      Text("\(rig.mates.count) AUTHORED").font(.system(size: 8.5, weight: .medium)).tracking(0.4)
        .foregroundStyle(UI.text3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.bottom, 3)
      ForEach(rig.mates) { mate in
        ListRow(icon: mate.type.icon, title: mate.name,
          detail: "\(rig.partName(mate.parent)) → \(rig.partName(mate.child))",
          selected: rig.selectedMateID == mate.id,
          onTap: { rig.selectedMateID = mate.id })
      }
      Divider().overlay(UI.stroke).padding(.top, 4)
      mateCreator
    }
  }

  // MARK: Center

  private var center: some View {
    // The REAL imported model (falls back to an import prompt). The scaffold
    // supplies the tool sidebar and view sidebar; view-related tray items live
    // in the shared ViewSidebar now.
    ZStack {
      if let part = model.selected {
        EngineViewport(document: part.document, assetName: part.name)
      } else {
        EmptyStage(status: "Import a model in Assets, then rig it here.",
          importAction: { model.importFiles() })
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
          Button { withAnimation(.easeInOut(duration: 0.15)) { _ = rig.addMate(type) } } label: {
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

}

// MARK: - Rig tool catalog

/// Rig's tool catalog for the shared ToolSidebar — the four groups from the
/// legacy ribbon, minus the per-group icon/tint the ribbon used.
enum RigTools {
  static let groups: [ToolGroup] = [
    ToolGroup("Structure", [
      RibbonTool("cube", "Box"), RibbonTool("cylinder", "Cylinder"),
      RibbonTool("circle.hexagongrid", "Sphere"), RibbonTool("scope", "Locator"),
    ]),
    ToolGroup("Mates", [
      RibbonTool("link", "Fastened"), RibbonTool("circle.circle", "Revolute"),
      RibbonTool("arrow.up.and.down", "Slider"), RibbonTool("cylinder.split.1x2", "Cylindrical"),
      RibbonTool("square.stack.3d.up", "Planar"), RibbonTool("circle.grid.2x2", "Ball"),
    ]),
    ToolGroup("Relations", [
      RibbonTool("gearshape.2", "Gear"), RibbonTool("arrow.left.arrow.right", "Rack"),
      RibbonTool("tornado", "Screw"), RibbonTool("equal", "Linear"),
    ]),
    ToolGroup("Inspect", [
      RibbonTool("ruler", "Measure"), RibbonTool("square.dashed", "Section"),
      RibbonTool("gauge.with.needle", "Limits"),
    ]),
  ]

  static let overflow: [RibbonTool] = []
  static let armGroup = RibbonGroup(
    "Rig", "point.3.connected.trianglepath.dotted", .accentColor, [])
}

// MARK: - Animate / timeline (Bottango-style dope sheet + curves)

struct AnimateWorkspace: View {
  private var anim: AnimationModel { AnimationModel.shared }
  private var rig: RigModel { RigModel.shared }
  private var model: DemoModel { DemoModel.shared }

  var body: some View {
    WorkspaceScaffold(
      toolGroups: AnimateTools.groups,
      toolOverflow: AnimateTools.overflow,
      toolArmGroup: AnimateTools.armGroup,
      leftTabs: [SidebarTab("Clips", "film.stack"),
                 SidebarTab("Channels", "square.3.layers.3d")],
      leftPanels: anim.animatePanels
    ) {
      center
    } left: { tab in
      if tab == "Clips" { clipsTab } else { channelsTab }
    } inspector: {
      CurveInspector()
    }
  }

  @ViewBuilder private var clipsTab: some View {
    VStack(spacing: 0) {
      ForEach(anim.clips) { clip in
        ListRow(icon: "play.rectangle", title: clip.name,
          detail: String(format: "%.1f s", clip.duration),
          selected: anim.clip?.id == clip.id,
          onTap: { anim.selectedClipID = clip.id; anim.apply() })
      }
      Divider().overlay(UI.stroke).padding(.top, 4)
      HStack(spacing: 8) {
        PanelAction(icon: "plus", label: "Clip") { anim.addClip() }
        PanelAction(icon: "doc.on.doc")
        Spacer()
      }.padding(10)
    }
  }

  /// The rig's driven mates — one animation channel each.
  @ViewBuilder private var channelsTab: some View {
    VStack(spacing: 0) {
      Text("\(rig.mates.count) FROM RIG").font(.system(size: 8.5, weight: .medium)).tracking(0.4)
        .foregroundStyle(UI.text3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.bottom, 3)
      if rig.mates.isEmpty {
        Text("Author mates in Rig to animate them.")
          .font(.system(size: 10)).foregroundStyle(UI.text3)
          .frame(maxWidth: .infinity).padding(.vertical, 18).padding(.horizontal, 12)
          .multilineTextAlignment(.center)
      }
      ForEach(rig.mates) { mate in
        ListRow(icon: mate.type.icon, title: mate.name,
          detail: String(format: "%.1f%@", mate.value, mate.type.unit),
          selected: rig.selectedMateID == mate.id,
          statusColor: keyCount(mate.id) > 0 ? UI.ok : nil,
          onTap: { rig.selectedMateID = mate.id })
      }
    }
  }

  // MARK: Center

  private var center: some View {
    VStack(spacing: 0) {
      ZStack {
        if let part = model.selected {
          EngineViewport(document: part.document, assetName: part.name)
        } else {
          EmptyStage(status: "Import a model in Assets, rig it, then animate here.",
            importAction: { model.importFiles() })
        }
      }
      .frame(maxHeight: .infinity)

      // Real timeline: tracks come from authored mates, transport drives playback.
      DopeSheetTimeline(
        tracks: anim.timelineTracks,
        progress: anim.progress,
        duration: anim.duration,
        isPlaying: anim.isPlaying,
        onScrub: { anim.scrub(toProgress: $0) },
        onTogglePlay: { anim.togglePlay() },
        onRewind: { anim.scrub(toProgress: 0) },
        onAddKey: { addKeyForSelectedMate() })
        .frame(height: 268)
        .padding(12)
    }
  }

  private func keyCount(_ mateID: UUID) -> Int {
    anim.clip?.tracks.first { $0.mateID == mateID }?.keys.count ?? 0
  }

  /// Records the selected mate's current value as a key at the playhead.
  private func addKeyForSelectedMate() {
    guard let mate = rig.selectedMate ?? rig.mates.first else { return }
    anim.addKey(for: mate.id, value: mate.value)
  }

}

// MARK: - Animate tool catalog

/// Animate's tool catalog. The old center tray's playback ACTIONS (Record, Loop)
/// move here so retiring the tray loses no verbs; Key already lived in the ribbon.
enum AnimateTools {
  static let groups: [ToolGroup] = [
    ToolGroup("Keys", [
      RibbonTool("diamond", "Key"), RibbonTool("waveform.path.ecg", "Curve"),
      RibbonTool("waveform.path", "Ease"),
    ]),
    ToolGroup("Playback", [
      RibbonTool("record.circle", "Record"),
      RibbonTool("arrow.triangle.2.circlepath", "Loop"),
    ]),
    ToolGroup("Edit", [
      RibbonTool("cursorarrow", "Select"), RibbonTool("square.on.square.dashed", "Ghost"),
      RibbonTool("arrow.left.and.right", "Mirror"),
    ]),
  ]

  static let overflow: [RibbonTool] = []
  static let armGroup = RibbonGroup("Animate", "diamond", .accentColor, [])
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
      CurveInspector().padding(14)
    }
    .frame(width: 250)
    .background(UI.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(UI.stroke, lineWidth: 1))
    .shadow(color: .black.opacity(0.22), radius: 22, x: 0, y: 12)
    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
  }

}

/// CurveCard's body without the card chrome, so the View sidebar's Inspector tab
/// can host the same editor at panel width.
struct CurveInspector: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      curveEditor
      HStack(spacing: 9) {
        Field(label: "Interp", value: "Bézier")
        Field(label: "Frame", value: "43")
      }
      Field(label: "Value", value: "42.0", unit: "°")
      Field(label: "Ease", value: "In / Out")
    }
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
