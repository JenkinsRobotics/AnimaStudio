import AnimaCore
import RealityKitViewport
import SwiftUI

struct MatePlacementSession: Equatable {
  var preferredPartID: PartID?
  var sourceCandidate: MateConnectorCandidate?

  var stepNumber: Int { sourceCandidate == nil ? 1 : 2 }

  var title: String {
    sourceCandidate == nil ? "Select the moving component connector" : "Select the fixed connector"
  }

  var detail: String {
    if let sourceCandidate {
      return "\(sourceCandidate.displayName) will move and align to your second selection."
    }
    return "Choose an orange face center, edge midpoint, corner, axis, or origin marker."
  }
}

struct MatePlacementOverlay: View {
  let session: MatePlacementSession
  let cancel: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Text("\(session.stepNumber)")
        .font(.headline.monospacedDigit())
        .foregroundStyle(.white)
        .frame(width: 30, height: 30)
        .background(StudioPalette.joint, in: Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text(session.title)
          .font(.callout.weight(.semibold))
        Text(session.detail)
          .font(.caption)
          .foregroundStyle(StudioPalette.muted)
          .lineLimit(2)
      }

      Button("Cancel", role: .cancel, action: cancel)
        .buttonStyle(.bordered)
        .keyboardShortcut(.cancelAction)
    }
    .padding(10)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11))
    .overlay {
      RoundedRectangle(cornerRadius: 11)
        .stroke(StudioPalette.joint.opacity(0.72), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Revolute mate placement, step \(session.stepNumber)")
  }
}
