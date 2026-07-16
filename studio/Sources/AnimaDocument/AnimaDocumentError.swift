import Foundation

/// Typed, user-presentable failures thrown by the `.animastudio` document layer.
public enum AnimaDocumentError: Error, Equatable, Sendable {
  /// The package directory or its `project.json` manifest does not exist.
  case packageNotFound(path: String)
  /// `project.json` exists but cannot be parsed into a manifest.
  case corruptManifest(path: String, detail: String)
  /// The manifest declares a `format_version` this build cannot read.
  case unsupportedVersion(found: String, supported: [String])
  /// An embedded asset payload referenced by the manifest is absent,
  /// or a file passed to `embedAsset(from:)`/`linkAsset(at:)` is unreadable.
  case missingAsset(path: String)
  /// Two assets in the document share the same original filename.
  case duplicateAssetName(name: String)
  /// Two assets in the document share the same identifier.
  case duplicateAssetID(id: UUID)
  /// A manifest path (or asset filename) would escape the package directory.
  case pathTraversal(path: String)
  /// A filesystem operation failed while writing or replacing the package.
  case writeFailed(path: String, detail: String)
}

extension AnimaDocumentError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .packageNotFound(let path):
      return "No Anima Studio project package was found at \(path)."
    case .corruptManifest(let path, let detail):
      return "The project manifest at \(path) is damaged and cannot be read: \(detail)"
    case .unsupportedVersion(let found, let supported):
      return
        "This project uses format version \(found), but this build of Anima Studio "
        + "supports version\(supported.count == 1 ? "" : "s") "
        + "\(supported.joined(separator: ", ")). Update the app to open it."
    case .missingAsset(let path):
      return "An asset file is missing: \(path)"
    case .duplicateAssetName(let name):
      return "The project already contains an asset named \"\(name)\"."
    case .duplicateAssetID(let id):
      return "The project contains two assets with the same identifier \(id.uuidString)."
    case .pathTraversal(let path):
      return "The project manifest contains an unsafe file path and was rejected: \(path)"
    case .writeFailed(let path, let detail):
      return "The project could not be saved to \(path): \(detail)"
    }
  }
}
