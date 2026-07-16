import AnimaEvaluation
import AnimaModel
import SwiftUI

struct TimelineEditorView: View {
  @Bindable var workspace: StudioWorkspaceModel

  private let trackHeaderWidth: CGFloat = 220
  private let rulerHeight: CGFloat = 30
  private let playRangeHeight: CGFloat = 11
  private let rowHeight: CGFloat = 44

  private var clip: AnimationClip { workspace.activeClip }

  var body: some View {
    VStack(spacing: 0) {
      transport
      Divider()
      editorModeBar
      Divider()
      editorContent
    }
    .background(Color.black.opacity(0.92))
  }

  private var transport: some View {
    HStack(spacing: 8) {
      transportButton("Previous Keyframe", systemImage: "chevron.left.2") {
        workspace.seekAdjacentKeyframe(forward: false)
      }
      transportButton("Previous Frame", systemImage: "chevron.left") {
        workspace.stepTimeline(byFrames: -1)
      }
      transportButton("Stop", systemImage: "stop.fill", action: workspace.stopPlayback)
      transportButton(
        workspace.isPlaying ? "Pause" : "Play",
        systemImage: workspace.isPlaying ? "pause.fill" : "play.fill",
        action: workspace.togglePlayback
      )
      .keyboardShortcut(.space, modifiers: [])
      transportButton("Next Frame", systemImage: "chevron.right") {
        workspace.stepTimeline(byFrames: 1)
      }
      transportButton("Next Keyframe", systemImage: "chevron.right.2") {
        workspace.seekAdjacentKeyframe(forward: true)
      }

      Divider().frame(height: 20)

      Button {
        workspace.loopsPreviewPlayback.toggle()
      } label: {
        Label("Loop Preview", systemImage: "repeat")
          .labelStyle(.iconOnly)
          .foregroundStyle(workspace.loopsPreviewPlayback ? .white : StudioPalette.muted)
          .frame(width: 27, height: 27)
          .background(
            workspace.loopsPreviewPlayback ? StudioPalette.accent : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
          )
      }
      .buttonStyle(.plain)
      .help(
        workspace.loopsPreviewPlayback
          ? "Looping virtual preview is on" : "Looping virtual preview is off"
      )

      Text(clip.name)
        .fontWeight(.semibold)
        .lineLimit(1)

      Spacer(minLength: 8)

      Menu {
        ForEach([24, 25, 30, 60], id: \.self) { framesPerSecond in
          Button {
            workspace.timelineDisplayFramesPerSecond = framesPerSecond
          } label: {
            if workspace.timelineDisplayFramesPerSecond == framesPerSecond {
              Label("\(framesPerSecond) fps", systemImage: "checkmark")
            } else {
              Text("\(framesPerSecond) fps")
            }
          }
        }
      } label: {
        Text("\(workspace.timelineDisplayFramesPerSecond) fps")
          .font(.caption.monospacedDigit())
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .help("Display and stepping grid; animation evaluation remains continuous-time")

      timecodeReadout

      Label("OUTPUT OFFLINE", systemImage: "lock.shield")
        .font(.caption2.weight(.bold))
        .foregroundStyle(StudioPalette.muted)
        .help("Timeline preview does not drive physical hardware")
    }
    .padding(.horizontal, 12)
    .frame(height: 44)
    .background(StudioPalette.chrome)
  }

  private var timecodeReadout: some View {
    let current = TimelineTimecode(
      timeSeconds: workspace.playheadSeconds,
      framesPerSecond: workspace.timelineDisplayFramesPerSecond
    )
    let duration = TimelineTimecode(
      timeSeconds: clip.durationSeconds,
      framesPerSecond: workspace.timelineDisplayFramesPerSecond
    )

    return HStack(spacing: 5) {
      Text(current.displayString)
        .foregroundStyle(.white)
      Text("/")
        .foregroundStyle(StudioPalette.muted)
      Text(duration.displayString)
        .foregroundStyle(StudioPalette.muted)
    }
    .font(.system(.caption, design: .monospaced).weight(.medium))
    .padding(.horizontal, 8)
    .frame(height: 27)
    .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 6))
    .overlay {
      RoundedRectangle(cornerRadius: 6)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .help("Minutes : seconds : frames")
    .accessibilityLabel("Timeline position")
    .accessibilityValue("\(current.displayString) of \(duration.displayString)")
  }

  private var editorModeBar: some View {
    HStack(spacing: 8) {
      ForEach(TimelineEditorMode.allCases, id: \.self) { mode in
        modeButton(mode)
      }

      Divider().frame(height: 20)

      Button("Add Key", systemImage: "diamond.fill") {}
        .disabled(true)
        .help("Key insertion arrives with editable animation commands")
      Button("Add Marker", systemImage: "bookmark.fill") {}
        .disabled(true)
        .help("Markers arrive with persistent animation documents")
      Button("Auto Key", systemImage: "record.circle") {}
        .disabled(true)
        .help("Auto-key arrives with undoable viewport authoring")

      Spacer(minLength: 8)

      Image(systemName: "minus.magnifyingglass")
        .foregroundStyle(StudioPalette.muted)
      Slider(value: $workspace.timelineZoom, in: 1...8)
        .frame(width: 105)
        .help("Timeline time zoom")
      Image(systemName: "plus.magnifyingglass")
        .foregroundStyle(StudioPalette.muted)
      Text("\(workspace.timelineZoom.formatted(.number.precision(.fractionLength(1))))×")
        .font(.caption2.monospacedDigit())
        .foregroundStyle(StudioPalette.muted)
        .frame(width: 34, alignment: .trailing)
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 10)
    .frame(height: 38)
    .background(Color.black.opacity(0.86))
  }

  @ViewBuilder
  private var editorContent: some View {
    switch workspace.timelineEditorMode {
    case .dopeSheet:
      dopeSheet
    case .graph:
      graphEditor
    }
  }

  private var dopeSheet: some View {
    GeometryReader { proxy in
      let availableCanvasWidth = max(proxy.size.width - trackHeaderWidth - 1, 1)
      let contentWidth = max(availableCanvasWidth * workspace.timelineZoom, availableCanvasWidth)
      let contentHeight = dopeSheetContentHeight

      ScrollView(.vertical) {
        HStack(alignment: .top, spacing: 0) {
          dopeSheetTrackHeaders
            .frame(width: trackHeaderWidth, height: contentHeight, alignment: .top)
          Divider()
          ScrollView(.horizontal) {
            dopeSheetCanvas(width: contentWidth, height: contentHeight)
          }
          .frame(width: availableCanvasWidth, height: contentHeight)
        }
        .frame(width: proxy.size.width, height: contentHeight, alignment: .topLeading)
      }
    }
  }

  private var dopeSheetTrackHeaders: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("TRACKS")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(StudioPalette.muted)
        Spacer()
        Text("\(motionTracks.count) motion")
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(.horizontal, 12)
      .frame(height: rulerHeight + playRangeHeight)

      ForEach(motionTracks) { motionTrack in
        timelineTrackHeader(
          title: motionTrack.name,
          detail: motionTrack.unit,
          systemImage: "rotate.3d",
          color: motionTrack.color
        )
      }

      timelineTrackHeader(
        title: "Audio",
        detail: "No media",
        systemImage: "waveform",
        color: Color.green.opacity(0.8)
      )
      timelineTrackHeader(
        title: "Events",
        detail: "Planned",
        systemImage: "bolt.fill",
        color: StudioPalette.hardware
      )
    }
    .background(StudioPalette.panelInset)
  }

  private func timelineTrackHeader(
    title: String,
    detail: String,
    systemImage: String,
    color: Color
  ) -> some View {
    HStack(spacing: 8) {
      Image(systemName: systemImage)
        .foregroundStyle(color)
        .frame(width: 16)
      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.callout)
          .lineLimit(1)
        Text(detail)
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
      }
      Spacer(minLength: 4)
    }
    .padding(.horizontal, 12)
    .frame(height: rowHeight)
    .overlay(alignment: .bottom) {
      Divider()
    }
  }

  private func dopeSheetCanvas(width: CGFloat, height: CGFloat) -> some View {
    ZStack(alignment: .topLeading) {
      StudioPalette.panel.opacity(0.58)

      timelineRows(width: width)
      timelineRuler(width: width)
      playRange(width: width)
      timeGrid(width: width, height: height)

      ForEach(Array(motionTracks.enumerated()), id: \.element.id) { rowIndex, motionTrack in
        ForEach(Array(motionTrack.track.keyframes.enumerated()), id: \.offset) { _, keyframe in
          Button {
            workspace.seekTimeline(to: keyframe.timeSeconds)
          } label: {
            RoundedRectangle(cornerRadius: 1.5)
              .fill(motionTrack.color)
              .stroke(.white.opacity(0.78), lineWidth: 1)
              .frame(width: 10, height: 10)
              .rotationEffect(.degrees(45))
          }
          .buttonStyle(.plain)
          .position(
            x: xPosition(for: keyframe.timeSeconds, width: width),
            y: rowCenter(rowIndex)
          )
          .help(
            "\(motionTrack.name) · \(timecode(for: keyframe.timeSeconds)) · \(keyframe.value.formatted(.number.precision(.fractionLength(3)))) rad"
          )
        }
      }

      emptyLaneMessage(
        "Import audio to display a waveform",
        rowIndex: motionTracks.count,
        color: .green
      )
      emptyLaneMessage(
        "Typed event tracks are not wired yet",
        rowIndex: motionTracks.count + 1,
        color: StudioPalette.hardware
      )

      playhead(width: width, height: height)
    }
    .frame(width: width, height: height)
    .contentShape(Rectangle())
    .gesture(timelineScrubGesture(width: width))
  }

  private func timelineRows(width: CGFloat) -> some View {
    ForEach(0..<dopeSheetRowCount, id: \.self) { rowIndex in
      ZStack(alignment: .bottom) {
        Rectangle()
          .fill(rowIndex.isMultiple(of: 2) ? Color.white.opacity(0.025) : Color.clear)
        Divider()
      }
      .frame(width: width, height: rowHeight)
      .offset(y: timelineBodyTop + CGFloat(rowIndex) * rowHeight)
    }
  }

  private func timelineRuler(width: CGFloat) -> some View {
    ZStack(alignment: .topLeading) {
      Rectangle()
        .fill(StudioPalette.panelInset)
        .frame(width: width, height: rulerHeight)
      ForEach(0...wholeSecondCount, id: \.self) { second in
        Text("\(second)s")
          .font(.caption2.monospacedDigit())
          .foregroundStyle(StudioPalette.muted)
          .position(x: xPosition(for: Double(second), width: width), y: rulerHeight / 2)
      }
    }
  }

  private func playRange(width: CGFloat) -> some View {
    ZStack {
      Capsule()
        .fill(StudioPalette.accent.opacity(0.32))
        .frame(width: max(width - 8, 1), height: 5)
      HStack {
        Circle().fill(StudioPalette.accent).frame(width: 7, height: 7)
        Spacer()
        Circle().fill(StudioPalette.accent).frame(width: 7, height: 7)
      }
      .padding(.horizontal, 2)
    }
    .frame(width: width, height: playRangeHeight)
    .offset(y: rulerHeight)
    .help("Full-clip play range; editable range handles are planned")
  }

  private func timeGrid(width: CGFloat, height: CGFloat) -> some View {
    ForEach(0...wholeSecondCount, id: \.self) { second in
      Rectangle()
        .fill(Color.white.opacity(second == 0 ? 0.18 : 0.08))
        .frame(width: 1, height: max(height - rulerHeight, 0))
        .offset(x: xPosition(for: Double(second), width: width), y: rulerHeight)
    }
  }

  private func emptyLaneMessage(_ title: String, rowIndex: Int, color: Color) -> some View {
    Label(title, systemImage: "plus.circle")
      .font(.caption)
      .foregroundStyle(color.opacity(0.72))
      .padding(.leading, 14)
      .position(x: 132, y: rowCenter(rowIndex))
      .allowsHitTesting(false)
  }

  private var graphEditor: some View {
    GeometryReader { proxy in
      let availableCanvasWidth = max(proxy.size.width - trackHeaderWidth - 1, 1)
      let contentWidth = max(availableCanvasWidth * workspace.timelineZoom, availableCanvasWidth)

      HStack(spacing: 0) {
        graphTrackHeaders
          .frame(width: trackHeaderWidth)
        Divider()
        ScrollView(.horizontal) {
          graphCanvas(width: contentWidth, height: proxy.size.height)
        }
        .frame(width: availableCanvasWidth, height: proxy.size.height)
      }
    }
  }

  private var graphTrackHeaders: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("VISIBLE CURVES")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(StudioPalette.muted)

      ForEach(graphTracks) { motionTrack in
        HStack(spacing: 8) {
          Circle()
            .fill(motionTrack.color)
            .frame(width: 8, height: 8)
          Text(motionTrack.name)
            .font(.callout)
            .lineLimit(1)
          Spacer()
          Text(motionTrack.unit)
            .font(.caption2)
            .foregroundStyle(StudioPalette.muted)
        }
      }

      Divider()
      Label("Select mates to isolate curves", systemImage: "cursorarrow.click.2")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      Label("Audio stays in the Dope Sheet", systemImage: "waveform.slash")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      Spacer()
      Label("Bézier handles planned", systemImage: "lock")
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
    }
    .padding(12)
    .background(StudioPalette.panelInset)
  }

  private func graphCanvas(width: CGFloat, height: CGFloat) -> some View {
    Canvas { context, size in
      let plotTop = rulerHeight
      let plotHeight = max(size.height - plotTop, 1)

      context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(StudioPalette.panel))

      for division in 0...4 {
        let y = plotTop + CGFloat(division) / 4 * plotHeight
        var horizontal = Path()
        horizontal.move(to: CGPoint(x: 0, y: y))
        horizontal.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(horizontal, with: .color(.white.opacity(0.08)), lineWidth: 1)
      }

      for second in 0...wholeSecondCount {
        let x = xPosition(for: Double(second), width: size.width)
        var vertical = Path()
        vertical.move(to: CGPoint(x: x, y: 0))
        vertical.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(vertical, with: .color(.white.opacity(0.08)), lineWidth: 1)
      }

      for motionTrack in graphTracks {
        drawGraphTrack(
          motionTrack,
          context: &context,
          size: size,
          plotTop: plotTop,
          plotHeight: plotHeight
        )
      }
    }
    .overlay(alignment: .topLeading) {
      ForEach(0...wholeSecondCount, id: \.self) { second in
        Text("\(second)s")
          .font(.caption2.monospacedDigit())
          .foregroundStyle(StudioPalette.muted)
          .position(x: xPosition(for: Double(second), width: width), y: rulerHeight / 2)
      }
    }
    .overlay(alignment: .topLeading) {
      playhead(width: width, height: height)
    }
    .frame(width: width, height: height)
    .contentShape(Rectangle())
    .gesture(timelineScrubGesture(width: width))
  }

  private func drawGraphTrack(
    _ motionTrack: TimelineMotionTrack,
    context: inout GraphicsContext,
    size: CGSize,
    plotTop: CGFloat,
    plotHeight: CGFloat
  ) {
    guard let first = motionTrack.track.keyframes.first else { return }

    func point(for keyframe: ScalarKeyframe) -> CGPoint {
      CGPoint(
        x: xPosition(for: keyframe.timeSeconds, width: size.width),
        y: plotTop + (1 - motionTrack.normalized(keyframe.value)) * plotHeight
      )
    }

    var path = Path()
    path.move(to: point(for: first))

    for index in motionTrack.track.keyframes.indices.dropFirst() {
      let previous = motionTrack.track.keyframes[index - 1]
      let current = motionTrack.track.keyframes[index]
      let currentPoint = point(for: current)
      if previous.interpolation == .hold {
        let previousPoint = point(for: previous)
        path.addLine(to: CGPoint(x: currentPoint.x, y: previousPoint.y))
      }
      path.addLine(to: currentPoint)
    }

    context.stroke(path, with: .color(motionTrack.color), lineWidth: 2)

    for keyframe in motionTrack.track.keyframes {
      let keyframePoint = point(for: keyframe)
      let rect = CGRect(x: keyframePoint.x - 4, y: keyframePoint.y - 4, width: 8, height: 8)
      context.fill(Path(ellipseIn: rect), with: .color(motionTrack.color))
      context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.72)), lineWidth: 1)
    }
  }

  private func playhead(width: CGFloat, height: CGFloat) -> some View {
    ZStack(alignment: .top) {
      Rectangle()
        .fill(StudioPalette.accent)
        .frame(width: 1.5, height: height)
      Image(systemName: "triangle.fill")
        .font(.system(size: 8))
        .foregroundStyle(StudioPalette.accent)
        .rotationEffect(.degrees(180))
        .offset(y: -1)
    }
    .offset(x: xPosition(for: workspace.playheadSeconds, width: width) - 4)
    .allowsHitTesting(false)
  }

  private func timelineScrubGesture(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        workspace.seekTimeline(
          to: min(
            max(Double(value.location.x / max(width, 1)) * clip.durationSeconds, 0),
            clip.durationSeconds)
        )
      }
  }

  private func transportButton(
    _ title: String,
    systemImage: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .labelStyle(.iconOnly)
        .frame(width: 23, height: 25)
    }
    .buttonStyle(.borderless)
    .help(title)
  }

  private func modeButton(_ mode: TimelineEditorMode) -> some View {
    Button {
      workspace.timelineEditorMode = mode
    } label: {
      Label(mode.title, systemImage: mode.systemImage)
        .font(.caption.weight(workspace.timelineEditorMode == mode ? .semibold : .regular))
        .foregroundStyle(
          workspace.timelineEditorMode == mode ? StudioPalette.accent : StudioPalette.muted
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
          workspace.timelineEditorMode == mode
            ? StudioPalette.accent.opacity(0.14) : Color.clear,
          in: Capsule()
        )
    }
    .buttonStyle(.plain)
  }

  private var motionTracks: [TimelineMotionTrack] {
    clip.jointTracks.enumerated().map { index, track in
      let joint = workspace.project.rig.joints.first { $0.id == track.jointID }
      return TimelineMotionTrack(
        track: track,
        name: joint?.displayName ?? track.jointID.rawValue,
        unit: "rad",
        minimumValue: joint?.minimumRadians ?? track.keyframes.map(\.value).min() ?? -1,
        maximumValue: joint?.maximumRadians ?? track.keyframes.map(\.value).max() ?? 1,
        color: Self.trackColors[index % Self.trackColors.count]
      )
    }
  }

  private var graphTracks: [TimelineMotionTrack] {
    let selectedJointIDs = Set(
      workspace.selection.compactMap { item -> JointID? in
        guard case .joint(let jointID) = item else { return nil }
        return jointID
      })
    guard !selectedJointIDs.isEmpty else { return motionTracks }
    return motionTracks.filter { selectedJointIDs.contains($0.id) }
  }

  private var dopeSheetRowCount: Int {
    motionTracks.count + 2
  }

  private var timelineBodyTop: CGFloat {
    rulerHeight + playRangeHeight
  }

  private var dopeSheetContentHeight: CGFloat {
    timelineBodyTop + CGFloat(dopeSheetRowCount) * rowHeight
  }

  private var wholeSecondCount: Int {
    max(Int(ceil(clip.durationSeconds)), 1)
  }

  private func rowCenter(_ rowIndex: Int) -> CGFloat {
    timelineBodyTop + CGFloat(rowIndex) * rowHeight + rowHeight / 2
  }

  private func xPosition(for seconds: Double, width: CGFloat) -> CGFloat {
    CGFloat(seconds / max(clip.durationSeconds, 0.001)) * width
  }

  private func timecode(for seconds: Double) -> String {
    TimelineTimecode(
      timeSeconds: seconds,
      framesPerSecond: workspace.timelineDisplayFramesPerSecond
    ).displayString
  }

  private static let trackColors: [Color] = [
    Color(red: 0.30, green: 0.68, blue: 0.98),
    Color(red: 0.79, green: 0.47, blue: 0.96),
    Color(red: 0.24, green: 0.78, blue: 0.64),
    Color(red: 0.98, green: 0.62, blue: 0.25),
    Color(red: 0.95, green: 0.39, blue: 0.55),
    Color(red: 0.85, green: 0.80, blue: 0.30),
  ]
}

private struct TimelineMotionTrack: Identifiable {
  let track: JointTrack
  let name: String
  let unit: String
  let minimumValue: Double
  let maximumValue: Double
  let color: Color

  var id: JointID { track.jointID }

  func normalized(_ value: Double) -> CGFloat {
    let range = maximumValue - minimumValue
    guard range > 1e-12 else { return 0.5 }
    return CGFloat(min(max((value - minimumValue) / range, 0), 1))
  }
}
