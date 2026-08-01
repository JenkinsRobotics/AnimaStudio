import Foundation

/// Renderer-neutral viewport navigation bindings (which drags orbit,
/// pan, and zoom) — pure data shared by every renderer host.
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
