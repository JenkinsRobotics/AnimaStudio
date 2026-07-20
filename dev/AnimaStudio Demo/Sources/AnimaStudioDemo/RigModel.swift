// Real rig state — the part tree comes from the imported STEP assembly nodes,
// and mates are authored between those actual parts (no mock data).
import GeomKit
import SwiftUI
import simd

enum MateType: String, CaseIterable, Identifiable {
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

enum MateAxis: String, CaseIterable, Identifiable {
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

struct Mate: Identifiable {
  let id = UUID()
  var name: String
  var type: MateType
  var parent: Int          // assembly-node id
  var child: Int           // assembly-node id
  var axis: MateAxis = .z
  var minValue: Double = -90
  var maxValue: Double = 90
  var value: Double = 0
}

// A flattened row of the assembly tree (depth drives indentation).
struct RigPartRow: Identifiable {
  let id: Int
  let name: String
  let depth: Int
  let faceCount: Int
}

@MainActor @Observable final class RigModel {
  static let shared = RigModel()

  var mates: [Mate] = []
  var selectedParts: Set<Int> = []
  var selectedMateID: UUID?

  var document: GeometryDocument? { DemoModel.shared.selected?.document }
  var nodes: [AssemblyNode] { document?.nodes ?? [] }

  var selectedMate: Mate? {
    get { mates.first { $0.id == selectedMateID } }
    set {
      guard let newValue, let i = mates.firstIndex(where: { $0.id == newValue.id }) else { return }
      mates[i] = newValue
    }
  }

  /// Depth-first flattening of the assembly so the tree renders in order.
  var partRows: [RigPartRow] {
    let nodes = self.nodes
    guard !nodes.isEmpty else { return [] }
    var faceCounts: [Int: Int] = [:]
    for face in document?.faces ?? [] where face.assemblyNode >= 0 {
      faceCounts[face.assemblyNode, default: 0] += 1
    }
    var childrenByParent: [Int: [Int]] = [:]
    var roots: [Int] = []
    for (index, node) in nodes.enumerated() {
      if let parent = node.parentIndex, parent >= 0, parent < nodes.count {
        childrenByParent[parent, default: []].append(index)
      } else {
        roots.append(index)
      }
    }
    var rows: [RigPartRow] = []
    func walk(_ index: Int, _ depth: Int) {
      guard index < nodes.count, depth < 12 else { return }   // depth guard: cyclic STEP data
      let node = nodes[index]
      rows.append(RigPartRow(
        id: index,
        name: node.name.isEmpty ? "Part \(index)" : node.name,
        depth: depth,
        faceCount: faceCounts[index] ?? 0))
      for child in childrenByParent[index] ?? [] { walk(child, depth + 1) }
    }
    for root in roots { walk(root, 0) }
    return rows
  }

  func partName(_ id: Int) -> String {
    guard id >= 0, id < nodes.count else { return "—" }
    let name = nodes[id].name
    return name.isEmpty ? "Part \(id)" : name
  }

  /// Creates a mate from the current two-part selection (parent = first picked).
  @discardableResult
  func addMate(_ type: MateType) -> Mate? {
    let picked = selectedParts.sorted()
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

  func togglePart(_ id: Int, extending: Bool) {
    if extending {
      if selectedParts.contains(id) { selectedParts.remove(id) } else { selectedParts.insert(id) }
    } else {
      selectedParts = selectedParts.contains(id) && selectedParts.count == 1 ? [] : [id]
    }
  }
}
