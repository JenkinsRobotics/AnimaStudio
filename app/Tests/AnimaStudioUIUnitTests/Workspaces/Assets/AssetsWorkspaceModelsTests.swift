import AnimaCoreClient
import AnimaDocument
import AnimaModel
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

  func testAssetBuilderStartsInPartsForAnActiveCharacter() {
    XCTAssertEqual(
      AssetBuilderSelection.initial(activeCharacterID: "robot"),
      .characterCollection(characterID: "robot", collection: .parts)
    )
    XCTAssertEqual(AssetBuilderSelection.initial(activeCharacterID: nil), .characters)
  }

  func testAssetBuilderProjectsEveryCharacterCollectionFromAnExistingSource() {
    XCTAssertTrue(AssetBuilderCollection.parts.isLive)
    XCTAssertTrue(AssetBuilderCollection.sourceAssets.isLive)
    XCTAssertTrue(AssetBuilderCollection.animations.isLive)
    XCTAssertTrue(AssetBuilderCollection.renders.isLive)
    XCTAssertTrue(AssetBuilderCollection.assemblies.isLive)
    XCTAssertTrue(AssetBuilderCollection.scripts.isLive)
  }

  func testAssetBuilderCollectionViewDefaultsToTableAndOffersGrid() {
    XCTAssertEqual(AssetBuilderLayoutMode.defaultMode, .table)
    XCTAssertEqual(AssetBuilderLayoutMode.allCases, [.table, .grid])
    XCTAssertEqual(AssetBuilderLayoutMode.table.title, "Table")
    XCTAssertEqual(AssetBuilderLayoutMode.grid.title, "Grid")
  }

  func testPartRowsProjectEngineStateAndFilterAcrossColumns() throws {
    let payload = Data(
      """
      [
        {"name":"base","parent":null,"model":"assets/base.stl","description":"Main frame","grounded":true},
        {"name":"head","parent":"base","model":"assets/head.usdz","model_node":"Head","suppressed":true},
        {"name":"locator","parent":"head","model":""}
      ]
      """.utf8
    )
    let parts = try JSONDecoder().decode([AnimaCorePartSummary].self, from: payload)
    let ids = Dictionary(uniqueKeysWithValues: parts.map { ($0.name, PartID()) })

    let rows = AssetBuilderCatalog.partRows(
      parts: parts,
      partID: { ids[$0] },
      version: { name in name == "head" ? 3 : 1 }
    )

    XCTAssertEqual(rows.map(\.state), [.grounded, .suppressed, .proxy])
    XCTAssertEqual(rows[1].sourceLabel, "head.usdz · Head")
    XCTAssertEqual(rows[1].version, 3)
    XCTAssertEqual(
      AssetBuilderCatalog.filteredParts(rows, query: "grounded").map(\.name), ["base"])
    XCTAssertEqual(
      AssetBuilderCatalog.filteredParts(rows, query: "head.usdz").map(\.name), ["head"])
  }

  func testAssetBuilderTreeUsesTheSharedTreeNodeContract() {
    let character = ProjectCharacterReference(folderName: "robot", displayName: "Robot")
    let nodes = AssetBuilderTreeAdapter.nodes(
      projectName: "Show",
      revision: 4,
      characters: [character],
      activeCharacterID: character.id,
      counts: [.parts: 7]
    )
    let model = TreeModel(roots: nodes)

    XCTAssertEqual(model.node(id: .project)?.detail, "Project · V4")
    XCTAssertEqual(model.node(id: .collection("robot", .parts))?.detail, "7")
    XCTAssertEqual(
      model.ancestorIDs(of: .collection("robot", .parts)),
      [.project, .characters, .character("robot")]
    )
  }
}
