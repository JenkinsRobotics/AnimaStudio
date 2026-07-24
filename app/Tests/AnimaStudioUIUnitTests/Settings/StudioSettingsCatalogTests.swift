import XCTest

@testable import AnimaStudioUI

final class StudioSettingsCatalogTests: XCTestCase {
  func testSettingsCatalogIncludesEveryDemoPagePlusWorkspaceAndDeveloper() {
    XCTAssertEqual(
      StudioSettingsTab.allCases.map(\.title),
      [
        "Workspace",
        "Renderer",
        "Appearance",
        "Materials & Edges",
        "Lighting",
        "Layout",
        "Navigation",
        "UI",
        "Developer",
      ]
    )
  }

  func testEverySettingsGroupHasAtLeastOnePage() {
    for group in StudioSettingsGroup.allCases {
      XCTAssertFalse(StudioSettingsTab.allCases.filter { $0.group == group }.isEmpty)
    }
  }

  func testProductionWorkspaceTabsStayStreamlinedByDefault() {
    XCTAssertEqual(
      StudioWorkspaceNavigation.visibleStages(
        showNodes: StudioWorkspaceTabDefaults.showsNodes,
        showDesign: StudioWorkspaceTabDefaults.showsDesign
      ),
      [.assets, .rig, .animate, .canvas2d, .show, .hardware]
    )
  }

  func testDeveloperCanEnableNodesAndDesignWithoutReorderingThePipeline() {
    XCTAssertEqual(
      StudioWorkspaceNavigation.visibleStages(showNodes: true, showDesign: true),
      [.assets, .rig, .animate, .canvas2d, .show, .nodes, .hardware, .design]
    )
  }
}
