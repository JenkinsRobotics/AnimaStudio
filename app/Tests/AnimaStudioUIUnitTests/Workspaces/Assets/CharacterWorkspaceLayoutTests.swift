import XCTest

@testable import AnimaStudioUI

final class CharacterWorkspaceLayoutTests: XCTestCase {
  func testEmptyCollectionUsesCompactFloatingMinimum() {
    XCTAssertEqual(
      AssetsWorkspacePanelSizing.collectionHeight(itemCount: 0),
      AssetsWorkspacePanelSizing.floatingMinimumHeight
    )
  }

  func testFloatingCollectionGrowsWithRowsAndStopsAtBoundedMaximum() {
    let oneRow = AssetsWorkspacePanelSizing.collectionHeight(itemCount: 1)
    let fourRows = AssetsWorkspacePanelSizing.collectionHeight(itemCount: 4)
    let manyRows = AssetsWorkspacePanelSizing.collectionHeight(itemCount: 40)

    XCTAssertEqual(oneRow, AssetsWorkspacePanelSizing.floatingMinimumHeight)
    XCTAssertGreaterThan(fourRows, oneRow)
    XCTAssertLessThanOrEqual(manyRows, AssetsWorkspacePanelSizing.floatingMaximumHeight)
  }

  func testCharacterBrowserUsesTheSameContentSizedBounds() {
    let empty = AssetsWorkspacePanelSizing.browserHeight(
      characterCount: 0,
      hasActiveCharacter: false
    )
    let populated = AssetsWorkspacePanelSizing.browserHeight(
      characterCount: 3,
      hasActiveCharacter: true
    )

    XCTAssertEqual(empty, AssetsWorkspacePanelSizing.floatingMinimumHeight)
    XCTAssertGreaterThan(populated, empty)
    XCTAssertLessThanOrEqual(populated, AssetsWorkspacePanelSizing.floatingMaximumHeight)
  }
}
