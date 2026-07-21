import AppKit
import GeomKit
import Metal
import QuartzCore
import RealityKit
import SwiftUI


struct CADInputOverlay: NSViewRepresentable {
  let orbit: (Float, Float) -> Void
  let pan: (Float, Float, Float) -> Void
  let roll: (Float) -> Void
  let zoom: (Float) -> Void
  let select: () -> Void

  init(
    orbit: @escaping (Float, Float) -> Void,
    pan: @escaping (Float, Float, Float) -> Void,
    roll: @escaping (Float) -> Void,
    zoom: @escaping (Float) -> Void,
    select: @escaping () -> Void = {}
  ) {
    self.orbit = orbit
    self.pan = pan
    self.roll = roll
    self.zoom = zoom
    self.select = select
  }

  func makeNSView(context: Context) -> CADInputNSView {
    let view = CADInputNSView()
    view.orbit = orbit
    view.pan = pan
    view.roll = roll
    view.zoom = zoom
    view.select = select
    return view
  }

  func updateNSView(_ view: CADInputNSView, context: Context) {
    view.orbit = orbit
    view.pan = pan
    view.roll = roll
    view.zoom = zoom
    view.select = select
  }
}

final class CADInputNSView: NSView {
  var orbit: ((Float, Float) -> Void)?
  var pan: ((Float, Float, Float) -> Void)?
  var roll: ((Float) -> Void)?
  var zoom: ((Float) -> Void)?
  var select: (() -> Void)?
  private var lastPoint: NSPoint?
  private var dragged = false
  private var mode: Mode = .none
  enum Mode { case none, orbit, pan, roll }

  override var acceptsFirstResponder: Bool { true }
  override func hitTest(_ point: NSPoint) -> NSView? { self }
  override func rightMouseDown(with event: NSEvent) {
    lastPoint = convert(event.locationInWindow, from: nil)
    mode = event.modifierFlags.contains(.shift) ? .roll : .orbit
  }
  override func otherMouseDown(with event: NSEvent) {
    lastPoint = convert(event.locationInWindow, from: nil)
    mode = .pan
  }
  override func mouseDown(with event: NSEvent) {
    lastPoint = convert(event.locationInWindow, from: nil)
    dragged = false
    mode = event.modifierFlags.contains(.shift) ? .pan : .none
  }
  override func rightMouseDragged(with event: NSEvent) { drag(event) }
  override func otherMouseDragged(with event: NSEvent) { drag(event) }
  override func mouseDragged(with event: NSEvent) { drag(event) }
  override func rightMouseUp(with event: NSEvent) {
    mode = .none
    lastPoint = nil
  }
  override func otherMouseUp(with event: NSEvent) {
    mode = .none
    lastPoint = nil
  }
  override func mouseUp(with event: NSEvent) {
    if mode == .none, !dragged { select?() }
    mode = .none
    lastPoint = nil
  }
  override func scrollWheel(with event: NSEvent) { zoom?(Float(event.scrollingDeltaY)) }

  private func drag(_ event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard let lastPoint else {
      self.lastPoint = point
      return
    }
    let dx = Float(point.x - lastPoint.x)
    let dy = Float(point.y - lastPoint.y)
    if hypot(dx, dy) > 2 { dragged = true }
    switch mode {
    case .orbit: orbit?(dx, dy)
    case .pan: pan?(dx, dy, Float(bounds.height))
    case .roll: roll?(dx)
    case .none: break
    }
    self.lastPoint = point
  }
}
