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

enum NavigatorRowState: String, CaseIterable, Hashable {
  case locked
  case hidden
  case suppressed
  case grounded

  var systemImage: String {
    switch self {
    case .locked: "lock.fill"
    case .hidden: "eye.slash.fill"
    case .suppressed: "nosign"
    case .grounded: "pin.fill"
    }
  }

  var help: String {
    switch self {
    case .locked: "Locked — editor changes are blocked"
    case .hidden: "Hidden in the viewport"
    case .suppressed: "Suppressed — excluded from the AnimaCore solve"
    case .grounded: "Grounded — fixed at its authored rest transform"
    }
  }

  var tint: Color {
    switch self {
    case .locked, .hidden: StudioPalette.muted
    case .suppressed: .orange
    case .grounded: StudioPalette.accent
    }
  }
}

struct PartTreeRow: View {
  let title: String
  let role: NavigatorNodeRole
  var detail: String?
  var isLocked = false
  var lockHelp = "Locked items cannot be edited or reorganized."
  var states: [NavigatorRowState] = []

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
      ForEach(effectiveStates, id: \.self) { state in
        Image(systemName: state.systemImage)
          .font(.caption2)
          .foregroundStyle(state.tint)
          .help(state == .locked ? lockHelp : state.help)
      }
    }
    .help(isLocked ? "\(role.title), locked" : role.title)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(title)
    .accessibilityValue(accessibilityValue)
  }

  private var effectiveStates: [NavigatorRowState] {
    var result = states
    if isLocked, !result.contains(.locked) { result.insert(.locked, at: 0) }
    return NavigatorRowState.allCases.filter(result.contains)
  }

  private var accessibilityValue: String {
    guard !effectiveStates.isEmpty else { return role.title }
    return "\(role.title), \(effectiveStates.map(\.rawValue).joined(separator: ", "))"
  }
}
