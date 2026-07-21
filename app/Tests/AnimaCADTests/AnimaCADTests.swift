import AnimaCAD
import AnimaCADViewport
import Foundation
import Testing

@Test func retainedRenderBackendsStayExplicitAndSTEPBacked() {
  #expect(CADRenderBackend.allCases.count == 4)
  #expect(CADRenderBackend.allCases.first == .metalKit)
  #expect(CADRenderBackend.metalKit.isPreferredSTEPVisualization)
  #expect(CADRenderBackend.realityKit.supportsNativeStudioInteraction)
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
