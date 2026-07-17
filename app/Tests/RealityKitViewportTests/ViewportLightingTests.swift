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

  func testShadowToggleControlsTheKeyLightShadowComponent() {
    let shadowed = ViewportLightingFactory.makeLights(
      preset: .balanced,
      baseIntensity: 10_000,
      showsShadows: true
    )
    let unshadowed = ViewportLightingFactory.makeLights(
      preset: .balanced,
      baseIntensity: 10_000,
      showsShadows: false
    )

    XCTAssertNotNil(shadowed[0].components[DirectionalLightComponent.Shadow.self])
    XCTAssertNil(shadowed[1].components[DirectionalLightComponent.Shadow.self])
    XCTAssertNil(unshadowed[0].components[DirectionalLightComponent.Shadow.self])
  }

  func testReflectionModesRemainStableAndStudioIsBrighterThanSubtle() {
    XCTAssertEqual(
      ViewportReflectionMode.allCases.map(\.rawValue),
      ["off", "subtle", "studio"]
    )
    XCTAssertGreaterThan(
      ViewportReflectionMode.studio.intensityExponent,
      ViewportReflectionMode.subtle.intensityExponent
    )
  }

  func testEnvironmentAndQualityChoicesRemainStable() {
    XCTAssertEqual(
      ViewportEnvironmentPreset.allCases.map(\.rawValue),
      ["softbox", "rim", "warmStage"]
    )
    XCTAssertEqual(ViewportRenderQuality.allCases.map(\.rawValue), ["standard", "high"])
  }

  func testLightingIntensityScalesKeyAndFillTogether() throws {
    let lights = ViewportLightingFactory.makeLights(
      preset: .balanced,
      baseIntensity: 10_000,
      intensityMultiplier: 0.5
    )
    XCTAssertEqual(
      try XCTUnwrap(lights[0].components[DirectionalLightComponent.self]).intensity,
      5_000
    )
    XCTAssertEqual(
      try XCTUnwrap(lights[1].components[DirectionalLightComponent.self]).intensity,
      1_400
    )
  }
}
