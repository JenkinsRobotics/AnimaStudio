import SwiftUI

enum UIDevTriadHandle: String, CaseIterable, Identifiable, Sendable {
  case center
  case translateX
  case translateY
  case translateZ
  case rotateX
  case rotateY
  case rotateZ

  var id: Self { self }

  var title: String {
    switch self {
    case .center: "Free Move"
    case .translateX: "Translate X"
    case .translateY: "Translate Y"
    case .translateZ: "Translate Z"
    case .rotateX: "Rotate X"
    case .rotateY: "Rotate Y"
    case .rotateZ: "Rotate Z"
    }
  }
}

struct UIDevTriadManipulatorLab: View {
  @State private var handleScale = 1.0
  @State private var strokeWidth = 2.0
  @State private var showsPlanePads = true
  @State private var showsRotationRings = true
  @State private var ghostsRestrictedHandles = true
  @State private var selectedHandle = UIDevTriadHandle.translateX
  @State private var dragValue = 24.0

  var body: some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(minimum: 340), alignment: .top),
        GridItem(.flexible(minimum: 290), alignment: .top),
      ],
      alignment: .leading,
      spacing: 16
    ) {
      previewCard
      tuningCard
      behaviorCard
    }
  }

  private var previewCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      StudioSectionHeader(
        title: "Interactive triad",
        detail: "Hover, select, and drag a handle to review emphasis and feedback."
      )
      Divider()
      UIDevTriadManipulatorPreview(
        handleScale: handleScale,
        strokeWidth: strokeWidth,
        showsPlanePads: showsPlanePads,
        showsRotationRings: showsRotationRings,
        ghostsRestrictedHandles: ghostsRestrictedHandles,
        selectedHandle: $selectedHandle,
        dragValue: $dragValue
      )
      .frame(height: 330)
      HStack {
        Label(selectedHandle.title, systemImage: "cursorarrow.click.2")
          .font(.caption.weight(.semibold))
        Spacer()
        Text(valueReadout)
          .font(.system(.caption, design: .monospaced).weight(.semibold))
          .foregroundStyle(StudioPalette.muted)
      }
      .padding(.horizontal, 10)
      .frame(height: 34)
      .background(StudioPalette.panelInset, in: RoundedRectangle(cornerRadius: 8))
    }
    .studioCardSurface()
  }

  private var tuningCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      StudioSectionHeader(
        title: "Visual tuning",
        detail: "These controls are UI-lab state, not saved project settings."
      )
      Divider()
      slider("Handle scale", value: $handleScale, range: 0.75...1.3, format: "%.2f×")
      slider("Stroke width", value: $strokeWidth, range: 1...4, format: "%.1f pt")
      Toggle("Show plane pads", isOn: $showsPlanePads)
      Toggle("Show rotation rings", isOn: $showsRotationRings)
      Toggle("Ghost restricted motion", isOn: $ghostsRestrictedHandles)
      StudioReadoutRow(title: "Selected Handle", value: selectedHandle.title)
    }
    .studioCardSurface()
  }

  private var behaviorCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      StudioSectionHeader(
        title: "Operator behavior",
        detail: "The visual prototype follows the planned shared DriveTarget interaction."
      )
      Divider()
      behavior("Center ball", "Free screen-plane drag for an unconstrained component.")
      behavior("Axis arrows", "Single-axis translation with a live millimeter readout.")
      behavior("Rotation rings", "Single-axis rotation with a live degree readout.")
      behavior("Plane pads", "Two-axis translation without changing the third axis.")
      behavior(
        "Restricted DOF", "Ghosted and inert, so constraints remain visible and explainable.")
    }
    .studioCardSurface()
  }

  private var valueReadout: String {
    switch selectedHandle {
    case .rotateX, .rotateY, .rotateZ: String(format: "%.1f°", dragValue)
    case .center, .translateX, .translateY, .translateZ:
      String(format: "%.1f mm", dragValue)
    }
  }

  private func slider(
    _ title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    format: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text(title)
          .font(.caption.weight(.medium))
        Spacer()
        Text(String(format: format, value.wrappedValue))
          .font(.system(.caption2, design: .monospaced))
          .foregroundStyle(StudioPalette.muted)
      }
      Slider(value: value, in: range)
    }
  }

  private func behavior(_ title: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 9) {
      Circle()
        .fill(StudioPalette.semanticPart)
        .frame(width: 7, height: 7)
        .padding(.top, 5)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
      }
    }
  }
}

private struct UIDevTriadManipulatorPreview: View {
  let handleScale: Double
  let strokeWidth: Double
  let showsPlanePads: Bool
  let showsRotationRings: Bool
  let ghostsRestrictedHandles: Bool
  @Binding var selectedHandle: UIDevTriadHandle
  @Binding var dragValue: Double

  @State private var hoveredHandle: UIDevTriadHandle?

  var body: some View {
    GeometryReader { proxy in
      let geometry = TriadGeometry(size: proxy.size, scale: handleScale)
      ZStack {
        Canvas { context, _ in
          drawPlanePads(context: &context, geometry: geometry)
          drawRotationRings(context: &context, geometry: geometry)
          drawAxes(context: &context, geometry: geometry)
          drawCenter(context: &context, geometry: geometry)
        }

        ForEach(UIDevTriadHandle.allCases) { handle in
          handleTarget(handle, geometry: geometry)
        }
      }
      .background(StudioPalette.field, in: RoundedRectangle(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(StudioPalette.border, lineWidth: 1)
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Triad manipulator preview")
    }
  }

  private func drawAxes(context: inout GraphicsContext, geometry: TriadGeometry) {
    for axis in TriadAxis.allCases {
      let handle = axis.translationHandle
      let isGhosted = ghostsRestrictedHandles && axis == .y
      let color = axis.color.opacity(isGhosted ? 0.28 : 1)
      let emphasis = selectedHandle == handle || hoveredHandle == handle
      var path = Path()
      path.move(to: geometry.origin)
      path.addLine(to: geometry.endpoint(for: axis))
      context.stroke(
        path,
        with: .color(emphasis ? .orange : color),
        style: StrokeStyle(lineWidth: emphasis ? strokeWidth + 2 : strokeWidth, lineCap: .round)
      )
      context.fill(
        geometry.arrowhead(for: axis),
        with: .color(emphasis ? .orange : color)
      )
    }
  }

  private func drawCenter(context: inout GraphicsContext, geometry: TriadGeometry) {
    let isEmphasized = selectedHandle == .center || hoveredHandle == .center
    let rect = CGRect(
      x: geometry.origin.x - 12,
      y: geometry.origin.y - 12,
      width: 24,
      height: 24
    )
    context.fill(Path(ellipseIn: rect), with: .color(StudioPalette.panel))
    context.stroke(
      Path(ellipseIn: rect),
      with: .color(isEmphasized ? .orange : .white.opacity(0.86)),
      lineWidth: isEmphasized ? strokeWidth + 2 : strokeWidth
    )
  }

  private func drawPlanePads(context: inout GraphicsContext, geometry: TriadGeometry) {
    guard showsPlanePads else { return }
    let pads: [(TriadAxis, TriadAxis, Color)] = [
      (.x, .z, .purple.opacity(0.45)),
      (.x, .y, .yellow.opacity(0.34)),
      (.y, .z, .cyan.opacity(0.34)),
    ]
    for (first, second, color) in pads {
      context.fill(geometry.planePad(first, second), with: .color(color))
      context.stroke(
        geometry.planePad(first, second),
        with: .color(color.opacity(0.9)),
        lineWidth: 1
      )
    }
  }

  private func drawRotationRings(context: inout GraphicsContext, geometry: TriadGeometry) {
    guard showsRotationRings else { return }
    for axis in TriadAxis.allCases {
      let handle = axis.rotationHandle
      let isGhosted = ghostsRestrictedHandles && axis == .y
      let base = axis.color.opacity(isGhosted ? 0.22 : 0.82)
      let emphasis = selectedHandle == handle || hoveredHandle == handle
      context.stroke(
        geometry.rotationRing(for: axis),
        with: .color(emphasis ? .orange : base),
        style: StrokeStyle(lineWidth: emphasis ? strokeWidth + 2 : strokeWidth)
      )
    }
  }

  private func handleTarget(_ handle: UIDevTriadHandle, geometry: TriadGeometry) -> some View {
    let center = geometry.hitCenter(for: handle)
    let isDisabled = ghostsRestrictedHandles && handle == .translateY
    return Circle()
      .fill(.clear)
      .frame(width: 34, height: 34)
      .contentShape(Circle())
      .position(center)
      .onHover { hovering in
        hoveredHandle = hovering ? handle : (hoveredHandle == handle ? nil : hoveredHandle)
      }
      .onTapGesture {
        guard !isDisabled else { return }
        selectedHandle = handle
      }
      .gesture(
        DragGesture(minimumDistance: 2)
          .onChanged { value in
            guard !isDisabled else { return }
            selectedHandle = handle
            dragValue = value.translation.width + value.translation.height
          }
      )
      .help(isDisabled ? "Translate Y is restricted in this sample" : handle.title)
      .accessibilityLabel(handle.title)
      .accessibilityHint(isDisabled ? "Restricted by the sample mate" : "Select and drag")
  }
}

private enum TriadAxis: CaseIterable {
  case x
  case y
  case z

  var color: Color {
    switch self {
    case .x: .red
    case .y: .green
    case .z: .blue
    }
  }

  var translationHandle: UIDevTriadHandle {
    switch self {
    case .x: .translateX
    case .y: .translateY
    case .z: .translateZ
    }
  }

  var rotationHandle: UIDevTriadHandle {
    switch self {
    case .x: .rotateX
    case .y: .rotateY
    case .z: .rotateZ
    }
  }
}

private struct TriadGeometry {
  let size: CGSize
  let scale: Double

  var origin: CGPoint { CGPoint(x: size.width * 0.5, y: size.height * 0.58) }

  func endpoint(for axis: TriadAxis) -> CGPoint {
    let length = 92 * scale
    return switch axis {
    case .x: CGPoint(x: origin.x + length * 0.92, y: origin.y + length * 0.38)
    case .y: CGPoint(x: origin.x - length * 0.86, y: origin.y + length * 0.45)
    case .z: CGPoint(x: origin.x, y: origin.y - length)
    }
  }

  func arrowhead(for axis: TriadAxis) -> Path {
    let end = endpoint(for: axis)
    let vector = CGVector(dx: end.x - origin.x, dy: end.y - origin.y)
    let magnitude = max(hypot(vector.dx, vector.dy), 1)
    let unit = CGVector(dx: vector.dx / magnitude, dy: vector.dy / magnitude)
    let normal = CGVector(dx: -unit.dy, dy: unit.dx)
    let base = CGPoint(x: end.x - unit.dx * 18, y: end.y - unit.dy * 18)
    var path = Path()
    path.move(to: end)
    path.addLine(to: CGPoint(x: base.x + normal.dx * 8, y: base.y + normal.dy * 8))
    path.addLine(to: CGPoint(x: base.x - normal.dx * 8, y: base.y - normal.dy * 8))
    path.closeSubpath()
    return path
  }

  func planePad(_ first: TriadAxis, _ second: TriadAxis) -> Path {
    let a = unitVector(for: first, length: 28 * scale)
    let b = unitVector(for: second, length: 28 * scale)
    let start = CGPoint(
      x: origin.x + a.dx * 0.45 + b.dx * 0.45, y: origin.y + a.dy * 0.45 + b.dy * 0.45)
    var path = Path()
    path.move(to: start)
    path.addLine(to: CGPoint(x: start.x + a.dx, y: start.y + a.dy))
    path.addLine(to: CGPoint(x: start.x + a.dx + b.dx, y: start.y + a.dy + b.dy))
    path.addLine(to: CGPoint(x: start.x + b.dx, y: start.y + b.dy))
    path.closeSubpath()
    return path
  }

  func rotationRing(for axis: TriadAxis) -> Path {
    let radius = 46 * scale
    let rect = CGRect(
      x: origin.x - radius,
      y: origin.y - radius * 0.42,
      width: radius * 2,
      height: radius * 0.84
    )
    let angle: CGFloat =
      switch axis {
      case .x: -0.48
      case .y: 0.48
      case .z: 0
      }
    let transform = CGAffineTransform(translationX: origin.x, y: origin.y)
      .rotated(by: angle)
      .translatedBy(x: -origin.x, y: -origin.y)
    return Path(ellipseIn: rect).applying(transform)
  }

  func hitCenter(for handle: UIDevTriadHandle) -> CGPoint {
    switch handle {
    case .center: origin
    case .translateX: endpoint(for: .x)
    case .translateY: endpoint(for: .y)
    case .translateZ: endpoint(for: .z)
    case .rotateX: pointOnRing(axis: .x)
    case .rotateY: pointOnRing(axis: .y)
    case .rotateZ: pointOnRing(axis: .z)
    }
  }

  private func pointOnRing(axis: TriadAxis) -> CGPoint {
    let radius = 46 * scale
    return switch axis {
    case .x: CGPoint(x: origin.x + radius * 0.78, y: origin.y - radius * 0.25)
    case .y: CGPoint(x: origin.x - radius * 0.78, y: origin.y - radius * 0.25)
    case .z: CGPoint(x: origin.x, y: origin.y + radius * 0.42)
    }
  }

  private func unitVector(for axis: TriadAxis, length: Double) -> CGVector {
    let end = endpoint(for: axis)
    let vector = CGVector(dx: end.x - origin.x, dy: end.y - origin.y)
    let magnitude = max(hypot(vector.dx, vector.dy), 1)
    return CGVector(dx: vector.dx / magnitude * length, dy: vector.dy / magnitude * length)
  }
}
