import Foundation
import SwiftUI

public struct AnimaStudioRootView: View {
  @State private var hasOpenProject = false
  @State private var designProfile: StudioDesignProfile
  @State private var recentProjects: [RecentProjectSummary]

  public init() {
    let profile = StudioDesignPersistence.load()
    StudioDesignRuntime.shared.apply(profile)
    _hasOpenProject = State(
      initialValue: ProcessInfo.processInfo.arguments.contains("--open-studio-project")
    )
    _designProfile = State(initialValue: profile)
    _recentProjects = State(initialValue: RecentProjectsPersistence.load())
  }

  public var body: some View {
    Group {
      if hasOpenProject {
        StudioWorkspaceView(designProfile: liveDesignProfile) {
          hasOpenProject = false
        }
      } else {
        StudioHomeView(
          recentProjects: recentProjects,
          createProject: createProject
        )
      }
    }
  }

  private func createProject() {
    recentProjects = RecentProjectsPersistence.recordOpened(
      .scratch(),
      in: recentProjects
    )
    hasOpenProject = true
  }

  private var liveDesignProfile: Binding<StudioDesignProfile> {
    Binding(
      get: { designProfile },
      set: { newProfile in
        let appliedProfile = newProfile.clamped()
        StudioDesignRuntime.shared.apply(appliedProfile)
        StudioDesignPersistence.save(appliedProfile)
        designProfile = appliedProfile
      }
    )
  }
}
