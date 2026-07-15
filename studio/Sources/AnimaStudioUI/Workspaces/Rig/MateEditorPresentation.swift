import Foundation

/// UI-only description of a mate freedom while AnimaCore's typed-mate
/// contract is still in flight. The identifiers and order deliberately mirror
/// the shared Python/format contract recorded in Kinematics.md.
enum MateEditorMotionKind: String, Sendable {
  case translation
  case rotation

  var unitLabel: String {
    switch self {
    case .translation: "mm"
    case .rotation: "deg"
    }
  }

  func countLabel(_ count: Int) -> String {
    switch self {
    case .translation: count == 1 ? "1 translational" : "\(count) translational"
    case .rotation: count == 1 ? "1 rotational" : "\(count) rotational"
    }
  }
}

enum MateEditorAxis: String, CaseIterable, Identifiable, Sendable {
  case x = "X"
  case y = "Y"
  case z = "Z"

  var id: Self { self }
}

enum MateEditorDegreeOfFreedom: String, Identifiable, Sendable {
  case translationX = "translation_x"
  case translationY = "translation_y"
  case translationZ = "translation_z"
  case rotationX = "rotation_x"
  case rotationY = "rotation_y"
  case rotationZ = "rotation_z"

  var id: Self { self }

  var motionKind: MateEditorMotionKind {
    switch self {
    case .translationX, .translationY, .translationZ: .translation
    case .rotationX, .rotationY, .rotationZ: .rotation
    }
  }

  var axis: MateEditorAxis {
    switch self {
    case .translationX, .rotationX: .x
    case .translationY, .rotationY: .y
    case .translationZ, .rotationZ: .z
    }
  }

  var title: String {
    "\(motionKind == .translation ? "Translation" : "Rotation") \(axis.rawValue)"
  }

  var unitLabel: String { motionKind.unitLabel }
}

extension MateCreationToolKind {
  /// Stable template order shared with the runtime contract.
  var editorDegreesOfFreedom: [MateEditorDegreeOfFreedom] {
    switch self {
    case .fastened:
      []
    case .parallel:
      [.translationX, .translationY, .translationZ, .rotationZ]
    case .slider:
      [.translationZ]
    case .revolute:
      [.rotationZ]
    case .cylindrical:
      [.rotationZ, .translationZ]
    case .pinSlot:
      [.rotationZ, .translationX]
    case .planar:
      [.translationX, .translationY, .rotationZ]
    case .ball:
      [.rotationX, .rotationY, .rotationZ]
    }
  }

  var supportsLimits: Bool { !editorDegreesOfFreedom.isEmpty }

  /// Offsets act on constrained freedoms; they shift the as-mated pose and do
  /// not consume one of the freedoms allowed by the mate kind.
  var offsetTranslationAxes: [MateEditorAxis] {
    let freeAxes = Set(
      editorDegreesOfFreedom
        .filter { $0.motionKind == .translation }
        .map(\.axis)
    )
    return MateEditorAxis.allCases.filter { !freeAxes.contains($0) }
  }

  var offsetRotationAxes: [MateEditorAxis] {
    let freeAxes = Set(
      editorDegreesOfFreedom
        .filter { $0.motionKind == .rotation }
        .map(\.axis)
    )
    return MateEditorAxis.allCases.filter { !freeAxes.contains($0) }
  }

  var editorDofSummary: String {
    guard !editorDegreesOfFreedom.isEmpty else { return "0 — fully bonded" }

    var runs: [(kind: MateEditorMotionKind, count: Int)] = []
    for freedom in editorDegreesOfFreedom {
      if runs.last?.kind == freedom.motionKind {
        runs[runs.count - 1].count += 1
      } else {
        runs.append((freedom.motionKind, 1))
      }
    }
    return runs.map { $0.kind.countLabel($0.count) }.joined(separator: " + ")
  }
}
