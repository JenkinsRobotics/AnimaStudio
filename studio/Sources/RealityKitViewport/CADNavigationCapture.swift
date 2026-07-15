import AppKit
import SwiftUI

public enum PreviewNavigationProfile: String, CaseIterable, Hashable, Sendable {
  case onshape
  case solidWorks

  public var displayName: String {
    switch self {
    case .onshape: "Onshape"
    case .solidWorks: "SolidWorks"
    }
  }
}

enum CADNavigationAction: Equatable {
  case orbit(deltaX: CGFloat, deltaY: CGFloat)
  case pan(deltaX: CGFloat, deltaY: CGFloat)
  case zoom(delta: CGFloat)
}

enum CADNavigationMouseButton {
  case right
  case middle
  case scroll
  case trackpadPan
  case magnify
}

struct CADNavigationInput {
  let button: CADNavigationMouseButton
  let deltaX: CGFloat
  let deltaY: CGFloat
  let isControlDown: Bool
  let isShiftDown: Bool
}

enum CADNavigationMapping {
  static func action(
    for input: CADNavigationInput,
    profile: PreviewNavigationProfile
  ) -> CADNavigationAction? {
    switch input.button {
    case .scroll, .magnify:
      return .zoom(delta: input.deltaY)
    case .trackpadPan:
      return .pan(deltaX: input.deltaX, deltaY: input.deltaY)
    case .right:
      guard profile == .onshape else { return nil }
      return input.isControlDown
        ? .pan(deltaX: input.deltaX, deltaY: input.deltaY)
        : .orbit(deltaX: input.deltaX, deltaY: input.deltaY)
    case .middle:
      switch profile {
      case .onshape:
        return .pan(deltaX: input.deltaX, deltaY: input.deltaY)
      case .solidWorks:
        if input.isShiftDown {
          return .zoom(delta: input.deltaY)
        }
        if input.isControlDown {
          return .pan(deltaX: input.deltaX, deltaY: input.deltaY)
        }
        return .orbit(deltaX: input.deltaX, deltaY: input.deltaY)
      }
    }
  }
}

struct CADNavigationCapture: NSViewRepresentable {
  let profile: PreviewNavigationProfile
  let onAction: (CADNavigationAction) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(profile: profile, onAction: onAction)
  }

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    context.coordinator.observedView = view
    context.coordinator.installMonitor()
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.profile = profile
    context.coordinator.onAction = onAction
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.removeMonitor()
  }

  @MainActor
  final class Coordinator {
    weak var observedView: NSView?
    var profile: PreviewNavigationProfile
    var onAction: (CADNavigationAction) -> Void
    private var eventMonitor: Any?

    init(
      profile: PreviewNavigationProfile,
      onAction: @escaping (CADNavigationAction) -> Void
    ) {
      self.profile = profile
      self.onAction = onAction
    }

    func installMonitor() {
      guard eventMonitor == nil else { return }
      eventMonitor = NSEvent.addLocalMonitorForEvents(
        matching: [.rightMouseDragged, .otherMouseDragged, .scrollWheel, .magnify]
      ) { [weak self] event in
        guard let self,
          let observedView,
          event.window === observedView.window,
          observedView.bounds.contains(observedView.convert(event.locationInWindow, from: nil)),
          let input = self.input(from: event),
          let action = CADNavigationMapping.action(for: input, profile: self.profile)
        else { return event }

        self.onAction(action)
        return nil
      }
    }

    func removeMonitor() {
      if let eventMonitor {
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
      }
    }

    private func input(from event: NSEvent) -> CADNavigationInput? {
      let button: CADNavigationMouseButton
      switch event.type {
      case .rightMouseDragged:
        button = .right
      case .otherMouseDragged where event.buttonNumber == 2:
        button = .middle
      case .scrollWheel:
        button = event.hasPreciseScrollingDeltas ? .trackpadPan : .scroll
      case .magnify:
        button = .magnify
      default:
        return nil
      }

      let deltaX = event.type == .scrollWheel ? event.scrollingDeltaX : event.deltaX
      let deltaY: CGFloat =
        switch event.type {
        case .scrollWheel: event.scrollingDeltaY
        case .magnify: event.magnification * 40
        default: event.deltaY
        }
      return CADNavigationInput(
        button: button,
        deltaX: deltaX,
        deltaY: deltaY,
        isControlDown: event.modifierFlags.contains(.control),
        isShiftDown: event.modifierFlags.contains(.shift)
      )
    }
  }
}
