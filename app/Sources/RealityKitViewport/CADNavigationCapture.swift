import AppKit
import SwiftUI

enum CADNavigationAction: Equatable {
  case orbit(deltaX: CGFloat, deltaY: CGFloat)
  case pan(deltaX: CGFloat, deltaY: CGFloat)
  case zoom(delta: CGFloat)
  case preciseZoom(delta: CGFloat)
}

extension CADNavigationAction {
  func scaled(by sensitivity: PreviewNavigationSensitivity) -> Self {
    switch self {
    case .orbit(let deltaX, let deltaY):
      let multiplier = CGFloat(sensitivity.orbit.multiplier)
      return .orbit(deltaX: deltaX * multiplier, deltaY: deltaY * multiplier)
    case .pan(let deltaX, let deltaY):
      let multiplier = CGFloat(sensitivity.pan.multiplier)
      return .pan(deltaX: deltaX * multiplier, deltaY: deltaY * multiplier)
    case .zoom(let delta):
      return .zoom(delta: delta * CGFloat(sensitivity.zoom.multiplier))
    case .preciseZoom(let delta):
      return .preciseZoom(delta: delta * CGFloat(sensitivity.zoom.multiplier) * 0.35)
    }
  }
}

enum CADNavigationMouseButton: Equatable {
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
  let isOptionDown: Bool
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
      case .onshape:
        return .orbit(deltaX: input.deltaX, deltaY: input.deltaY)
      case .custom:
        return customAction(for: input, mapping: customMapping)
      case .default, .solidWorks, .fusion360:
        return nil
      }
    case .middle:
      switch profile {
      case .onshape:
        return .pan(deltaX: input.deltaX, deltaY: input.deltaY)
      case .default, .solidWorks:
        if input.isShiftDown {
          return .preciseZoom(delta: input.deltaY)
        }
        if input.isOptionDown {
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
    if binding == mapping.preciseZoomDrag {
      return .preciseZoom(delta: input.deltaY)
    }
    return nil
  }

  private static func dragBinding(
    for input: CADNavigationInput
  ) -> NavigationDragBinding? {
    switch input.button {
    case .right where input.isOptionDown:
      .optionRightMouse
    case .right where input.isControlDown:
      .controlRightMouse
    case .right where input.isShiftDown:
      .shiftRightMouse
    case .right:
      .rightMouse
    case .middle where input.isOptionDown:
      .optionMiddleMouse
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

enum CADZoomInputNormalizer {
  /// One normalized unit is one conventional wheel notch. Camera application
  /// turns that into approximately 13% distance change at Standard speed.
  static func normalizedDelta(
    rawDeltaY: CGFloat,
    hasPreciseScrollingDeltas: Bool,
    isReversed: Bool
  ) -> CGFloat {
    guard rawDeltaY != 0 else { return 0 }
    let direction: CGFloat = isReversed ? -1 : 1
    if hasPreciseScrollingDeltas {
      return min(max(rawDeltaY * 0.035, -0.45), 0.45) * direction
    }
    return (rawDeltaY > 0 ? 1 : -1) * direction
  }
}

enum CADRightMouseEnd: Equatable {
  case openContextMenu
  case suppressContextMenu
  case ignored
}

struct CADRightMouseSequence: Equatable {
  private(set) var start: CGPoint?
  private(set) var didDrag = false

  mutating func begin(at point: CGPoint) {
    start = point
    didDrag = false
  }

  @discardableResult
  mutating func drag(to point: CGPoint, threshold: CGFloat = 3) -> Bool {
    guard let start else { return false }
    if hypot(point.x - start.x, point.y - start.y) >= threshold {
      didDrag = true
    }
    return didDrag
  }

  mutating func end() -> CADRightMouseEnd {
    guard start != nil else { return .ignored }
    let result: CADRightMouseEnd = didDrag ? .suppressContextMenu : .openContextMenu
    start = nil
    didDrag = false
    return result
  }
}

enum CADScrollInputClassifier {
  static func button(
    hasPreciseScrollingDeltas: Bool,
    hasGesturePhase: Bool,
    hasMomentumPhase: Bool,
    deltaX: CGFloat
  ) -> CADNavigationMouseButton {
    guard hasPreciseScrollingDeltas else { return .scroll }
    if hasGesturePhase || hasMomentumPhase || abs(deltaX) > 0.01 {
      return .trackpadPan
    }
    return .scroll
  }
}

/// Captures Escape ahead of the window's default cancel handling so a
/// selected sub-object feature clears before component selection does
/// (staged Escape, matching the workspace's existing conventions). The
/// event is consumed only when `shouldConsume` returns true; otherwise it
/// flows to the regular `onExitCommand`/cancel-action handling untouched.
struct ViewportEscapeCapture: NSViewRepresentable {
  /// Called with whether a text control is currently editing; returns
  /// true when the Escape press was handled and must not propagate.
  let shouldConsume: (_ isTextInputActive: Bool) -> Bool

  func makeCoordinator() -> Coordinator {
    Coordinator(shouldConsume: shouldConsume)
  }

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    context.coordinator.observedView = view
    context.coordinator.installMonitor()
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.shouldConsume = shouldConsume
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.removeMonitor()
  }

  @MainActor
  final class Coordinator {
    private static let escapeKeyCode: UInt16 = 53

    weak var observedView: NSView?
    var shouldConsume: (_ isTextInputActive: Bool) -> Bool
    private var eventMonitor: Any?

    init(shouldConsume: @escaping (_ isTextInputActive: Bool) -> Bool) {
      self.shouldConsume = shouldConsume
    }

    func installMonitor() {
      guard eventMonitor == nil else { return }
      eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
        [weak self] event in
        guard let self,
          let observedView,
          event.keyCode == Self.escapeKeyCode,
          event.window === observedView.window
        else { return event }

        let isTextInputActive = observedView.window?.firstResponder is NSText
        return self.shouldConsume(isTextInputActive) ? nil : event
      }
    }

    func removeMonitor() {
      if let eventMonitor {
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
      }
    }
  }
}

struct CADNavigationCapture: NSViewRepresentable {
  let profile: PreviewNavigationProfile
  let customMapping: CustomNavigationMapping
  let sensitivity: PreviewNavigationSensitivity
  let reversesWheelZoom: Bool
  let onAction: (CADNavigationAction) -> Void
  let onFrameAll: () -> Void
  let onContextMenuRequest: (CGPoint) -> Void
  let onBackgroundClick: (CGPoint, Bool) -> Void

  init(
    profile: PreviewNavigationProfile,
    customMapping: CustomNavigationMapping = CustomNavigationMapping(),
    sensitivity: PreviewNavigationSensitivity = PreviewNavigationSensitivity(),
    reversesWheelZoom: Bool = false,
    onAction: @escaping (CADNavigationAction) -> Void,
    onFrameAll: @escaping () -> Void = {},
    onContextMenuRequest: @escaping (CGPoint) -> Void = { _ in },
    onBackgroundClick: @escaping (CGPoint, Bool) -> Void = { _, _ in }
  ) {
    self.profile = profile
    self.customMapping = customMapping
    self.sensitivity = sensitivity
    self.reversesWheelZoom = reversesWheelZoom
    self.onAction = onAction
    self.onFrameAll = onFrameAll
    self.onContextMenuRequest = onContextMenuRequest
    self.onBackgroundClick = onBackgroundClick
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      profile: profile,
      customMapping: customMapping,
      sensitivity: sensitivity,
      reversesWheelZoom: reversesWheelZoom,
      onAction: onAction,
      onFrameAll: onFrameAll,
      onContextMenuRequest: onContextMenuRequest,
      onBackgroundClick: onBackgroundClick
    )
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
    context.coordinator.sensitivity = sensitivity
    context.coordinator.reversesWheelZoom = reversesWheelZoom
    context.coordinator.onAction = onAction
    context.coordinator.onFrameAll = onFrameAll
    context.coordinator.onContextMenuRequest = onContextMenuRequest
    context.coordinator.onBackgroundClick = onBackgroundClick
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.removeMonitor()
  }

  @MainActor
  final class Coordinator {
    weak var observedView: NSView?
    var profile: PreviewNavigationProfile
    var customMapping: CustomNavigationMapping
    var sensitivity: PreviewNavigationSensitivity
    var reversesWheelZoom: Bool
    var onAction: (CADNavigationAction) -> Void
    var onFrameAll: () -> Void
    var onContextMenuRequest: (CGPoint) -> Void
    var onBackgroundClick: (CGPoint, Bool) -> Void
    private var eventMonitor: Any?
    private var rightMouseSequence = CADRightMouseSequence()
    private var leftMouseStart: CGPoint?

    init(
      profile: PreviewNavigationProfile,
      customMapping: CustomNavigationMapping,
      sensitivity: PreviewNavigationSensitivity,
      reversesWheelZoom: Bool,
      onAction: @escaping (CADNavigationAction) -> Void,
      onFrameAll: @escaping () -> Void,
      onContextMenuRequest: @escaping (CGPoint) -> Void,
      onBackgroundClick: @escaping (CGPoint, Bool) -> Void
    ) {
      self.profile = profile
      self.customMapping = customMapping
      self.sensitivity = sensitivity
      self.reversesWheelZoom = reversesWheelZoom
      self.onAction = onAction
      self.onFrameAll = onFrameAll
      self.onContextMenuRequest = onContextMenuRequest
      self.onBackgroundClick = onBackgroundClick
    }

    func installMonitor() {
      guard eventMonitor == nil else { return }
      eventMonitor = NSEvent.addLocalMonitorForEvents(
        matching: [
          .leftMouseDown, .leftMouseDragged, .leftMouseUp,
          .rightMouseDown, .rightMouseDragged, .rightMouseUp,
          .otherMouseDown, .otherMouseDragged, .otherMouseUp,
          .scrollWheel, .magnify,
        ]
      ) { [weak self] event in
        guard let self,
          let observedView,
          event.window === observedView.window,
          observedView.bounds.contains(observedView.convert(event.locationInWindow, from: nil))
        else { return event }
        return self.handle(event, in: observedView)
      }
    }

    func removeMonitor() {
      if let eventMonitor {
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
      }
    }

    private func handle(_ event: NSEvent, in observedView: NSView) -> NSEvent? {
      let localPoint = observedView.convert(event.locationInWindow, from: nil)
      switch event.type {
      case .leftMouseDown:
        leftMouseStart = localPoint
        return event
      case .leftMouseDragged:
        return event
      case .leftMouseUp:
        defer { leftMouseStart = nil }
        guard let leftMouseStart,
          hypot(localPoint.x - leftMouseStart.x, localPoint.y - leftMouseStart.y) < 3
        else { return event }
        onBackgroundClick(
          CGPoint(x: localPoint.x, y: observedView.bounds.height - localPoint.y),
          event.modifierFlags.contains(.option)
        )
        return event
      case .rightMouseDown:
        rightMouseSequence.begin(at: localPoint)
        return nil
      case .rightMouseDragged:
        if rightMouseSequence.drag(to: localPoint) {
          emitNavigationAction(for: event)
        }
        return nil
      case .rightMouseUp:
        if rightMouseSequence.end() == .openContextMenu {
          onContextMenuRequest(
            CGPoint(x: localPoint.x, y: observedView.bounds.height - localPoint.y)
          )
        }
        return nil
      case .otherMouseDown where event.buttonNumber == 2:
        if event.clickCount == 2 {
          onFrameAll()
        }
        return nil
      case .otherMouseDragged where event.buttonNumber == 2:
        emitNavigationAction(for: event)
        return nil
      case .otherMouseUp where event.buttonNumber == 2:
        return nil
      case .scrollWheel, .magnify:
        emitNavigationAction(for: event)
        return nil
      default:
        return event
      }
    }

    private func emitNavigationAction(for event: NSEvent) {
      guard let input = input(from: event),
        let action = CADNavigationMapping.action(
          for: input,
          profile: profile,
          customMapping: customMapping
        )
      else { return }
      onAction(action.scaled(by: sensitivity))
    }

    private func input(from event: NSEvent) -> CADNavigationInput? {
      let button: CADNavigationMouseButton
      switch event.type {
      case .rightMouseDragged:
        button = .right
      case .otherMouseDragged where event.buttonNumber == 2:
        button = .middle
      case .scrollWheel:
        button = CADScrollInputClassifier.button(
          hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas,
          hasGesturePhase: event.phase != [],
          hasMomentumPhase: event.momentumPhase != [],
          deltaX: event.scrollingDeltaX
        )
      case .magnify:
        button = .magnify
      default:
        return nil
      }

      let deltaX = event.type == .scrollWheel ? event.scrollingDeltaX : event.deltaX
      let deltaY: CGFloat =
        switch event.type {
        case .scrollWheel:
          button == .trackpadPan
            ? event.scrollingDeltaY
            : CADZoomInputNormalizer.normalizedDelta(
              rawDeltaY: event.scrollingDeltaY,
              hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas,
              isReversed: reversesWheelZoom
            )
        case .magnify: min(max(event.magnification * 4, -0.45), 0.45)
        default: event.deltaY
        }
      return CADNavigationInput(
        button: button,
        deltaX: deltaX,
        deltaY: deltaY,
        isControlDown: event.modifierFlags.contains(.control),
        isShiftDown: event.modifierFlags.contains(.shift),
        isOptionDown: event.modifierFlags.contains(.option)
      )
    }
  }
}
