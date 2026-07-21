import XCTest

@testable import AnimaStudioUI

final class TimelineWorkspaceSurfaceTests: XCTestCase {
  func testTimelineUsesBroadBaseMarginWithoutOverlays() {
    let overlays = StudioWorkspaceOverlayInsets()

    XCTAssertEqual(
      TimelineWorkspaceSurfaceSizing.leadingInset(for: overlays),
      TimelineWorkspaceSurfaceSizing.baseHorizontalInset
    )
    XCTAssertEqual(
      TimelineWorkspaceSurfaceSizing.trailingInset(for: overlays),
      TimelineWorkspaceSurfaceSizing.baseHorizontalInset
    )
  }

  func testTimelineMovesInsideRevealedSidebars() {
    let overlays = StudioWorkspaceOverlayInsets(top: 92, leading: 336, trailing: 366)

    XCTAssertEqual(TimelineWorkspaceSurfaceSizing.leadingInset(for: overlays), 336)
    XCTAssertEqual(TimelineWorkspaceSurfaceSizing.trailingInset(for: overlays), 366)
  }

  func testTimelineIgnoresTopToolClearance() {
    let overlays = StudioWorkspaceOverlayInsets(top: 92, leading: 0, trailing: 0)

    XCTAssertEqual(
      TimelineWorkspaceSurfaceSizing.leadingInset(for: overlays),
      TimelineWorkspaceSurfaceSizing.baseHorizontalInset
    )
    XCTAssertEqual(
      TimelineWorkspaceSurfaceSizing.trailingInset(for: overlays),
      TimelineWorkspaceSurfaceSizing.baseHorizontalInset
    )
  }
}
