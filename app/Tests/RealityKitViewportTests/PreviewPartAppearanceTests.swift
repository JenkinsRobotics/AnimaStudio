import AnimaEvaluation
import AnimaModel
import XCTest
import simd

@testable import RealityKitViewport

final class PreviewPartAppearanceTests: XCTestCase {
  func testHexRoundTripIsStableAndCaseInsensitive() throws {
    let appearance = try XCTUnwrap(PreviewPartAppearance(hexRGB: "#9dcfed"))

    XCTAssertEqual(appearance.hexRGB, "#9DCFED")
    XCTAssertEqual(appearance.red, 157.0 / 255.0, accuracy: 1e-12)
    XCTAssertEqual(appearance.green, 207.0 / 255.0, accuracy: 1e-12)
    XCTAssertEqual(appearance.blue, 237.0 / 255.0, accuracy: 1e-12)
  }

  func testInvalidHexIsRejected() {
    XCTAssertNil(PreviewPartAppearance(hexRGB: "#FFF"))
    XCTAssertNil(PreviewPartAppearance(hexRGB: "#GGGGGG"))
  }

  func testComponentsAndOpacityAreClamped() {
    let appearance = PreviewPartAppearance(
      red: -1,
      green: 0.5,
      blue: 2,
      opacity: 4,
      isVisible: false
    )

    XCTAssertEqual(appearance.red, 0)
    XCTAssertEqual(appearance.green, 0.5)
    XCTAssertEqual(appearance.blue, 1)
    XCTAssertEqual(appearance.opacity, 1)
    XCTAssertFalse(appearance.isVisible)
  }

  func testLocatorAndSolidDefaultsRemainDistinct() {
    XCTAssertNotEqual(
      PreviewPartAppearance.defaultAppearance(for: .locator),
      PreviewPartAppearance.defaultAppearance(for: .box)
    )
    XCTAssertEqual(
      PreviewPartAppearance.defaultAppearance(for: .box),
      PreviewPartAppearance.defaultAppearance(for: .sphere)
    )
    XCTAssertEqual(
      PreviewPartAppearance.defaultAppearance(for: .box).proxyFilletRadiusMeters,
      0,
      "generated boxes must be sharp unless the operator adds a fillet"
    )
  }

  func testProxyFilletRadiusIsClampedToValidBoxRange() {
    let negative = PreviewPartAppearance(
      red: 0.2, green: 0.4, blue: 0.8, proxyFilletRadiusMeters: -1)
    let excessive = PreviewPartAppearance(
      red: 0.2, green: 0.4, blue: 0.8, proxyFilletRadiusMeters: 10)

    XCTAssertEqual(negative.proxyFilletRadiusMeters, 0)
    XCTAssertEqual(
      excessive.proxyFilletRadiusMeters,
      PreviewPartAppearance.maximumProxyFilletRadiusMeters
    )
  }

  func testCharacterSpaceEulerUsesEngineIntrinsicXYZOrder() {
    let rotation = RigVector3(x: 0.3, y: -0.2, z: 0.7)
    let actual = CharacterSpaceTransform.orientation(rotationEulerRadians: rotation)
    let x = simd_quatf(angle: 0.3, axis: SIMD3<Float>(1, 0, 0))
    let y = simd_quatf(angle: -0.2, axis: SIMD3<Float>(0, 1, 0))
    let z = simd_quatf(angle: 0.7, axis: SIMD3<Float>(0, 0, 1))
    let expected = simd_normalize(x * y * z)
    let reversed = simd_normalize(z * y * x)

    XCTAssertEqual(abs(simd_dot(actual.vector, expected.vector)), 1, accuracy: 1e-6)
    XCTAssertLessThan(abs(simd_dot(actual.vector, reversed.vector)), 0.999)
  }
}
