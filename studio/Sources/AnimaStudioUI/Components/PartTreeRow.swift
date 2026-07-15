import SwiftUI

enum NavigatorNodeRole {
  case sourceAssembly
  case sourceNode
  case componentGroup
  case semanticPart
  case joint
  case hardwareOutput

  var title: String {
    switch self {
    case .sourceAssembly: "Source assembly"
    case .sourceNode: "Source model node"
    case .componentGroup: "Component group"
    case .semanticPart: "Semantic part"
    case .joint: "Mate"
    case .hardwareOutput: "Hardware output"
    }
  }

  var systemImage: String {
    switch self {
    case .sourceAssembly: "square.3.layers.3d"
    case .sourceNode: "cube"
    case .componentGroup: "folder.fill"
    case .semanticPart: "shippingbox"
    case .joint: "rotate.3d"
    case .hardwareOutput: "powerplug"
    }
  }

  var tint: Color {
    switch self {
    case .sourceAssembly, .sourceNode: StudioPalette.sourceModel
    case .componentGroup: StudioPalette.accent
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
  var isLocked = false
  var lockHelp = "Locked items cannot be edited or reorganized."

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
      if isLocked {
        Image(systemName: "lock.fill")
          .font(.caption2)
          .foregroundStyle(StudioPalette.muted)
          .help(lockHelp)
      }
    }
    .help(isLocked ? "\(role.title), locked" : role.title)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(title)
    .accessibilityValue(isLocked ? "\(role.title), locked" : role.title)
  }
}
