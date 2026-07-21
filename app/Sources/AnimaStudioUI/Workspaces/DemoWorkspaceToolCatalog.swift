import Foundation

/// Faithful, namespaced projection of the Demo app's workspace catalogs.
///
/// Production remains the owner of command wiring. This catalog is additive:
/// callers merge it with the existing production tools and duplicate labels
/// are ignored instead of replacing a live command with a specimen.
enum DemoWorkspaceToolCatalog {
  static func groups(for workspace: StudioWorkspaceKind) -> [StudioToolGroup] {
    switch workspace {
    case .assets:
      [
        group(
          "Import", "square.and.arrow.down",
          [
            tool("Character", "person.crop.square", primary: true),
            tool("3D Model", "cube", primary: true),
            tool("Audio", "waveform"), tool("Video", "play.rectangle"),
            tool("Image", "photo"),
          ]),
        group(
          "Manage", "slider.horizontal.3",
          [
            tool("Replace", "arrow.triangle.2.circlepath", primary: true),
            tool("Reveal", "magnifyingglass", primary: true),
            tool("Folder", "folder.badge.plus"), tool("Duplicate", "square.on.square"),
          ]),
        group(
          "Prepare", "wrench.and.screwdriver",
          [
            tool("Units", "ruler", primary: true),
            tool("Validate", "checkmark.seal", primary: true),
            tool("Up Axis", "arrow.up.to.line"), tool("Origin", "scope"),
            tool("Hierarchy", "list.bullet.indent"),
          ]),
      ]
    case .rig:
      [
        group(
          "Structure", "cube",
          [
            tool("Box", "cube"), tool("Cylinder", "cylinder"),
            tool("Sphere", "circle.hexagongrid"), tool("Locator", "scope"),
          ]),
        group(
          "Mates", "link",
          [
            tool("Fastened", "link"), tool("Revolute", "circle.circle"),
            tool("Slider", "arrow.up.and.down"), tool("Cylindrical", "cylinder.split.1x2"),
            tool("Planar", "square.stack.3d.up"), tool("Ball", "circle.grid.2x2"),
          ]),
        group(
          "Relations", "gearshape.2",
          [
            tool("Gear", "gearshape.2"), tool("Rack", "arrow.left.arrow.right"),
            tool("Screw", "tornado"), tool("Linear", "equal"),
          ]),
        group(
          "Inspect", "ruler",
          [
            tool("Measure", "ruler"), tool("Section", "square.dashed"),
            tool("Limits", "gauge.with.needle"),
          ]),
      ]
    case .animate:
      [
        group(
          "Keys", "diamond",
          [
            tool("Key", "diamond"), tool("Curve", "waveform.path.ecg"),
            tool("Ease", "waveform.path"),
          ]),
        group(
          "Playback", "play.circle",
          [
            tool("Record", "record.circle"), tool("Loop", "arrow.triangle.2.circlepath"),
          ]),
        group(
          "Edit", "cursorarrow",
          [
            tool("Select", "cursorarrow"), tool("Ghost", "square.on.square.dashed"),
            tool("Mirror", "arrow.left.and.right"),
          ]),
      ]
    case .show:
      [
        group(
          "Nodes", "point.3.connected.trianglepath.dotted",
          [
            tool("Scene", "rectangle.3.group"), tool("Trigger", "sensor.tag.radiowaves.forward"),
            tool("Clip", "waveform.path"),
          ]),
        group(
          "Output", "speaker.wave.2",
          [
            tool("Audio", "speaker.wave.2"), tool("Video", "play.tv"),
            tool("Light", "light.max"),
          ]),
        group(
          "Edit", "cursorarrow",
          [
            tool("Select", "cursorarrow"), tool("Sequence", "list.number"),
          ]),
      ]
    case .hardware:
      [
        group(
          "Wire", "link",
          [
            tool("Bind", "link"), tool("Arm", "bolt.fill"), tool("Home", "house"),
          ]),
        group(
          "Tune", "wrench.and.screwdriver",
          [
            tool("Calibrate", "wrench.and.screwdriver"), tool("Test", "play"),
            tool("Monitor", "waveform.path.ecg"),
          ]),
      ]
    case .design:
      designGroups
    case .nodes:
      []
    }
  }

  static let designGroups: [StudioToolGroup] = [
    group(
      "Create", "square.stack.3d.up",
      [
        designTool("Sketch", "pencil"), designTool("Extrude", "square.stack.3d.up"),
        designTool("Revolve", "arrow.clockwise"), designTool("Sweep", "scribble"),
        designTool("Loft", "square.on.square"),
      ]),
    group(
      "Modify", "circle.lefthalf.filled",
      [
        designTool("Fillet", "circle.lefthalf.filled"), designTool("Shell", "cube.transparent"),
        designTool("Draft", "triangle"), designTool("Hole", "circle.dashed"),
      ]),
    group(
      "Pattern", "square.grid.3x3",
      [
        designTool("Pattern", "square.grid.3x3"), designTool("Mirror", "flip.horizontal"),
      ]),
    group(
      "Utility", "ruler",
      [
        designTool("Measure", "ruler"), designTool("Insert", "plus.square"),
      ]),
  ]

  static let designCategories: [StudioToolCategory] = [
    category(
      "Design",
      [
        group(
          "Create", "square.stack.3d.up",
          [
            designTool("Extrude", "square.stack.3d.up"), designTool("Revolve", "arrow.clockwise"),
            designTool("Loft", "square.on.square"), designTool("Sweep", "scribble"),
          ]),
        group(
          "Modify", "circle.lefthalf.filled",
          [
            designTool("Fillet", "circle.lefthalf.filled"), designTool("Chamfer", "triangle"),
            designTool("Shell", "cube.transparent"),
            designTool("Draft", "triangle.righthalf.filled"),
            designTool("Mirror", "flip.horizontal"), designTool("Pattern", "circle.grid.2x2"),
          ]),
        group(
          "Utility", "ruler",
          [
            designTool("Measure", "ruler"), designTool("Insert", "plus.square"),
            designTool("Select", "cursorarrow"),
          ]),
      ]),
    category(
      "Sketch",
      [
        group(
          "Draw", "pencil",
          [
            designTool("Line", "line.diagonal"), designTool("Rectangle", "rectangle"),
            designTool("Circle", "circle"),
            designTool("Spline", "point.topleft.down.to.point.bottomright.curvepath"),
            designTool("Arc", "pencil"),
          ]),
        group(
          "Constrain", "ruler",
          [
            designTool("Dimension", "ruler"), designTool("Angle", "angle"),
            designTool("Equal", "equal"),
          ]),
      ]),
    category(
      "Surface",
      [
        group(
          "Create", "square.dashed",
          [
            designTool("Patch", "square.dashed"), designTool("Loft", "square.on.square"),
            designTool("Sweep", "scribble.variable"),
            designTool("Extend", "rectangle.expand.vertical"),
          ]),
        group(
          "Modify", "scissors",
          [
            designTool("Trim", "scissors"), designTool("Stitch", "arrow.triangle.merge"),
          ]),
      ]),
    category(
      "Mesh",
      [
        group(
          "Prepare", "circle.hexagongrid",
          [
            designTool("Remesh", "circle.hexagongrid"), designTool("Reduce", "wand.and.stars"),
            designTool("Repair", "bandage"),
          ])
      ]),
    category(
      "Sheet Metal",
      [
        group(
          "Create", "rectangle.portrait",
          [
            designTool("Flange", "rectangle.portrait"), designTool("Bend", "arrow.uturn.up"),
            designTool("Unfold", "square.split.2x1"),
          ])
      ]),
    category(
      "Assemble",
      [
        group(
          "Connect", "link",
          [
            designTool("Mate", "link"), designTool("Align", "arrow.left.and.right"),
            designTool("Group", "square.stack.3d.up"),
          ])
      ]),
  ]

  static func merge(
    production: [StudioToolGroup],
    incoming: [StudioToolGroup]
  ) -> [StudioToolGroup] {
    var result = production
    for incomingGroup in incoming {
      if let index = result.firstIndex(where: { $0.title == incomingGroup.title }) {
        let existing = Set(result[index].tools.map(\.title))
        let additions = incomingGroup.tools.filter { !existing.contains($0.title) }
        guard !additions.isEmpty else { continue }
        let current = result[index]
        result[index] = StudioToolGroup(
          id: current.id,
          title: current.title,
          tools: current.tools + additions,
          categoryIcon: current.categoryIcon
        )
      } else {
        result.append(incomingGroup)
      }
    }
    return result
  }

  private static func category(
    _ title: String,
    _ groups: [StudioToolGroup]
  ) -> StudioToolCategory {
    StudioToolCategory(id: "demo.design.\(title)", title: title, groups: groups)
  }

  private static func group(
    _ title: String,
    _ icon: String,
    _ tools: [StudioToolDescriptor]
  ) -> StudioToolGroup {
    StudioToolGroup(id: "demo.\(title)", title: title, tools: tools, categoryIcon: icon)
  }

  private static func tool(
    _ title: String,
    _ icon: String,
    primary: Bool = false
  ) -> StudioToolDescriptor {
    StudioToolDescriptor(
      id: "demo.tool.\(title)",
      title: title,
      systemImage: icon,
      help: "Demo catalog concept — planned production wiring.",
      behavior: .unavailable,
      primary: primary
    )
  }

  private static func designTool(_ title: String, _ icon: String) -> StudioToolDescriptor {
    StudioToolDescriptor(
      id: "demo.design.\(title)",
      title: title,
      systemImage: icon,
      help: "Place a \(title.lowercased()) placeholder on the Design sandbox canvas.",
      behavior: .arm(.designPlaceholder(toolID: title)),
      primary: true
    )
  }
}
