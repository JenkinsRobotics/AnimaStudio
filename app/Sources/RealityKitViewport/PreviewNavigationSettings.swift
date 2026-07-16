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
  case shiftRightMouse
  case optionRightMouse
  case middleMouse
  case controlRightMouse
  case controlMiddleMouse
  case shiftMiddleMouse
  case optionMiddleMouse

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .rightMouse: "Right Mouse Drag"
    case .shiftRightMouse: "Shift + Right Mouse Drag"
    case .optionRightMouse: "Option + Right Mouse Drag"
    case .middleMouse: "Middle Mouse Drag"
    case .controlRightMouse: "Control + Right Mouse Drag"
    case .controlMiddleMouse: "Control + Middle Mouse Drag"
    case .shiftMiddleMouse: "Shift + Middle Mouse Drag"
    case .optionMiddleMouse: "Option + Middle Mouse Drag"
    }
  }
}

public struct PreviewNavigationProfileSummary: Equatable, Sendable {
  public let orbit: String
  public let pan: String
  public let zoom: String
  public let special: String

  public init(orbit: String, pan: String, zoom: String, special: String) {
    self.orbit = orbit
    self.pan = pan
    self.zoom = zoom
    self.special = special
  }
}

extension PreviewNavigationProfile {
  public func summary(
    customMapping: CustomNavigationMapping = CustomNavigationMapping()
  ) -> PreviewNavigationProfileSummary {
    switch self {
    case .default, .solidWorks:
      PreviewNavigationProfileSummary(
        orbit: "Middle drag",
        pan: "Option + middle drag",
        zoom: "Scroll wheel",
        special: "Shift + middle drag — precise zoom"
      )
    case .onshape:
      PreviewNavigationProfileSummary(
        orbit: "Right drag",
        pan: "Middle drag",
        zoom: "Scroll wheel",
        special: "Option + click — select through"
      )
    case .fusion360:
      PreviewNavigationProfileSummary(
        orbit: "Shift + middle drag",
        pan: "Middle drag",
        zoom: "Scroll wheel",
        special: "Double middle click — zoom to fit"
      )
    case .custom:
      PreviewNavigationProfileSummary(
        orbit: customMapping.rotateDrag.title,
        pan: customMapping.panDrag.title,
        zoom: "Scroll wheel",
        special: "\(customMapping.preciseZoomDrag.title) — precise zoom"
      )
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
  public let preciseZoomDrag: NavigationDragBinding

  public init(
    rotateDrag: NavigationDragBinding = .rightMouse,
    panDrag: NavigationDragBinding = .middleMouse,
    preciseZoomDrag: NavigationDragBinding = .shiftMiddleMouse
  ) {
    self.rotateDrag = rotateDrag
    let resolvedPan =
      panDrag == rotateDrag
      ? NavigationDragBinding.allCases.first { $0 != rotateDrag } ?? .middleMouse
      : panDrag
    self.panDrag = resolvedPan
    self.preciseZoomDrag =
      [rotateDrag, resolvedPan].contains(preciseZoomDrag)
      ? NavigationDragBinding.allCases.first {
        $0 != rotateDrag && $0 != resolvedPan
      } ?? .shiftMiddleMouse
      : preciseZoomDrag
  }
}
