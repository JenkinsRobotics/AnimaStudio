import AppKit
import SwiftUI

/// Resolved renderer input. Preset meaning stays in RealityKitViewport; this
/// adapter only receives explicit chords so all CAD renderers can behave alike
/// without depending on UI/profile types.
public struct CADViewportNavigationConfiguration: Equatable, Sendable {
  public let orbitDragBindings: Set<String>
  public let panDragBindings: Set<String>
  public let preciseZoomDragBindings: Set<String>
  public let orbitMultiplier: Float
  public let panMultiplier: Float
  public let zoomMultiplier: Float
  public let reversesWheelZoom: Bool

  public init(
    orbitDragBindings: Set<String> = ["rightMouse"],
    panDragBindings: Set<String> = ["middleMouse", "controlRightMouse"],
    preciseZoomDragBindings: Set<String> = [],
    orbitMultiplier: Float = 1,
    panMultiplier: Float = 1,
    zoomMultiplier: Float = 0.65,
    reversesWheelZoom: Bool = false
  ) {
    self.orbitDragBindings = orbitDragBindings
    self.panDragBindings = panDragBindings
    self.preciseZoomDragBindings = preciseZoomDragBindings
    self.orbitMultiplier = orbitMultiplier
    self.panMultiplier = panMultiplier
    self.zoomMultiplier = zoomMultiplier
    self.reversesWheelZoom = reversesWheelZoom
  }

  public static let onshape = CADViewportNavigationConfiguration()
}

struct CADMouseInputOverlay: NSViewRepresentable {
  let navigation: CADViewportNavigationConfiguration
  let orbit: (Float, Float) -> Void
  let pan: (Float, Float, Float) -> Void
  let roll: (Float) -> Void
  let zoom: (Float) -> Void
  let frameAll: () -> Void
  let select: (CGPoint, CGSize, Bool) -> Void
  let boxSelect: (CGRect, CGSize, Bool, Bool) -> Void
  let contextMenu: (CGPoint, CGSize) -> Void
  let hover: (CGPoint?, CGSize, Bool) -> Void
  let beginDirectManipulation: (CGPoint, CGSize) -> Bool
  let updateDirectManipulation: (CGSize, CGSize) -> Void
  let endDirectManipulation: () -> Void

  func makeNSView(context: Context) -> InputView {
    let view = InputView()
    update(view)
    return view
  }

  func updateNSView(_ view: InputView, context: Context) { update(view) }

  private func update(_ view: InputView) {
    view.navigation = navigation
    view.orbit = orbit
    view.pan = pan
    view.roll = roll
    view.zoom = zoom
    view.frameAll = frameAll
    view.select = select
    view.boxSelect = boxSelect
    view.contextMenu = contextMenu
    view.hover = hover
    view.beginDirectManipulation = beginDirectManipulation
    view.updateDirectManipulation = updateDirectManipulation
    view.endDirectManipulation = endDirectManipulation
  }

  final class InputView: NSView {
    var navigation = CADViewportNavigationConfiguration.onshape
    var orbit: ((Float, Float) -> Void)?
    var pan: ((Float, Float, Float) -> Void)?
    var roll: ((Float) -> Void)?
    var zoom: ((Float) -> Void)?
    var frameAll: (() -> Void)?
    var select: ((CGPoint, CGSize, Bool) -> Void)?
    var boxSelect: ((CGRect, CGSize, Bool, Bool) -> Void)?
    var contextMenu: ((CGPoint, CGSize) -> Void)?
    var hover: ((CGPoint?, CGSize, Bool) -> Void)?
    var beginDirectManipulation: ((CGPoint, CGSize) -> Bool)?
    var updateDirectManipulation: ((CGSize, CGSize) -> Void)?
    var endDirectManipulation: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var pointerDown: NSPoint?
    private var dragged = false
    private var directlyManipulatesSelection = false
    private var selectionBox: CGRect?
    private var navigationBinding: String?
    private var rightPointerDown: NSPoint?
    private var rightDragged = false

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
      if let trackingArea { removeTrackingArea(trackingArea) }
      let next = NSTrackingArea(
        rect: bounds,
        options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
        owner: self
      )
      addTrackingArea(next)
      trackingArea = next
      super.updateTrackingAreas()
    }

    override func mouseDown(with event: NSEvent) {
      window?.makeFirstResponder(self)
      pointerDown = convert(event.locationInWindow, from: nil)
      dragged = false
      let extendsSelection =
        event.modifierFlags.contains(.shift)
        || event.modifierFlags.contains(.command)
      directlyManipulatesSelection =
        !extendsSelection
        && (pointerDown.map { beginDirectManipulation?($0, bounds.size) ?? false } ?? false)
      selectionBox = nil
    }

    override func mouseMoved(with event: NSEvent) {
      hover?(
        convert(event.locationInWindow, from: nil),
        bounds.size,
        event.modifierFlags.contains(.shift)
      )
    }

    override func mouseExited(with event: NSEvent) {
      hover?(nil, bounds.size, false)
    }

    override func mouseDragged(with event: NSEvent) {
      guard let pointerDown else { return }
      let location = convert(event.locationInWindow, from: nil)
      dragged = dragged || hypot(location.x - pointerDown.x, location.y - pointerDown.y) >= 3
      if directlyManipulatesSelection {
        updateDirectManipulation?(
          CGSize(
            width: location.x - pointerDown.x,
            height: location.y - pointerDown.y),
          bounds.size)
      } else if dragged {
        // Left-button motion is object manipulation or window/crossing
        // selection. It is never camera pan.
        selectionBox = CGRect(
          x: min(pointerDown.x, location.x),
          y: min(pointerDown.y, location.y),
          width: abs(location.x - pointerDown.x),
          height: abs(location.y - pointerDown.y))
        needsDisplay = true
      }
    }

    override func mouseUp(with event: NSEvent) {
      if directlyManipulatesSelection {
        endDirectManipulation?()
      } else if let selectionBox, dragged, let pointerDown {
        let end = convert(event.locationInWindow, from: nil)
        let crossing = end.x < pointerDown.x
        let extendsSelection =
          event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)
        boxSelect?(selectionBox, bounds.size, crossing, extendsSelection)
      } else if !dragged {
        let location = convert(event.locationInWindow, from: nil)
        let extendsSelection =
          event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)
        select?(location, bounds.size, extendsSelection)
      }
      pointerDown = nil
      directlyManipulatesSelection = false
      selectionBox = nil
      needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
      window?.makeFirstResponder(self)
      navigationBinding = dragBinding(button: .right, event: event)
      rightPointerDown = convert(event.locationInWindow, from: nil)
      rightDragged = false
    }

    override func rightMouseDragged(with event: NSEvent) {
      if let start = rightPointerDown {
        let location = convert(event.locationInWindow, from: nil)
        rightDragged =
          rightDragged || hypot(location.x - start.x, location.y - start.y) >= 3
      }
      guard rightDragged else { return }
      applyNavigation(binding: navigationBinding, event: event)
    }

    override func rightMouseUp(with event: NSEvent) {
      if !rightDragged {
        contextMenu?(convert(event.locationInWindow, from: nil), bounds.size)
      }
      navigationBinding = nil
      rightPointerDown = nil
      rightDragged = false
    }

    override func otherMouseDown(with event: NSEvent) {
      window?.makeFirstResponder(self)
      guard event.buttonNumber == 2 else { return }
      if event.clickCount == 2 {
        frameAll?()
        navigationBinding = nil
      } else {
        navigationBinding = dragBinding(button: .middle, event: event)
      }
    }

    override func otherMouseDragged(with event: NSEvent) {
      guard event.buttonNumber == 2 else { return }
      applyNavigation(binding: navigationBinding, event: event)
    }

    override func otherMouseUp(with event: NSEvent) { navigationBinding = nil }

    override func scrollWheel(with event: NSEvent) {
      let direction: Float = navigation.reversesWheelZoom ? -1 : 1
      let normalized: Float
      if event.hasPreciseScrollingDeltas {
        normalized = min(max(Float(event.scrollingDeltaY) * 0.035, -0.45), 0.45)
      } else {
        normalized = event.scrollingDeltaY == 0 ? 0 : (event.scrollingDeltaY > 0 ? 1 : -1)
      }
      // CADCameraState's exponential zoom was calibrated to raw wheel deltas.
      zoom?(normalized * direction * navigation.zoomMultiplier * 86)
    }

    override func draw(_ dirtyRect: NSRect) {
      super.draw(dirtyRect)
      guard let selectionBox, selectionBox.width >= 1, selectionBox.height >= 1 else { return }
      let crossing = pointerDown.map { selectionBox.minX < $0.x } ?? false
      let color = crossing ? NSColor.systemYellow : NSColor.systemBlue
      color.withAlphaComponent(0.12).setFill()
      NSBezierPath(rect: selectionBox).fill()
      color.withAlphaComponent(0.9).setStroke()
      let border = NSBezierPath(rect: selectionBox)
      border.lineWidth = 1
      if crossing { border.setLineDash([5, 4], count: 2, phase: 0) }
      border.stroke()
    }

    override func keyDown(with event: NSEvent) {
      if event.charactersIgnoringModifiers?.lowercased() == "f" {
        frameAll?()
        return
      }
      let stepDegrees: Float = event.modifierFlags.contains(.shift) ? 90 : 15
      let calibratedDelta = stepDegrees * .pi / 180 / 0.006
      switch event.keyCode {
      case 123: orbit?(calibratedDelta, 0)  // left
      case 124: orbit?(-calibratedDelta, 0)  // right
      case 125: orbit?(0, calibratedDelta)  // down
      case 126: orbit?(0, -calibratedDelta)  // up
      default: super.keyDown(with: event)
      }
    }

    private enum MouseButton { case right, middle }

    private func dragBinding(button: MouseButton, event: NSEvent) -> String {
      let control = event.modifierFlags.contains(.control)
      let shift = event.modifierFlags.contains(.shift)
      let option = event.modifierFlags.contains(.option)
      switch button {
      case .right:
        if option { return "optionRightMouse" }
        if control { return "controlRightMouse" }
        if shift { return "shiftRightMouse" }
        return "rightMouse"
      case .middle:
        if control && shift { return "controlShiftMiddleMouse" }
        if option { return "optionMiddleMouse" }
        if control { return "controlMiddleMouse" }
        if shift { return "shiftMiddleMouse" }
        return "middleMouse"
      }
    }

    private func applyNavigation(binding: String?, event: NSEvent) {
      guard let binding else { return }
      if navigation.orbitDragBindings.contains(binding) {
        orbit?(
          Float(event.deltaX) * navigation.orbitMultiplier,
          Float(event.deltaY) * navigation.orbitMultiplier)
      } else if navigation.panDragBindings.contains(binding) {
        pan?(
          Float(event.deltaX) * navigation.panMultiplier,
          Float(event.deltaY) * navigation.panMultiplier,
          Float(max(bounds.height, 1)))
      } else if navigation.preciseZoomDragBindings.contains(binding) {
        zoom?(Float(event.deltaY) * navigation.zoomMultiplier * 0.35)
      }
    }
  }
}
