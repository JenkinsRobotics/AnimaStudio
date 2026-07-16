import AnimaDocument
import XCTest

@testable import AnimaStudioUI

final class AssetsWorkspaceModelsTests: XCTestCase {
  func testOnlyRigidPartsPipelineIsCurrentlyAvailable() {
    XCTAssertTrue(CharacterPipelineKind.rigidParts3D.isAvailable)
    XCTAssertFalse(CharacterPipelineKind.live2D.isAvailable)
    XCTAssertTrue(CharacterPipelineKind.live2D.detail.contains("coming later"))
    XCTAssertTrue(CharacterPipelineKind.rigidParts3D.detail.contains("rigid"))
  }

  func testNewCharacterValidationUsesProjectIndex() {
    let existing = [ProjectCharacterReference(folderName: "robot", displayName: "Robot")]

    XCTAssertNil(
      NewCharacterValidation.message(name: "Second Robot", existingCharacters: existing)
    )
    XCTAssertNotNil(
      NewCharacterValidation.message(name: "robot", existingCharacters: existing)
    )
    XCTAssertNotNil(NewCharacterValidation.message(name: "   ", existingCharacters: existing))
  }

  func testImportProgressUsesCompletedFileCount() {
    let progress = CharacterImportProgress(
      completedFiles: 2,
      totalFiles: 4,
      currentFilename: "head.usdz"
    )
    XCTAssertEqual(progress.fractionCompleted, 0.5)
  }
}
