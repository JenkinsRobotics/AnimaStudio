#if DEBUG
  import SwiftUI

  #Preview("Anima Studio · Home") {
    StudioHomeView(
      recentProjects: [
        RecentProjectSummary(
          displayName: "Jaeger Joint Representation",
          lastOpenedAt: Date(timeIntervalSince1970: 1_700_000_000),
          revisionNumber: 12,
          milestoneName: "Rig foundation",
          thumbnailKind: .rig
        ),
        RecentProjectSummary(
          displayName: "MK1 Robot Component",
          lastOpenedAt: Date(timeIntervalSince1970: 1_735_000_000),
          revisionNumber: 38,
          thumbnailKind: .character
        ),
      ],
      createProject: {},
      openProject: {},
      openRecentProject: { _ in }
    )
    .frame(width: 1_180, height: 760)
  }

  #Preview("Anima Studio · Complete Workspace") {
    StudioWorkspaceView(closeProject: {})
      .frame(width: 1_440, height: 920)
  }

  #Preview("Animate · Timeline") {
    AnimationTimelinePreview()
      .frame(width: 1_200, height: 420)
  }

  @MainActor
  private struct AnimationTimelinePreview: View {
    @State private var workspace = StudioWorkspaceModel()

    var body: some View {
      TimelineEditorView(workspace: workspace)
    }
  }
#endif
