import AnimaCAD
import AnimaCADViewport
import Foundation
import Testing
import simd

@Test func retainedRenderBackendsStayExplicitAndSTEPBacked() {
  #expect(CADRenderBackend.allCases.count == 4)
  #expect(CADRenderBackend.allCases.first == .metalKit)
  #expect(CADRenderBackend.metalKit.isPreferredSTEPVisualization)
  #expect(CADRenderBackend.realityKit.supportsNativeStudioInteraction)
}

@Test func realityKitIsRetiredFromTheSelectableCADEnginesAndDefaultsToWeb() {
  #expect(CADRenderBackend.defaultBackend == .threeJSWebGPU)
  #expect(!CADRenderBackend.selectable.contains(.realityKit))
  #expect(CADRenderBackend.selectable == [.metalKit, .threeJSWebGPU, .rawWebGPU])
  // A stored RealityKit choice migrates onto the default; others are unchanged.
  #expect(CADRenderBackend.realityKit.selectableOrDefault == .threeJSWebGPU)
  #expect(CADRenderBackend.metalKit.selectableOrDefault == .metalKit)
  #expect(CADRenderBackend.rawWebGPU.selectableOrDefault == .rawWebGPU)
}

@Test func coordinatedThemesChangeTheWholeRenderEnvironment() {
  #expect(CADViewportTheme.all.count == 10)
  #expect(Set(CADViewportTheme.all.map(\.name)).count == CADViewportTheme.all.count)
  #expect(CADViewportTheme.studioBlue.background != CADViewportTheme.onshape.background)
  #expect(CADViewportTheme.studioBlue.key != CADViewportTheme.onshape.key)
  #expect(CADViewportTheme.studioBlue.edgeColor != CADViewportTheme.onshape.edgeColor)
  #expect(CADViewportTheme.studioBlue.roughness != CADViewportTheme.onshape.roughness)
}

@Test func kernelFixtureProducesTopologyAndRendererBuffers() throws {
  let document = try CADGeometryDocument.makeTestDocument()
  #expect(!document.faces.isEmpty)
  #expect(!document.edges.isEmpty)
  #expect(!document.nodes.isEmpty)
  #expect(document.triangleCount > 0)
  #expect(document.renderGeometry.vertexCount > 0)
  #expect(document.metrics.triangulationMilliseconds >= 0)
}

@Test func malformedSTEPReturnsAnErrorInsteadOfCrashing() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    "anima-cad-malformed-\(UUID().uuidString).step")
  try "This is not a STEP document.".write(to: url, atomically: true, encoding: .utf8)
  defer { try? FileManager.default.removeItem(at: url) }
  #expect(throws: CADGeometryImportError.self) {
    _ = try CADGeometryDocument.loadSTEP(url)
  }
}

@Test func workspaceReferenceGeometryDefaultsVisibleAndTogglesIndependently() {
  var visibility = CADReferenceGeometryVisibility()
  for geometry in CADReferenceGeometry.allCases {
    #expect(visibility.contains(geometry))
  }

  visibility.toggle(.frontPlane)
  #expect(!visibility.contains(.frontPlane))
  #expect(visibility.contains(.origin))
  #expect(visibility.contains(.topPlane))
  #expect(visibility.contains(.rightPlane))
}

@Test func workspaceReferenceGeometryUsesOneModelScaledPresentation() {
  let presentation = CADWorkspaceReferenceGeometry(
    visibility: CADReferenceGeometryVisibility(showsRightPlane: false),
    modelDiagonalMeters: 2,
    gridDivisions: 12
  )
  #expect(presentation.planeSizeMeters == 2.5)
  #expect(presentation.axisLengthMeters == 0.7)
  #expect(presentation.gridDivisions == 12)
  #expect(!presentation.visibility.showsRightPlane)
}

@Test func partRestTransformMatchesAnimaCoreIntrinsicXYZConvention() {
  let transform = CADPartRestTransform(
    positionMeters: [0.5, -0.25, 1],
    rotationEulerRadians: [.pi / 2, 0, .pi / 2]
  )
  let transformed = transform.matrix * SIMD4<Float>(1, 0, 0, 1)

  #expect(abs(transformed.x - 0.5) < 0.000_01)
  #expect(abs(transformed.y + 0.25) < 0.000_01)
  #expect(abs(transformed.z - 2) < 0.000_01)
  #expect(abs(transformed.w - 1) < 0.000_01)
}

@Test func partOriginPresentationKeepsOneColumnMajorMatrixForBothRenderers() throws {
  let source = CADPartOriginPresentation(
    transform: CADPartRestTransform(
      positionMeters: [1, 2, 3],
      rotationEulerRadians: [0, 0, .pi / 2]
    ),
    axisLengthMeters: 0.4
  )
  let decoded = try JSONDecoder().decode(
    CADPartOriginPresentation.self,
    from: JSONEncoder().encode(source)
  )

  #expect(decoded == source)
  #expect(decoded.matrixColumnMajor.count == 16)
  #expect(decoded.matrix.columns.3 == SIMD4<Float>(1, 2, 3, 1))
  #expect(decoded.axisLengthMeters == 0.4)
}

@Test func partTransformPresentationKeepsTheNodePlusOnePartID() throws {
  let transform = CADPartRestTransform(
    positionMeters: [0.2, 0.3, 0.4],
    rotationEulerRadians: [0.1, 0.2, 0.3]
  )
  let source = CADPartTransformPresentation(partID: 42, matrix: transform.matrix)
  let decoded = try JSONDecoder().decode(
    CADPartTransformPresentation.self,
    from: JSONEncoder().encode(source)
  )

  #expect(decoded == source)
  #expect(decoded.partID == 42)
  #expect(decoded.matrix.columns.3 == SIMD4<Float>(0.2, 0.3, 0.4, 1))
}

@Test func gizmoDeltasEditTheRestTransformInItsLocalFrame() {
  let source = CADPartRestTransform(
    positionMeters: [1, 2, 3],
    rotationEulerRadians: [0, 0, .pi / 2]
  )
  let translated = source.translated(localAxis: .x, distanceMeters: 0.5)
  let rotated = source.rotated(localAxis: .z, angleRadians: 0.25)

  #expect(abs(translated.positionMeters[0] - 1) < 0.000_01)
  #expect(abs(translated.positionMeters[1] - 2.5) < 0.000_01)
  #expect(abs(translated.positionMeters[2] - 3) < 0.000_01)
  #expect(rotated.rotationEulerRadians == [0, 0, .pi / 2 + 0.25])
}

@Test func assemblyDeltaRoundTripsIntrinsicXYZTransform() {
  let source = CADPartRestTransform(
    positionMeters: [1, -2, 0.5],
    rotationEulerRadians: [0.2, -0.35, 0.6])
  let delta = CADPartRestTransform(
    positionMeters: [0.4, 0.1, -0.2],
    rotationEulerRadians: [-0.15, 0.25, 0.1]
  ).matrix
  let transformed = source.applyingAssemblyDelta(delta)
  let expected = delta * source.matrix

  for column in 0..<4 {
    #expect(simd_distance(transformed.matrix[column], expected[column]) < 0.000_1)
  }
}

@Test func viewportProjectionAnchorsTheOriginAndRejectsInvisiblePoints() throws {
  let viewProjection = CADViewportProjection.viewProjection(
    cameraPosition: SIMD3<Float>(0, 0, 2),
    cameraTarget: .zero,
    cameraUp: SIMD3<Float>(0, 1, 0),
    cameraDistance: 2,
    modelDiagonalMeters: 1,
    aspect: 1)
  let center = try #require(
    CADViewportProjection.project(
      worldPosition: .zero,
      viewProjection: viewProjection))

  #expect(abs(center.x - 0.5) < 0.000_01)
  #expect(abs(center.y - 0.5) < 0.000_01)
  #expect(
    CADViewportProjection.project(
      worldPosition: SIMD3<Float>(10, 0, 0),
      viewProjection: viewProjection) == nil)
  #expect(
    CADViewportProjection.project(
      worldPosition: SIMD3<Float>(0, 0, 3),
      viewProjection: viewProjection) == nil)
}
