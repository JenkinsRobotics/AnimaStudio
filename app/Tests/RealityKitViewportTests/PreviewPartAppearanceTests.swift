import AnimaEvaluation
import AnimaModel
import XCTest

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
  }
}
