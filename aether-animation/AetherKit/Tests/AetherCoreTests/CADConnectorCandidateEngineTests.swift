import Foundation
import Testing
import simd

@testable import AetherKernel
@testable import AetherViewport

/// The discrete snap-candidate engine ported from the OCCT Mate Lab: exact
/// nodes (face center, circle center, edge midpoint, vertex), never an
/// arbitrary cursor point.
@Suite struct CADConnectorCandidateEngineTests {
  private func circleEdge(
    id: Int, radius: Float, center: SIMD3<Float>, samples: Int = 32
  ) -> CADEdge {
    let points = (0...samples).map { index -> SIMD3<Float> in
      let angle = Float(index) / Float(samples) * 2 * .pi
      return center + SIMD3(cos(angle) * radius, sin(angle) * radius, 0)
    }
    return CADEdge(id: id, points: points, assemblyNode: 0)
  }

  @Test func circularEdgeYieldsExactCenterAndAxis() throws {
    let edge = circleEdge(id: 7, radius: 0.05, center: SIMD3(0.1, 0.2, 0.3))
    let circle = try #require(CADConnectorCandidateEngine.circleCenter(of: edge))
    #expect(simd_distance(circle.center, SIMD3(0.1, 0.2, 0.3)) < 0.001)
    // Circle in the XY plane: axis is ±Z.
    #expect(abs(abs(circle.axis.z) - 1) < 0.001)
  }

  @Test func openPolylineIsNotACircle() {
    let open = CADEdge(
      id: 1,
      points: (0...10).map { SIMD3(Float($0) * 0.01, 0, 0) },
      assemblyNode: 0)
    #expect(CADConnectorCandidateEngine.circleCenter(of: open) == nil)
  }

  @Test func arcMidpointIsHalfwayByLengthNotByIndex() throws {
    // Uneven sampling: three points, second segment twice the first. The
    // true arc midpoint sits inside the longer segment.
    let points: [SIMD3<Float>] = [
      SIMD3(0, 0, 0), SIMD3(0.01, 0, 0), SIMD3(0.03, 0, 0),
    ]
    let midpoint = try #require(CADConnectorCandidateEngine.arcMidpoint(of: points))
    #expect(abs(midpoint.point.x - 0.015) < 0.000_1)
    #expect(simd_distance(midpoint.tangent, SIMD3(1, 0, 0)) < 0.001)
  }

  @Test func kernelFixtureEnumeratesDiscreteDedupedCandidates() throws {
    let document = try CADGeometryDocument.makeTestDocument()
    let face = try #require(document.faces.first)
    let candidates = CADConnectorCandidateEngine.candidates(
      nodeIndex: face.assemblyNode,
      hitFaceID: face.id,
      hitNormal: face.normals.first ?? SIMD3(0, 0, 1),
      document: document)

    #expect(candidates.contains { $0.kind == .faceCenter })
    #expect(candidates.contains { $0.kind == .vertex })
    // Epsilon dedup: no two candidates of one kind share an origin.
    for kind in [CADConnectorCandidateKind.vertex, .edgeMidpoint, .circleCenter] {
      let origins = candidates.filter { $0.kind == kind }.map(\.origin)
      for (index, origin) in origins.enumerated() {
        for other in origins[(index + 1)...] {
          #expect(simd_distance(origin, other) >= 0.000_001)
        }
      }
    }
    // Every candidate carries an orthonormal frame.
    for candidate in candidates {
      #expect(abs(simd_length(candidate.zAxis) - 1) < 0.001)
      #expect(abs(simd_dot(candidate.zAxis, candidate.xAxis)) < 0.01)
    }
  }
}
