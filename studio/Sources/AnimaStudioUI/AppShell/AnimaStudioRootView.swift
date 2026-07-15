import SwiftUI

public struct AnimaStudioRootView: View {
  @State private var hasOpenProject = false
  @State private var designProfile: StudioDesignProfile

  public init() {
    let profile = StudioDesignPersistence.load()
    StudioDesignRuntime.shared.apply(profile)
    _designProfile = State(initialValue: profile)
  }

  public var body: some View {
    Group {
      if hasOpenProject {
        StudioWorkspaceView(designProfile: liveDesignProfile) {
          hasOpenProject = false
        }
      } else {
        StudioHomeView {
          hasOpenProject = true
        }
      }
    }
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
