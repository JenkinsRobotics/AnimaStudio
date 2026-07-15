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
}
