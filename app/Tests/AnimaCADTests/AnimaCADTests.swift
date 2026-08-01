import AnimaCAD
import Foundation
import Metal
import Testing
import simd

@testable import AnimaCADViewport

private enum CADSourceFixtureError: LocalizedError, Sendable {
  case unreadable

  var errorDescription: String? { "Fixture source is unreadable" }
}

@Test func cadSourceBatchKeepsHealthyDocumentsWhenOneSourceFails() throws {
  let first = URL(fileURLWithPath: "/tmp/base.step")
  let missing = URL(fileURLWithPath: "/tmp/missing.step")
  let third = URL(fileURLWithPath: "/tmp/head.step")

  let batch = CADSourceLoadBatch.importing([first, missing, third]) { url in
    if url == missing { throw CADSourceFixtureError.unreadable }
    return try CADGeometryDocument.makeTestDocument()
  }

  #expect(batch.document != nil)
  #expect(batch.triangleCountsByURL.keys.sorted(by: { $0.path < $1.path }) == [first, third])
  #expect(batch.failuresByURL[missing] == "Fixture source is unreadable")
  #expect(batch.partIDRangesByURL[first]?.lowerBound == 0)
  #expect(
    batch.partIDRangesByURL[third]?.lowerBound
      == batch.partIDRangesByURL[first]?.upperBound
  )
}

@Test func cadSourceBatchLeavesAnEmptyUsableViewportWhenEverySourceFails() {
  let missing = URL(fileURLWithPath: "/tmp/missing.step")
  let batch = CADSourceLoadBatch.importing([missing]) { _ in
    throw CADSourceFixtureError.unreadable
  }

  #expect(batch.document == nil)
  #expect(batch.partIDRangesByURL.isEmpty)
  #expect(batch.triangleCountsByURL.isEmpty)
  #expect(batch.failuresByURL[missing] == "Fixture source is unreadable")
}

@Test func retainedRenderBackendsStayExplicitAndSTEPBacked() {
  #expect(CADRenderBackend.allCases.count == 4)
  #expect(CADRenderBackend.allCases.first == .metalKit)
  #expect(CADRenderBackend.metalKit.isPreferredSTEPVisualization)
  #expect(CADRenderBackend.realityKit.supportsNativeStudioInteraction)
}

@MainActor
@Test func cadCameraOrientationRoundTripsWorldDirectionAndRoll() {
  let camera = CADCameraState()
  let requested = CADCameraOrientationPresentation(
    direction: SIMD3<Float>(0.42, 0.71, -0.56),
    rollRadians: .pi / 3
  )

  camera.set(orientation: requested)
  let reported = camera.orientationPresentation

  #expect(simd_distance(reported.direction, requested.direction) < 0.000_01)
  #expect(abs(reported.rollRadians - requested.rollRadians) < 0.000_01)

  camera.orbit(deltaX: 18, deltaY: -11)
  #expect(simd_distance(camera.orientationPresentation.direction, requested.direction) > 0.001)
  #expect(abs(camera.orientationPresentation.rollRadians - requested.rollRadians) < 0.000_01)
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
  #expect(CADViewportTheme.all.count == 12)
  #expect(Set(CADViewportTheme.all.map(\.name)).count == CADViewportTheme.all.count)
  #expect(CADViewportTheme.defaultTheme == .onshape)
  #expect(CADViewportTheme.named(nil) == .onshape)
  #expect(CADViewportTheme.named("Missing theme") == .onshape)
  #expect(CADViewportTheme.studioBlue.background != CADViewportTheme.onshape.background)
  #expect(CADViewportTheme.studioBlue.key != CADViewportTheme.onshape.key)
  #expect(CADViewportTheme.studioBlue.edgeColor != CADViewportTheme.onshape.edgeColor)
  #expect(CADViewportTheme.studioBlue.roughness != CADViewportTheme.onshape.roughness)
  #expect(CADViewportTheme.onshape.background.min() > 0.98)
  #expect(CADViewportTheme.onshape.edgeColor.max() < 0.15)
  #expect(CADViewportTheme.onshape.neutralColor.z > CADViewportTheme.onshape.neutralColor.x)
  #expect(CADViewportTheme.onshape.key.intensity >= 4_000)
  #expect(CADViewportTheme.onshape.fill.intensity < CADViewportTheme.onshape.key.intensity * 0.5)
  #expect(CADViewportTheme.onshape.ambientStrength < 0.3)
  #expect(CADViewportTheme.onshape.shadowStrength > 0.65)
}

@Test func metalLightingUsesSRGBAndSeparatesTopFromUnderside() {
  #expect(CADMetalLightingModel.colorPixelFormat == .bgra8Unorm_srgb)
  #expect(CADMetalLightingModel.ambientFloorScale < 0.5)
  #expect(CADMetalLightingModel.ambientCeilingScale > 1)

  let view = SIMD3<Float>(0, 0, 1)
  let front = CADMetalLightingModel.readableNormal([0, 0, 1], viewDirection: view)
  let reversed = CADMetalLightingModel.readableNormal([0, 0, -1], viewDirection: view)
  let missing = CADMetalLightingModel.readableNormal(.zero, viewDirection: view)

  #expect(front == view)
  #expect(reversed == view)
  #expect(missing == view)
  let underside = CADMetalLightingModel.ambientLevel(normalY: -1, strength: 0.24)
  let topside = CADMetalLightingModel.ambientLevel(normalY: 1, strength: 0.24)
  #expect(underside < 0.11)
  #expect(topside > underside * 3)
  #expect(CADMetalLightingModel.ambientLevel(normalY: 1, strength: 0) == 0)
  #expect(CADMetalLightingModel.ambientLevel(normalY: -1, strength: 0) == 0)

  #expect(CADMetalLightingModel.darkMaterialLift(sourceLuminance: 0, lightingEnergy: 0) == 0)
  #expect(CADMetalLightingModel.darkMaterialLift(sourceLuminance: 0, lightingEnergy: 1) > 0.05)
  #expect(CADMetalLightingModel.darkMaterialLift(sourceLuminance: 0.5, lightingEnergy: 1) == 0)
}

@Test func viewportPerformanceUsesRendererFramesAndTargetsStableSixtyHz() {
  let snapshot = CADViewportPerformanceSnapshot(
    framesPerSecond: 60,
    cpuPercent: 12.5,
    memoryMegabytes: 256)

  #expect(CADMetalRendererPolicy.preferredFramesPerSecond == 60)
  #expect(snapshot.frameTimeMilliseconds == 1_000 / 60.0)
  #expect(CADViewportPerformanceSnapshot.waiting.frameTimeMilliseconds == nil)
}

@Test func metalEdgeDefinitionMapsToVisibleScreenSpaceWidth() {
  #expect(CADMetalEdgeStyle.offsetsPixels(strength: 0).isEmpty)
  #expect(CADMetalEdgeStyle.offsetsPixels(strength: 0.1) == [0])
  #expect(CADMetalEdgeStyle.offsetsPixels(strength: 0.5).count == 3)
  #expect(CADMetalEdgeStyle.offsetsPixels(strength: 1).count == 5)
  #expect(CADMetalEdgeStyle.widthPixels(strength: 1) >= 3)
  #expect(CADMetalEdgeStyle.opacity(strength: 1) == 1)
}

@Test @MainActor func metalRendererBuildsItsRuntimeShaderAndPipelines() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  try CADMetalRuntimeValidation.validateRenderer(device: device)
}

@Test func kernelFixtureProducesTopologyAndRendererBuffers() throws {
  let document = try CADGeometryDocument.makeTestDocument()
  #expect(!document.faces.isEmpty)
  #expect(!document.edges.isEmpty)
  #expect(!document.nodes.isEmpty)
  #expect(document.triangleCount > 0)
  #expect(document.renderGeometry.vertexCount > 0)
  #expect(document.renderGeometry.edgePartIDs.count == document.renderGeometry.edgePositions.count)
  #expect(document.renderGeometry.edgePartIDs.contains { $0 > 0 })
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
  #expect(presentation.showsFloorGrid)
  #expect(presentation.floorGridSpacingMeters == 0.1)
  #expect(presentation.floorGridExtentMeters == 8)
  #expect(presentation.floorGridMajorLineInterval == 5)
  #expect(presentation.floorGridOpacity == 0.24)
}

@Test func workspaceFloorGridSettingsAreBoundedForEveryRenderer() {
  let presentation = CADWorkspaceReferenceGeometry(
    visibility: .init(),
    modelDiagonalMeters: 0,
    showsFloorGrid: false,
    floorGridSpacingMeters: 0,
    floorGridExtentMultiplier: 100,
    floorGridMajorLineInterval: 1,
    floorGridOpacity: 2
  )

  #expect(!presentation.showsFloorGrid)
  #expect(presentation.floorGridSpacingMeters == 0.000_1)
  #expect(abs(presentation.floorGridExtentMeters - 0.02) < 0.000_001)
  #expect(presentation.floorGridMajorLineInterval == 2)
  #expect(presentation.floorGridOpacity == 0.9)
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

@Test func partAppearancePresentationClampsAndRoundTripsRendererValues() throws {
  let source = CADPartAppearancePresentation(
    partID: 42,
    color: SIMD4(-1, 0.25, 2, 0.65),
    roughness: 1.4,
    metallic: -0.2
  )
  let decoded = try JSONDecoder().decode(
    CADPartAppearancePresentation.self,
    from: JSONEncoder().encode(source)
  )

  #expect(decoded == source)
  #expect(decoded.partID == 42)
  #expect(decoded.color == SIMD4<Float>(0, 0.25, 1, 0.65))
  #expect(decoded.roughness == 1)
  #expect(decoded.metallic == 0)
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
  let expectedRotation =
    source.matrix
    * CADPartRestTransform(rotationEulerRadians: [0, 0, 0.25]).matrix
  for column in 0..<4 {
    #expect(simd_distance(rotated.matrix[column], expectedRotation[column]) < 0.000_1)
  }
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

@Test func gizmoDragUsesTheProjectedLocalAxesAndPlanes() {
  let frame = CADProjectedLocalFrame(
    origin: .init(x: 0.5, y: 0.5),
    xAxis: .init(x: 0.6, y: 0.5),
    yAxis: .init(x: 0.5, y: 0.4),
    zAxis: .init(x: 0.44, y: 0.56))
  let geometry = CADGizmoProjectedGeometry(
    projectedFrame: frame,
    viewportSize: CGSize(width: 1_000, height: 1_000))

  #expect(
    abs(
      CADGizmoInteraction.axisDragPoints(
        CGSize(width: 24, height: 0),
        projectedAxis: geometry.xAxis) - 24) < 0.000_1)
  #expect(
    abs(
      CADGizmoInteraction.axisDragPoints(
        CGSize(width: 0, height: -24),
        projectedAxis: geometry.yAxis) - 24) < 0.000_1)

  let plane = CADGizmoInteraction.planeDragPoints(
    CGSize(width: 18, height: -12),
    firstAxis: geometry.xAxis,
    secondAxis: geometry.yAxis)
  #expect(abs(plane.x - 18) < 0.000_1)
  #expect(abs(plane.y - 12) < 0.000_1)

  let quarterTurn = CADGizmoInteraction.rotationRadians(
    start: CGPoint(x: 1, y: 0),
    current: CGPoint(x: 0, y: 1),
    center: .zero,
    orientationSign: 1)
  #expect(abs(quarterTurn - .pi / 2) < 0.000_1)
}

@Test func gizmoAxesFollowTheRotatedPartFrame() throws {
  let viewProjection = CADViewportProjection.viewProjection(
    cameraPosition: SIMD3<Float>(0, 0, 3),
    cameraTarget: .zero,
    cameraUp: SIMD3<Float>(0, 1, 0),
    cameraDistance: 3,
    modelDiagonalMeters: 1,
    aspect: 1)
  let identity = try #require(
    CADProjectedLocalFrame(
      localFrame: matrix_identity_float4x4,
      axisLengthMeters: 0.5,
      viewProjection: viewProjection))
  let rotated = try #require(
    CADProjectedLocalFrame(
      localFrame: CADPartRestTransform(
        rotationEulerRadians: [0, 0, .pi / 2]
      ).matrix,
      axisLengthMeters: 0.5,
      viewProjection: viewProjection))
  let identityGeometry = CADGizmoProjectedGeometry(
    projectedFrame: identity,
    viewportSize: CGSize(width: 800, height: 800))
  let rotatedGeometry = CADGizmoProjectedGeometry(
    projectedFrame: rotated,
    viewportSize: CGSize(width: 800, height: 800))
  let identityX = simd_normalize(identityGeometry.xAxis)
  let rotatedX = simd_normalize(rotatedGeometry.xAxis)

  #expect(abs(simd_dot(identityX, rotatedX)) < 0.001)
}

@Test func selectionGizmoUsesTheCombinedRenderedBoundsCenter() {
  let subject = CADPartRestTransform(
    positionMeters: [0, 0, 0],
    rotationEulerRadians: [0, 0, .pi / 2])
  let bounds: [Int: CADPartLocalBounds] = [
    1: CADPartLocalBounds(
      minimum: SIMD3<Float>(-1, -1, -1),
      maximum: SIMD3<Float>(1, 1, 1)),
    2: CADPartLocalBounds(
      minimum: SIMD3<Float>(-1, -1, -1),
      maximum: SIMD3<Float>(1, 1, 1)),
  ]
  var secondTransform = matrix_identity_float4x4
  secondTransform.columns.3 = SIMD4(8, 2, 0, 1)

  let centered = CADSelectionGizmoPlacement.centeredTransform(
    subjectTransform: subject,
    selectedPartIDs: [1, 2],
    localBoundsByPartID: bounds,
    partTransforms: [
      1: matrix_identity_float4x4,
      2: secondTransform,
    ])

  #expect(abs(centered.positionMeters[0] - 4) < 0.000_01)
  #expect(abs(centered.positionMeters[1] - 1) < 0.000_01)
  #expect(abs(centered.positionMeters[2]) < 0.000_01)
  #expect(abs(centered.rotationEulerRadians[2] - .pi / 2) < 0.000_01)
}

@Test func centeredGizmoEditsMapBackToTheSemanticOrigin() {
  let subject = CADPartRestTransform(
    positionMeters: [1, 2, 3],
    rotationEulerRadians: [0, 0, 0])
  let centered = CADPartRestTransform(
    positionMeters: [5, 2, 3],
    rotationEulerRadians: [0, 0, 0])
  let movedGizmo = CADPartRestTransform(
    positionMeters: [5, 7, 3],
    rotationEulerRadians: [0, 0, 0])

  let movedSubject = CADSelectionGizmoPlacement.subjectTransform(
    for: movedGizmo,
    currentGizmoTransform: centered,
    currentSubjectTransform: subject)

  #expect(abs(movedSubject.positionMeters[0] - 1) < 0.000_01)
  #expect(abs(movedSubject.positionMeters[1] - 7) < 0.000_01)
  #expect(abs(movedSubject.positionMeters[2] - 3) < 0.000_01)
}

@Test func directPartDragMovesInTheCameraFacingPlane() {
  let source = CADPartRestTransform(
    positionMeters: [0, 0, 0],
    rotationEulerRadians: [0.1, 0.2, 0.3])
  let moved = CADDirectManipulation.translated(
    source,
    screenTranslation: CGSize(width: 100, height: 50),
    viewportHeightPoints: 1_000,
    cameraPosition: SIMD3<Float>(0, 0, 2),
    cameraTarget: .zero,
    cameraUp: SIMD3<Float>(0, 1, 0))

  #expect(moved.positionMeters[0] > 0)
  #expect(moved.positionMeters[1] > 0)
  #expect(abs(moved.positionMeters[2]) < 0.000_001)
  #expect(moved.rotationEulerRadians == source.rotationEulerRadians)
}

@Test func directPartDragKeepsDepthScaleStableFromTheGestureStart() {
  let near = CADDirectManipulation.translated(
    CADPartRestTransform(positionMeters: [0, 0, 1]),
    screenTranslation: CGSize(width: 100, height: 0),
    viewportHeightPoints: 1_000,
    cameraPosition: SIMD3<Float>(0, 0, 2),
    cameraTarget: .zero,
    cameraUp: SIMD3<Float>(0, 1, 0))
  let far = CADDirectManipulation.translated(
    CADPartRestTransform(positionMeters: [0, 0, -2]),
    screenTranslation: CGSize(width: 100, height: 0),
    viewportHeightPoints: 1_000,
    cameraPosition: SIMD3<Float>(0, 0, 2),
    cameraTarget: .zero,
    cameraUp: SIMD3<Float>(0, 1, 0))

  #expect(far.positionMeters[0] > near.positionMeters[0])
}

@Test func metalPartPickerUsesVisibleTransformedNodePlusOneIDs() throws {
  let document = try CADGeometryDocument.makeTestDocument()
  let geometry = document.renderGeometry
  let center = geometry.bounds.center
  let diagonal = max(geometry.bounds.diagonal, 0.001)
  let cameraPosition = center + SIMD3<Float>(0, 0, diagonal * 2)
  let viewProjection = CADViewportProjection.viewProjection(
    cameraPosition: cameraPosition,
    cameraTarget: center,
    cameraUp: SIMD3<Float>(0, 1, 0),
    cameraDistance: diagonal * 2,
    modelDiagonalMeters: diagonal,
    aspect: 1)
  let viewportSize = CGSize(width: 200, height: 200)
  let picked = try #require(
    CADMetalPartPicker.partID(
      at: CGPoint(x: 100, y: 100),
      viewportSize: viewportSize,
      geometry: geometry,
      viewProjection: viewProjection,
      hiddenPartIDs: [],
      partTransforms: []))

  #expect(picked > 0)
  #expect(
    CADMetalPartPicker.partID(
      at: CGPoint(x: 100, y: 100),
      viewportSize: viewportSize,
      geometry: geometry,
      viewProjection: viewProjection,
      hiddenPartIDs: [picked],
      partTransforms: []) == nil)

  let translated = CADPartTransformPresentation(
    partID: picked,
    matrix: CADPartRestTransform(positionMeters: [Double(diagonal) * 4, 0, 0]).matrix)
  #expect(
    CADMetalPartPicker.partID(
      at: CGPoint(x: 100, y: 100),
      viewportSize: viewportSize,
      geometry: geometry,
      viewProjection: viewProjection,
      hiddenPartIDs: [],
      partTransforms: [translated]) == nil)
}

@Test func metalFeaturePickerInfersAnExactConnectorFrame() throws {
  let document = try CADGeometryDocument.makeTestDocument()
  let geometry = document.renderGeometry
  let center = geometry.bounds.center
  let diagonal = max(geometry.bounds.diagonal, 0.001)
  let viewProjection = CADViewportProjection.viewProjection(
    cameraPosition: center + SIMD3<Float>(0, 0, diagonal * 2),
    cameraTarget: center,
    cameraUp: SIMD3<Float>(0, 1, 0),
    cameraDistance: diagonal * 2,
    modelDiagonalMeters: diagonal,
    aspect: 1)
  let pick = try #require(
    CADMetalFeaturePicker.feature(
      at: CGPoint(x: 100, y: 100),
      viewportSize: CGSize(width: 200, height: 200),
      document: document,
      viewProjection: viewProjection,
      hiddenPartIDs: [],
      partTransforms: []))

  #expect(pick.partID > 0)
  #expect(!pick.nodeName.isEmpty)
  #expect(abs(simd_length(pick.primaryAxis) - 1) < 0.000_1)
  #expect(abs(simd_length(pick.secondaryAxis) - 1) < 0.000_1)
  #expect(abs(simd_length(pick.screenXAxis) - 1) < 0.000_1)
  #expect(abs(simd_length(pick.screenYAxis) - 1) < 0.000_1)
  #expect(abs(simd_length(pick.screenZAxis) - 1) < 0.000_1)
}
