import Foundation

public enum ProjectAssetKind: String, Codable, Sendable {
  case model3D
  case audio
  case image
}

public struct ProjectAsset: Identifiable, Equatable, Codable, Sendable {
  public let id: AssetID
  public var name: String
  public var kind: ProjectAssetKind
  public var sourcePath: String

  public init(
    id: AssetID = AssetID(),
    name: String,
    kind: ProjectAssetKind,
    sourcePath: String
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.sourcePath = sourcePath
  }
}

public struct AnimaProject: Equatable, Codable, Sendable {
  public var name: String
  public var assets: [ProjectAsset]
  public var rig: CharacterRig
  public var clips: [AnimationClip]

  public init(
    name: String,
    assets: [ProjectAsset] = [],
    rig: CharacterRig,
    clips: [AnimationClip]
  ) {
    precondition(Set(assets.map(\.id)).count == assets.count)
    self.name = name
    self.assets = assets
    self.rig = rig
    self.clips = clips
  }
}
