import Foundation
import Testing
import simd

@testable import AetherViewport

/// Behavior pins for the engine-owned in-world tool geometry: every
/// renderer draws these exact line lists, so their shape is contract.
struct CADToolGeometryTests {

  private func gizmo(enabled: Bool = true) -> CADGizmoPresentation {
    CADGizmoPresentation(
      origin: SIMD3(1, 2, 3),
      xAxis: SIMD3(1, 0, 0), yAxis: SIMD3(0, 1, 0), zAxis: SIMD3(0, 0, 1),
      armLengthMeters: 0.5, isEnabled: enabled)
  }

  @Test func gizmoLineListShapeIsStable() {
    let vertices = CADToolGeometry.gizmoLineVertices(gizmo())
    // Per axis: arm + 4 barbs + 48 ring segments = 53 lines; ×3 axes,
    // plus 3 plane tabs × 4 edges = 171 lines = 342 vertices.
    #expect(vertices.count == 342)
    // Arm tips land at origin + axis * arm.
    #expect(vertices[1].position == SIMD4(1.5, 2, 3, 1))
  }

  @Test func gizmoDisabledTurnsAllLinesGrey() {
    let vertices = CADToolGeometry.gizmoLineVertices(gizmo(enabled: false))
    let grey = SIMD4<Float>(0.62, 0.62, 0.66, 0.7)
    #expect(vertices.prefix(106).allSatisfy { $0.color == grey })
  }

  @Test func connectorTriadDrawsThreeArmsWithLongPrimary() {
    let marker = CADConnectorMarker(
      partID: 7, origin: SIMD3(0, 0, 0),
      xAxis: SIMD3(1, 0, 0), zAxis: SIMD3(0, 0, 1),
      isSelected: false)
    let vertices = CADToolGeometry.connectorMarkerLineVertices(
      markers: [marker], transformsByPartID: [:], axisLength: 0.1)
    #expect(vertices.count == 6)  // three lines
    // Primary (z) arm is 1.4× the axis length.
    #expect(abs(vertices[5].position.z - 0.14) < 1e-6)
    // Selection emphasis scales arms by 1.3.
    let selected = CADToolGeometry.connectorMarkerLineVertices(
      markers: [CADConnectorMarker(
        partID: 7, origin: .zero, xAxis: SIMD3(1, 0, 0),
        zAxis: SIMD3(0, 0, 1), isSelected: true)],
      transformsByPartID: [:], axisLength: 0.1)
    #expect(abs(selected[1].position.x - 0.13) < 1e-6)
  }

  @Test func snapNodeIsSmallStarInNodeColor() {
    let node = CADConnectorMarker(
      partID: 1, origin: SIMD3(0.2, 0, 0),
      xAxis: SIMD3(1, 0, 0), zAxis: SIMD3(0, 0, 1),
      isSelected: false, isNode: true)
    let vertices = CADToolGeometry.connectorMarkerLineVertices(
      markers: [node], transformsByPartID: [:], axisLength: 0.1)
    #expect(vertices.count == 6)
    #expect(vertices.allSatisfy { $0.color == SIMD4(0.20, 0.82, 1.0, 0.9) })
    // Star arms are ±0.3 × axisLength about the origin.
    #expect(abs(vertices[0].position.x - 0.17) < 1e-6)
  }

  @Test func partTransformCarriesTriadWithComponent() {
    let marker = CADConnectorMarker(
      partID: 3, origin: SIMD3(0, 0, 0),
      xAxis: SIMD3(1, 0, 0), zAxis: SIMD3(0, 0, 1),
      isSelected: false)
    var translate = matrix_identity_float4x4
    translate.columns.3 = SIMD4(5, 0, 0, 1)
    let vertices = CADToolGeometry.connectorMarkerLineVertices(
      markers: [marker], transformsByPartID: [3: translate], axisLength: 0.1)
    #expect(vertices[0].position.x == 5)
  }
}
