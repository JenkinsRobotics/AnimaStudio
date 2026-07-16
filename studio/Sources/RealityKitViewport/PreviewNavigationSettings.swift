public enum PreviewNavigationProfile: String, CaseIterable, Identifiable, Sendable {
  case `default`
  case solidWorks
  case onshape
  case fusion360
  case custom

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .default: "Default"
    case .solidWorks: "SolidWorks"
    case .onshape: "Onshape"
    case .fusion360: "Fusion 360"
    case .custom: "Custom"
    }
  }
}

public enum NavigationDragBinding: String, CaseIterable, Identifiable, Sendable {
  case rightMouse
  case middleMouse
  case controlRightMouse
  case controlMiddleMouse
  case shiftMiddleMouse

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .rightMouse: "Right Mouse Drag"
    case .middleMouse: "Middle Mouse Drag"
    case .controlRightMouse: "Control + Right Mouse Drag"
    case .controlMiddleMouse: "Control + Middle Mouse Drag"
    case .shiftMiddleMouse: "Shift + Middle Mouse Drag"
    }
  }
}

/// User-adjustable pointer response. The presets keep navigation predictable
/// across mouse profiles while still letting an operator tune each motion
/// independently. Zoom intentionally defaults one step below the other axes.
public enum PreviewNavigationSpeed: String, CaseIterable, Identifiable, Sendable {
  case slow
  case reduced
  case standard
  case fast
  case veryFast

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .slow: "Slow"
    case .reduced: "Reduced"
    case .standard: "Standard"
    case .fast: "Fast"
    case .veryFast: "Very Fast"
    }
  }

  public var multiplier: Double {
    switch self {
    case .slow: 0.4
    case .reduced: 0.65
    case .standard: 1
    case .fast: 1.35
    case .veryFast: 1.75
    }
  }
}

public struct PreviewNavigationSensitivity: Equatable, Sendable {
  public let orbit: PreviewNavigationSpeed
  public let pan: PreviewNavigationSpeed
  public let zoom: PreviewNavigationSpeed

  public init(
    orbit: PreviewNavigationSpeed = .standard,
    pan: PreviewNavigationSpeed = .standard,
    zoom: PreviewNavigationSpeed = .reduced
  ) {
    self.orbit = orbit
    self.pan = pan
    self.zoom = zoom
  }
}

public struct CustomNavigationMapping: Equatable, Sendable {
  public let rotateDrag: NavigationDragBinding
  public let panDrag: NavigationDragBinding

  public init(
    rotateDrag: NavigationDragBinding = .rightMouse,
    panDrag: NavigationDragBinding = .middleMouse
  ) {
    self.rotateDrag = rotateDrag
    self.panDrag =
      panDrag == rotateDrag
      ? NavigationDragBinding.allCases.first { $0 != rotateDrag } ?? .middleMouse
      : panDrag
  }
}
