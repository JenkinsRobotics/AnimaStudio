// Move controls shown after double-clicking a body — directional arrows that
// drag the part in the camera plane, plus a Copy affordance.
import SwiftUI

struct MoveGizmo: View {
  var onNudge: (CGFloat, CGFloat) -> Void = { _, _ in }
  var onDismiss: () -> Void = {}

  @State private var drag: CGSize = .zero

  var body: some View {
    ZStack {
      arrow("arrow.up", dx: 0, dy: -1).offset(y: -46)
      arrow("arrow.down", dx: 0, dy: 1).offset(y: 46)
      arrow("arrow.left", dx: -1, dy: 0).offset(x: -46)
      arrow("arrow.right", dx: 1, dy: 0).offset(x: 46)
      arrow("arrow.up.left", dx: -1, dy: -1).offset(x: -33, y: -33)
      arrow("arrow.up.right", dx: 1, dy: -1).offset(x: 33, y: -33)

      // Centre handle — free drag in the camera plane.
      Circle()
        .fill(.regularMaterial)
        .overlay(Circle().stroke(UI.accent, lineWidth: 1.5))
        .overlay(Circle().fill(UI.accent).frame(width: 6, height: 6))
        .frame(width: 24, height: 24)
        .gesture(
          DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
              onNudge(value.translation.width - drag.width, value.translation.height - drag.height)
              drag = value.translation
            }
            .onEnded { _ in drag = .zero })

      Text("Copy")
        .font(.system(size: 10, weight: .medium)).foregroundStyle(UI.text)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(UI.stroke, lineWidth: 1))
        .offset(y: 74)
    }
    .frame(width: 160, height: 160)
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { onDismiss() }
  }

  private func arrow(_ icon: String, dx: CGFloat, dy: CGFloat) -> some View {
    Image(systemName: icon)
      .font(.system(size: 12, weight: .bold))
      .foregroundStyle(UI.text)
      .frame(width: 26, height: 26)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
      .overlay(RoundedRectangle(cornerRadius: 7).stroke(UI.stroke, lineWidth: 1))
      .gesture(
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
          .onChanged { value in
            let step = value.translation.width * dx + value.translation.height * dy
            let moved = step - (drag.width * dx + drag.height * dy)
            onNudge(dx * moved, dy * moved)
            drag = value.translation
          }
          .onEnded { _ in drag = .zero })
  }
}
