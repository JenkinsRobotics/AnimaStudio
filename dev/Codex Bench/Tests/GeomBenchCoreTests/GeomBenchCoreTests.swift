import Foundation
import GeomBenchCore
import Testing
import simd

@Test func pipelineCatalogContainsFourKeptSTEPArchitectures() {
  #expect(PipelineID.allCases.count == 4)
  #expect(Set(PipelineID.allCases.map(\.rawValue)).count == 4)
  #expect(PipelineID.allCases.map(\.rawValue) == [1, 2, 7, 10])
  #expect(PipelineID.allCases.allSatisfy { $0.acceptsSTEP })
  #expect(PipelineID.threeJSWebGPU.shortName.contains("WebGPU"))
  #expect(PipelineID.openCascadeWebGPU.shortName.contains("Raw WebGPU"))
  #expect(PipelineID.occtRealityKit.contributor == "Codex")
  #expect(PipelineID.occtMetalKit.role == .productionCandidate)
  #expect(PipelineID.occtRealityKit.role == .secondaryAppleRenderer)
  #expect(PipelineID.threeJSWebGPU.role == .optionalEnvironmentRenderer)
  #expect(PipelineID.openCascadeWebGPU.role == .browserRendererCandidate)
}

@Test func internalTestGeometryProducesTopologyAndTelemetry() throws {
  let document = try GeometryDocument.demo()
  #expect(!document.faces.isEmpty)
  #expect(!document.edges.isEmpty)
  #expect(!document.nodes.isEmpty)
  #expect(document.triangleCount > 0)
  #expect(document.metrics.triangulationMilliseconds >= 0)
}

@Test func malformedSTEPReturnsAnImportError() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    "codex-bench-malformed-\(UUID().uuidString).step")
  try "This is not a STEP document.".write(to: url, atomically: true, encoding: .utf8)
  defer { try? FileManager.default.removeItem(at: url) }

  do {
    _ = try GeometryDocument.loadSTEP(url)
    Issue.record("Malformed STEP unexpectedly produced geometry")
  } catch let error as GeometryImportError {
    #expect(error.localizedDescription.contains("Open CASCADE"))
  }
}

@Test func cameraOperationsStayFiniteAndBounded() {
  var camera = CADCameraState()
  camera.orbit(deltaX: 120, deltaY: 100_000)
  #expect(camera.pitch <= 1.52)
  camera.zoom(scrollDelta: -100_000)
  #expect(camera.distance >= 0.002)
  camera.pan(deltaX: 20, deltaY: -40, viewportHeight: 800)
  #expect(camera.position.x.isFinite)
  let originalUp = camera.upVector
  camera.roll(deltaX: 100)
  #expect(simd_length(camera.upVector - originalUp) > 0.01)
  #expect(abs(simd_length(camera.upVector) - 1) < 0.0001)
}
