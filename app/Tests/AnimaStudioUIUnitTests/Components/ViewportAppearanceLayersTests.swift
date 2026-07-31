import XCTest

@testable import AnimaCADViewport

final class ViewportAppearanceLayersTests: XCTestCase {
  // MARK: - Lighting slider curve

  func testSliderEndpointsAreOffNominalAndBlinding() {
    XCTAssertEqual(CADLightingScale.multiplier(position: 0), 0)
    XCTAssertEqual(CADLightingScale.multiplier(position: 0.5), 1, accuracy: 0.0001)
    XCTAssertEqual(CADLightingScale.multiplier(position: 1), 4)
  }

  func testSliderPositionsClampOutOfRange() {
    XCTAssertEqual(CADLightingScale.multiplier(position: -3), 0)
    XCTAssertEqual(CADLightingScale.multiplier(position: 7), 4)
  }

  func testPositionMultiplierRoundTrip() {
    for t: Float in [0, 0.1, 0.25, 0.5, 0.77, 1] {
      let roundTrip = CADLightingScale.position(
        multiplier: CADLightingScale.multiplier(position: t))
      XCTAssertEqual(roundTrip, t, accuracy: 0.0001)
    }
  }

  func testIntensityAgainstNominalRoundTrip() {
    let nominal: Float = 4_400
    let intensity = CADLightingScale.intensity(
      position: 0.5, nominal: nominal, fallbackNominal: 1)
    XCTAssertEqual(intensity, nominal, accuracy: 0.01)
    let position = CADLightingScale.position(
      intensity: intensity, nominal: nominal, fallbackNominal: 1)
    XCTAssertEqual(position, 0.5, accuracy: 0.0001)
  }

  func testZeroNominalFallsBackSoSliderStillWorks() {
    let intensity = CADLightingScale.intensity(
      position: 1, nominal: 0, fallbackNominal: 1_200)
    XCTAssertEqual(intensity, 4_800, accuracy: 0.01)
  }

  // MARK: - Theme layer fields

  func testThemeDefaultsToSolidBackgroundAndKeepsExistingCallSites() {
    let theme = CADViewportTheme.onshape
    XCTAssertNil(theme.backgroundBottom)
    XCTAssertGreaterThan(theme.floorColor.x, 0)
  }

  func testGradientBackgroundCarriesBottomColor() {
    var theme = CADViewportTheme.onshape
    theme.backgroundBottom = SIMD3(0.1, 0.2, 0.3)
    XCTAssertEqual(theme.backgroundBottom, SIMD3(0.1, 0.2, 0.3))
  }
}
