import RealityKitViewport
import SwiftUI

struct ViewportViewCube: View {
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

      axisLegend
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
        var path = Path()
        if let first = face.points.first {
          path.move(to: first)
          for point in face.points.dropFirst() {
            path.addLine(to: point)
          }
          path.closeSubpath()
        }

        context.fill(path, with: .color(fillColor(for: face.face)))
        context.stroke(path, with: .color(.white.opacity(0.58)), lineWidth: 1)

        let label = Text(face.face.title)
          .font(.system(size: 8, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
        context.draw(label, at: face.center)
      }
    }
    .frame(width: 82, height: 82)
    .contentShape(Rectangle())
    .gesture(
      SpatialTapGesture()
        .onEnded { value in
          guard
            let direction = ViewCubeGeometry.hitDirection(
              at: value.location,
              in: CGSize(width: 82, height: 82),
              orientation: orientation
            )
          else { return }
          onSelectDirection(direction)
        }
    )
    .help("Click a face, edge, or corner to orient the camera")
  }

  private var axisLegend: some View {
    HStack(spacing: 8) {
      axisLabel("X", color: .red)
      axisLabel("Y", color: .green)
      axisLabel("Z", color: .blue)
    }
    .font(.caption2.bold())
  }

  private func axisLabel(_ title: String, color: Color) -> some View {
    Text(title)
      .foregroundStyle(color)
      .accessibilityLabel("\(title) axis")
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
}
