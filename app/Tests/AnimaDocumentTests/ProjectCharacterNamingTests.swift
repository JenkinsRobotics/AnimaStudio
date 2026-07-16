import XCTest

@testable import AnimaDocument

final class ProjectCharacterNamingTests: XCTestCase {
  func testCreatesTrimmedDisplayNameAndPortableIdentifier() throws {
    let reference = try ProjectCharacterNaming.reference(
      for: "  Café Robot / Head  ",
      existingCharacters: []
    )

    XCTAssertEqual(reference.displayName, "Café Robot / Head")
    XCTAssertEqual(reference.folderName, "cafe-robot-head")
    XCTAssertEqual(
      reference.characterPath, "characters/cafe-robot-head/cafe-robot-head.character.anima")
  }

  func testRejectsBlankAndCaseInsensitiveDuplicateNames() {
    XCTAssertThrowsError(
      try ProjectCharacterNaming.reference(for: "   ", existingCharacters: [])
    ) { error in
      XCTAssertEqual(error as? ProjectCharacterNameError, .empty)
    }

    let existing = [ProjectCharacterReference(folderName: "wall-e", displayName: "WALL-E")]
    XCTAssertThrowsError(
      try ProjectCharacterNaming.reference(for: "wall-e", existingCharacters: existing)
    ) { error in
      XCTAssertEqual(error as? ProjectCharacterNameError, .duplicate("wall-e"))
    }
  }

  func testRejectsDifferentNamesThatMapToSameFolder() {
    let existing = [ProjectCharacterReference(folderName: "robot-head", displayName: "Robot Head")]
    XCTAssertThrowsError(
      try ProjectCharacterNaming.reference(for: "Robot/Head", existingCharacters: existing)
    )
  }
}
