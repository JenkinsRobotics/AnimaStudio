import CoreGraphics
import Foundation

public enum PanelPlacement: String, CaseIterable, Codable, Identifiable, Sendable {
  case docked
  case floating
  case hidden

  public var id: String { rawValue }

  public var label: String {
    switch self {
    case .docked: "Docked"
    case .floating: "Floating"
    case .hidden: "Hidden"
    }
  }
}

public enum FloatingRibbonEdge: String, CaseIterable, Codable, Identifiable, Sendable {
  case top
  case bottom

  public var id: String { rawValue }
  public var label: String { self == .top ? "Top" : "Bottom" }
}

/// Shared density contract for the single application header. These values
/// intentionally mirror the AnimaStudio Demo shell so related prototypes can
/// be compared without chrome size changing the perceived workspace.
public enum WorkspaceHeaderMetrics {
  public static let height = 54.0
  public static let controlWidth = 28.0
  public static let controlHeight = 24.0
  public static let stageChipHeight = 30.0
  public static let compactStageChipHeight = 28.0
  public static let capsuleInset = 4.0
}

/// The area covered by in-window floating chrome. Spatial canvases can render
/// beneath it, while structured content can opt into these safe insets.
public struct PanelObstructionInsets: Equatable, Sendable {
  public let top: Double
  public let bottom: Double
  public let leading: Double
  public let trailing: Double

  public init(
    leftPlacement: PanelPlacement,
    rightPlacement: PanelPlacement,
    ribbonPlacement: PanelPlacement,
    floatingRibbonEdge: FloatingRibbonEdge = .top,
    leftPanelWidth: Double,
    rightPanelWidth: Double,
    panelClearance: Double = 18,
    ribbonClearance: Double = 74
  ) {
    top = ribbonPlacement == .floating && floatingRibbonEdge == .top ? ribbonClearance : 0
    bottom = ribbonPlacement == .floating && floatingRibbonEdge == .bottom ? ribbonClearance : 0
    leading = leftPlacement == .floating ? leftPanelWidth + panelClearance : 0
    trailing = rightPlacement == .floating ? rightPanelWidth + panelClearance : 0
  }
}

/// Keeps in-window floating side panels useful without turning them into
/// full-height docked columns. Small windows still receive all available
/// height inside the standard workspace margins.
public enum FloatingPanelSizing {
  /// Spatial previews need a real canvas even when their surrounding panel is
  /// content-sized. Property cards deliberately do not inherit this minimum.
  public static let spatialPreviewMinimumContentHeight = 220.0

  public static func height(
    availableHeight: Double,
    preferredFraction: Double = 0.72,
    minimumHeight: Double = 380,
    verticalMargins: Double = 24
  ) -> Double {
    let usableHeight = max(0, availableHeight - verticalMargins)
    let preferredHeight = max(minimumHeight, availableHeight * preferredFraction)
    return min(usableHeight, preferredHeight)
  }
}

/// Geometry-only drag constraint shared by every floating widget. The caller
/// supplies the widget frame captured at drag start, avoiding incremental
/// clamping and the visible snap that produces.
public enum FloatingWidgetPlacement {
  public static func constrainedTranslation(
    startingFrame: CGRect,
    translation: CGSize,
    workspaceSize: CGSize,
    margin: Double = 8
  ) -> CGSize {
    guard workspaceSize.width > 0, workspaceSize.height > 0, !startingFrame.isEmpty else {
      return .zero
    }

    let horizontalMargin = min(CGFloat(margin), workspaceSize.width / 2)
    let verticalMargin = min(CGFloat(margin), workspaceSize.height / 2)
    let minimumX = horizontalMargin - startingFrame.minX
    let maximumX = workspaceSize.width - horizontalMargin - startingFrame.maxX
    let minimumY = verticalMargin - startingFrame.minY
    let maximumY = workspaceSize.height - verticalMargin - startingFrame.maxY

    return CGSize(
      width: clamped(translation.width, minimum: minimumX, maximum: maximumX),
      height: clamped(translation.height, minimum: minimumY, maximum: maximumY)
    )
  }

  private static func clamped(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
    guard minimum <= maximum else { return (minimum + maximum) / 2 }
    return min(maximum, max(minimum, value))
  }
}

public enum WorkspaceTabLabelMode: String, CaseIterable, Codable, Identifiable, Sendable {
  case automatic
  case all
  case selectedOnly
  case iconsOnly

  public var id: String { rawValue }

  public var label: String {
    switch self {
    case .automatic: "Automatic"
    case .all: "All Labels"
    case .selectedOnly: "Selected Only"
    case .iconsOnly: "Icons Only"
    }
  }

  public func showsLabel(isSelected: Bool, compact: Bool) -> Bool {
    switch self {
    case .automatic: compact ? isSelected : true
    case .all: true
    case .selectedOnly: isSelected
    case .iconsOnly: false
    }
  }
}

public enum WorkspaceLayoutPreset: String, CaseIterable, Codable, Identifiable, Sendable {
  case studio
  case classic
  case canvas

  public var id: String { rawValue }

  public var label: String {
    switch self {
    case .studio: "Floating"
    case .classic: "Docked"
    case .canvas: "Canvas"
    }
  }

  public var leftPanel: PanelPlacement {
    switch self {
    case .studio: .floating
    case .classic: .docked
    case .canvas: .hidden
    }
  }

  public var rightPanel: PanelPlacement {
    switch self {
    case .studio: .floating
    case .classic: .docked
    case .canvas: .hidden
    }
  }

  public var ribbon: PanelPlacement {
    switch self {
    case .studio, .canvas: .floating
    case .classic: .docked
    }
  }

  public var next: WorkspaceLayoutPreset {
    switch self {
    case .studio: .classic
    case .classic: .canvas
    case .canvas: .studio
    }
  }
}

public enum CanvasPanelRevealPolicy {
  public static func isEnabled(
    layoutPreset: WorkspaceLayoutPreset?, panelPlacement: PanelPlacement
  ) -> Bool {
    layoutPreset == .canvas && panelPlacement == .hidden
  }
}

public struct RibbonTool: Identifiable, Hashable, Sendable {
  public let id: String
  public let title: String
  public let systemImage: String
  public let enabled: Bool

  public init(_ title: String, _ systemImage: String, enabled: Bool = true) {
    self.id = title
    self.title = title
    self.systemImage = systemImage
    self.enabled = enabled
  }
}

public struct RibbonGroup: Identifiable, Hashable, Sendable {
  public let id: String
  public let title: String
  public let tint: String
  public let tools: [RibbonTool]

  public init(_ title: String, tint: String, tools: [RibbonTool]) {
    self.id = title
    self.title = title
    self.tint = tint
    self.tools = tools
  }
}

public enum UIWorkspace: Int, CaseIterable, Codable, Identifiable, Sendable {
  case assets
  case rig
  case animate
  case show
  case hardware
  case nodes
  case uiKit

  public var id: Int { rawValue }

  /// The directed authoring path used by the centered stage navigator.
  public static let authoringPipeline: [UIWorkspace] = [
    .assets, .rig, .animate, .show, .hardware,
  ]

  /// Specialist workspaces remain adjacent to, but outside, the production path.
  public static let utilityWorkspaces: [UIWorkspace] = [.nodes, .uiKit]

  /// The single centered navigator. A visual divider can preserve the
  /// authoring/utility distinction without requiring a second control.
  public static let centeredNavigation = authoringPipeline + utilityWorkspaces

  public var name: String {
    switch self {
    case .assets: "Assets"
    case .rig: "Rig"
    case .animate: "Animate"
    case .show: "Show"
    case .hardware: "Hardware"
    case .nodes: "Nodes"
    case .uiKit: "UI Kit"
    }
  }

  public var systemImage: String {
    switch self {
    case .assets: "shippingbox"
    case .rig: "point.3.connected.trianglepath.dotted"
    case .animate: "play.circle"
    case .show: "theatermasks"
    case .hardware: "cable.connector"
    case .nodes: "point.3.filled.connected.trianglepath.dotted"
    case .uiKit: "paintpalette"
    }
  }

  public var purpose: String {
    switch self {
    case .assets: "Import, inspect, version, and organize reusable character content."
    case .rig: "Create parts, connectors, mates, motion limits, and actuator intent."
    case .animate: "Author expressive motion with tracks, curves, audio, and live preview."
    case .show: "Sequence animation, audio, screens, lighting, events, and operator cues."
    case .hardware: "Map semantic motion to devices with visible safety and live telemetry."
    case .nodes: "Compose deterministic behavior, AI, I/O, and performance logic visually."
    case .uiKit: "Review reusable controls, panels, menus, dialogs, and interaction states."
    }
  }

  public var ribbonGroups: [RibbonGroup] {
    switch self {
    case .assets:
      [
        RibbonGroup(
          "Import", tint: "blue",
          tools: [
            RibbonTool("Character", "person.crop.rectangle.stack"),
            RibbonTool("3D Model", "cube.transparent"),
            RibbonTool("Audio", "waveform"), RibbonTool("Video", "play.rectangle"),
            RibbonTool("Image", "photo"),
          ]),
        RibbonGroup(
          "Manage", tint: "indigo",
          tools: [
            RibbonTool("Replace", "arrow.triangle.2.circlepath"),
            RibbonTool("Reveal", "magnifyingglass"), RibbonTool("Folder", "folder.badge.plus"),
            RibbonTool("Duplicate", "square.on.square"),
          ]),
        RibbonGroup(
          "Prepare", tint: "teal",
          tools: [
            RibbonTool("Units", "ruler"), RibbonTool("Up Axis", "move.3d"),
            RibbonTool("Origin", "scope"), RibbonTool("Hierarchy", "list.bullet.indent"),
            RibbonTool("Validate", "checkmark.shield"),
          ]),
      ]
    case .rig:
      [
        RibbonGroup(
          "Structure", tint: "teal",
          tools: [
            RibbonTool("Box", "cube"), RibbonTool("Cylinder", "cylinder"),
            RibbonTool("Sphere", "circle.grid.cross"), RibbonTool("Locator", "scope"),
          ]),
        RibbonGroup(
          "Mates", tint: "purple",
          tools: [
            RibbonTool("Fastened", "link"), RibbonTool("Revolute", "rotate.3d"),
            RibbonTool("Slider", "arrow.up.and.down"),
            RibbonTool("Cylindrical", "cylinder.split.1x2"),
            RibbonTool("Planar", "square.3.layers.3d"), RibbonTool("Ball", "circle.hexagongrid"),
          ]),
        RibbonGroup(
          "Relations", tint: "orange",
          tools: [
            RibbonTool("Gear", "gearshape.2"), RibbonTool("Rack", "arrow.left.arrow.right"),
            RibbonTool("Screw", "scribble.variable"), RibbonTool("Linear", "equal"),
          ]),
        RibbonGroup(
          "Inspect", tint: "blue",
          tools: [
            RibbonTool("Measure", "ruler"), RibbonTool("Section", "square.split.diagonal"),
            RibbonTool("Limits", "gauge.with.dots.needle.33percent"),
          ]),
      ]
    case .animate:
      [
        RibbonGroup(
          "Keyframes", tint: "blue",
          tools: [
            RibbonTool("Auto Key", "diamond.fill"), RibbonTool("Insert", "plus.diamond"),
            RibbonTool("Hold", "step.forward"),
            RibbonTool("Bezier", "point.topleft.down.curvedto.point.bottomright.up"),
          ]),
        RibbonGroup(
          "Motion", tint: "purple",
          tools: [
            RibbonTool("Pose", "figure.arms.open"),
            RibbonTool("Mirror", "arrow.left.and.right.righttriangle.left.righttriangle.right"),
            RibbonTool("Loop", "repeat"), RibbonTool("Blend", "circle.lefthalf.filled"),
          ]),
        RibbonGroup(
          "Capture", tint: "red",
          tools: [
            RibbonTool("Record", "record.circle"), RibbonTool("Puppet", "hand.draw"),
            RibbonTool("Audio", "waveform.badge.mic"), RibbonTool("Face", "face.smiling"),
          ]),
      ]
    case .show:
      [
        RibbonGroup(
          "Create Cue", tint: "orange",
          tools: [
            RibbonTool("Animation", "figure.wave"), RibbonTool("Audio", "speaker.wave.2"),
            RibbonTool("Screen", "display"), RibbonTool("Lighting", "lightbulb.led"),
            RibbonTool("Event", "bolt"),
          ]),
        RibbonGroup(
          "Sequence", tint: "blue",
          tools: [
            RibbonTool("Scene", "rectangle.3.group"),
            RibbonTool("Transition", "arrow.triangle.swap"),
            RibbonTool("Marker", "flag"), RibbonTool("Loop", "repeat"),
          ]),
        RibbonGroup(
          "Run", tint: "green",
          tools: [
            RibbonTool("Rehearse", "play"), RibbonTool("Go", "play.fill"),
            RibbonTool("Hold", "pause.fill"), RibbonTool("Stop", "stop.fill"),
          ]),
      ]
    case .hardware:
      [
        RibbonGroup(
          "Connections", tint: "blue",
          tools: [
            RibbonTool("Discover", "dot.radiowaves.left.and.right"),
            RibbonTool("Connect", "cable.connector"),
            RibbonTool("Driver", "externaldrive.connected.to.line.below"),
          ]),
        RibbonGroup(
          "Map", tint: "purple",
          tools: [
            RibbonTool("Servo", "slider.horizontal.3"),
            RibbonTool("Stepper", "gearshape.arrow.triangle.2.circlepath"),
            RibbonTool("Dynamixel", "hexagon"), RibbonTool("Output", "arrow.up.forward.square"),
          ]),
        RibbonGroup(
          "Safety", tint: "red",
          tools: [
            RibbonTool("Limits", "shield.lefthalf.filled"), RibbonTool("Test", "stethoscope"),
            RibbonTool("Arm", "lock.open"), RibbonTool("E-Stop", "octagon.fill"),
          ]),
      ]
    case .nodes:
      [
        RibbonGroup(
          "Inputs", tint: "blue",
          tools: [
            RibbonTool("Trigger", "bolt"), RibbonTool("Sensor", "sensor"),
            RibbonTool("Speech", "waveform"), RibbonTool("Vision", "eye"),
          ]),
        RibbonGroup(
          "Logic", tint: "purple",
          tools: [
            RibbonTool("If", "arrow.triangle.branch"), RibbonTool("Select", "list.number"),
            RibbonTool("Wait", "clock"), RibbonTool("Loop", "repeat"),
            RibbonTool("Call", "arrow.turn.down.right"),
          ]),
        RibbonGroup(
          "AI + Media", tint: "pink",
          tools: [
            RibbonTool("LLM", "brain"), RibbonTool("STT", "mic"),
            RibbonTool("TTS", "speaker.wave.2"), RibbonTool("Clip", "film.stack"),
          ]),
        RibbonGroup(
          "Outputs", tint: "green",
          tools: [
            RibbonTool("Motion", "figure.walk.motion"), RibbonTool("Screen", "display"),
            RibbonTool("Hardware", "cable.connector"),
          ]),
      ]
    case .uiKit:
      [
        RibbonGroup(
          "Catalog", tint: "blue",
          tools: [
            RibbonTool("Panels", "sidebar.left"), RibbonTool("Inspectors", "sidebar.right"),
            RibbonTool("Dialogs", "macwindow"), RibbonTool("Popovers", "rectangle.inset.filled"),
          ]),
        RibbonGroup(
          "Components", tint: "purple",
          tools: [
            RibbonTool("Buttons", "button.programmable"),
            RibbonTool("Inputs", "character.cursor.ibeam"),
            RibbonTool("Menus", "menucard"), RibbonTool("Timeline", "timeline.selection"),
          ]),
        RibbonGroup(
          "Review", tint: "green",
          tools: [
            RibbonTool("States", "circle.grid.2x2"),
            RibbonTool("Spacing", "arrow.left.and.right.square"),
            RibbonTool("Contrast", "circle.lefthalf.filled"),
          ]),
      ]
    }
  }
}

public struct WorkspaceTour: Equatable, Sendable {
  public private(set) var index: Int

  public init(index: Int = 0) {
    self.index = min(max(index, 0), UIWorkspace.allCases.count - 1)
  }

  public var workspace: UIWorkspace { UIWorkspace.allCases[index] }
  public var progressLabel: String { "\(index + 1) of \(UIWorkspace.allCases.count)" }

  public mutating func advance() {
    index = (index + 1) % UIWorkspace.allCases.count
  }

  public mutating func retreat() {
    index = (index - 1 + UIWorkspace.allCases.count) % UIWorkspace.allCases.count
  }

  public mutating func select(_ workspace: UIWorkspace) {
    index = workspace.rawValue
  }
}

/// Review inventory for reusable visual assets. Adding a shared component to
/// CodexUI also requires adding it here and presenting it in the UI Kit.
public struct UIKitAssetDescriptor: Identifiable, Hashable, Sendable {
  public let id: String
  public let section: String
  public let specimen: String

  public init(_ id: String, section: String, specimen: String) {
    self.id = id
    self.section = section
    self.specimen = specimen
  }
}

public enum UIKitAssetCatalog {
  public static let all: [UIKitAssetDescriptor] = [
    UIKitAssetDescriptor("PrototypePanel", section: "Panels & Dialogs", specimen: "Panel anatomy"),
    UIKitAssetDescriptor("PrototypeRow", section: "Rows & Fields", specimen: "Hierarchy rows"),
    UIKitAssetDescriptor("PropertyField", section: "Rows & Fields", specimen: "Numeric inspector"),
    UIKitAssetDescriptor("LabelPill", section: "Buttons & Controls", specimen: "Pills and states"),
    UIKitAssetDescriptor("MetricCard", section: "Diagnostics & Status", specimen: "Metric card"),
    UIKitAssetDescriptor(
      "ChromeIconButtonStyle", section: "Diagnostics & Status", specimen: "Command buttons"),
    UIKitAssetDescriptor(
      "WorkspaceStageTabs", section: "App Chrome", specimen: "Workspace navigator"),
    UIKitAssetDescriptor("AdaptiveRibbon", section: "App Chrome", specimen: "Tool ribbon"),
    UIKitAssetDescriptor(
      "DockingWorkspace", section: "Appearance & Layout", specimen: "Layout contract"),
    UIKitAssetDescriptor("MockViewport", section: "Viewport", specimen: "Viewport mock"),
    UIKitAssetDescriptor(
      "TimelinePrototype", section: "Timelines", specimen: "Production dope sheet"),
    UIKitAssetDescriptor(
      "ViewportPerformanceHUD", section: "Diagnostics & Status", specimen: "Performance HUD"),
    UIKitAssetDescriptor("PrototypeSettingsView", section: "Settings", specimen: "Settings form"),
    UIKitAssetDescriptor(
      "SpatialSelectionToolsSpecimen", section: "Contextual Animatronic Widgets",
      specimen: "Selection rail and adaptive actions"),
    UIKitAssetDescriptor(
      "SpatialContextStackSpecimen", section: "Contextual Animatronic Widgets",
      specimen: "Context stack"),
    UIKitAssetDescriptor(
      "SpatialTimelineSpecimen", section: "Timelines", specimen: "Live Follow timeline"),
    UIKitAssetDescriptor(
      "PrototypeNodeCard", section: "Nodes", specimen: "Node types and states"),
    UIKitAssetDescriptor(
      "PrototypeNodeLibrary", section: "Nodes", specimen: "Categorized node library"),
    UIKitAssetDescriptor(
      "PrototypeNodeInspector", section: "Nodes", specimen: "Selected-node inspector"),
    UIKitAssetDescriptor(
      "PrototypeNodePortRow", section: "Nodes", specimen: "Typed node ports"),
    UIKitAssetDescriptor(
      "PrototypeNodeCanvas", section: "Node Canvas", specimen: "Connected behavior graph"),
  ]
}
