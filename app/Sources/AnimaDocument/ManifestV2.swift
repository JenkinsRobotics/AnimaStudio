import AnimaModel
import Foundation

/// Version-2 `project.json` shape for the plain-folder project layout.
/// Canonical engine documents are indexed, never embedded in this manifest.
struct ManifestV2: Codable {
  static let formatVersion = "2"
  static let supportedVersions = ["2"]

  var formatVersion: String
  var projectID: UUID
  var displayName: String
  var revision: Int
  var milestoneName: String?
  var createdDate: Date
  var modifiedDate: Date
  var characters: [ManifestCharacter]
  var scenes: [ManifestScene]
  var editorState: ManifestEditorState
  var assets: [ManifestAsset]

  enum CodingKeys: String, CodingKey {
    case formatVersion = "format_version"
    case projectID = "project_id"
    case displayName = "display_name"
    case revision
    case milestoneName = "milestone_name"
    case createdDate = "created_date"
    case modifiedDate = "modified_date"
    case characters
    case scenes
    case editorState = "editor_state"
    case assets
  }

  struct ManifestCharacter: Codable {
    var folderName: String
    var displayName: String
    var characterFilename: String
    var editorFilename: String

    enum CodingKeys: String, CodingKey {
      case folderName = "folder_name"
      case displayName = "display_name"
      case characterFilename = "character_file"
      case editorFilename = "editor_file"
    }
  }

  struct ManifestScene: Codable {
    var name: String
    var displayName: String
    var filename: String

    enum CodingKeys: String, CodingKey {
      case name
      case displayName = "display_name"
      case filename = "scene_file"
    }
  }

  struct ManifestEditorState: Codable {
    var activeCharacterFolderName: String?
    var activeSceneName: String?
    var activeWorkspaceID: String?

    enum CodingKeys: String, CodingKey {
      case activeCharacterFolderName = "active_character"
      case activeSceneName = "active_scene"
      case activeWorkspaceID = "active_workspace"
    }
  }

  struct ManifestAsset: Codable {
    var id: UUID
    var originalFilename: String
    var kind: String
    var mode: String
    var packagePath: String?
    var externalPath: String?
    var bookmark: Data?

    enum CodingKeys: String, CodingKey {
      case id
      case originalFilename = "original_filename"
      case kind
      case mode
      case packagePath = "package_path"
      case externalPath = "external_path"
      case bookmark
    }
  }

  struct VersionProbe: Codable {
    var formatVersion: String

    enum CodingKeys: String, CodingKey {
      case formatVersion = "format_version"
    }
  }
}

enum ManifestCoding {
  static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

extension ManifestV2 {
  init(document: AnimaStudioDocument, createdDate: Date, modifiedDate: Date) {
    self.formatVersion = Self.formatVersion
    self.projectID = document.projectID
    self.displayName = document.project.name
    self.revision = document.metadata.revision
    self.milestoneName = document.metadata.milestoneName
    self.createdDate = createdDate
    self.modifiedDate = modifiedDate
    self.characters = document.characters.map(ManifestCharacter.init)
    self.scenes = document.scenes.map(ManifestScene.init)
    self.editorState = ManifestEditorState(document.editorState)
    self.assets = document.assets
      .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
      .map(ManifestAsset.init(reference:))
  }

  func document() -> AnimaStudioDocument {
    AnimaStudioDocument(
      projectID: projectID,
      project: AnimaProject(
        name: displayName,
        rig: CharacterRig(parts: [], joints: []),
        clips: []
      ),
      metadata: DocumentMetadata(
        revision: revision,
        milestoneName: milestoneName,
        createdDate: createdDate,
        modifiedDate: modifiedDate
      ),
      characters: characters.map(\.reference),
      scenes: scenes.map(\.reference),
      editorState: editorState.reference,
      assets: assets.map { $0.reference() }
    )
  }
}

extension ManifestV2.ManifestCharacter {
  init(_ reference: ProjectCharacterReference) {
    self.folderName = reference.folderName
    self.displayName = reference.displayName
    self.characterFilename = reference.characterFilename
    self.editorFilename = reference.editorFilename
  }

  var reference: ProjectCharacterReference {
    ProjectCharacterReference(
      folderName: folderName,
      displayName: displayName,
      characterFilename: characterFilename,
      editorFilename: editorFilename
    )
  }
}

extension ManifestV2.ManifestScene {
  init(_ reference: ProjectSceneReference) {
    self.name = reference.name
    self.displayName = reference.displayName
    self.filename = reference.filename
  }

  var reference: ProjectSceneReference {
    ProjectSceneReference(name: name, displayName: displayName, filename: filename)
  }
}

extension ManifestV2.ManifestEditorState {
  init(_ state: ProjectEditorState) {
    self.activeCharacterFolderName = state.activeCharacterFolderName
    self.activeSceneName = state.activeSceneName
    self.activeWorkspaceID = state.activeWorkspaceID
  }

  var reference: ProjectEditorState {
    ProjectEditorState(
      activeCharacterFolderName: activeCharacterFolderName,
      activeSceneName: activeSceneName,
      activeWorkspaceID: activeWorkspaceID
    )
  }
}

extension ManifestV2.ManifestAsset {
  init(reference: DocumentAssetReference) {
    self.id = reference.id.rawValue
    self.originalFilename = reference.originalFilename
    self.kind = reference.kind
    switch reference.storage {
    case .embedded(let packageRelativePath):
      self.mode = "embedded"
      self.packagePath = packageRelativePath
      self.externalPath = nil
      self.bookmark = nil
    case .linked(let externalPath, let bookmarkData):
      self.mode = "linked"
      self.packagePath = nil
      self.externalPath = externalPath
      self.bookmark = bookmarkData
    }
  }

  func reference() -> DocumentAssetReference {
    let storage: DocumentAssetStorage =
      if mode == "linked" {
        .linked(externalPath: externalPath ?? "", bookmarkData: bookmark)
      } else {
        .embedded(packageRelativePath: packagePath ?? "")
      }
    return DocumentAssetReference(
      id: AssetID(rawValue: id),
      originalFilename: originalFilename,
      kind: kind,
      storage: storage
    )
  }
}
