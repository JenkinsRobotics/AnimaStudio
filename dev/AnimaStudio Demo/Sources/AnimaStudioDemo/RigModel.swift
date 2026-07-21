// Real rig state — the part tree comes from the imported STEP assembly nodes,
// and mates are authored between those actual parts (no mock data).
import GeomKit
import SwiftUI
import simd

enum MateType: String, CaseIterable, Identifiable, Codable {
  case fastened, revolute, slider, cylindrical, planar, ball
  var id: String { rawValue }
  var label: String { rawValue.capitalized }
  var icon: String {
    switch self {
    case .fastened: return "link"
    case .revolute: return "circle.circle"
    case .slider: return "arrow.up.and.down"
    case .cylindrical: return "cylinder.split.1x2"
    case .planar: return "square.stack.3d.up"
    case .ball: return "circle.grid.2x2"
    }
  }
  /// Degrees-of-freedom driven by a single scalar (what the timeline animates).
  var isDriven: Bool { self != .fastened && self != .ball && self != .planar }
  var unit: String { self == .slider || self == .cylindrical ? "mm" : "°" }
}

enum MateAxis: String, CaseIterable, Identifiable, Codable {
  case x = "X", y = "Y", z = "Z"
  var id: String { rawValue }
  var vector: SIMD3<Float> {
    switch self {
    case .x: return [1, 0, 0]
    case .y: return [0, 1, 0]
    case .z: return [0, 0, 1]
    }
  }
}

struct Mate: Identifiable, Codable, Equatable {
  var id = UUID()          // var so Codable actually decodes it (identity must survive save/load)
  var name: String
  var type: MateType
  var parent: PartID       // stable character-part id
  var child: PartID        // stable character-part id
  var axis: MateAxis = .z
  var minValue: Double = -90
  var maxValue: Double = 90
  var value: Double = 0
}

// A flattened row of the character's part list (depth drives indentation).
struct RigPartRow: Identifiable {
  let id: PartID
  let name: String
  let depth: Int
  let faceCount: Int
}

@MainActor @Observable final class RigModel {
  static let shared = RigModel()

  var selectedParts: Set<PartID> = []
  var selectedMateID: UUID?
  // Rig workspace sidebar. Model-owned, not @State, so it survives the
  // float/dock flip that rebuilds the workspace view.
  let rigPanels = PanelStackState(
    order: ["Structure", "Mates"],
    defaults: [], side: .left)

  private var project: ProjectModel { ProjectModel.shared }

  /// Mates belong to the active character.
  var mates: [Mate] {
    get { project.active?.mates ?? [] }
    set { if let i = project.activeIndex { project.characters[i].mates = newValue } }
  }

  var parts: [CharacterPart] { project.active?.parts ?? [] }

  var selectedMate: Mate? {
    get { mates.first { $0.id == selectedMateID } }
    set {
      guard let newValue, let i = mates.firstIndex(where: { $0.id == newValue.id }) else { return }
      mates[i] = newValue
    }
  }

  /// Character parts, indented by their depth in the source asset's node tree.
  var partRows: [RigPartRow] {
    let docs = DemoModel.shared.documentsByName()
    return parts.map { part in
      let doc = docs[part.assetName]
      let depth = doc.map { Self.nodeDepth(part.node, in: $0) } ?? 0
      let faces = doc?.faces.reduce(0) { $0 + ($1.assemblyNode == part.node ? 1 : 0) } ?? 0
      return RigPartRow(id: part.id, name: part.name, depth: depth, faceCount: faces)
    }
  }

  static func nodeDepth(_ node: Int, in doc: GeometryDocument) -> Int {
    var depth = 0
    var current = node
    while current >= 0, current < doc.nodes.count, depth < 12,
      let parent = doc.nodes[current].parentIndex, parent >= 0 {
      current = parent
      depth += 1
    }
    return depth
  }

  func partName(_ id: PartID) -> String { parts.first { $0.id == id }?.name ?? "—" }

  /// Rotation pivot per part: the part's centroid in CHARACTER space.
  func pivots() -> [PartID: SIMD3<Float>] {
    let bounds = DemoModel.shared.nodeBounds()
    var out: [PartID: SIMD3<Float>] = [:]
    for part in parts {
      guard let box = bounds[part.assetName]?[part.node] else { continue }
      let centre = (box.0 + box.1) * 0.5
      let p = part.restTransform.matrix * SIMD4<Float>(centre, 1)
      out[part.id] = SIMD3(p.x, p.y, p.z)
    }
    return out
  }

  func pose() -> [PartID: simd_float4x4] { RigPose.evaluate(mates: mates, pivots: pivots()) }

  /// Pose keyed by assembly node, for rendering one asset's document.
  func poseByNode(assetName: String) -> [Int: simd_float4x4] {
    let pose = self.pose()
    var out: [Int: simd_float4x4] = [:]
    for part in parts where part.assetName == assetName {
      if let m = pose[part.id] { out[part.node] = m }
    }
    return out
  }

  /// Creates a mate between the two selected parts (parent = first picked).
  @discardableResult
  func addMate(_ type: MateType) -> Mate? {
    let ordered = parts.map(\.id).filter { selectedParts.contains($0) }
    let picked = ordered.count >= 2 ? ordered : Array(selectedParts)
    guard picked.count >= 2 else { return nil }
    let mate = Mate(
      name: "\(type.label) \(mates.filter { $0.type == type }.count + 1)",
      type: type, parent: picked[0], child: picked[1],
      minValue: type.isDriven ? -90 : 0, maxValue: type.isDriven ? 90 : 0)
    mates.append(mate)
    selectedMateID = mate.id
    return mate
  }

  func removeMate(_ id: UUID) {
    mates.removeAll { $0.id == id }
    if selectedMateID == id { selectedMateID = mates.last?.id }
  }

  func togglePart(_ id: PartID, extending: Bool) {
    if extending {
      if selectedParts.contains(id) { selectedParts.remove(id) } else { selectedParts.insert(id) }
    } else {
      selectedParts = selectedParts.contains(id) && selectedParts.count == 1 ? [] : [id]
    }
  }
}
