import SwiftUI

enum NavigatorNodeRole {
  case sourceAssembly
  case sourceNode
  case semanticPart
  case joint
  case hardwareOutput

  var title: String {
    switch self {
    case .sourceAssembly: "Source assembly"
    case .sourceNode: "Source model node"
    case .semanticPart: "Semantic part"
    case .joint: "Joint"
    case .hardwareOutput: "Hardware output"
    }
  }

  var systemImage: String {
    switch self {
    case .sourceAssembly: "square.3.layers.3d"
    case .sourceNode: "cube"
    case .semanticPart: "shippingbox"
    case .joint: "rotate.3d"
    case .hardwareOutput: "powerplug"
    }
  }

  var tint: Color {
    switch self {
    case .sourceAssembly, .sourceNode: StudioPalette.sourceModel
    case .semanticPart: StudioPalette.semanticPart
    case .joint: StudioPalette.joint
    case .hardwareOutput: StudioPalette.hardware
    }
  }
}

struct PartTreeRow: View {
  let title: String
  let role: NavigatorNodeRole
  var detail: String?
  var isSourceLocked = false

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: role.systemImage)
        .foregroundStyle(role.tint)
        .frame(width: 16)
      Text(title)
        .lineLimit(1)
      Spacer(minLength: 6)
      if let detail {
        Text(detail)
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
      }
      if isSourceLocked {
        Image(systemName: "lock.fill")
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
          .help(
            "Source-owned hierarchy. Map it into the semantic rig before editing relationships.")
      }
    }
    .help(isSourceLocked ? "\(role.title), read-only source hierarchy" : role.title)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(title)
    .accessibilityValue(isSourceLocked ? "\(role.title), read only" : role.title)
  }
}
