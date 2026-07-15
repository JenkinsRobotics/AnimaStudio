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
