import Foundation
import SwiftUI

public struct AnimaStudioRootView: View {
  @State private var projectSession: StudioProjectSession?
  @State private var designProfile: StudioDesignProfile
  @State private var recentProjects: [RecentProjectSummary]
  @State private var lifecycleErrorMessage: String?

  public init() {
    let profile = StudioDesignPersistence.load()
    StudioDesignRuntime.shared.apply(profile)
    let opensPreview = ProcessInfo.processInfo.arguments.contains("--open-studio-project")
    _projectSession = State(initialValue: opensPreview ? Self.previewSession() : nil)
    _designProfile = State(initialValue: profile)
    _recentProjects = State(initialValue: RecentProjectsPersistence.load())
  }

  public var body: some View {
    Group {
      if projectSession != nil {
        StudioWorkspaceView(
          session: activeSession,
          designProfile: liveDesignProfile,
          newProject: createProject,
          openProject: openProject,
          didPersistProject: recordRecent,
          closeProject: { projectSession = nil }
        )
        .id(projectSession?.document.projectID)
      } else {
        StudioHomeView(
          recentProjects: recentProjects,
          createProject: createProject,
          openProject: openProject,
          openRecentProject: openRecent,
          removeRecentProject: removeRecent
        )
      }
    }
    .alert(
      "Project Could Not Be Opened or Saved",
      isPresented: Binding(
        get: { lifecycleErrorMessage != nil },
        set: { if !$0 { lifecycleErrorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(lifecycleErrorMessage ?? "Unknown project error")
    }
  }

  private var activeSession: Binding<StudioProjectSession> {
    Binding(
      get: { projectSession! },
      set: { projectSession = $0 }
    )
  }

  private func createProject() {
    guard let url = ProjectLifecycle.chooseNewProjectURL() else { return }
    do {
      let session = try ProjectLifecycle.createProject(at: url)
      projectSession = session
      recordRecent(session)
    } catch {
      lifecycleErrorMessage = error.localizedDescription
    }
  }

  private func openProject() {
    guard let url = ProjectLifecycle.chooseProjectToOpen() else { return }
    do {
      let session = try ProjectLifecycle.openProject(at: url)
      projectSession = session
      recordRecent(session)
    } catch {
      lifecycleErrorMessage = error.localizedDescription
    }
  }

  private func openRecent(_ recent: RecentProjectSummary) {
    do {
      let session = try ProjectLifecycle.openRecent(recent)
      projectSession = session
      recordRecent(session)
    } catch {
      if recent.resolvedProjectURL() == nil {
        removeRecent(recent.id)
      }
      lifecycleErrorMessage = error.localizedDescription
    }
  }

  private func removeRecent(_ id: RecentProjectSummary.ID) {
    recentProjects = RecentProjectsPersistence.remove(id: id)
  }

  private func recordRecent(_ session: StudioProjectSession) {
    recentProjects = RecentProjectsPersistence.recordOpened(
      .project(session),
      in: recentProjects
    )
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

  private static func previewSession() -> StudioProjectSession {
    StudioProjectSession(
      document: ProjectLifecycle.makeEmptyDocument(name: "Untitled Character"),
      projectURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("AnimaStudio-Preview", isDirectory: true)
    )
  }
}
