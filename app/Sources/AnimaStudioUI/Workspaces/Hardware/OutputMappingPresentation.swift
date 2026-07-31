import AnimaCoreClient
import Foundation

enum HardwareOutputTargetKind: String, Equatable, Sendable {
  case rotation
  case translation
  case parameter

  var unitLabel: String {
    switch self {
    case .rotation: "deg"
    case .translation: "mm"
    case .parameter: "value"
    }
  }

  func displayValue(fromNative value: Double) -> Double {
    switch self {
    case .rotation: value * 180 / .pi
    case .translation: value * 1_000
    case .parameter: value
    }
  }

  func nativeValue(fromDisplay value: Double) -> Double {
    switch self {
    case .rotation: value * .pi / 180
    case .translation: value / 1_000
    case .parameter: value
    }
  }
}

struct HardwareOutputTargetOption: Identifiable, Equatable, Sendable {
  let path: String
  let label: String
  let kind: HardwareOutputTargetKind
  let suggestedValueAtZero: Double
  let suggestedValueAtOne: Double

  var id: String { path }

  static func catalog(
    mates: [AnimaCoreJointSummary],
    chain: AnimaCoreKinematicChainSummary?,
    parameters: [AnimaCoreParameterSummary]
  ) -> [Self] {
    var optionsByPath: [String: Self] = [:]

    for mate in mates {
      for degreeOfFreedom in mate.degreesOfFreedom {
        guard let minimum = degreeOfFreedom.minimum,
          let maximum = degreeOfFreedom.maximum,
          minimum.isFinite,
          maximum.isFinite,
          minimum != maximum
        else { continue }
        let kind: HardwareOutputTargetKind =
          degreeOfFreedom.kind == .rotation ? .rotation : .translation
        optionsByPath[degreeOfFreedom.path] = Self(
          path: degreeOfFreedom.path,
          label: "\(mate.name) · \(degreeOfFreedom.path.split(separator: ".").last ?? "")",
          kind: kind,
          suggestedValueAtZero: kind.displayValue(fromNative: minimum),
          suggestedValueAtOne: kind.displayValue(fromNative: maximum)
        )
      }
    }

    if let chain {
      for joint in chain.joints {
        guard let minimum = joint.minimum,
          let maximum = joint.maximum,
          minimum.isFinite,
          maximum.isFinite,
          minimum != maximum
        else { continue }
        let kind: HardwareOutputTargetKind =
          joint.jointType == .revolute ? .rotation : .translation
        optionsByPath[joint.degreeOfFreedomPath] = Self(
          path: joint.degreeOfFreedomPath,
          label: "\(chain.name) · \(joint.name)",
          kind: kind,
          suggestedValueAtZero: kind.displayValue(fromNative: minimum),
          suggestedValueAtOne: kind.displayValue(fromNative: maximum)
        )
      }
    }

    for parameter in parameters {
      optionsByPath[parameter.name] = Self(
        path: parameter.name,
        label: parameter.description.isEmpty
          ? parameter.name
          : "\(parameter.name) · \(parameter.description)",
        kind: .parameter,
        suggestedValueAtZero: 0,
        suggestedValueAtOne: 1
      )
    }

    return optionsByPath.values.sorted {
      if $0.kind.rawValue == $1.kind.rawValue { return $0.label < $1.label }
      return $0.kind.rawValue < $1.kind.rawValue
    }
  }
}

enum HardwareOutputMappingValidationError: LocalizedError, Equatable {
  case noTarget
  case targetUnavailable(String)
  case invalidChannel
  case duplicateChannel(Int)
  case invalidRange

  var errorDescription: String? {
    switch self {
    case .noTarget:
      "Choose a bounded DOF or parameter."
    case .targetUnavailable(let path):
      "The target ‘\(path)’ is no longer available."
    case .invalidChannel:
      "Channel must be zero or greater."
    case .duplicateChannel(let channel):
      "Channel \(channel) is already assigned."
    case .invalidRange:
      "The channel endpoints must be finite and different."
    }
  }
}

struct HardwareOutputMappingDraft: Equatable, Sendable {
  var targetPath: String
  var channel: Int
  var valueAtZero: Double
  var valueAtOne: Double

  init(
    target: HardwareOutputTargetOption,
    channel: Int
  ) {
    targetPath = target.path
    self.channel = channel
    valueAtZero = target.suggestedValueAtZero
    valueAtOne = target.suggestedValueAtOne
  }

  init(
    mapping: AnimaCoreOutputSummary,
    target: HardwareOutputTargetOption
  ) {
    targetPath = mapping.targetPath
    channel = mapping.channel
    valueAtZero = target.kind.displayValue(fromNative: mapping.valueAtZero)
    valueAtOne = target.kind.displayValue(fromNative: mapping.valueAtOne)
  }

  mutating func select(_ target: HardwareOutputTargetOption) {
    targetPath = target.path
    valueAtZero = target.suggestedValueAtZero
    valueAtOne = target.suggestedValueAtOne
  }

  mutating func reverse() {
    swap(&valueAtZero, &valueAtOne)
  }

  func validatedNativeValues(
    targets: [HardwareOutputTargetOption],
    existingMappings: [AnimaCoreOutputSummary],
    originalChannel: Int?
  ) throws -> (target: HardwareOutputTargetOption, valueAtZero: Double, valueAtOne: Double) {
    guard !targetPath.isEmpty else {
      throw HardwareOutputMappingValidationError.noTarget
    }
    guard let target = targets.first(where: { $0.path == targetPath }) else {
      throw HardwareOutputMappingValidationError.targetUnavailable(targetPath)
    }
    guard channel >= 0 else {
      throw HardwareOutputMappingValidationError.invalidChannel
    }
    if existingMappings.contains(where: {
      $0.channel == channel && $0.channel != originalChannel
    }) {
      throw HardwareOutputMappingValidationError.duplicateChannel(channel)
    }
    guard valueAtZero.isFinite, valueAtOne.isFinite, valueAtZero != valueAtOne else {
      throw HardwareOutputMappingValidationError.invalidRange
    }
    return (
      target,
      target.kind.nativeValue(fromDisplay: valueAtZero),
      target.kind.nativeValue(fromDisplay: valueAtOne)
    )
  }
}
