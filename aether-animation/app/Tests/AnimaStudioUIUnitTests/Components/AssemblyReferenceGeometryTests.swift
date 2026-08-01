import AnimaModel
import Testing

@testable import AnimaStudioUI

@Test @MainActor
func assemblyReferenceGeometryVisibilityLivesInTheSharedWorkspace() {
  let workspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)

  #expect(workspace.cadReferenceGeometryVisibility.showsOrigin)
  #expect(workspace.cadReferenceGeometryVisibility.showsFrontPlane)
  #expect(workspace.cadReferenceGeometryVisibility.showsTopPlane)
  #expect(workspace.cadReferenceGeometryVisibility.showsRightPlane)

  workspace.toggleCADReferenceGeometry(.frontPlane)

  #expect(workspace.cadReferenceGeometryVisibility.showsOrigin)
  #expect(!workspace.cadReferenceGeometryVisibility.showsFrontPlane)
  #expect(workspace.cadReferenceGeometryVisibility.showsTopPlane)
  #expect(workspace.cadReferenceGeometryVisibility.showsRightPlane)
}

@Test @MainActor
func cadPartOriginProjectionUsesTheEditableAssemblyRestTransform() throws {
  let workspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)
  let part = RigPartDefinition(
    displayName: "Arm",
    primitiveKind: .mesh,
    positionMeters: RigVector3(x: 0.4, y: -0.2, z: 0.7),
    rotationEulerRadians: RigVector3(x: 0.1, y: 0.2, z: 0.3)
  )
  workspace.project.rig.parts = [part]

  let transform = try #require(workspace.cadPartRestTransform(for: part.id))

  #expect(transform.positionMeters == [0.4, -0.2, 0.7])
  #expect(transform.rotationEulerRadians == [0.1, 0.2, 0.3])
}
