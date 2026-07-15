import AppKit
import SwiftUI

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
    profile: PreviewNavigationProfile,
    customMapping: CustomNavigationMapping = CustomNavigationMapping()
  ) -> CADNavigationAction? {
    switch input.button {
    case .scroll, .magnify:
      return .zoom(delta: input.deltaY)
    case .trackpadPan:
      return .pan(deltaX: input.deltaX, deltaY: input.deltaY)
    case .right:
      switch profile {
      case .default, .onshape:
        return .orbit(deltaX: input.deltaX, deltaY: input.deltaY)
      case .custom:
        return customAction(for: input, mapping: customMapping)
      case .solidWorks, .fusion360:
        return nil
      }
    case .middle:
      switch profile {
      case .default, .onshape:
        return .pan(deltaX: input.deltaX, deltaY: input.deltaY)
      case .solidWorks:
        if input.isControlDown || input.isShiftDown {
          return .pan(deltaX: input.deltaX, deltaY: input.deltaY)
        }
        return .orbit(deltaX: input.deltaX, deltaY: input.deltaY)
      case .fusion360:
        return input.isShiftDown
          ? .orbit(deltaX: input.deltaX, deltaY: input.deltaY)
          : .pan(deltaX: input.deltaX, deltaY: input.deltaY)
      case .custom:
        return customAction(for: input, mapping: customMapping)
      }
    }
  }

  private static func customAction(
    for input: CADNavigationInput,
    mapping: CustomNavigationMapping
  ) -> CADNavigationAction? {
    guard let binding = dragBinding(for: input) else { return nil }
    if binding == mapping.rotateDrag {
      return .orbit(deltaX: input.deltaX, deltaY: input.deltaY)
    }
    if binding == mapping.panDrag {
      return .pan(deltaX: input.deltaX, deltaY: input.deltaY)
    }
    return nil
  }

  private static func dragBinding(
    for input: CADNavigationInput
  ) -> NavigationDragBinding? {
    switch input.button {
    case .right where input.isControlDown:
      .controlRightMouse
    case .right:
      .rightMouse
    case .middle where input.isControlDown:
      .controlMiddleMouse
    case .middle where input.isShiftDown:
      .shiftMiddleMouse
    case .middle:
      .middleMouse
    case .scroll, .trackpadPan, .magnify:
      nil
    }
  }
}

struct CADNavigationCapture: NSViewRepresentable {
  let profile: PreviewNavigationProfile
  let customMapping: CustomNavigationMapping
  let onAction: (CADNavigationAction) -> Void

  init(
    profile: PreviewNavigationProfile,
    customMapping: CustomNavigationMapping = CustomNavigationMapping(),
    onAction: @escaping (CADNavigationAction) -> Void
  ) {
    self.profile = profile
    self.customMapping = customMapping
    self.onAction = onAction
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(profile: profile, customMapping: customMapping, onAction: onAction)
  }

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    context.coordinator.observedView = view
    context.coordinator.installMonitor()
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.profile = profile
    context.coordinator.customMapping = customMapping
    context.coordinator.onAction = onAction
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.removeMonitor()
  }

  @MainActor
  final class Coordinator {
    weak var observedView: NSView?
    var profile: PreviewNavigationProfile
    var customMapping: CustomNavigationMapping
    var onAction: (CADNavigationAction) -> Void
    private var eventMonitor: Any?

    init(
      profile: PreviewNavigationProfile,
      customMapping: CustomNavigationMapping,
      onAction: @escaping (CADNavigationAction) -> Void
    ) {
      self.profile = profile
      self.customMapping = customMapping
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
          let action = CADNavigationMapping.action(
            for: input,
            profile: self.profile,
            customMapping: self.customMapping
          )
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
