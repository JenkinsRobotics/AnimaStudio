// Character assembly + coordinate spaces.
//
//   part space      — geometry exactly as imported (STEP coordinates)
//   character space — parts PLACED around a centered character origin
//   world space     — the character positioned in the scene (it can move)
//
//   world = characterWorld × rigPose(part) × placement(part) × partGeometry
//
// Mates reference stable PartIDs, so re-importing or reordering assets can never
// silently repoint a rig.
import Foundation
import GeomKit
import simd

typealias PartID = UUID

/// An editable transform (Codable, inspector-friendly).
struct Transform3: Codable, Equatable {
  var translation: SIMD3<Float> = .zero
  var rotationDegrees: SIMD3<Float> = .zero
  var scale: Float = 1

  static let identity = Transform3()

  var matrix: simd_float4x4 {
    let r = radians(rotationDegrees)
    let rot = simd_float4x4(simd_quatf(angle: r.z, axis: [0, 0, 1]))
      * simd_float4x4(simd_quatf(angle: r.y, axis: [0, 1, 0]))
      * simd_float4x4(simd_quatf(angle: r.x, axis: [1, 0, 0]))
    var m = rot
    m.columns.0 *= scale
    m.columns.1 *= scale
    m.columns.2 *= scale
    m.columns.3 = SIMD4(translation, 1)
    return m
  }

  private func radians(_ d: SIMD3<Float>) -> SIMD3<Float> { d * .pi / 180 }
}

/// One part belonging to a character: a reference into an imported asset plus
/// where it sits in CHARACTER space.
struct CharacterPart: Identifiable, Codable, Equatable {
  var id: PartID = UUID()
  var assetName: String        // the imported file it came from
  var node: Int                // assembly node inside that asset's document
  var name: String
  /// Rest transform in CHARACTER space (parts are placed relative to the origin).
  var restTransform: Transform3 = .identity
  var groupID: UUID?          // organization only — groups never define motion
  var visible = true
}

/// Organization only — groups never define motion (mates do).
struct PartGroup: Identifiable, Codable, Equatable {
  var id = UUID()
  var name: String
}

struct Character: Identifiable, Codable, Equatable {
  var id = UUID()
  var name: String
  var sourceAssets: [String] = []       // imported files backing this character
  var parts: [CharacterPart] = []
  var groups: [PartGroup] = []          // organization only
  var groundedPartID: PartID?           // the base part everything else mates to
  var mates: [Mate] = []
  var clips: [Clip] = []
  var channels: [ServoChannel] = []
  /// Where the character sits in WORLD space (animated by the Show).
  var worldTransform: Transform3 = .identity

  func part(_ id: PartID) -> CharacterPart? { parts.first { $0.id == id } }
}

enum CharacterMath {
  /// Character-space bounds of the given parts, using each asset's node bounds.
  static func bounds(of parts: [CharacterPart], nodeBounds: [String: [Int: (SIMD3<Float>, SIMD3<Float>)]])
    -> (min: SIMD3<Float>, max: SIMD3<Float>)?
  {
    var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    var found = false
    for part in parts {
      guard let box = nodeBounds[part.assetName]?[part.node] else { continue }
      found = true
      // Transform the 8 corners so rotation is respected.
      for xi in [box.0.x, box.1.x] {
        for yi in [box.0.y, box.1.y] {
          for zi in [box.0.z, box.1.z] {
            let p = part.restTransform.matrix * SIMD4<Float>(xi, yi, zi, 1)
            let v = SIMD3(p.x, p.y, p.z)
            lo = simd_min(lo, v)
            hi = simd_max(hi, v)
          }
        }
      }
    }
    return found ? (lo, hi) : nil
  }

  /// Offset every placement so the assembly's centre sits on the character origin.
  static func centeredPlacements(_ parts: [CharacterPart],
    nodeBounds: [String: [Int: (SIMD3<Float>, SIMD3<Float>)]]) -> [CharacterPart]
  {
    guard let box = bounds(of: parts, nodeBounds: nodeBounds) else { return parts }
    let centre = (box.min + box.max) * 0.5
    return parts.map { part in
      var moved = part
      moved.restTransform.translation -= centre
      return moved
    }
  }

  /// Full world transform for a part: character × rig pose × placement.
  static func worldMatrix(part: CharacterPart, pose: [PartID: simd_float4x4],
    characterWorld: Transform3) -> simd_float4x4
  {
    characterWorld.matrix * (pose[part.id] ?? matrix_identity_float4x4) * part.restTransform.matrix
  }
}

@MainActor @Observable final class ProjectModel {
  static let shared = ProjectModel()

  var characters: [Character] = []
  var activeCharacterID: UUID?

  // Character-tree UI state (project navigator on the Character tab).
  var projectFilter = ""
  var charactersExpanded = true
  var expandedCharacters: Set<UUID> = []
  /// Which child folder of a character is focused, e.g. "Parts", "Animations".
  var focusedFolder: String?

  func toggleExpanded(_ id: UUID) {
    if expandedCharacters.contains(id) { expandedCharacters.remove(id) }
    else { expandedCharacters.insert(id) }
  }

  var activeIndex: Int? {
    if let id = activeCharacterID, let i = characters.firstIndex(where: { $0.id == id }) { return i }
    return characters.isEmpty ? nil : 0
  }
  var active: Character? { activeIndex.map { characters[$0] } }

  @discardableResult
  func addCharacter(named name: String? = nil) -> Character {
    let character = Character(name: name ?? "Character \(characters.count + 1)")
    characters.append(character)
    activeCharacterID = character.id
    return character
  }

  func removeCharacter(_ id: UUID) {
    characters.removeAll { $0.id == id }
    if activeCharacterID == id { activeCharacterID = characters.first?.id }
  }

  /// Adds every assembly node of an imported asset as parts of the active
  /// character (creating a character if there isn't one yet).
  @discardableResult
  func addAsset(_ asset: ImportedPart) -> Int {
    if activeIndex == nil { addCharacter(named: asset.name) }
    guard let index = activeIndex else { return 0 }
    if !characters[index].sourceAssets.contains(asset.name) {
      characters[index].sourceAssets.append(asset.name)
    }
    let existing = Set(characters[index].parts.map { "\($0.assetName)#\($0.node)" })
    var added = 0
    for node in asset.document.nodes.indices {
      let key = "\(asset.name)#\(node)"
      guard !existing.contains(key) else { continue }
      let raw = asset.document.nodes[node].name
      characters[index].parts.append(CharacterPart(
        assetName: asset.name, node: node,
        name: raw.isEmpty ? "Part \(node)" : raw))
      added += 1
    }
    return added
  }

  func centerOrigin() {
    guard let index = activeIndex else { return }
    characters[index].parts = CharacterMath.centeredPlacements(
      characters[index].parts, nodeBounds: DemoModel.shared.nodeBounds())
  }
}
