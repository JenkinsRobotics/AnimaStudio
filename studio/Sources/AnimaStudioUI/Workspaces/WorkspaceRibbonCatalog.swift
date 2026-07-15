import Foundation

enum WorkspaceRibbonAction: String, Sendable {
  case importModel
  case stopPlayback
  case togglePlayback
  case toggleLoop
  case previousKeyframe
  case nextKeyframe
  case frameSelection
  case toggleGrid
  case toggleBottomEditor
}

enum WorkspaceRibbonGroupRole: Sendable {
  case accent
  case assets
  case components
  case mates
  case hardware
  case planned
}

struct WorkspaceRibbonToolDescriptor: Identifiable, Sendable {
  let title: String
  let systemImage: String
  let help: String
  let action: WorkspaceRibbonAction?

  var id: String { title }
  var isImplemented: Bool { action != nil }
}

struct WorkspaceRibbonGroupDescriptor: Identifiable, Sendable {
  let title: String
  let systemImage: String
  let role: WorkspaceRibbonGroupRole
  let tools: [WorkspaceRibbonToolDescriptor]

  var id: String { title }
}

enum WorkspaceRibbonCatalog {
  static func groups(for workspace: StudioWorkspaceKind) -> [WorkspaceRibbonGroupDescriptor] {
    switch workspace {
    case .assets: assetGroups
    case .rig: []
    case .animate: animationGroups
    case .show: showGroups
    case .hardware: hardwareGroups
    }
  }

  private static let assetGroups = [
    group(
      "Import", "square.and.arrow.down", .assets,
      [
        tool(
          "3D Model", "cube.transparent", "Import a USD, USDZ, or RealityKit model.", .importModel),
        tool("Audio", "waveform", "Import reference or show audio."),
        tool("Video", "play.rectangle", "Import video for screens or reference."),
        tool("Image", "photo", "Import an image or texture."),
        tool("LED Layout", "circle.grid.3x3", "Import an LED or pixel layout."),
        tool("Batch", "square.stack.3d.up", "Import several compatible assets together."),
      ]),
    group(
      "Manage", "folder", .accent,
      [
        tool("Relink", "link", "Relink a missing source file."),
        tool(
          "Replace", "arrow.triangle.2.circlepath", "Replace an asset while preserving references."),
        tool("Reimport", "arrow.clockwise", "Reload an asset from its source."),
        tool("Reveal", "magnifyingglass", "Reveal the source file in Finder."),
        tool("Folder", "folder.badge.plus", "Create an asset folder."),
        tool("Duplicate", "plus.square.on.square", "Duplicate the selected asset."),
      ]),
    group(
      "Prepare", "slider.horizontal.3", .components,
      [
        tool("Units", "ruler", "Inspect or convert source units."),
        tool("Up Axis", "axis.3d", "Convert the source up axis."),
        tool("Origin", "scope", "Inspect or reset the model origin."),
        tool("Hierarchy", "list.bullet.indent", "Inspect the imported model hierarchy."),
        tool(
          "Map Nodes", "point.3.connected.trianglepath.dotted",
          "Map source nodes to semantic components."),
        tool("Validate", "checkmark.shield", "Validate asset compatibility and references."),
      ]),
  ]

  private static let animationGroups = [
    group(
      "Transport", "play.circle", .accent,
      [
        tool("Stop", "stop.fill", "Stop playback and return to the start.", .stopPlayback),
        tool("Play", "play.fill", "Play or pause the active animation.", .togglePlayback),
        tool("Loop", "repeat", "Loop preview playback.", .toggleLoop),
        tool("Previous Key", "backward.end", "Move to the previous keyframe.", .previousKeyframe),
        tool("Next Key", "forward.end", "Move to the next keyframe.", .nextKeyframe),
        tool(
          "Frame", "arrow.up.left.and.down.right.magnifyingglass", "Frame the selected model node.",
          .frameSelection),
        tool("Grid", "grid", "Show or hide the viewport grid.", .toggleGrid),
      ]),
    group(
      "Keyframes", "diamond", .mates,
      [
        tool("Add Key", "diamond.fill", "Add a keyframe at the playhead."),
        tool("Delete", "trash", "Delete selected keyframes."),
        tool("Copy", "doc.on.doc", "Copy selected keyframes."),
        tool("Paste", "doc.on.clipboard", "Paste keyframes at the playhead."),
        tool("Auto Key", "record.circle", "Create keys when animated values change."),
        tool("Snap", "dot.scope", "Snap keyframes to display frames."),
        tool("Reverse", "arrow.left.arrow.right", "Reverse selected motion timing."),
      ]),
    group(
      "Curves", "point.topleft.down.curvedto.point.bottomright.up", .components,
      [
        tool("Hold", "step.forward", "Use stepped hold interpolation."),
        tool("Linear", "line.diagonal", "Use linear interpolation."),
        tool("Bézier", "scribble.variable", "Use editable Bézier interpolation."),
        tool("Ease In", "arrow.right.to.line.compact", "Ease into selected keys."),
        tool("Ease Out", "arrow.left.to.line.compact", "Ease out of selected keys."),
        tool("Graph", "chart.xyaxis.line", "Open the animation graph presentation."),
      ]),
    group(
      "Tracks", "square.stack.3d.up", .assets,
      [
        tool("Add Track", "plus.rectangle.on.folder", "Add a motion track."),
        tool("Group", "folder", "Group selected tracks."),
        tool("Mute", "speaker.slash", "Mute selected tracks."),
        tool("Solo", "headphones", "Solo selected tracks."),
        tool("Lock", "lock", "Lock selected tracks."),
        tool("Layers", "square.3.layers.3d", "Create or manage motion layers."),
        tool(
          "Timeline", "rectangle.bottomthird.inset.filled", "Show or hide the timeline.",
          .toggleBottomEditor),
      ]),
    group(
      "Reference", "waveform.path", .planned,
      [
        tool("Audio", "waveform", "Add reference audio and its waveform."),
        tool("Video", "play.rectangle", "Add reference video."),
        tool("Marker", "bookmark", "Add a timeline marker."),
        tool("Lip Sync", "mouth", "Add a lip-sync authoring track."),
        tool("Beat", "metronome", "Detect or author beat markers."),
      ]),
  ]

  private static let showGroups = [
    group(
      "Sequence", "rectangle.stack.badge.plus", .accent,
      [
        tool("Character", "figure.wave", "Add a character track."),
        tool("Audio", "waveform", "Add an audio track."),
        tool("Video", "play.rectangle", "Add a video track."),
        tool("Screen", "display", "Add a simulated screen track."),
        tool("LED", "circle.grid.3x3", "Add an LED-matrix track."),
        tool("Event", "bolt.circle", "Add an event track."),
      ]),
    group(
      "Clips", "film.stack", .assets,
      [
        tool("Animation", "figure.walk.motion", "Add an animation clip."),
        tool("Trim", "timeline.selection", "Trim the selected clip."),
        tool("Split", "scissors", "Split a clip at the playhead."),
        tool("Loop", "repeat", "Loop the selected clip."),
        tool("Crossfade", "waveform.path.ecg.rectangle", "Crossfade compatible clips."),
        tool("Speed", "gauge.with.dots.needle.50percent", "Change clip playback speed."),
      ]),
    group(
      "Events", "wave.3.right.circle", .mates,
      [
        tool("Trigger", "bolt.circle", "Emit a one-shot trigger."),
        tool("On / Off", "switch.2", "Author a Boolean event."),
        tool(
          "Curve", "point.topleft.down.curvedto.point.bottomright.up",
          "Author a numeric event curve."),
        tool("Message", "text.bubble", "Send a text or message event."),
        tool("Hardware", "cable.connector", "Send a bounded hardware command."),
        tool("Network", "network", "Send a network event through a configured plugin."),
      ]),
    group(
      "Sync", "clock.arrow.2.circlepath", .components,
      [
        tool("Timecode", "clock", "Configure show timecode."),
        tool("Marker", "bookmark", "Add a show marker."),
        tool("Pre-roll", "backward.frame", "Configure show pre-roll."),
        tool("Scene", "rectangle.3.group", "Group clips into a scene."),
        tool(
          "Timeline", "rectangle.bottomthird.inset.filled", "Show or hide the show timeline.",
          .toggleBottomEditor),
        tool("Grid", "grid", "Show or hide the preview grid.", .toggleGrid),
      ]),
  ]

  private static let hardwareGroups = [
    group(
      "Connection", "cable.connector", .hardware,
      [
        tool("Connect", "bolt.horizontal.circle", "Connect to a configured hardware driver."),
        tool("Rescan", "arrow.clockwise", "Rescan serial and network devices."),
        tool("Serial", "cable.connector.horizontal", "Configure a serial device."),
        tool("Network", "network", "Discover or configure a network device."),
        tool("Diagnostics", "stethoscope", "Open connection diagnostics."),
      ]),
    group(
      "Outputs", "square.grid.3x3", .accent,
      [
        tool("Servo", "capsule", "Add a standard servo output."),
        tool("PCA9685", "cpu", "Add a PCA9685 servo controller."),
        tool("Stepper", "move.3d", "Add a stepper output."),
        tool("DYNAMIXEL", "hexagon", "Add a DYNAMIXEL output."),
        tool("Digital", "switch.2", "Add a digital output."),
        tool("PWM", "waveform.path", "Add a PWM output."),
        tool("LED", "circle.grid.3x3", "Add an LED controller."),
        tool("Screen", "display", "Add a screen controller."),
        tool("Plugin", "puzzlepiece.extension", "Add a custom output plugin."),
      ]),
    group(
      "Mapping", "arrow.triangle.branch", .components,
      [
        tool(
          "Map DOF", "point.3.connected.trianglepath.dotted", "Map a rig DOF to an output channel."),
        tool("Range", "slider.horizontal.below.rectangle", "Set minimum and maximum output."),
        tool("Reverse", "arrow.left.arrow.right", "Reverse output direction."),
        tool("Neutral", "scope", "Set the neutral output value."),
        tool("Deadband", "minus.plus.batteryblock", "Set an output deadband."),
        tool("Curve", "chart.xyaxis.line", "Shape the output response curve."),
        tool("Velocity", "speedometer", "Limit output velocity."),
        tool(
          "Acceleration", "gauge.open.with.lines.needle.33percent", "Limit output acceleration."),
        tool("Smoothing", "waveform.path.ecg", "Configure output smoothing."),
      ]),
    group(
      "Calibration", "wrench.and.screwdriver", .mates,
      [
        tool("Jog", "arrow.left.and.right", "Jog a selected output safely."),
        tool("Neutral", "scope", "Move the selected output to neutral."),
        tool("Sweep", "arrow.triangle.2.circlepath", "Sweep within configured safe limits."),
        tool("Set Min", "arrow.down.to.line", "Capture the physical minimum."),
        tool("Set Max", "arrow.up.to.line", "Capture the physical maximum."),
        tool("Test Channel", "play.square", "Test one mapped channel."),
        tool("Test Rig", "figure.walk.motion", "Exercise the complete mechanism virtually first."),
      ]),
    group(
      "Safety", "exclamationmark.shield", .hardware,
      [
        tool("Arm", "power", "Arm hardware output after safety checks."),
        tool("E-Stop", "stop.circle.fill", "Immediately stop and disarm output."),
        tool("Failsafe", "heart.text.square", "Configure heartbeat and timeout behavior."),
        tool("Safe Pose", "figure.stand", "Configure the safe fallback pose."),
        tool("Limits", "shield.lefthalf.filled", "Review enforced output limits."),
        tool("Reset Fault", "arrow.counterclockwise.circle", "Reset a resolved hardware fault."),
      ]),
    group(
      "Monitor", "waveform.path.ecg.rectangle", .planned,
      [
        tool("Channels", "list.number", "Monitor live channel targets."),
        tool("Position", "scope", "Compare commanded and reported position."),
        tool("Health", "heart.text.square", "Monitor driver health."),
        tool("Latency", "timer", "Monitor communication latency."),
        tool("Logs", "doc.text.magnifyingglass", "Open filterable hardware logs."),
        tool("Export", "square.and.arrow.up", "Export hardware logs."),
        tool("Firmware", "memorychip", "Inspect device firmware information."),
      ]),
  ]

  private static func group(
    _ title: String,
    _ systemImage: String,
    _ role: WorkspaceRibbonGroupRole,
    _ tools: [WorkspaceRibbonToolDescriptor]
  ) -> WorkspaceRibbonGroupDescriptor {
    WorkspaceRibbonGroupDescriptor(
      title: title,
      systemImage: systemImage,
      role: role,
      tools: tools
    )
  }

  private static func tool(
    _ title: String,
    _ systemImage: String,
    _ help: String,
    _ action: WorkspaceRibbonAction? = nil
  ) -> WorkspaceRibbonToolDescriptor {
    WorkspaceRibbonToolDescriptor(
      title: title,
      systemImage: systemImage,
      help: help,
      action: action
    )
  }
}
