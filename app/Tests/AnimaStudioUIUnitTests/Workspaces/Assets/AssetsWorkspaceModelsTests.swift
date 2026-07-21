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

  func testAssetBuilderPartSelectionSupportsReplacementAndCommandToggle() {
    let first = PartID()
    let second = PartID()
    let orderedIDs = [first, second]

    XCTAssertEqual(
      AssetBuilderPartSelection.selecting(
        first,
        in: [second],
        orderedIDs: orderedIDs,
        anchor: second,
        command: false,
        shift: false
      ),
      AssetBuilderPartSelection.Result(ids: [first], anchor: first)
    )
    XCTAssertEqual(
      AssetBuilderPartSelection.selecting(
        second,
        in: [first],
        orderedIDs: orderedIDs,
        anchor: first,
        command: true,
        shift: false
      ),
      AssetBuilderPartSelection.Result(ids: [first, second], anchor: second)
    )
    XCTAssertEqual(
      AssetBuilderPartSelection.selecting(
        first,
        in: [first, second],
        orderedIDs: orderedIDs,
        anchor: second,
        command: true,
        shift: false
      ),
      AssetBuilderPartSelection.Result(ids: [second], anchor: first)
    )
  }

  func testAssetBuilderShiftSelectsInclusiveRangeFromAnchorInEitherDirection() {
    let first = PartID()
    let second = PartID()
    let third = PartID()
    let fourth = PartID()
    let orderedIDs = [first, second, third, fourth]

    XCTAssertEqual(
      AssetBuilderPartSelection.selecting(
        fourth,
        in: [second],
        orderedIDs: orderedIDs,
        anchor: second,
        command: false,
        shift: true
      ),
      AssetBuilderPartSelection.Result(ids: [second, third, fourth], anchor: second)
    )
    XCTAssertEqual(
      AssetBuilderPartSelection.selecting(
        first,
        in: [fourth],
        orderedIDs: orderedIDs,
        anchor: fourth,
        command: false,
        shift: true
      ),
      AssetBuilderPartSelection.Result(ids: Set(orderedIDs), anchor: fourth)
    )
  }

  func testAssetBuilderCommandShiftAddsRangeAndMissingAnchorFallsBackToClickedPart() {
    let first = PartID()
    let second = PartID()
    let third = PartID()
    let fourth = PartID()
    let orderedIDs = [first, second, third, fourth]

    XCTAssertEqual(
      AssetBuilderPartSelection.selecting(
        fourth,
        in: [first],
        orderedIDs: orderedIDs,
        anchor: second,
        command: true,
        shift: true
      ),
      AssetBuilderPartSelection.Result(ids: Set(orderedIDs), anchor: second)
    )

    let unavailableAnchor = PartID()
    XCTAssertEqual(
      AssetBuilderPartSelection.selecting(
        third,
        in: [first],
        orderedIDs: orderedIDs,
        anchor: unavailableAnchor,
        command: false,
        shift: true
      ),
      AssetBuilderPartSelection.Result(ids: [third], anchor: third)
    )
  }

  func testSameFilenameImportFindsTheReferencedAssetAndAllSharingParts() throws {
    let character = ProjectCharacterReference(folderName: "robot", displayName: "Robot")
    let staleAsset = DocumentAssetReference(
      originalFilename: "head.stl",
      kind: "model3D",
      storage: .embedded(packageRelativePath: "characters/robot/assets/old-head.stl")
    )
    let currentAsset = DocumentAssetReference(
      originalFilename: "Head.STL",
      kind: "model3D",
      storage: .embedded(packageRelativePath: "assets/models/head.stl")
    )
    let payload = Data(
      """
      [
        {"name":"head","model":"assets/head.stl"},
        {"name":"head_cap","model":"assets/head.stl"}
      ]
      """.utf8
    )
    let parts = try JSONDecoder().decode([AnimaCorePartSummary].self, from: payload)

    let replacement = try XCTUnwrap(
      AssetBuilderImportMatching.automaticReplacement(
        sourceFilename: "head.stl",
        character: character,
        assets: [staleAsset, currentAsset],
        modelImports: [
          "assets/head.stl": ModelImportMetadata(
            unitName: "millimeters",
            unitScaleToMeters: 0.001,
            assetID: currentAsset.id.rawValue
          )
        ],
        parts: parts
      )
    )

    XCTAssertEqual(replacement.asset.id, currentAsset.id)
    XCTAssertEqual(replacement.modelReference, "assets/head.stl")
    XCTAssertEqual(replacement.partNames, ["head", "head_cap"])
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
      characters: [character],
      characterLibraryCount: 2,
      activeCharacterID: character.id,
      counts: [.parts: 7]
    )
    let model = TreeModel(roots: nodes)

    XCTAssertFalse(AssetBuilderFeatureAvailability.showsLibraries)
    XCTAssertEqual(nodes.map(\.id), [.characters])
    XCTAssertEqual(model.node(id: .characters)?.detail, "1")
    XCTAssertNil(model.node(id: .characterLibrary))
    XCTAssertNil(model.node(id: .library))
    XCTAssertEqual(model.node(id: .collection("robot", .parts))?.detail, "7")
    XCTAssertEqual(
      model.ancestorIDs(of: .collection("robot", .parts)),
      [.characters, .character("robot")]
    )
  }
}
