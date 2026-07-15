import CoreGraphics
import RealityKitViewport
import XCTest

@testable import AnimaStudioUI

final class ViewCubeGeometryTests: XCTestCase {
  private let size = CGSize(width: 100, height: 100)

  func testFrontOrientationShowsAndSelectsFrontFace() {
    let orientation = PreviewCameraOrientation(direction: .front)
    let faces = ViewCubeGeometry.projectedFaces(in: size, orientation: orientation)

    XCTAssertEqual(faces.map(\.face), [.front])
    XCTAssertEqual(
      ViewCubeGeometry.hitDirection(
        at: CGPoint(x: 50, y: 50),
        in: size,
        orientation: orientation
      ),
      .front
    )
  }

  func testHomeOrientationShowsPositiveAxisFaces() {
    let faces = ViewCubeGeometry.projectedFaces(
      in: size,
      orientation: PreviewCameraOrientation(direction: .home)
    )

    XCTAssertEqual(Set(faces.map(\.face)), Set([.front, .right, .top]))
  }

  func testProjectedCornerSelectsTrimetricDirection() throws {
    let orientation = PreviewCameraOrientation(direction: .front)
    let face = try XCTUnwrap(
      ViewCubeGeometry.projectedFaces(in: size, orientation: orientation).first
    )
    let direction = try XCTUnwrap(
      ViewCubeGeometry.hitDirection(
        at: face.points[2],
        in: size,
        orientation: orientation
      )
    )

    XCTAssertEqual(direction.x, 1 / sqrt(3), accuracy: 0.0001)
    XCTAssertEqual(direction.y, 1 / sqrt(3), accuracy: 0.0001)
    XCTAssertEqual(direction.z, 1 / sqrt(3), accuracy: 0.0001)
  }

  func testProjectedEdgeSelectsTwoAxisDirection() throws {
    let orientation = PreviewCameraOrientation(direction: .front)
    let face = try XCTUnwrap(
      ViewCubeGeometry.projectedFaces(in: size, orientation: orientation).first
    )
    let midpoint = CGPoint(
      x: (face.points[0].x + face.points[1].x) / 2,
      y: (face.points[0].y + face.points[1].y) / 2
    )
    let direction = try XCTUnwrap(
      ViewCubeGeometry.hitDirection(at: midpoint, in: size, orientation: orientation)
    )

    XCTAssertEqual(direction.x, 0, accuracy: 0.0001)
    XCTAssertEqual(direction.y, -1 / sqrt(2), accuracy: 0.0001)
    XCTAssertEqual(direction.z, 1 / sqrt(2), accuracy: 0.0001)
  }

  @MainActor
  func testWorkspaceTreatsCubeAndReportedOrbitAsCustomCameraViews() {
    let workspace = StudioWorkspaceModel()

    workspace.setCameraDirection(.back)
    XCTAssertEqual(workspace.cameraViewpoint, .custom)
    XCTAssertEqual(workspace.cameraState.orientation.direction, .back)
    XCTAssertEqual(workspace.cameraCommandRevision, 1)

    let orbitState = PreviewCameraState(
      orientation: PreviewCameraOrientation(direction: .left),
      distance: 3
    )
    workspace.reportCameraState(orbitState)
    XCTAssertEqual(workspace.cameraState, orbitState)
    XCTAssertEqual(workspace.cameraViewpoint, .custom)
    XCTAssertEqual(workspace.cameraCommandRevision, 1)
  }
}
