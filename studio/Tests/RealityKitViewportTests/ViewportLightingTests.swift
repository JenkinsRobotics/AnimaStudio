import RealityKit
import XCTest

@testable import RealityKitViewport

@MainActor
final class ViewportLightingTests: XCTestCase {
  func testLightingPresetIdentifiersRemainStable() {
    XCTAssertEqual(
      ViewportLightingPreset.allCases.map(\.rawValue),
      ["balanced", "soft", "bright", "dramatic"]
    )
  }

  func testSoftLightingUsesMoreFillThanBalanced() {
    XCTAssertGreaterThan(
      ViewportLightingPreset.soft.configuration.fillMultiplier,
      ViewportLightingPreset.balanced.configuration.fillMultiplier
    )
  }

  func testLightingFactoryCreatesNamedKeyAndFillLights() throws {
    let lights = ViewportLightingFactory.makeLights(
      preset: .balanced,
      baseIntensity: 10_000
    )

    XCTAssertEqual(lights.map(\.name), ["viewportKeyLight", "viewportFillLight"])
    let key = try XCTUnwrap(lights[0].components[DirectionalLightComponent.self])
    let fill = try XCTUnwrap(lights[1].components[DirectionalLightComponent.self])
    XCTAssertEqual(key.intensity, 10_000)
    XCTAssertEqual(fill.intensity, 2_800)
  }

  func testBrightLightingHasTheHighestCombinedIntensity() {
    let totals = Dictionary(
      uniqueKeysWithValues: ViewportLightingPreset.allCases.map { preset in
        let configuration = preset.configuration
        return (preset, configuration.keyMultiplier + configuration.fillMultiplier)
      }
    )

    XCTAssertEqual(totals.max(by: { $0.value < $1.value })?.key, .bright)
  }
}
