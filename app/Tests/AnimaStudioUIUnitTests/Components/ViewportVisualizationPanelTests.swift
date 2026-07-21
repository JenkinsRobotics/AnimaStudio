import XCTest

@testable import AnimaStudioUI

final class ViewportVisualizationPanelTests: XCTestCase {
  func testMaterialCatalogHasStableUniqueSearchablePresetsInEveryCategory() {
    let presets = VisualizationMaterialCatalog.presets

    XCTAssertEqual(Set(presets.map(\.id)).count, presets.count)
    XCTAssertTrue(
      VisualizationMaterialCategory.allCases.allSatisfy {
        !VisualizationMaterialCatalog.presets(in: $0).isEmpty
      }
    )
    XCTAssertTrue(
      presets.allSatisfy {
        !$0.name.isEmpty && !$0.family.isEmpty && $0.hexRGB.hasPrefix("#")
          && (0...1).contains($0.opacity)
      }
    )

    XCTAssertEqual(
      VisualizationMaterialCatalog.presets(in: .plastic, matching: "glossy").map(\.id),
      ["plastic-glossy-abs-red"]
    )
    XCTAssertEqual(
      VisualizationMaterialCatalog.presets(in: .glass, matching: "thin").map(\.id),
      ["glass-clear-thin"]
    )
  }

  func testMaterialPresetProducesRendererAppearanceWithoutChangingItsIdentity() throws {
    let preset = try XCTUnwrap(
      VisualizationMaterialCatalog.presets.first { $0.id == "metal-brushed-aluminum" }
    )
    let appearance = preset.appearance

    XCTAssertEqual(appearance.hexRGB, preset.hexRGB)
    XCTAssertEqual(appearance.finish, preset.finish)
    XCTAssertEqual(appearance.opacity, preset.opacity)
  }

  func testEnvironmentCatalogHasFiveStableDistinctVisualPresets() {
    let presets = VisualizationEnvironmentCatalog.presets

    XCTAssertEqual(presets.count, 5)
    XCTAssertEqual(Set(presets.map(\.id)).count, presets.count)
    XCTAssertEqual(presets.map(\.id), VisualizationEnvironmentPresetID.allCases)
    XCTAssertTrue(presets.contains { $0.background.mode == .transparent })
    XCTAssertTrue(presets.contains { $0.background.mode == .solid })
    XCTAssertTrue(presets.contains { $0.background.mode == .gradient })
  }

  func testEnvironmentCatalogMatchesCompleteRenderConfiguration() throws {
    let preset = try XCTUnwrap(
      VisualizationEnvironmentCatalog.presets.first { $0.id == .coloredMood }
    )

    XCTAssertEqual(
      VisualizationEnvironmentCatalog.matching(
        background: preset.background,
        environment: preset.environment,
        intensity: preset.intensity,
        rotationDegrees: preset.rotationDegrees
      ),
      preset
    )
    XCTAssertNil(
      VisualizationEnvironmentCatalog.matching(
        background: preset.background,
        environment: preset.environment,
        intensity: preset.intensity + 0.1,
        rotationDegrees: preset.rotationDegrees
      )
    )
  }
}
