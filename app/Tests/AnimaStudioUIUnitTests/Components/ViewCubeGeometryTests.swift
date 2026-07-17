import CoreGraphics
import RealityKitViewport
import XCTest

@testable import AnimaStudioUI

final class ViewCubeGeometryTests: XCTestCase {
  private let size = CGSize(width: 100, height: 100)

  @MainActor
  func testNamedAndPreviousViewsUseWorkspaceCameraState() {
    let workspace = StudioWorkspaceModel()
    let original = workspace.cameraState
    workspace.setCameraDirection(.front)
    XCTAssertEqual(workspace.previousCameraState, original)

    workspace.saveNamedCameraView(name: "Front")
    let saved = workspace.namedCameraViews[0]
    workspace.setCameraDirection(.top)
    workspace.restoreNamedCameraView(id: saved.id)
    XCTAssertEqual(workspace.cameraState, saved.state)

    workspace.restorePreviousCameraView()
    XCTAssertEqual(workspace.cameraState.orientation.direction, .top)
  }

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
    XCTAssertEqual(
      ViewCubeGeometry.hitTarget(
        at: CGPoint(x: 50, y: 50),
        in: size,
        orientation: orientation
      )?.kind,
      .face(.front)
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
    XCTAssertEqual(
      ViewCubeGeometry.hitTarget(
        at: face.points[2],
        in: size,
        orientation: orientation
      )?.kind,
      .corner
    )
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
    XCTAssertEqual(
      ViewCubeGeometry.hitTarget(
        at: midpoint,
        in: size,
        orientation: orientation
      )?.kind,
      .edge
    )
  }

  func testProjectedAxesShareOneOriginAndPointAlongPositiveWorldAxes() throws {
    let axes = ViewCubeGeometry.projectedAxes(
      in: size,
      orientation: PreviewCameraOrientation(direction: .home)
    )
    let origin = try XCTUnwrap(axes.first?.origin)

    XCTAssertEqual(axes.count, 3)
    XCTAssertTrue(axes.allSatisfy { $0.origin == origin })
    XCTAssertEqual(axes.map(\.axis), [.x, .y, .z])
    XCTAssertEqual(
      axes.map { $0.axis.direction },
      [
        SIMD3<Float>(1, 0, 0),
        SIMD3<Float>(0, 1, 0),
        SIMD3<Float>(0, 0, 1),
      ])
    XCTAssertTrue(axes.allSatisfy { $0.endpoint != origin })
  }

  func testFaceLabelDecalsStayCenteredAndUseNonMirroredAffineProjection() throws {
    let orientations = [
      PreviewCameraOrientation(direction: .home),
      PreviewCameraOrientation(direction: .right),
      PreviewCameraOrientation(direction: .top),
    ]
    let labelSize = CGSize(width: 28, height: 9)

    for orientation in orientations {
      for face in ViewCubeGeometry.projectedFaces(in: size, orientation: orientation) {
        let decal = try XCTUnwrap(
          ViewCubeGeometry.labelProjection(
            for: face,
            orientation: orientation,
            labelSize: labelSize
          )
        )
        let projectedCenter = CGPoint(
          x: decal.localBounds.midX,
          y: decal.localBounds.midY
        ).applying(decal.transform)
        XCTAssertEqual(projectedCenter.x, face.center.x, accuracy: 0.001)
        XCTAssertEqual(projectedCenter.y, face.center.y, accuracy: 0.001)
        XCTAssertGreaterThan(decal.determinant, 0)
      }
    }
  }

  func testFaceLabelDecalsRemainReadableInPrincipalAndRolledViews() throws {
    let cases: [(ViewCubeFace, PreviewCameraDirection)] = [
      (.front, .front),
      (.back, .back),
      (.right, .right),
      (.left, .left),
      (.top, .top),
      (.bottom, .bottom),
    ]

    for (expectedFace, direction) in cases {
      for rollRadians in [Float(0), Float.pi / 2, .pi] {
        let orientation = PreviewCameraOrientation(
          direction: direction,
          rollRadians: rollRadians
        )
        let face = try XCTUnwrap(
          ViewCubeGeometry.projectedFaces(in: size, orientation: orientation)
            .first(where: { $0.face == expectedFace })
        )
        let decal = try XCTUnwrap(
          ViewCubeGeometry.labelProjection(
            for: face,
            orientation: orientation,
            labelSize: CGSize(width: 28, height: 9)
          )
        )
        let start = CGPoint(x: 0, y: decal.localBounds.midY).applying(decal.transform)
        let end = CGPoint(
          x: decal.localBounds.maxX,
          y: decal.localBounds.midY
        ).applying(decal.transform)
        XCTAssertGreaterThan(decal.determinant, 0)
        XCTAssertTrue(
          end.x > start.x || (abs(end.x - start.x) < 0.001 && end.y < start.y),
          "\(expectedFace) at roll \(rollRadians) rendered upside-down"
        )
      }
    }
  }

  func testFaceLabelDecalHidesNearEdgeOnSlivers() throws {
    let orientation = PreviewCameraOrientation(
      direction: PreviewCameraDirection(x: 1, y: 0, z: 0.04)
    )
    let front = try XCTUnwrap(
      ViewCubeGeometry.projectedFaces(in: size, orientation: orientation)
        .first(where: { $0.face == .front })
    )

    XCTAssertNil(
      ViewCubeGeometry.labelProjection(
        for: front,
        orientation: orientation,
        labelSize: CGSize(width: 28, height: 9)
      )
    )
  }

  func testRollControlsOnlyAppearForHeadOnPrincipalFaces() {
    XCTAssertEqual(
      ViewCubeGeometry.headOnFace(
        for: PreviewCameraOrientation(direction: .front)
      ),
      .front
    )
    XCTAssertEqual(
      ViewCubeGeometry.headOnFace(
        for: PreviewCameraOrientation(direction: .top, rollRadians: .pi / 2)
      ),
      .top
    )
    XCTAssertNil(
      ViewCubeGeometry.headOnFace(
        for: PreviewCameraOrientation(direction: .home)
      )
    )
    XCTAssertNil(
      ViewCubeGeometry.headOnFace(
        for: PreviewCameraOrientation(
          direction: .front.nudged(horizontalRadians: .pi / 12, verticalRadians: 0)
        )
      )
    )
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

    workspace.rollCamera(by: .pi / 2)
    XCTAssertEqual(workspace.cameraState.orientation.direction, .left)
    XCTAssertEqual(workspace.cameraState.orientation.rollRadians, .pi / 2, accuracy: 0.001)
    XCTAssertEqual(workspace.cameraCommandRevision, 2)

    workspace.setCameraViewpoint(.home)
    XCTAssertEqual(workspace.cameraState.orientation.rollRadians, 0, accuracy: 0.001)
    XCTAssertEqual(workspace.cameraCommandRevision, 3)
  }
}
