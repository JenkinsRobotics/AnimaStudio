import Foundation

public enum ProjectCharacterNameError: Error, Equatable, Sendable {
  case empty
  case duplicate(String)
}

extension ProjectCharacterNameError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .empty:
      "Enter a character name."
    case .duplicate(let name):
      "A character named ‘\(name)’ already exists in this project."
    }
  }
}

/// Creates stable folder/engine identifiers from operator-facing names.
/// Character display names remain independent of the project name.
public enum ProjectCharacterNaming {
  public static func reference(
    for displayName: String,
    existingCharacters: [ProjectCharacterReference]
  ) throws -> ProjectCharacterReference {
    let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw ProjectCharacterNameError.empty }

    let folderName = identifier(for: trimmed)
    let hasDuplicate = existingCharacters.contains { character in
      character.displayName.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive])
        == .orderedSame
        || character.folderName.caseInsensitiveCompare(folderName) == .orderedSame
    }
    guard !hasDuplicate else { throw ProjectCharacterNameError.duplicate(trimmed) }
    return ProjectCharacterReference(folderName: folderName, displayName: trimmed)
  }

  public static func identifier(for displayName: String) -> String {
    let folded = displayName.folding(
      options: [.diacriticInsensitive, .caseInsensitive],
      locale: Locale(identifier: "en_US_POSIX")
    )
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let normalized = folded.unicodeScalars.map { scalar in
      allowed.contains(scalar) ? Character(String(scalar)) : "-"
    }
    let collapsed = String(normalized)
      .split(separator: "-", omittingEmptySubsequences: true)
      .joined(separator: "-")
    return collapsed.isEmpty ? "character" : collapsed
  }
}
