import Foundation
import XCTest

@testable import AnimaStudioUI

final class StudioDesignProfileTests: XCTestCase {
  func testStandardProfileRoundTripsDeterministically() throws {
    let firstEncoding = try StudioDesignPersistence.encode(.standard)
    let decoded = try StudioDesignPersistence.decode(firstEncoding)
    let secondEncoding = try StudioDesignPersistence.encode(decoded)

    XCTAssertEqual(decoded, .standard)
    XCTAssertEqual(firstEncoding, secondEncoding)
  }

  func testUnsafeImportedMeasurementsAreClampedToReadableRanges() {
    var profile = StudioDesignProfile.standard
    profile.fieldHeight = -100
    profile.navigatorWidth = 9_999
    profile.borderOpacity = 3
    profile.accent.red = -2

    let clamped = profile.clamped()

    XCTAssertEqual(clamped.fieldHeight, 26)
    XCTAssertEqual(clamped.navigatorWidth, 420)
    XCTAssertEqual(clamped.borderOpacity, 0.5)
    XCTAssertEqual(clamped.accent.red, 0)
  }

  func testPersistenceUsesOneVersionedProfileValue() throws {
    let suiteName = "StudioDesignProfileTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      return XCTFail("Could not create isolated defaults")
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    XCTAssertEqual(StudioDesignPersistence.load(from: defaults), .standard)
    StudioDesignPersistence.save(.compact, to: defaults)
    XCTAssertEqual(StudioDesignPersistence.load(from: defaults), .compact)
    StudioDesignPersistence.reset(defaults)
    XCTAssertEqual(StudioDesignPersistence.load(from: defaults), .standard)
  }

  func testBuiltInPresetsAreDistinctAndValid() {
    XCTAssertEqual(StudioDesignPreset.allCases, [.standard, .compact, .highContrast])
    XCTAssertNotEqual(StudioDesignProfile.standard, .compact)
    XCTAssertNotEqual(StudioDesignProfile.standard, .highContrast)

    for preset in StudioDesignPreset.allCases {
      XCTAssertEqual(preset.profile, preset.profile.clamped())
      XCTAssertFalse(preset.title.isEmpty)
    }
  }
}
