import RealityKitViewport
import SwiftUI

struct ViewportViewCube: View {
  @State private var hoverLocation: CGPoint?

  let orientation: PreviewCameraOrientation
  let onSelectDirection: (PreviewCameraDirection) -> Void
  let onNudge: (_ horizontalRadians: Float, _ verticalRadians: Float) -> Void

  var body: some View {
    VStack(spacing: 1) {
      nudgeButton(
        systemImage: "triangle.fill",
        label: "Rotate view up",
        horizontalRadians: 0,
        verticalRadians: incrementRadians
      )

      HStack(spacing: 1) {
        nudgeButton(
          systemImage: "triangle.fill",
          label: "Rotate view left",
          rotationDegrees: -90,
          horizontalRadians: -incrementRadians,
          verticalRadians: 0
        )

        cube

        nudgeButton(
          systemImage: "triangle.fill",
          label: "Rotate view right",
          rotationDegrees: 90,
          horizontalRadians: incrementRadians,
          verticalRadians: 0
        )
      }

      nudgeButton(
        systemImage: "triangle.fill",
        label: "Rotate view down",
        rotationDegrees: 180,
        horizontalRadians: 0,
        verticalRadians: -incrementRadians
      )
    }
    .padding(7)
    .background(StudioPalette.panel.opacity(0.88), in: RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(StudioPalette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.28), radius: 7, y: 3)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("View cube")
  }

  private var cube: some View {
    Canvas { context, size in
      let faces = ViewCubeGeometry.projectedFaces(in: size, orientation: orientation)
      for face in faces {
        let path = polygonPath(face.points)

        context.fill(path, with: .color(fillColor(for: face.face)))
        context.stroke(path, with: .color(.white.opacity(0.58)), lineWidth: 1)

        var labelContext = context
        labelContext.clip(to: path)
        labelContext.translateBy(x: face.center.x, y: face.center.y)
        labelContext.rotate(
          by: .radians(Double(ViewCubeGeometry.labelAngleRadians(for: face)))
        )
        let label = Text(face.face.title)
          .font(.system(size: 8, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
        labelContext.draw(label, at: .zero)
      }

      if let hoverLocation,
        let target = ViewCubeGeometry.hitTarget(
          at: hoverLocation,
          in: size,
          orientation: orientation
        )
      {
        drawHighlight(target.highlight, in: &context)
      }

      drawAxes(in: &context, size: size)
    }
    .frame(width: Self.cubeSize.width, height: Self.cubeSize.height)
    .contentShape(Rectangle())
    .gesture(
      SpatialTapGesture()
        .onEnded { value in
          guard
            let target = ViewCubeGeometry.hitTarget(
              at: value.location,
              in: Self.cubeSize,
              orientation: orientation
            )
          else { return }
          onSelectDirection(target.direction)
        }
    )
    .onContinuousHover { phase in
      switch phase {
      case .active(let location): hoverLocation = location
      case .ended: hoverLocation = nil
      }
    }
    .help("Click a face, edge, or corner to orient the camera")
  }

  private func drawAxes(
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    let axes = ViewCubeGeometry.projectedAxes(in: size, orientation: orientation)
    guard let origin = axes.first?.origin else { return }

    for axis in axes {
      var path = Path()
      path.move(to: axis.origin)
      path.addLine(to: axis.endpoint)
      let color = axisColor(axis.axis)
      context.stroke(path, with: .color(color), lineWidth: 1.6)

      let label = Text(axis.axis.title)
        .font(.system(size: 10, weight: .heavy, design: .rounded))
        .foregroundStyle(color)
      context.draw(label, at: axisLabelPosition(for: axis))
    }

    let originMarker = Path(
      ellipseIn: CGRect(x: origin.x - 2, y: origin.y - 2, width: 4, height: 4)
    )
    context.fill(originMarker, with: .color(.white.opacity(0.9)))
  }

  private func drawHighlight(
    _ highlight: ViewCubeHighlight,
    in context: inout GraphicsContext
  ) {
    let accent = Color.cyan
    switch highlight {
    case .face(let points):
      let path = polygonPath(points)
      context.fill(path, with: .color(accent.opacity(0.34)))
      context.stroke(path, with: .color(accent), lineWidth: 2)
    case .edge(let start, let end):
      var path = Path()
      path.move(to: start)
      path.addLine(to: end)
      context.stroke(path, with: .color(accent), lineWidth: 4)
    case .corner(let point):
      let path = Path(
        ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
      )
      context.fill(path, with: .color(accent.opacity(0.8)))
      context.stroke(path, with: .color(.white), lineWidth: 1)
    }
  }

  private func polygonPath(_ points: [CGPoint]) -> Path {
    var path = Path()
    guard let first = points.first else { return path }
    path.move(to: first)
    for point in points.dropFirst() {
      path.addLine(to: point)
    }
    path.closeSubpath()
    return path
  }

  private func axisColor(_ axis: ViewCubeAxis) -> Color {
    switch axis {
    case .x: .red
    case .y: .green
    case .z: .blue
    }
  }

  private func axisLabelPosition(for axis: ProjectedViewCubeAxis) -> CGPoint {
    let deltaX = axis.endpoint.x - axis.origin.x
    let deltaY = axis.endpoint.y - axis.origin.y
    let length = max(hypot(deltaX, deltaY), 0.001)
    return CGPoint(
      x: axis.endpoint.x + deltaX / length * 6,
      y: axis.endpoint.y + deltaY / length * 6
    )
  }

  private func nudgeButton(
    systemImage: String,
    label: String,
    rotationDegrees: Double = 0,
    horizontalRadians: Float,
    verticalRadians: Float
  ) -> some View {
    Button {
      onNudge(horizontalRadians, verticalRadians)
    } label: {
      Image(systemName: systemImage)
        .font(.system(size: 8, weight: .semibold))
        .rotationEffect(.degrees(rotationDegrees))
        .frame(width: 17, height: 17)
        .foregroundStyle(StudioPalette.muted)
    }
    .buttonStyle(.plain)
    .help("\(label) by 15°")
    .accessibilityLabel(label)
  }

  private func fillColor(for face: ViewCubeFace) -> Color {
    switch face {
    case .top, .bottom: Color(red: 0.34, green: 0.46, blue: 0.59)
    case .front, .back: Color(red: 0.27, green: 0.36, blue: 0.47)
    case .right, .left: Color(red: 0.22, green: 0.29, blue: 0.38)
    }
  }

  private var incrementRadians: Float { .pi / 12 }

  private static let cubeSize = CGSize(width: 92, height: 92)
}
