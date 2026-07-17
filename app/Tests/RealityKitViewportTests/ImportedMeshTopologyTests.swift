import AnimaModel
import XCTest

@testable import RealityKitViewport

final class ImportedMeshTopologyTests: XCTestCase {
  func testTriangulatedCubeBecomesSixFacesTwelveSharpEdgesAndEightCorners() {
    let topology = ImportedMeshTopologyBuilder.build(geometries: [cubeGeometry()])

    XCTAssertEqual(topology.faces.count, 6)
    XCTAssertEqual(topology.edges.count, 12)
    XCTAssertEqual(topology.corners.count, 8)
    XCTAssertEqual(topology.boundsExtent, 2, accuracy: 0.0001)
    XCTAssertTrue(topology.faces.allSatisfy { $0.triangles.count == 2 })
  }

  func testCoplanarTriangleDiagonalIsNotAFeatureEdge() {
    let geometry = ImportedMeshGeometry(
      name: "Quad",
      positions: [
        SIMD3(-1, -1, 0), SIMD3(1, -1, 0), SIMD3(1, 1, 0), SIMD3(-1, 1, 0),
      ],
      indices: [0, 1, 2, 0, 2, 3]
    )

    let topology = ImportedMeshTopologyBuilder.build(geometries: [geometry])

    XCTAssertEqual(topology.faces.count, 1)
    XCTAssertEqual(topology.faces[0].triangles.count, 2)
    XCTAssertEqual(topology.edges.count, 1, "the four boundary segments form one polyline")
    XCTAssertEqual(topology.edges[0].points.count, 5, "the closed polyline repeats its start")
    XCTAssertEqual(topology.corners.count, 0, "a corner requires at least three feature edges")
  }

  func testSTLStyleDuplicateVerticesAreWeldedBeforeAdjacencyAnalysis() {
    let uniqueCube = cubeGeometry()
    var expandedPositions: [SIMD3<Float>] = []
    var expandedIndices: [UInt32] = []
    for index in uniqueCube.indices {
      expandedIndices.append(UInt32(expandedPositions.count))
      expandedPositions.append(uniqueCube.positions[Int(index)])
    }
    let expanded = ImportedMeshGeometry(
      name: "Expanded Cube",
      positions: expandedPositions,
      indices: expandedIndices
    )

    let topology = ImportedMeshTopologyBuilder.build(geometries: [expanded])

    XCTAssertEqual(topology.faces.count, 6)
    XCTAssertEqual(topology.edges.count, 12)
    XCTAssertEqual(topology.corners.count, 8)
  }

  func testDirectionalBoxSelectionUsesWindowAndCrossingRules() {
    let start = CGPoint(x: 10, y: 10)
    XCTAssertEqual(
      BoxSelectionState.mode(start: start, current: CGPoint(x: 100, y: 80)),
      .window
    )
    XCTAssertEqual(
      BoxSelectionState.mode(start: start, current: CGPoint(x: -50, y: 80)),
      .crossing
    )

    let selection = CGRect(x: 0, y: 0, width: 100, height: 100)
    let enclosed = CGRect(x: 20, y: 20, width: 20, height: 20)
    let touching = CGRect(x: 90, y: 90, width: 30, height: 30)
    XCTAssertTrue(BoxSelectionState.includes(enclosed, in: selection, mode: .window))
    XCTAssertFalse(BoxSelectionState.includes(touching, in: selection, mode: .window))
    XCTAssertTrue(BoxSelectionState.includes(touching, in: selection, mode: .crossing))
  }

  @MainActor
  func testModelLoaderReturnsCachedTopologyAlongsideRenderableSTL() async throws {
    let modelURL = try XCTUnwrap(
      Bundle.module.url(
        forResource: "MillimeterTriangle",
        withExtension: "stl",
        subdirectory: "Fixtures"
      )
    )

    let first = try await RealityKitModelLoader.loadWithTopology(
      contentsOf: modelURL,
      unitScaleToMeters: 0.001
    )
    let second = try await RealityKitModelLoader.loadWithTopology(
      contentsOf: modelURL,
      unitScaleToMeters: 0.001
    )

    let firstTopology = try XCTUnwrap(first.topology)
    XCTAssertEqual(firstTopology, second.topology)
    XCTAssertEqual(firstTopology.faces.count, 1)
    XCTAssertEqual(first.entity.visualBounds(relativeTo: nil).extents.x, 1, accuracy: 0.0001)
  }

  @MainActor
  func testUSDModelNodeTopologyIsScopedToTheSelectedSubtree() async throws {
    let modelURL = try XCTUnwrap(
      Bundle.module.url(
        forResource: "SimpleRobot",
        withExtension: "usda",
        subdirectory: "Fixtures"
      )
    )

    let loaded = try await RealityKitModelLoader.loadWithTopology(
      contentsOf: modelURL,
      modelNode: "SimpleRobot/HeadYaw/Head"
    )

    let topology = try XCTUnwrap(loaded.topology)
    XCTAssertEqual(topology.faces.count, 6)
    XCTAssertEqual(topology.edges.count, 12)
    XCTAssertEqual(topology.corners.count, 8)
  }

  @MainActor
  func testOverlayFeedsMeshFeaturesIntoTheExistingViewportPickContract() async throws {
    let part = RigPartDefinition(displayName: "Imported", primitiveKind: .box)
    let topology = ImportedMeshTopologyBuilder.build(geometries: [cubeGeometry()])
    let layer = await MeshFeatureOverlayFactory.make(partID: part.id, topology: topology)
    let featureEntity = try XCTUnwrap(
      layer.children.first { $0.components[MeshFeatureComponent.self] != nil }
    )
    let candidate = try XCTUnwrap(MeshFeatureOverlayFactory.candidate(from: featureEntity))

    XCTAssertEqual(candidate.partID, part.id)
    XCTAssertEqual(candidate.featureKind, .faceCenter)
    XCTAssertEqual(
      RobotPreviewView.tapTarget(
        for: featureEntity,
        rig: CharacterRig(parts: [part], joints: [])
      ),
      .feature(candidate)
    )
  }

  private func cubeGeometry() -> ImportedMeshGeometry {
    let n: Float = -1
    let p: Float = 1
    let quads: [[SIMD3<Float>]] = [
      [SIMD3(n, n, p), SIMD3(p, n, p), SIMD3(p, p, p), SIMD3(n, p, p)],
      [SIMD3(p, n, n), SIMD3(n, n, n), SIMD3(n, p, n), SIMD3(p, p, n)],
      [SIMD3(p, n, p), SIMD3(p, n, n), SIMD3(p, p, n), SIMD3(p, p, p)],
      [SIMD3(n, n, n), SIMD3(n, n, p), SIMD3(n, p, p), SIMD3(n, p, n)],
      [SIMD3(n, p, p), SIMD3(p, p, p), SIMD3(p, p, n), SIMD3(n, p, n)],
      [SIMD3(n, n, n), SIMD3(p, n, n), SIMD3(p, n, p), SIMD3(n, n, p)],
    ]
    var positions: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    for quad in quads {
      let base = UInt32(positions.count)
      positions.append(contentsOf: quad)
      indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
    }
    return ImportedMeshGeometry(name: "Cube", positions: positions, indices: indices)
  }
}
