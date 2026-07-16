import AnimaDocument
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
