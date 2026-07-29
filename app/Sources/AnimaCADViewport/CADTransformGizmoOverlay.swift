import SwiftUI

/// Renderer-independent direct-manipulation surface. The GPU adapters draw the
/// selected frame and transformed mesh; this overlay owns hit testing and turns
/// pointer deltas into edits of AnimaCore's part rest transform.
struct CADTransformGizmoOverlay: View {
  let transform: CADPartRestTransform
  let label: String
  let isEnabled: Bool
  let metersPerPoint: Double
  let onChange: @MainActor @Sendable (CADPartRestTransform) -> Void

  var body: some View {
    ZStack {
      translationHandle(.x, color: .red)
        .offset(x: 48)
      translationHandle(.y, color: .green)
        .rotationEffect(.degrees(-90))
        .offset(y: -48)
      translationHandle(.z, color: .blue)
        .rotationEffect(.degrees(135))
        .offset(x: -36, y: 36)

      rotationHandle(.x, color: .red)
        .offset(x: -68, y: -48)
      rotationHandle(.y, color: .green)
        .offset(x: 70, y: -42)
      rotationHandle(.z, color: .blue)
        .offset(x: 66, y: 54)

      Circle()
        .fill(.ultraThickMaterial)
        .frame(width: 24, height: 24)
        .overlay {
          Image(systemName: isEnabled ? "move.3d" : "lock.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(isEnabled ? .primary : .secondary)
        }
        .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
    }
    .frame(width: 190, height: 190)
    .overlay(alignment: .bottom) {
      Text(isEnabled ? label : "\(label) · fixed")
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThickMaterial, in: Capsule())
        .offset(y: 12)
    }
    .accessibilityElement(children: .contain)
  }

  private func translationHandle(_ axis: CADTransformAxis, color: Color) -> some View {
    CADGizmoDragHandle(
      transform: transform,
      axis: axis,
      operation: .translate,
      subjectLabel: label,
      isEnabled: isEnabled,
      metersPerPoint: metersPerPoint,
      color: color,
      onChange: onChange
    )
  }

  private func rotationHandle(_ axis: CADTransformAxis, color: Color) -> some View {
    CADGizmoDragHandle(
      transform: transform,
      axis: axis,
      operation: .rotate,
      subjectLabel: label,
      isEnabled: isEnabled,
      metersPerPoint: metersPerPoint,
      color: color,
      onChange: onChange
    )
  }
}

private enum CADGizmoOperation {
  case translate
  case rotate
}

private struct CADGizmoDragHandle: View {
  let transform: CADPartRestTransform
  let axis: CADTransformAxis
  let operation: CADGizmoOperation
  let subjectLabel: String
  let isEnabled: Bool
  let metersPerPoint: Double
  let color: Color
  let onChange: @MainActor @Sendable (CADPartRestTransform) -> Void

  @State private var dragStart: CADPartRestTransform?

  var body: some View {
    Group {
      switch operation {
      case .translate:
        HStack(spacing: 0) {
          Capsule()
            .fill(color)
            .frame(width: 70, height: 7)
          Image(systemName: "arrowtriangle.right.fill")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(color)
            .offset(x: -3)
        }
        .frame(width: 90, height: 30)
      case .rotate:
        Image(systemName: "arrow.triangle.2.circlepath")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(color)
          .frame(width: 38, height: 38)
          .background(.ultraThickMaterial, in: Circle())
          .overlay(Circle().stroke(color.opacity(0.7), lineWidth: 1))
      }
    }
    .opacity(isEnabled ? 1 : 0.38)
    .contentShape(Rectangle())
    .gesture(isEnabled ? dragGesture : nil)
    .accessibilityLabel(
      "\(operation == .translate ? "Translate" : "Rotate") \(axis.rawValue.uppercased())"
    )
    .accessibilityHint(isEnabled ? "Drag to edit \(subjectLabel)" : "\(subjectLabel) is fixed")
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 1)
      .onChanged { value in
        let start = dragStart ?? transform
        if dragStart == nil { dragStart = start }
        let scalar = dragScalar(value.translation)
        switch operation {
        case .translate:
          onChange(start.translated(localAxis: axis, distanceMeters: scalar * metersPerPoint))
        case .rotate:
          onChange(start.rotated(localAxis: axis, angleRadians: scalar * 0.008))
        }
      }
      .onEnded { _ in dragStart = nil }
  }

  private func dragScalar(_ translation: CGSize) -> Double {
    switch axis {
    case .x:
      Double(translation.width)
    case .y:
      Double(-translation.height)
    case .z:
      Double((translation.width - translation.height) * 0.5)
    }
  }
}
