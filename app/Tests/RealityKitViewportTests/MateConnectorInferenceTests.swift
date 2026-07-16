import AnimaEvaluation
import AnimaModel
import XCTest
import simd

@testable import RealityKitViewport

final class MateConnectorInferenceTests: XCTestCase {
  func testBoxOffersFaceEdgeAndCornerAttachmentChoices() {
    let part = RigPartDefinition(displayName: "Box", primitiveKind: .box)

    let candidates = MateConnectorInference.candidates(for: part)

    XCTAssertEqual(candidates.count, 26)
    XCTAssertEqual(candidates.count { $0.featureKind == .faceCenter }, 6)
    XCTAssertEqual(candidates.count { $0.featureKind == .edgeMidpoint }, 12)
    XCTAssertEqual(candidates.count { $0.featureKind == .corner }, 8)
    XCTAssertEqual(Set(candidates.map(\.id)).count, candidates.count)
  }

  func testCylinderOffersAxisAndCircularFaceCenters() {
    let part = RigPartDefinition(displayName: "Cylinder", primitiveKind: .cylinder)

    let candidates = MateConnectorInference.candidates(for: part)

    XCTAssertEqual(candidates.map(\.id), ["axis-center", "face-top", "face-bottom"])
    XCTAssertEqual(candidates.first?.connector.primaryAxis, RigVector3(x: 0, y: 1, z: 0))
  }

  func testInferredConnectorFramesNormalizeToOrthonormalBases() {
    let part = RigPartDefinition(displayName: "Box", primitiveKind: .box)

    for candidate in MateConnectorInference.candidates(for: part) {
      let basis = MateConnectorMath.orthonormalBasis(for: candidate.connector)
      XCTAssertEqual(simd_length(basis.x), 1, accuracy: 1e-9)
      XCTAssertEqual(simd_length(basis.y), 1, accuracy: 1e-9)
      XCTAssertEqual(simd_length(basis.z), 1, accuracy: 1e-9)
      XCTAssertEqual(simd_dot(basis.x, basis.z), 0, accuracy: 1e-9)
    }
  }
}
