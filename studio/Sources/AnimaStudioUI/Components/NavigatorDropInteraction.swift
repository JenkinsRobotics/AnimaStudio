import AnimaCore
import Foundation
import SwiftUI

enum NavigatorDropIntent: Equatable {
  case before
  case group
  case after
}

enum NavigatorDropBehavior {
  case component
  case componentGroup
  case mate

  func intent(
    for payload: NavigatorDragPayload,
    verticalPosition: CGFloat,
    rowHeight: CGFloat
  ) -> NavigatorDropIntent? {
    let height = max(rowHeight, 1)
    let position = min(max(verticalPosition / height, 0), 1)

    switch (self, payload) {
    case (.component, .component):
      if position < 0.25 { return .before }
      if position > 0.75 { return .after }
      return .group
    case (.componentGroup, .component):
      return .group
    case (.componentGroup, .componentGroup), (.mate, .mate):
      return position < 0.5 ? .before : .after
    default:
      return nil
    }
  }
}

private struct NavigatorDropHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 24

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

private struct NavigatorDropTargetModifier: ViewModifier {
  @Binding var activePayload: NavigatorDragPayload?
  let behavior: NavigatorDropBehavior
  let onDrop: (NavigatorDragPayload, NavigatorDropIntent) -> Bool
  @State private var activeIntent: NavigatorDropIntent?
  @State private var rowHeight: CGFloat = NavigatorDropHeightKey.defaultValue

  func body(content: Content) -> some View {
    content
      .background {
        GeometryReader { proxy in
          Color.clear.preference(key: NavigatorDropHeightKey.self, value: proxy.size.height)
        }
      }
      .onPreferenceChange(NavigatorDropHeightKey.self) { rowHeight = $0 }
      .overlay(alignment: .top) {
        if activeIntent == .before { insertionLine }
      }
      .overlay {
        if activeIntent == .group { groupTarget }
      }
      .overlay(alignment: .bottom) {
        if activeIntent == .after { insertionLine }
      }
      .onDrop(
        of: [NavigatorDragPayload.typeIdentifier],
        delegate: NavigatorRowDropDelegate(
          activePayload: $activePayload,
          activeIntent: $activeIntent,
          behavior: behavior,
          rowHeight: rowHeight,
          onDrop: onDrop
        )
      )
  }

  private var insertionLine: some View {
    HStack(spacing: 0) {
      Circle()
        .frame(width: 6, height: 6)
      Rectangle()
        .frame(height: 2)
    }
    .foregroundStyle(StudioPalette.accent)
    .shadow(color: .black.opacity(0.35), radius: 1)
    .padding(.horizontal, -4)
    .allowsHitTesting(false)
  }

  private var groupTarget: some View {
    ZStack(alignment: .trailing) {
      RoundedRectangle(cornerRadius: 5)
        .fill(StudioPalette.accent.opacity(0.16))
        .stroke(StudioPalette.accent, lineWidth: 2)

      Label("Group", systemImage: "plus.circle.fill")
        .font(.caption.bold())
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.regularMaterial, in: Capsule())
        .padding(.trailing, 4)
    }
    .allowsHitTesting(false)
  }
}

private struct NavigatorRowDropDelegate: DropDelegate {
  @Binding var activePayload: NavigatorDragPayload?
  @Binding var activeIntent: NavigatorDropIntent?
  let behavior: NavigatorDropBehavior
  let rowHeight: CGFloat
  let onDrop: (NavigatorDragPayload, NavigatorDropIntent) -> Bool

  func validateDrop(info: DropInfo) -> Bool {
    resolvedIntent(for: info) != nil
  }

  func dropEntered(info: DropInfo) {
    activeIntent = resolvedIntent(for: info)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    activeIntent = resolvedIntent(for: info)
    return DropProposal(operation: activeIntent == nil ? .cancel : .move)
  }

  func dropExited(info: DropInfo) {
    activeIntent = nil
  }

  func performDrop(info: DropInfo) -> Bool {
    guard let payload = activePayload, let intent = resolvedIntent(for: info) else {
      activeIntent = nil
      return false
    }
    activeIntent = nil
    activePayload = nil
    return onDrop(payload, intent)
  }

  private func resolvedIntent(for info: DropInfo) -> NavigatorDropIntent? {
    guard let activePayload else { return nil }
    return behavior.intent(
      for: activePayload,
      verticalPosition: info.location.y,
      rowHeight: rowHeight
    )
  }
}

private struct NavigatorTopLevelDropModifier: ViewModifier {
  @Binding var activePayload: NavigatorDragPayload?
  let onDrop: (PartID) -> Bool
  @State private var isTargeted = false

  func body(content: Content) -> some View {
    content
      .overlay {
        if isTargeted {
          RoundedRectangle(cornerRadius: 4)
            .fill(StudioPalette.accent.opacity(0.14))
            .stroke(StudioPalette.accent, lineWidth: 1.5)
            .allowsHitTesting(false)
        }
      }
      .onDrop(of: [NavigatorDragPayload.typeIdentifier], isTargeted: $isTargeted) { _ in
        guard case .component(let id) = activePayload else { return false }
        activePayload = nil
        return onDrop(id)
      }
  }
}

extension View {
  func navigatorDragSource(
    _ payload: NavigatorDragPayload,
    activePayload: Binding<NavigatorDragPayload?>
  ) -> some View {
    onDrag {
      activePayload.wrappedValue = payload
      return payload.itemProvider
    }
  }

  func navigatorDropTarget(
    activePayload: Binding<NavigatorDragPayload?>,
    behavior: NavigatorDropBehavior,
    onDrop: @escaping (NavigatorDragPayload, NavigatorDropIntent) -> Bool
  ) -> some View {
    modifier(
      NavigatorDropTargetModifier(
        activePayload: activePayload,
        behavior: behavior,
        onDrop: onDrop
      )
    )
  }

  func navigatorTopLevelDropTarget(
    activePayload: Binding<NavigatorDragPayload?>,
    onDrop: @escaping (PartID) -> Bool
  ) -> some View {
    modifier(NavigatorTopLevelDropModifier(activePayload: activePayload, onDrop: onDrop))
  }
}
