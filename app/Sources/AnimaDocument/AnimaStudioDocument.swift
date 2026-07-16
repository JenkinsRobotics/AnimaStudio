import AnimaModel
import Foundation

/// Document-level metadata persisted in `project.json`.
public struct DocumentMetadata: Equatable, Sendable {
  public var revision: Int
  public var milestoneName: String?
  public var createdDate: Date?
  public var modifiedDate: Date?

  public init(
    revision: Int = 0,
    milestoneName: String? = nil,
    createdDate: Date? = nil,
    modifiedDate: Date? = nil
  ) {
    self.revision = revision
    self.milestoneName = milestoneName
    self.createdDate = createdDate
    self.modifiedDate = modifiedDate
  }
}

/// One self-contained character directory indexed by `project.json`.
public struct ProjectCharacterReference: Equatable, Identifiable, Sendable {
  public var folderName: String
  public var displayName: String
  public var characterFilename: String
  public var editorFilename: String

  public var id: String { folderName }
  public var directoryPath: String { "characters/\(folderName)" }
  public var characterPath: String { "\(directoryPath)/\(characterFilename)" }
  public var editorPath: String { "\(directoryPath)/\(editorFilename)" }
  public var assetsDirectoryPath: String { "\(directoryPath)/assets" }

  public init(
    folderName: String,
    displayName: String,
    characterFilename: String? = nil,
    editorFilename: String? = nil
  ) {
    self.folderName = folderName
    self.displayName = displayName
    self.characterFilename = characterFilename ?? "\(folderName).character.anima"
    self.editorFilename = editorFilename ?? "\(folderName).editor.json"
  }
}

/// One canonical scene document indexed by `project.json`.
public struct ProjectSceneReference: Equatable, Identifiable, Sendable {
  public var name: String
  public var displayName: String
  public var filename: String

  public var id: String { name }
  public var scenePath: String { "scenes/\(filename)" }

  public init(name: String, displayName: String, filename: String? = nil) {
    self.name = name
    self.displayName = displayName
    self.filename = filename ?? "\(name).scene.anima"
  }
}

/// App-only editor state. It is deliberately separate from canonical engine
/// character and scene documents.
public struct ProjectEditorState: Equatable, Sendable {
  public var activeCharacterFolderName: String?
  public var activeSceneName: String?
  public var activeWorkspaceID: String?

  public init(
    activeCharacterFolderName: String? = nil,
    activeSceneName: String? = nil,
    activeWorkspaceID: String? = nil
  ) {
    self.activeCharacterFolderName = activeCharacterFolderName
    self.activeSceneName = activeSceneName
    self.activeWorkspaceID = activeWorkspaceID
  }
}

/// The app-owned projection of one plain-folder Anima Studio project.
///
/// `project` is live Swift editing/presentation state only. It is never
/// encoded into `project.json`; canonical rig/clip meaning lives in the
/// indexed `.character.anima` files authored by AnimaCore.
public struct AnimaStudioDocument: Equatable, Sendable {
  public var projectID: UUID
  public var project: AnimaProject
  public var metadata: DocumentMetadata
  public var characters: [ProjectCharacterReference]
  public var scenes: [ProjectSceneReference]
  public var editorState: ProjectEditorState
  public var assets: [DocumentAssetReference]

  public init(
    projectID: UUID = UUID(),
    project: AnimaProject,
    metadata: DocumentMetadata = DocumentMetadata(),
    characters: [ProjectCharacterReference] = [],
    scenes: [ProjectSceneReference] = [],
    editorState: ProjectEditorState = ProjectEditorState(),
    assets: [DocumentAssetReference] = []
  ) {
    self.projectID = projectID
    self.project = project
    self.metadata = metadata
    self.characters = characters
    self.scenes = scenes
    self.editorState = editorState
    self.assets = assets
  }

  public var displayName: String { project.name }

  public var activeCharacter: ProjectCharacterReference? {
    if let active = editorState.activeCharacterFolderName,
      let character = characters.first(where: { $0.folderName == active })
    {
      return character
    }
    return characters.first
  }
}

/// One app-owned file that should be written as part of the same atomic save
/// as `project.json` (canonical text returned by AnimaCore or editor JSON).
public struct ProjectFileWrite: Equatable, Sendable {
  public var relativePath: String
  public var data: Data

  public init(relativePath: String, data: Data) {
    self.relativePath = relativePath
    self.data = data
  }

  public init(relativePath: String, text: String) {
    self.init(relativePath: relativePath, data: Data(text.utf8))
  }
}
