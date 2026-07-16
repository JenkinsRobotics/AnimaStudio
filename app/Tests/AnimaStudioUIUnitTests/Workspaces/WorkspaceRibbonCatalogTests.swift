import XCTest

@testable import AnimaStudioUI

final class WorkspaceRibbonCatalogTests: XCTestCase {
  func testEveryNonRigWorkspaceHasAGroupedToolCatalog() {
    for workspace in StudioWorkspaceKind.allCases where workspace != .rig {
      let groups = WorkspaceRibbonCatalog.groups(for: workspace)
      XCTAssertFalse(groups.isEmpty, "\(workspace) needs ribbon groups")
      XCTAssertTrue(groups.allSatisfy { !$0.tools.isEmpty })
    }
    XCTAssertTrue(WorkspaceRibbonCatalog.groups(for: .rig).isEmpty)
  }

  func testAssetCatalogCoversImportManagementAndPreparation() {
    let groups = WorkspaceRibbonCatalog.groups(for: .assets)
    XCTAssertEqual(groups.map(\.title), ["Import", "Manage", "Prepare"])
    XCTAssertTrue(groups.flatMap(\.tools).contains { $0.title == "Map Nodes" })
    XCTAssertEqual(
      groups.flatMap(\.tools).filter(\.isImplemented).map(\.title),
      ["3D Model"]
    )
  }

  func testAnimationCatalogIncludesExtendedAuthoringFamilies() {
    let groups = WorkspaceRibbonCatalog.groups(for: .animate)
    XCTAssertEqual(
      groups.map(\.title),
      ["Transport", "Keyframes", "Curves", "Tracks", "Reference"]
    )
    let titles = groups.flatMap(\.tools).map(\.title)
    XCTAssertTrue(titles.contains("Bézier"))
    XCTAssertTrue(titles.contains("Auto Key"))
    XCTAssertTrue(titles.contains("Lip Sync"))
  }

  func testShowCatalogIncludesMediaEventsAndSync() {
    let groups = WorkspaceRibbonCatalog.groups(for: .show)
    XCTAssertEqual(groups.map(\.title), ["Sequence", "Clips", "Events", "Sync"])
    let titles = groups.flatMap(\.tools).map(\.title)
    XCTAssertTrue(titles.contains("Screen"))
    XCTAssertTrue(titles.contains("LED"))
    XCTAssertTrue(titles.contains("Timecode"))
  }

  func testNodeCatalogIncludesInputVoiceAIAndOutputConceptFamilies() {
    let groups = WorkspaceRibbonCatalog.groups(for: .nodes)
    XCTAssertEqual(
      groups.map(\.title),
      [
        "Flow", "Actions", "Graph", "Program Logic", "Conditions", "I/O & Registers",
        "Background", "Inputs", "Voice & AI", "Outputs",
      ]
    )

    let titles = groups.flatMap(\.tools).map(\.title)
    XCTAssertTrue(titles.contains("Parallel"))
    XCTAssertTrue(titles.contains("IF / ELSE"))
    XCTAssertTrue(titles.contains("SELECT"))
    XCTAssertTrue(titles.contains("CALL"))
    XCTAssertTrue(titles.contains("WAIT Until"))
    XCTAssertTrue(titles.contains("JMP (Import)"))
    XCTAssertTrue(titles.contains("LBL (Import)"))
    XCTAssertTrue(titles.contains("XOR"))
    XCTAssertTrue(titles.contains("Position"))
    XCTAssertTrue(titles.contains("Monitor"))
    XCTAssertTrue(titles.contains("Wait for Event"))
    XCTAssertTrue(titles.contains("STT"))
    XCTAssertTrue(titles.contains("LLM"))
    XCTAssertTrue(titles.contains("TTS"))
    XCTAssertTrue(titles.contains("Screen"))
    XCTAssertTrue(groups.dropFirst(3).flatMap(\.tools).allSatisfy { !$0.isImplemented })
  }

  func testHardwareCatalogIncludesConnectionMappingCalibrationSafetyAndMonitoring() {
    XCTAssertEqual(
      WorkspaceRibbonCatalog.groups(for: .hardware).map(\.title),
      ["Connection", "Outputs", "Mapping", "Calibration", "Safety", "Monitor"]
    )
  }

  func testEveryToolHasReadablePresentationAndPlannedToolsHaveNoAction() {
    for workspace in StudioWorkspaceKind.allCases {
      for tool in WorkspaceRibbonCatalog.groups(for: workspace).flatMap(\.tools) {
        XCTAssertFalse(tool.title.isEmpty)
        XCTAssertFalse(tool.systemImage.isEmpty)
        XCTAssertFalse(tool.help.isEmpty)
        XCTAssertEqual(tool.isImplemented, tool.action != nil)
      }
    }
  }
}
