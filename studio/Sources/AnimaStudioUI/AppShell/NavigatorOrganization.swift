import AnimaCore
import Foundation

struct NavigatorComponentGroup: Identifiable, Equatable {
  let id: UUID
  var displayName: String
  var componentIDs: [PartID]
  var isLocked: Bool

  init(
    id: UUID = UUID(),
    displayName: String,
    componentIDs: [PartID] = [],
    isLocked: Bool = false
  ) {
    self.id = id
    self.displayName = displayName
    self.componentIDs = componentIDs
    self.isLocked = isLocked
  }
}

enum NavigatorMoveDirection {
  case up
  case down
}

enum NavigatorDragPayload: Equatable, Sendable {
  case component(PartID)
  case componentGroup(UUID)
  case mate(JointID)

  private static let componentPrefix = "anima-component:"
  private static let componentGroupPrefix = "anima-component-group:"
  private static let matePrefix = "anima-mate:"
  static let typeIdentifier = "org.animastudio.navigator-item"

  var itemProvider: NSItemProvider {
    NSItemProvider(item: encodedValue as NSString, typeIdentifier: Self.typeIdentifier)
  }

  var encodedValue: String {
    switch self {
    case .component(let id):
      Self.componentPrefix + id.rawValue.uuidString
    case .componentGroup(let id):
      Self.componentGroupPrefix + id.uuidString
    case .mate(let id):
      Self.matePrefix + id.rawValue
    }
  }

  init?(encodedValue: String) {
    if encodedValue.hasPrefix(Self.componentPrefix),
      let rawID = UUID(uuidString: String(encodedValue.dropFirst(Self.componentPrefix.count)))
    {
      self = .component(PartID(rawValue: rawID))
      return
    }
    if encodedValue.hasPrefix(Self.componentGroupPrefix),
      let rawID = UUID(uuidString: String(encodedValue.dropFirst(Self.componentGroupPrefix.count)))
    {
      self = .componentGroup(rawID)
      return
    }
    if encodedValue.hasPrefix(Self.matePrefix) {
      let rawID = String(encodedValue.dropFirst(Self.matePrefix.count))
      guard !rawID.isEmpty else { return nil }
      self = .mate(JointID(rawValue: rawID))
      return
    }
    return nil
  }
}

enum NavigatorOrdering {
  static func moved<Value: Equatable>(
    _ values: [Value],
    value: Value,
    direction: NavigatorMoveDirection
  ) -> [Value] {
    guard let sourceIndex = values.firstIndex(of: value) else { return values }
    let destinationIndex =
      switch direction {
      case .up: sourceIndex - 1
      case .down: sourceIndex + 1
      }
    guard values.indices.contains(destinationIndex) else { return values }

    var result = values
    result.swapAt(sourceIndex, destinationIndex)
    return result
  }

  static func moving<Value: Equatable>(
    _ values: [Value],
    value: Value,
    before destination: Value
  ) -> [Value] {
    moving(values, value: value, relativeTo: destination, placement: .before)
  }

  static func moving<Value: Equatable>(
    _ values: [Value],
    value: Value,
    relativeTo destination: Value,
    placement: NavigatorRelativePlacement
  ) -> [Value] {
    guard value != destination, values.contains(value), values.contains(destination) else {
      return values
    }

    var result = values
    result.removeAll { $0 == value }
    guard let destinationIndex = result.firstIndex(of: destination) else { return values }
    let insertionIndex = placement == .before ? destinationIndex : destinationIndex + 1
    result.insert(value, at: insertionIndex)
    return result
  }
}

enum NavigatorRelativePlacement {
  case before
  case after
}
