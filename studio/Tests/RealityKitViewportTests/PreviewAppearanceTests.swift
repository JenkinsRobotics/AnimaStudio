import XCTest

@testable import RealityKitViewport

final class PreviewAppearanceTests: XCTestCase {
  func testProfessionalAppearancePresetsStayStable() {
    XCTAssertEqual(
      PreviewAppearance.allCases.map(\.rawValue),
      ["midnight", "graphite", "cadLight", "blueprint"]
    )
    XCTAssertEqual(Set(PreviewAppearance.allCases.map(\.title)).count, 4)
  }
}
