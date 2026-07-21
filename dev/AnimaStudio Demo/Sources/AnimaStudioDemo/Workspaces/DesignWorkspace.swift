// Design — a UI sandbox, NOT a modeller. It exists to lay out and tune the
// floating-pill shell against a familiar CAD reference (Onshape).
//
// The layout encodes one rule, which is the whole point of the sandbox:
//
//   TOP pill    → tools that act on OBJECTS   (Sketch, Extrude, Fillet…)
//   LEFT rail   → which BROWSER PANEL is shown (Features, Layers, Components…)
//   RIGHT panel → CAMERA settings only         (view preset, display, edges)
//   RIGHT rail  → VIEWPORT actions only        (pan, orbit, measure)
//
// Separating camera actions from object actions is the distinction users most
// often trip over ("move camera" vs "move object"), so it gets its own rail.
// Committing a tool drops a flat placeholder card; no geometry is created.
// ponytail: placeholders on purpose — this tab is for judging UI feel.
import SwiftUI

// MARK: - Model

struct DesignShape: Identifiable {
  let id = UUID()
  var kind: String
  var icon: String
  var tint: Color
  var position: CGPoint      // unit coords (0...1) so it survives resize
  var size: CGFloat = 76

  // Editable properties surfaced in the Inspector.
  var material = "Not set"
  var appearance = "Not set"
  var opacity = 1.0
  var visible = true
  var rotation = SIMD3<Double>(0, 0, 0)   // degrees, per axis

  /// Position in mm, projected from the unit canvas position (demo scale).
  var positionMM: SIMD3<Double> {
    SIMD3(Double(position.x) * 200 - 100, Double(position.y) * 200 - 100, 0)
  }
}

/// Which browser panel the left rail is showing. Panel switches, not tools.
enum WorkspaceTab: String, CaseIterable, Identifiable {
  /// Documents = the part & assembly files (what tabs-along-the-bottom would be).
  /// Features  = the build history (sketches, extrudes, planes).
  /// Bodies    = the solid part files that history produced.
  /// Mates     = the joints connecting those bodies.
  case documents = "Documents", features = "Features", bodies = "Bodies", mates = "Mates"

  var id: String { rawValue }
  var icon: String {
    switch self {
    case .documents: return "doc.on.doc"
    case .features: return "list.bullet.indent"
    case .bodies: return "cube"
    case .mates: return "point.3.connected.trianglepath.dotted"
    }
  }
}


@MainActor @Observable final class DesignModel {
  static let shared = DesignModel()

  var shapes: [DesignShape] = []
  var selectedID: UUID?

  // Left-sidebar state, via the shared panel engine. Exclusive = browser idiom
  // (one panel at a time by default), but panels can still stack or tear off.
  let leftPanels = PanelStackState(
    order: WorkspaceTab.allCases.map(\.rawValue),
    defaults: [], side: .left)
  var defaultGeometryExpanded = true

  var selected: DesignShape? { shapes.first { $0.id == selectedID } }

  func place(_ tool: RibbonTool, tint: Color, at point: CGPoint) {
    let shape = DesignShape(kind: tool.label, icon: tool.icon, tint: tint, position: point)
    shapes.append(shape)
    selectedID = shape.id
  }

  func remove(_ id: UUID) {
    shapes.removeAll { $0.id == id }
    if selectedID == id { selectedID = nil }
  }

  func move(_ id: UUID, to point: CGPoint) {
    guard let i = shapes.firstIndex(where: { $0.id == id }) else { return }
    shapes[i].position = point
  }

  /// A two-way binding to the selected shape, so the Inspector edits it live.
  var selectedBinding: Binding<DesignShape>? {
    guard let id = selectedID, let i = shapes.firstIndex(where: { $0.id == id })
    else { return nil }
    return Binding(get: { self.shapes[i] }, set: { self.shapes[i] = $0 })
  }
}

// MARK: - Workspace


struct DesignWorkspace: View {
  private var design: DesignModel { DesignModel.shared }
  private var tools: ToolState { ToolState.shared }

  var body: some View {
    WorkspaceScaffold(
      toolGroups: DesignTools.groups,
      toolCategories: DesignTools.categories,
      toolOverflow: DesignTools.overflow,
      toolArmGroup: DesignTools.armGroup,
      leftTabs: WorkspaceTab.allCases.map { SidebarTab($0.rawValue, $0.icon) },
      leftPanels: design.leftPanels
    ) {
      canvas
    } left: { tab in
      WorkspaceBrowserContent(tab: WorkspaceTab(rawValue: tab) ?? .features)
    } inspector: {
      designInspector
    }
  }

  /// What the View sidebar's Inspector tab shows for this workspace. The
  /// inspector is context-aware — here it's the selected part's properties, but
  /// the same slot would hold mate properties, sketch properties, etc.
  @ViewBuilder private var designInspector: some View {
    if let binding = design.selectedBinding {
      PartPropertiesPanel(shape: binding, onDelete: { DesignModel.shared.remove($0) })
    } else {
      Text("Nothing selected").font(.system(size: 11)).foregroundStyle(UI.text3)
        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 18)
    }
  }

  // MARK: Canvas

  private var canvas: some View {
    GeometryReader { geo in
      ZStack(alignment: .topLeading) {
        DesignGrid()
        ForEach(design.shapes) { shape in shapeCard(shape, in: geo.size) }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .onTapGesture { point in
        guard let tool = tools.tool else { design.selectedID = nil; return }
        let unit = CGPoint(
          x: point.x / max(geo.size.width, 1), y: point.y / max(geo.size.height, 1))
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
          design.place(tool, tint: tools.tint, at: unit)
        }
        tools.committed()
      }
    }
    .focusable()
    .onKeyPress(.escape) { tools.disarm(); return .handled }
  }

  private func shapeCard(_ shape: DesignShape, in size: CGSize) -> some View {
    let selected = design.selectedID == shape.id
    return VStack(spacing: 6) {
      Image(systemName: shape.icon).font(.system(size: 22, weight: .light))
      Text(shape.kind).font(.system(size: 10, weight: .medium))
    }
    .foregroundStyle(selected ? .white : shape.tint)
    .frame(width: shape.size, height: shape.size)
    .background(selected ? shape.tint : shape.tint.opacity(0.14),
      in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(selected ? UI.accent : shape.tint.opacity(0.45), lineWidth: selected ? 2 : 1))
    .position(x: shape.position.x * size.width, y: shape.position.y * size.height)
    .onTapGesture { design.selectedID = shape.id }
    .gesture(
      DragGesture(coordinateSpace: .local).onChanged { value in
        design.move(shape.id, to: CGPoint(
          x: value.location.x / max(size.width, 1),
          y: value.location.y / max(size.height, 1)))
      })
  }
}

// MARK: - Tool catalog

/// Design's tool catalog. Static so self-tests can assert it without a view.
enum DesignTools {
  static let groups: [ToolGroup] = [
    ToolGroup("Create", [
      RibbonTool("pencil", "Sketch"), RibbonTool("square.stack.3d.up", "Extrude"),
      RibbonTool("arrow.clockwise", "Revolve"), RibbonTool("scribble", "Sweep"),
      RibbonTool("square.on.square", "Loft"),
    ]),
    ToolGroup("Modify", [
      RibbonTool("circle.lefthalf.filled", "Fillet"), RibbonTool("cube.transparent", "Shell"),
      RibbonTool("triangle", "Draft"), RibbonTool("circle.dashed", "Hole"),
    ]),
    ToolGroup("Pattern", [
      RibbonTool("square.grid.3x3", "Pattern"), RibbonTool("flip.horizontal", "Mirror"),
    ]),
    ToolGroup("Utility", [
      RibbonTool("ruler", "Measure"), RibbonTool("plus.square", "Insert"),
    ]),
  ]

  static let overflow: [RibbonTool] = [
    RibbonTool("square.3.layers.3d", "Thicken"), RibbonTool("scissors", "Split"),
    RibbonTool("move.3d", "Transform"),
    RibbonTool("square.on.square.intersection.dashed", "Boolean"),
  ]

  /// Flattened catalog — order matches the reference toolbar left to right.
  static var primary: [RibbonTool] { groups.flatMap(\.tools) }

  static let armGroup = RibbonGroup("Design", "pencil", .accentColor, [])

  /// Category tabs for the expanded ribbon. Design has enough tools to split
  /// into the Fusion-style Design · Sketch · Surface · … tabs.
  static let categories: [ToolCategory] = [
    ToolCategory("Design", [
      ToolGroup("Create", [
        RibbonTool("square.stack.3d.up", "Extrude"), RibbonTool("arrow.clockwise", "Revolve"),
        RibbonTool("square.on.square", "Loft"), RibbonTool("scribble", "Sweep"),
      ]),
      ToolGroup("Modify", [
        RibbonTool("circle.lefthalf.filled", "Fillet"), RibbonTool("triangle", "Chamfer"),
        RibbonTool("cube.transparent", "Shell"), RibbonTool("triangle.righthalf.filled", "Draft"),
        RibbonTool("flip.horizontal", "Mirror"), RibbonTool("circle.grid.2x2", "Pattern"),
      ]),
      ToolGroup("Utility", [
        RibbonTool("ruler", "Measure"), RibbonTool("plus.square", "Insert"),
        RibbonTool("cursorarrow", "Select"),
      ]),
    ]),
    ToolCategory("Sketch", [
      ToolGroup("Draw", [
        RibbonTool("line.diagonal", "Line"), RibbonTool("rectangle", "Rectangle"),
        RibbonTool("circle", "Circle"), RibbonTool("point.topleft.down.to.point.bottomright.curvepath", "Spline"),
        RibbonTool("pencil", "Arc"),
      ]),
      ToolGroup("Constrain", [
        RibbonTool("ruler", "Dimension"), RibbonTool("angle", "Angle"),
        RibbonTool("equal", "Equal"),
      ]),
    ]),
    ToolCategory("Surface", [
      ToolGroup("Create", [
        RibbonTool("square.dashed", "Patch"), RibbonTool("square.on.square", "Loft"),
        RibbonTool("scribble.variable", "Sweep"), RibbonTool("rectangle.expand.vertical", "Extend"),
      ]),
      ToolGroup("Modify", [
        RibbonTool("scissors", "Trim"), RibbonTool("arrow.triangle.merge", "Stitch"),
      ]),
    ]),
    ToolCategory("Mesh", [
      ToolGroup("Prepare", [
        RibbonTool("circle.hexagongrid", "Remesh"), RibbonTool("wand.and.stars", "Reduce"),
        RibbonTool("bandage", "Repair"),
      ]),
    ]),
    ToolCategory("Sheet Metal", [
      ToolGroup("Create", [
        RibbonTool("rectangle.portrait", "Flange"), RibbonTool("arrow.uturn.up", "Bend"),
        RibbonTool("square.split.2x1", "Unfold"),
      ]),
    ]),
    ToolCategory("Assemble", [
      ToolGroup("Structure", [
        RibbonTool("shippingbox", "Component"), RibbonTool("point.3.connected.trianglepath.dotted", "Joint"),
        RibbonTool("square.on.square.dashed", "Pattern"),
      ]),
    ]),
  ]
}


// MARK: - Left sidebar content

/// Rows for Design's workspace sidebar. The rail and panel chrome are generic
/// (see Sidebars.swift); a workspace supplies only its rows.
struct WorkspaceBrowserContent: View {
  let tab: WorkspaceTab
  private var design: DesignModel { DesignModel.shared }

  var body: some View {
    VStack(spacing: 0) {
      switch tab {
      case .documents: documentRows
      case .features: featureRows
      case .bodies: bodyRows
      case .mates: mateRows
      }
    }
  }

  /// Build history — a collapsible "Default geometry" group (origin + planes),
  /// then the sketches/extrudes/etc. placed, numbered per type in creation order.
  @ViewBuilder private var featureRows: some View {
    // Collapsible section header with a disclosure chevron.
    Button {
      withAnimation(.easeOut(duration: 0.18)) {
        design.defaultGeometryExpanded.toggle()
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "chevron.right")
          .font(.system(size: 9, weight: .semibold)).foregroundStyle(UI.text3)
          .rotationEffect(.degrees(design.defaultGeometryExpanded ? 90 : 0))
        Text("Default geometry").font(.system(size: 11.5, weight: .medium))
          .foregroundStyle(UI.text2)
        Spacer(minLength: 8)
      }
      .padding(.horizontal, 12).padding(.vertical, 6).contentShape(Rectangle())
    }.buttonStyle(.plain)

    if design.defaultGeometryExpanded {
      row(icon: "smallcircle.filled.circle", title: "Origin", muted: false, indent: 16)
      ForEach(["Top", "Front", "Right"], id: \.self) { name in
        row(icon: "squareshape.dashed.squareshape", title: name, muted: true, indent: 16)
      }
    }

    ForEach(Array(numberedShapes.enumerated()), id: \.element.0.id) { _, entry in
      let (shape, label) = entry
      Button { DesignModel.shared.selectedID = shape.id } label: {
        row(icon: shape.icon, title: label,
          muted: false, indent: 0, selected: design.selectedID == shape.id)
      }.buttonStyle(.plain)
    }
  }

  /// Pairs each feature with a per-type running number ("Sketch 1", "Extrude 1",
  /// "Sketch 2"…), like a real feature tree. Starts with a placeholder history
  /// so the panel reads as a populated part; placed shapes append to it.
  private var numberedShapes: [(DesignShape, String)] {
    var counts: [String: Int] = [:]
    return (Self.sampleHistory + design.shapes).map { shape in
      counts[shape.kind, default: 0] += 1
      return (shape, "\(shape.kind) \(counts[shape.kind]!)")
    }
  }

  /// Stand-in feature history matching the reference tree.
  private static let sampleHistory: [DesignShape] = [
    DesignShape(kind: "Sketch", icon: "pencil", tint: .teal, position: .zero),
    DesignShape(kind: "Extrude", icon: "square.stack.3d.up", tint: .teal, position: .zero),
    DesignShape(kind: "Sketch", icon: "pencil", tint: .teal, position: .zero),
    DesignShape(kind: "Extrude", icon: "square.stack.3d.up", tint: .teal, position: .zero),
    DesignShape(kind: "Shell", icon: "cube.transparent", tint: .teal, position: .zero),
    DesignShape(kind: "Sketch", icon: "pencil", tint: .teal, position: .zero),
    DesignShape(kind: "Extrude", icon: "square.stack.3d.up", tint: .teal, position: .zero),
  ]

  /// Part & assembly documents — the same set that would otherwise be tabs
  /// along the bottom, surfaced here as a sidebar list for consistency.
  @ViewBuilder private var documentRows: some View {
    sectionHeader("Parts", add: true)
    ForEach(["ARCADP001", "ARCADP002", "ARCADP002 Copy 1",
             "ARCADP003", "ARCADP004"], id: \.self) { name in
      row(icon: "doc", title: name, muted: false, indent: 0,
        selected: name == "ARCADP001")
    }
    sectionHeader("Assemblies", add: true)
    ForEach(["Rover Assembly", "Drivetrain"], id: \.self) { name in
      row(icon: "square.stack.3d.up", title: name, muted: false, indent: 0)
    }
  }

  /// A section title with a trailing "+" to add a new document of that kind.
  private func sectionHeader(_ text: String, add: Bool) -> some View {
    HStack(spacing: 6) {
      Text(text.uppercased()).font(.system(size: 9.5, weight: .semibold)).tracking(0.6)
        .foregroundStyle(UI.text3)
      Spacer(minLength: 8)
      if add {
        Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
          .foregroundStyle(UI.text3)
      }
    }
    .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 3)
  }

  /// Solid bodies — the part files the history produced. Placeholder set until
  /// real geometry exists.
  @ViewBuilder private var bodyRows: some View {
    heading("Part files")
    ForEach(["Rover Base", "Bracket L", "Bracket R", "Cover"], id: \.self) { name in
      row(icon: "cube.fill", title: name, muted: false, indent: 0)
    }
  }

  /// Joints connecting the bodies.
  @ViewBuilder private var mateRows: some View {
    heading("Mates")
    ForEach([("Base → Bracket L", "circle.circle"),
             ("Base → Bracket R", "circle.circle"),
             ("Cover → Base", "link")], id: \.0) { name, icon in
      row(icon: icon, title: name, muted: false, indent: 0)
    }
  }

  private func heading(_ text: String) -> some View {
    Text(text).font(.system(size: 10.5, weight: .medium))
      .foregroundStyle(UI.text3)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 3)
  }

  private func staticRows(_ names: [String], _ icon: String) -> some View {
    ForEach(names, id: \.self) { name in row(icon: icon, title: name, muted: false, indent: 0) }
  }

  private func row(icon: String, title: String, muted: Bool, indent: CGFloat,
    selected: Bool = false) -> some View
  {
    HStack(spacing: 9) {
      Image(systemName: icon).font(.system(size: 12))
        .foregroundStyle(muted ? UI.text3 : (selected ? UI.accent : UI.accent2))
        .frame(width: 16)
      Text(title).font(.system(size: 11.5, weight: selected ? .medium : .regular))
        .foregroundStyle(muted ? UI.text3 : UI.text)
      Spacer(minLength: 8)
    }
    .padding(.leading, 12 + indent).padding(.trailing, 12).padding(.vertical, 5.5)
    .background(selected ? UI.accent.opacity(0.14) : .clear)
    .overlay(alignment: .leading) {
      if selected {
        Rectangle().fill(UI.accent).frame(width: 2)   // selection bar, like Xcode/Fusion
      }
    }
    .contentShape(Rectangle())
  }
}


/// Faint construction grid so placeholders have something to sit on.
private struct DesignGrid: View {
  var body: some View {
    Canvas { context, size in
      let step: CGFloat = 40
      var path = Path()
      var x: CGFloat = 0
      while x <= size.width {
        path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
        x += step
      }
      var y: CGFloat = 0
      while y <= size.height {
        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
        y += step
      }
      context.stroke(path, with: .color(UI.stroke.opacity(0.5)), lineWidth: 0.5)
    }
  }
}

// MARK: - Properties inspector

/// The context-aware Inspector content for a selected part: collapsible General,
/// Transform, and Information sections. A mate/sketch selection would swap this
/// view for its own; the sidebar slot is the same.
struct PartPropertiesPanel: View {
  @Binding var shape: DesignShape
  var onDelete: (UUID) -> Void = { _ in }

  @State private var generalOpen = true
  @State private var transformOpen = true
  @State private var infoOpen = true

  private let materials = ["Not set", "Aluminum", "Steel", "ABS Plastic", "PLA"]
  private let appearances = ["Not set", "Painted", "Anodized", "Brushed", "Matte"]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      PropSection("General", isOpen: $generalOpen) {
        menuRow("Material", selection: $shape.material, options: materials)
        menuRow("Appearance", selection: $shape.appearance, options: appearances)
        opacityRow
        toggleRow("Visible", isOn: $shape.visible)
      }
      PropSection("Transform", isOpen: $transformOpen) {
        numberRow("Position X", value: positionBinding(0), unit: "mm")
        numberRow("Position Y", value: positionBinding(1), unit: "mm")
        numberRow("Position Z", value: .constant(0), unit: "mm")
        numberRow("Rotation X", value: $shape.rotation.x, unit: "deg", step: 1)
        numberRow("Rotation Y", value: $shape.rotation.y, unit: "deg", step: 1)
        numberRow("Rotation Z", value: $shape.rotation.z, unit: "deg", step: 1)
      }
      PropSection("Information", isOpen: $infoOpen) {
        infoRow("Type", "Solid body")
        infoRow("Volume", "—")
        infoRow("Mass", "—")
      }

      Divider().overlay(UI.stroke).padding(.vertical, 8)
      Button { onDelete(shape.id) } label: {
        Label("Delete", systemImage: "trash").font(.system(size: 11.5))
      }.buttonStyle(.plain).foregroundStyle(.red).padding(.horizontal, 12)
    }
    .padding(.vertical, 4)
  }

  // Position is stored as a unit canvas point; expose ±100mm about center.
  private func positionBinding(_ axis: Int) -> Binding<Double> {
    Binding(
      get: { shape.positionMM[axis] },
      set: { mm in
        let unit = (mm + 100) / 200
        if axis == 0 { shape.position.x = unit } else if axis == 1 { shape.position.y = unit }
      })
  }

  // MARK: Rows

  private func menuRow(_ label: String, selection: Binding<String>, options: [String]) -> some View {
    row(label) {
      Menu {
        ForEach(options, id: \.self) { opt in Button(opt) { selection.wrappedValue = opt } }
      } label: {
        HStack(spacing: 4) {
          Text(selection.wrappedValue).font(.system(size: 11))
            .foregroundStyle(selection.wrappedValue == "Not set" ? UI.text3 : UI.text)
          Image(systemName: "chevron.down").font(.system(size: 8)).foregroundStyle(UI.text3)
        }
      }.menuStyle(.borderlessButton).fixedSize()
    }
  }

  private var opacityRow: some View {
    row("Opacity") {
      HStack(spacing: 8) {
        Slider(value: $shape.opacity, in: 0...1).controlSize(.mini).frame(width: 90)
        Text("\(Int(shape.opacity * 100)) %").font(.system(size: 10.5, design: .monospaced))
          .foregroundStyle(UI.text2).frame(width: 34, alignment: .trailing)
      }
    }
  }

  private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
    row(label) {
      Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.mini)
    }
  }

  private func numberRow(_ label: String, value: Binding<Double>, unit: String,
    step: Double = 1) -> some View
  {
    row(label) {
      HStack(spacing: 4) {
        Text("\(String(format: "%.2f", value.wrappedValue)) \(unit)")
          .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(UI.text2)
          .frame(minWidth: 60, alignment: .trailing)
          .padding(.horizontal, 8).padding(.vertical, 4)
          .background(UI.panelHi, in: RoundedRectangle(cornerRadius: 6))
        Stepper("", value: value, step: step).labelsHidden().controlSize(.mini)
      }
    }
  }

  private func infoRow(_ label: String, _ value: String) -> some View {
    row(label) {
      Text(value).font(.system(size: 11)).foregroundStyle(UI.text2)
    }
  }

  private func row<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
    HStack {
      Text(label).font(.system(size: 11)).foregroundStyle(UI.text3)
      Spacer(minLength: 10)
      control()
    }
    .padding(.horizontal, 12).padding(.vertical, 5)
  }
}

/// A collapsible titled section with a disclosure chevron, matching the feature
/// tree's group style.
struct PropSection<Content: View>: View {
  let title: String
  @Binding var isOpen: Bool
  @ViewBuilder var content: Content

  init(_ title: String, isOpen: Binding<Bool>, @ViewBuilder content: () -> Content) {
    self.title = title; self._isOpen = isOpen; self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(.easeOut(duration: 0.16)) { isOpen.toggle() }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
            .foregroundStyle(UI.text3).rotationEffect(.degrees(isOpen ? 90 : 0))
          Text(title).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(UI.text)
          Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 7).contentShape(Rectangle())
      }.buttonStyle(.plain)
      if isOpen { content }
    }
  }
}
