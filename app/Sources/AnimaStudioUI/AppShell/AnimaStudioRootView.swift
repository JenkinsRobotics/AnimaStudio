import Foundation
import SwiftUI

public struct AnimaStudioRootView: View {
  @State private var projectSession: StudioProjectSession?
  @State private var designProfile: StudioDesignProfile
  @State private var recentProjects: [RecentProjectSummary]
  @State private var lifecycleErrorMessage: String?
  @State private var startupWorkspace = StudioWorkspaceKind.assets

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
          startupWorkspace: startupWorkspace,
          newProject: createProjectWithPanel,
          openProject: openProject,
          didPersistProject: recordRecent,
          closeProject: { projectSession = nil }
        )
        .id(projectSession?.document.projectID)
      } else {
        StudioHomeView(
          recentProjects: recentProjects,
          createProject: createProjectFromHome,
          openProject: openProject,
          openRecentProject: openRecent,
          removeRecentProject: removeRecent,
          refreshProjects: refreshRecentProjects,
          toggleTheme: toggleHomeTheme
        )
      }
    }
    .onAppear {
      // Hold the workspace-root security scope for the whole app session so the
      // sandbox permits lazy mesh reads during rendering. Verified in the real
      // sandboxed process: without this a project STL is unreadable and the
      // viewport falls back to placeholders. Idempotent.
      WorkspaceLocationPreference().activatePersistentWorkspaceRootAccess()
      StudioAppearanceMode.applyCurrent()
    }
    .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) {
      _ in
      // Live-apply the light/dark appearance when the setting changes.
      StudioAppearanceMode.applyCurrent()
      let storedProfile = StudioDesignPersistence.load()
      guard storedProfile != designProfile else { return }
      StudioDesignRuntime.shared.apply(storedProfile)
      designProfile = storedProfile
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

  private func createProjectWithPanel() {
    guard let url = ProjectLifecycle.chooseNewProjectURL() else { return }
    do {
      let session = try ProjectLifecycle.createProject(at: url)
      startupWorkspace = .assets
      projectSession = session
      recordRecent(session)
    } catch {
      lifecycleErrorMessage = error.localizedDescription
    }
  }

  private func createProjectFromHome(startingIn workspace: StudioWorkspaceKind) {
    do {
      let session = try ProjectLifecycle.createProjectInDefaultLocation()
      startupWorkspace = workspace
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
      startupWorkspace = .assets
      projectSession = session
      recordRecent(session)
    } catch {
      lifecycleErrorMessage = error.localizedDescription
    }
  }

  private func openRecent(_ recent: RecentProjectSummary) {
    do {
      let session = try ProjectLifecycle.openRecent(recent)
      startupWorkspace = .assets
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

  @discardableResult
  private func refreshRecentProjects() -> [RecentProjectSummary] {
    let stored = RecentProjectsPersistence.load()
    let merged = RecentProjectsPersistence.mergedWithDiscoveredProjects(
      stored,
      in: ProjectLifecycle.defaultProjectsDirectory()
    )
    RecentProjectsPersistence.save(merged)
    recentProjects = merged
    return merged
  }

  private func toggleHomeTheme() {
    liveDesignProfile.wrappedValue = designProfile == .highContrast ? .standard : .highContrast
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
