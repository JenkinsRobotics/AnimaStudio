import AnimaCoreClient
import AnimaDocument
import AnimaModel
import Foundation

enum CharacterPipelineKind: String, CaseIterable, Identifiable {
  case rigidParts3D
  case live2D

  var id: Self { self }

  var title: String {
    switch self {
    case .rigidParts3D: "3D Character"
    case .live2D: "2D (Live2D-style)"
    }
  }

  var detail: String {
    switch self {
    case .rigidParts3D: "An assembly of rigid model parts connected with mates."
    case .live2D: "Layered 2D character authoring — coming later."
    }
  }

  var isAvailable: Bool { self == .rigidParts3D }
}

struct CharacterImportProgress: Equatable {
  var completedFiles: Int
  var totalFiles: Int
  var currentFilename: String

  var fractionCompleted: Double {
    guard totalFiles > 0 else { return 0 }
    return Double(completedFiles) / Double(totalFiles)
  }
}

enum NewCharacterValidation {
  static func message(
    name: String,
    existingCharacters: [ProjectCharacterReference]
  ) -> String? {
    do {
      _ = try ProjectCharacterNaming.reference(
        for: name,
        existingCharacters: existingCharacters
      )
      return nil
    } catch {
      return error.localizedDescription
    }
  }
}

enum AssetBuilderCollection: String, CaseIterable, Hashable, Identifiable, Sendable {
  case parts
  case sourceAssets
  case renders
  case assemblies
  case scripts
  case animations

  var id: Self { self }

  var title: String {
    switch self {
    case .parts: "Parts"
    case .sourceAssets: "Source Assets"
    case .renders: "Renders"
    case .assemblies: "Assemblies"
    case .scripts: "Scripts"
    case .animations: "Animations"
    }
  }

  var systemImage: String {
    switch self {
    case .parts: "cube"
    case .sourceAssets: "shippingbox"
    case .renders: "photo"
    case .assemblies: "square.3.layers.3d"
    case .scripts: "curlybraces"
    case .animations: "waveform.path.ecg"
    }
  }

  /// Every per-character branch projects an existing engine/project/editor source.
  var isLive: Bool { true }
}

enum AssetBuilderLayoutMode: String, CaseIterable, Identifiable, Sendable {
  case table
  case grid

  static let defaultMode = AssetBuilderLayoutMode.table

  var id: Self { self }

  var title: String {
    switch self {
    case .table: "Table"
    case .grid: "Grid"
    }
  }

  var systemImage: String {
    switch self {
    case .table: "list.bullet.rectangle"
    case .grid: "square.grid.2x2"
    }
  }
}

enum AssetLibraryCategory: String, CaseIterable, Hashable, Identifiable, Sendable {
  case castings
  case motors
  case structural
  case displays
  case hardware

  var id: Self { self }
  var title: String { rawValue.capitalized }

  var systemImage: String {
    switch self {
    case .castings: "cube.transparent"
    case .motors: "gearshape.2"
    case .structural: "square.3.layers.3d.down.right"
    case .displays: "display"
    case .hardware: "wrench.and.screwdriver"
    }
  }
}

enum AssetBuilderSelection: Hashable, Sendable {
  case characters
  case characterCollection(characterID: String, collection: AssetBuilderCollection)
  case partsLibrary(AssetLibraryCategory?)

  static func initial(activeCharacterID: String?) -> Self {
    guard let activeCharacterID else { return .characters }
    return .characterCollection(characterID: activeCharacterID, collection: .parts)
  }

  var characterID: String? {
    guard case .characterCollection(let characterID, _) = self else { return nil }
    return characterID
  }
}

enum AssetBuilderTreeNodeID: Hashable, Sendable {
  case project
  case characters
  case character(String)
  case collection(String, AssetBuilderCollection)
  case library
  case libraryCategory(AssetLibraryCategory)
}

struct AssetBuilderTreeNode: TreeNode {
  let id: AssetBuilderTreeNodeID
  let selectionValue: AssetBuilderSelection
  let title: String
  let systemImage: String
  let detail: String?
  var children: [AssetBuilderTreeNode]
  let filterTokens: Set<TreeFilterToken>
  let isLocked = true
  let acceptsChildren = false

  var filterText: String {
    [title, detail].compactMap { $0 }.joined(separator: " ")
  }
}

enum AssetBuilderTreeAdapter {
  static func nodes(
    projectName: String,
    revision: Int,
    characters: [ProjectCharacterReference],
    activeCharacterID: String?,
    counts: [AssetBuilderCollection: Int]
  ) -> [AssetBuilderTreeNode] {
    let characterNodes = characters.map { character in
      AssetBuilderTreeNode(
        id: .character(character.id),
        selectionValue: .characterCollection(characterID: character.id, collection: .parts),
        title: character.displayName,
        systemImage: "figure.stand",
        detail: nil,
        children: AssetBuilderCollection.allCases.map { collection in
          AssetBuilderTreeNode(
            id: .collection(character.id, collection),
            selectionValue: .characterCollection(characterID: character.id, collection: collection),
            title: collection.title,
            systemImage: collection.systemImage,
            detail: character.id == activeCharacterID ? counts[collection].map(String.init) : nil,
            children: [],
            filterTokens: collection == .parts ? [.part] : []
          )
        },
        filterTokens: []
      )
    }
    let project = AssetBuilderTreeNode(
      id: .project,
      selectionValue: .characters,
      title: projectName,
      systemImage: "folder.fill",
      detail: "Project · V\(revision)",
      children: [
        AssetBuilderTreeNode(
          id: .characters,
          selectionValue: .characters,
          title: "Characters",
          systemImage: "person.2",
          detail: String(characters.count),
          children: characterNodes,
          filterTokens: []
        )
      ],
      filterTokens: []
    )
    let library = AssetBuilderTreeNode(
      id: .library,
      selectionValue: .partsLibrary(nil),
      title: "Parts Library",
      systemImage: "books.vertical",
      detail: "User library · Planned",
      children: AssetLibraryCategory.allCases.map { category in
        AssetBuilderTreeNode(
          id: .libraryCategory(category),
          selectionValue: .partsLibrary(category),
          title: category.title,
          systemImage: category.systemImage,
          detail: nil,
          children: [],
          filterTokens: []
        )
      },
      filterTokens: []
    )
    return [project, library]
  }
}

enum AssetBuilderPartState: Equatable, Sendable {
  case ready
  case grounded
  case suppressed
  case proxy

  var label: String {
    switch self {
    case .ready: "Ready"
    case .grounded: "Grounded"
    case .suppressed: "Suppressed"
    case .proxy: "No model"
    }
  }
}

struct AssetBuilderPartRow: Identifiable, Equatable, Sendable {
  let id: PartID
  let name: String
  let parent: String?
  let model: String
  let modelNode: String?
  let description: String
  let state: AssetBuilderPartState
  let version: Int

  var sourceLabel: String {
    guard !model.isEmpty else { return "Primitive / proxy" }
    let filename = URL(fileURLWithPath: model).lastPathComponent
    guard let modelNode, !modelNode.isEmpty else { return filename }
    return "\(filename) · \(modelNode)"
  }
}

struct AssetBuilderListItem: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let detail: String
  let systemImage: String
  let badge: String
}

enum AssetBuilderCatalog {
  static func partRows(
    parts: [AnimaCorePartSummary],
    partID: (String) -> PartID?,
    version: (String) -> Int = { _ in 1 }
  ) -> [AssetBuilderPartRow] {
    parts.compactMap { part in
      guard let id = partID(part.name) else { return nil }
      let state: AssetBuilderPartState
      if part.isSuppressed {
        state = .suppressed
      } else if part.isGrounded {
        state = .grounded
      } else if part.model.isEmpty {
        state = .proxy
      } else {
        state = .ready
      }
      return AssetBuilderPartRow(
        id: id,
        name: part.name,
        parent: part.parent,
        model: part.model,
        modelNode: part.modelNode,
        description: part.description,
        state: state,
        version: max(version(part.name), 1)
      )
    }
  }

  static func filteredParts(_ rows: [AssetBuilderPartRow], query: String) -> [AssetBuilderPartRow] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !needle.isEmpty else { return rows }
    return rows.filter { row in
      [row.name, row.parent ?? "", row.sourceLabel, row.state.label, row.description]
        .contains { $0.lowercased().contains(needle) }
    }
  }
}
