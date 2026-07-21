import AppKit
import SwiftUI

struct CADMouseInputOverlay: NSViewRepresentable {
  let orbit: (Float, Float) -> Void
  let pan: (Float, Float, Float) -> Void
  let roll: (Float) -> Void
  let zoom: (Float) -> Void
  let select: () -> Void

  func makeNSView(context: Context) -> InputView {
    let view = InputView()
    update(view)
    return view
  }

  func updateNSView(_ view: InputView, context: Context) { update(view) }

  private func update(_ view: InputView) {
    view.orbit = orbit
    view.pan = pan
    view.roll = roll
    view.zoom = zoom
    view.select = select
  }

  final class InputView: NSView {
    var orbit: ((Float, Float) -> Void)?
    var pan: ((Float, Float, Float) -> Void)?
    var roll: ((Float) -> Void)?
    var zoom: ((Float) -> Void)?
    var select: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var pointerDown: NSPoint?
    private var dragged = false

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
      if let trackingArea { removeTrackingArea(trackingArea) }
      let next = NSTrackingArea(
        rect: bounds,
        options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
        owner: self
      )
      addTrackingArea(next)
      trackingArea = next
      super.updateTrackingAreas()
    }

    override func mouseDown(with event: NSEvent) {
      pointerDown = convert(event.locationInWindow, from: nil)
      dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
      dragged = true
      pan?(Float(event.deltaX), Float(event.deltaY), Float(max(bounds.height, 1)))
    }

    override func mouseUp(with event: NSEvent) {
      if !dragged { select?() }
      pointerDown = nil
    }

    override func rightMouseDragged(with event: NSEvent) {
      if event.modifierFlags.contains(.shift) {
        roll?(Float(event.deltaX))
      } else {
        orbit?(Float(event.deltaX), Float(event.deltaY))
      }
    }

    override func otherMouseDragged(with event: NSEvent) {
      if event.modifierFlags.contains(.shift) {
        roll?(Float(event.deltaX))
      } else {
        pan?(Float(event.deltaX), Float(event.deltaY), Float(max(bounds.height, 1)))
      }
    }

    override func scrollWheel(with event: NSEvent) { zoom?(Float(event.scrollingDeltaY)) }
  }
}
