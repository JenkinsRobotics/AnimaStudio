#if DEBUG
  import SwiftUI

  #Preview("Anima Studio · Home") {
    StudioHomeView(createProject: {})
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
