import Foundation
import SwiftUI

struct UIDevTimelineDesignBView: View {
  @State private var variant: UIDevTimelineBVariant = .dopeSheet
  @State private var tracks = UIDevTimelineBSamples.tracks
  @State private var selectedTrackID = UIDevTimelineBSamples.tracks[0].id
  @State private var selectedKeyframeID: UUID?
  @State private var playhead = 2.4
  @State private var isPlaying = false
  @State private var nextTrackNumber = 1
  @State private var trackSearch = ""
  @State private var status = "Click any row to create a keyframe"

  private let duration = UIDevTimelineBSamples.duration
  private let framesPerSecond = 30

  private var filteredTracks: [UIDevTimelineBTrack] {
    guard !trackSearch.isEmpty else { return tracks }
    return tracks.filter { $0.name.localizedCaseInsensitiveContains(trackSearch) }
  }

  private var frameCount: Int {
    Int((duration * Double(framesPerSecond)).rounded())
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      variantBar
      Divider()
      timelineSurface
      Divider()
      footer
    }
    .frame(maxWidth: 1_080, minHeight: 480, maxHeight: 620)
    .background(StudioPalette.panel)
    .clipShape(RoundedRectangle(cornerRadius: 13))
    .overlay {
      RoundedRectangle(cornerRadius: 13)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Timeline Design B interaction prototype")
  }

  private var header: some View {
    HStack(spacing: 6) {
      Menu {
        Button("Reset Preview") { resetPreview() }
      } label: {
        Image(systemName: "clock.arrow.circlepath")
      }
      .menuStyle(.borderlessButton)
      .frame(width: 24)

      Menu("Playback") {
        Button("Play / Pause", action: togglePlayback)
        Button("Jump to Start") { playhead = 0 }
        Button("Jump to End") { playhead = duration }
      }
      .menuStyle(.borderlessButton)
      .frame(width: 74)

      Menu("View") {
        ForEach(UIDevTimelineBVariant.allCases) { option in
          Button(option.title) { variant = option }
        }
      }
      .menuStyle(.borderlessButton)
      .frame(width: 48)

      Button("Marker") {
        addKeyframeAtPlayhead()
      }
      .buttonStyle(.plain)
      .font(.caption)

      Spacer()

      transportButton("backward.end.fill") { playhead = 0 }
      transportButton("backward.frame.fill") { playhead = max(playhead - 0.25, 0) }
      transportButton(isPlaying ? "pause.fill" : "play.fill", action: togglePlayback)
      transportButton("forward.frame.fill") { playhead = min(playhead + 0.25, duration) }
      transportButton("forward.end.fill") { playhead = duration }

      Spacer()

      compactFrameField(label: "START", value: "0")
      compactFrameField(label: "END", value: "\(frameCount)")
    }
    .padding(.horizontal, 8)
    .frame(height: 32)
    .background(StudioPalette.chrome)
  }

  private var variantBar: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text("TIMELINE DESIGN B")
          .font(.caption2.weight(.bold))
          .tracking(1.0)
          .foregroundStyle(StudioPalette.accent)
        Text(variant.detail)
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
      }

      Spacer(minLength: 16)

      Picker("Timeline variant", selection: $variant) {
        ForEach(UIDevTimelineBVariant.allCases) { option in
          Label(option.title, systemImage: option.systemImage)
            .tag(option)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(maxWidth: 500)

      Button {
        addTrack()
      } label: {
        Label("Add Row", systemImage: "plus")
      }
      .buttonStyle(
        StudioButtonStyle(role: .secondary, density: .compact, expandsHorizontally: false)
      )

      Button {
        deleteSelectedKeyframe()
      } label: {
        Image(systemName: "trash")
      }
      .buttonStyle(StudioIconButtonStyle())
      .disabled(selectedKeyframeID == nil)
      .help("Delete selected keyframe")
    }
    .padding(.horizontal, 12)
    .frame(height: 48)
    .background(StudioPalette.ribbonChrome)
  }

  private var timelineSurface: some View {
    ScrollView([.horizontal, .vertical]) {
      VStack(spacing: 0) {
        HStack(spacing: 0) {
          HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
              .font(.system(size: 9))
              .foregroundStyle(StudioPalette.muted)
            TextField("Search channels", text: $trackSearch)
              .textFieldStyle(.plain)
              .font(.system(size: 9))
            if !trackSearch.isEmpty {
              Button {
                trackSearch = ""
              } label: {
                Image(systemName: "xmark.circle.fill")
              }
              .buttonStyle(.plain)
              .foregroundStyle(StudioPalette.muted)
              .help("Clear channel search")
            }
          }
          .padding(.horizontal, 8)
          .frame(width: 170, height: 28)
          .background(StudioPalette.panelInset)

          Divider()

          timelineRuler
            .frame(minWidth: 720)
            .frame(height: 28)
        }

        timelineSummaryRow

        ForEach(filteredTracks) { track in
          timelineRow(track)
        }

        if filteredTracks.isEmpty {
          HStack(spacing: 0) {
            Text("No matching channels")
              .font(.caption2)
              .foregroundStyle(StudioPalette.muted)
              .padding(.horizontal, 10)
              .frame(width: 170, height: 44, alignment: .leading)
              .background(StudioPalette.panelInset)
            Divider()
            Rectangle()
              .fill(Color.black.opacity(0.11))
              .frame(minWidth: 720, minHeight: 44)
          }
        }
      }
      .frame(minWidth: 890, alignment: .topLeading)
    }
    .background(Color.black.opacity(0.15))
  }

  private var timelineRuler: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        StudioPalette.panelInset
        ForEach(0...24, id: \.self) { tick in
          let frame = tick * 10
          let x = proxy.size.width * CGFloat(Double(frame) / Double(frameCount))
          Rectangle()
            .fill(frame == 0 ? StudioPalette.accent : StudioPalette.border)
            .frame(width: 1, height: 28)
            .offset(x: x)
          Text("\(frame)")
            .font(.system(size: 7, design: .monospaced))
            .foregroundStyle(StudioPalette.muted)
            .offset(x: min(x + 3, proxy.size.width - 22), y: 5)
        }

        let playheadX = proxy.size.width * CGFloat(playhead / duration)
        Text("\(frame(at: playhead))")
          .font(.system(size: 7, weight: .bold, design: .monospaced))
          .foregroundStyle(Color.white)
          .padding(.horizontal, 4)
          .frame(height: 15)
          .background(StudioPalette.accent)
          .clipShape(RoundedRectangle(cornerRadius: 3))
          .position(
            x: min(max(playheadX, 12), proxy.size.width - 12),
            y: 8
          )

        Path { path in
          path.move(to: CGPoint(x: playheadX - 4, y: 14))
          path.addLine(to: CGPoint(x: playheadX + 4, y: 14))
          path.addLine(to: CGPoint(x: playheadX, y: 20))
          path.closeSubpath()
        }
        .fill(StudioPalette.accent)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { gesture in
            playhead = time(at: gesture.location.x, width: proxy.size.width)
          }
      )
    }
  }

  private var timelineSummaryRow: some View {
    HStack(spacing: 0) {
      HStack(spacing: 7) {
        Image(systemName: "chevron.down")
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(StudioPalette.muted)
        Text("Summary")
          .font(.caption.weight(.semibold))
        Spacer()
        Text("\(tracks.reduce(0) { $0 + $1.keyframes.count })")
          .font(.caption2.monospaced())
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(.horizontal, 10)
      .frame(width: 170, height: 26)
      .background(StudioPalette.chrome)

      Divider()

      UIDevTimelineBSummaryCanvas(
        keyframeTimes: tracks.flatMap { $0.keyframes.map(\.time) },
        duration: duration,
        playhead: playhead
      )
      .frame(minWidth: 720, minHeight: 26, maxHeight: 26)
    }
  }

  private func timelineRow(_ track: UIDevTimelineBTrack) -> some View {
    let isSelected = selectedTrackID == track.id
    let tint = trackColor(track.colorIndex)

    return HStack(spacing: 0) {
      Button {
        selectedTrackID = track.id
        selectedKeyframeID = nil
      } label: {
        HStack(spacing: 7) {
          Image(systemName: "chevron.down")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(StudioPalette.muted)
          Circle()
            .fill(tint)
            .frame(width: 8, height: 8)
          Text(track.name)
            .font(.caption.weight(isSelected ? .semibold : .regular))
            .lineLimit(1)
          Spacer()
          Text("\(track.keyframes.count)")
            .font(.caption2.monospaced())
            .foregroundStyle(StudioPalette.muted)
        }
        .padding(.horizontal, 10)
        .frame(width: 170, height: variant.rowHeight)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .background(isSelected ? StudioPalette.accent.opacity(0.13) : StudioPalette.panelInset)

      Divider()

      UIDevTimelineBTrackCanvas(
        track: track,
        variant: variant,
        duration: duration,
        playhead: playhead,
        selectedKeyframeID: selectedKeyframeID,
        tint: tint,
        selectKeyframe: { keyframeID in
          selectedTrackID = track.id
          selectedKeyframeID = keyframeID
          status = "Selected \(track.name) keyframe"
        },
        insertKeyframe: { normalizedX, normalizedY in
          insertKeyframe(
            trackID: track.id,
            time: normalizedX * duration,
            value: UIDevTimelineBGeometry.value(
              atNormalizedY: normalizedY,
              variant: variant
            )
          )
        }
      )
      .frame(minWidth: 720)
      .frame(height: variant.rowHeight)
    }
  }

  private var footer: some View {
    HStack(spacing: 14) {
      Label("Click row: add key", systemImage: "cursorarrow.click")
      Label("Drag ruler: scrub", systemImage: "arrow.left.and.right")
      Label(
        "Connected line: motion", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
      Spacer()
      Text(status)
        .lineLimit(1)
      Text("TIME \(timecode(playhead))  FRAME \(frame(at: playhead))/\(frameCount)")
        .font(.caption2.monospaced().weight(.bold))
        .foregroundStyle(StudioPalette.accent)
    }
    .font(.caption2)
    .foregroundStyle(StudioPalette.muted)
    .padding(.horizontal, 12)
    .frame(height: 34)
    .background(StudioPalette.chrome)
  }

  private func transportButton(
    _ systemImage: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 10, weight: .semibold))
        .frame(width: 20, height: 20)
    }
    .buttonStyle(.plain)
    .foregroundStyle(StudioPalette.muted)
  }

  private func compactFrameField(label: String, value: String) -> some View {
    HStack(spacing: 4) {
      Text(label)
        .foregroundStyle(StudioPalette.muted)
      Text(value)
        .foregroundStyle(Color.primary)
    }
    .font(.system(size: 8, weight: .medium, design: .monospaced))
    .padding(.horizontal, 6)
    .frame(height: 18)
    .background(StudioPalette.panelInset)
    .clipShape(RoundedRectangle(cornerRadius: 4))
    .overlay {
      RoundedRectangle(cornerRadius: 4)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
  }

  private func insertKeyframe(trackID: UUID, time: Double, value: Double) {
    guard let index = tracks.firstIndex(where: { $0.id == trackID }) else { return }
    selectedTrackID = trackID
    selectedKeyframeID = tracks[index].insertKeyframe(
      time: time,
      value: value,
      duration: duration
    )
    playhead = min(max(time, 0), duration)
    status = "Created keyframe on \(tracks[index].name)"
  }

  private func addKeyframeAtPlayhead() {
    let trackID = selectedTrackID
    insertKeyframe(trackID: trackID, time: playhead, value: 0.5)
  }

  private func deleteSelectedKeyframe() {
    guard let selectedKeyframeID else { return }
    for index in tracks.indices {
      if let keyIndex = tracks[index].keyframes.firstIndex(where: { $0.id == selectedKeyframeID }) {
        tracks[index].keyframes.remove(at: keyIndex)
        self.selectedKeyframeID = nil
        status = "Deleted keyframe from \(tracks[index].name)"
        return
      }
    }
  }

  private func addTrack() {
    let colorIndex = tracks.count
    let track = UIDevTimelineBTrack(
      name: "Motion Row \(nextTrackNumber)",
      colorIndex: colorIndex,
      keyframes: [
        .init(time: 0, value: 0.5),
        .init(time: duration, value: 0.5),
      ]
    )
    tracks.append(track)
    selectedTrackID = track.id
    selectedKeyframeID = nil
    nextTrackNumber += 1
    status = "Added \(track.name)"
  }

  private func togglePlayback() {
    isPlaying.toggle()
    status = isPlaying ? "Playback preview armed" : "Playback preview paused"
  }

  private func resetPreview() {
    tracks = UIDevTimelineBSamples.tracks
    selectedTrackID = tracks[0].id
    selectedKeyframeID = nil
    playhead = 0
    isPlaying = false
    trackSearch = ""
    nextTrackNumber = 1
    status = "Timeline preview reset"
  }

  private func time(at x: CGFloat, width: CGFloat) -> Double {
    min(max(Double(x / max(width, 1)) * duration, 0), duration)
  }

  private func timecode(_ time: Double) -> String {
    let frame = Int((time * 30).rounded())
    return String(format: "%02d:%02d  F%03d", Int(time) / 60, Int(time) % 60, frame)
  }

  private func frame(at time: Double) -> Int {
    min(max(Int((time * Double(framesPerSecond)).rounded()), 0), frameCount)
  }

  private func trackColor(_ index: Int) -> Color {
    let colors = [
      StudioPalette.accent,
      StudioPalette.semanticPart,
      StudioPalette.joint,
      StudioPalette.hardware,
      StudioPalette.sourceModel,
      Color.pink,
    ]
    return colors[index % colors.count]
  }
}

private struct UIDevTimelineBSummaryCanvas: View {
  let keyframeTimes: [Double]
  let duration: Double
  let playhead: Double

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Canvas { context, size in
          for tick in 0...24 {
            let x = size.width * CGFloat(tick) / 24
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(
              path,
              with: .color(Color.white.opacity(tick.isMultiple(of: 3) ? 0.10 : 0.045)),
              lineWidth: 1
            )
          }
        }

        ForEach(Array(keyframeTimes.enumerated()), id: \.offset) { _, time in
          Image(systemName: "diamond.fill")
            .font(.system(size: 6, weight: .bold))
            .foregroundStyle(StudioPalette.muted)
            .position(
              x: proxy.size.width * CGFloat(min(max(time / duration, 0), 1)),
              y: proxy.size.height / 2
            )
        }

        Rectangle()
          .fill(StudioPalette.accent)
          .frame(width: 1)
          .offset(
            x: proxy.size.width * CGFloat(min(max(playhead / duration, 0), 1))
              - proxy.size.width / 2
          )
      }
      .background(Color.black.opacity(0.14))
    }
    .allowsHitTesting(false)
  }
}

private struct UIDevTimelineBTrackCanvas: View {
  let track: UIDevTimelineBTrack
  let variant: UIDevTimelineBVariant
  let duration: Double
  let playhead: Double
  let selectedKeyframeID: UUID?
  let tint: Color
  let selectKeyframe: (UUID) -> Void
  let insertKeyframe: (Double, Double) -> Void

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        backgroundGrid(size: proxy.size)
        connectionPath(size: proxy.size)
          .stroke(
            tint.opacity(variant == .dopeSheet ? 0.50 : 0.88),
            style: StrokeStyle(
              lineWidth: variant == .waypointLanes ? 2.5 : 1.5,
              lineCap: .round,
              lineJoin: .round
            )
          )

        ForEach(track.keyframes) { keyframe in
          keyframeMarker(keyframe, size: proxy.size)
        }

        Rectangle()
          .fill(StudioPalette.accent)
          .frame(width: 1)
          .offset(x: playheadX(width: proxy.size.width) - proxy.size.width / 2)
          .allowsHitTesting(false)
      }
      .contentShape(Rectangle())
      .gesture(
        SpatialTapGesture()
          .onEnded { gesture in
            handleTap(at: gesture.location, size: proxy.size)
          }
      )
    }
  }

  private func backgroundGrid(size: CGSize) -> some View {
    Canvas { context, canvasSize in
      for tick in 0...24 {
        let x = canvasSize.width * CGFloat(tick) / 24
        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: canvasSize.height))
        context.stroke(
          path,
          with: .color(Color.white.opacity(tick.isMultiple(of: 3) ? 0.10 : 0.045)),
          lineWidth: 1
        )
      }

      if variant != .dopeSheet {
        for level in 1...3 {
          let y = canvasSize.height * CGFloat(level) / 4
          var path = Path()
          path.move(to: CGPoint(x: 0, y: y))
          path.addLine(to: CGPoint(x: canvasSize.width, y: y))
          context.stroke(path, with: .color(Color.white.opacity(0.05)), lineWidth: 1)
        }
      }
    }
    .background(Color.black.opacity(0.11))
    .allowsHitTesting(false)
  }

  private func connectionPath(size: CGSize) -> Path {
    let points = track.keyframes.map { point(for: $0, size: size) }
    return Path { path in
      guard let first = points.first else { return }
      path.move(to: first)
      for index in points.indices.dropFirst() {
        let previous = points[index - 1]
        let next = points[index]
        if variant == .motionCurves {
          let controlX = previous.x + (next.x - previous.x) * 0.5
          path.addCurve(
            to: next,
            control1: CGPoint(x: controlX, y: previous.y),
            control2: CGPoint(x: controlX, y: next.y)
          )
        } else {
          path.addLine(to: next)
        }
      }
    }
  }

  private func keyframeMarker(_ keyframe: UIDevTimelineBKeyframe, size: CGSize) -> some View {
    let isSelected = selectedKeyframeID == keyframe.id
    let point = point(for: keyframe, size: size)

    return Image(systemName: variant == .dopeSheet ? "diamond.fill" : "circle.fill")
      .font(.system(size: isSelected ? 12 : 9, weight: .bold))
      .foregroundStyle(isSelected ? Color.white : tint)
      .overlay {
        Image(systemName: variant == .dopeSheet ? "diamond" : "circle")
          .font(.system(size: isSelected ? 12 : 9, weight: .bold))
          .foregroundStyle(isSelected ? tint : Color.black.opacity(0.40))
      }
      .shadow(color: tint.opacity(0.35), radius: isSelected ? 5 : 2)
      .position(point)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }

  private func handleTap(at location: CGPoint, size: CGSize) {
    if let keyframe = track.keyframes.min(by: {
      distance(from: point(for: $0, size: size), to: location)
        < distance(from: point(for: $1, size: size), to: location)
    }), distance(from: point(for: keyframe, size: size), to: location) <= 14 {
      selectKeyframe(keyframe.id)
      return
    }

    insertKeyframe(
      min(max(Double(location.x / max(size.width, 1)), 0), 1),
      min(max(Double(location.y / max(size.height, 1)), 0), 1)
    )
  }

  private func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
    hypot(first.x - second.x, first.y - second.y)
  }

  private func point(for keyframe: UIDevTimelineBKeyframe, size: CGSize) -> CGPoint {
    let normalized = UIDevTimelineBGeometry.normalizedPoint(
      for: keyframe,
      variant: variant,
      duration: duration
    )
    return CGPoint(
      x: normalized.x * size.width,
      y: normalized.y * size.height
    )
  }

  private func playheadX(width: CGFloat) -> CGFloat {
    width * CGFloat(min(max(playhead / duration, 0), 1))
  }
}
