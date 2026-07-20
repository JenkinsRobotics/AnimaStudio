// Small shared state so the Home header can drive Home's own sheets.
import Observation

@MainActor @Observable final class HomeState {
  static let shared = HomeState()
  var showNewCharacter = false
}
