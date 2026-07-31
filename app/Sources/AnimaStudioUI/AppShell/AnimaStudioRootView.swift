import Foundation
import Observation
import SwiftUI

/// One application-owned project session shared by every native macOS window.
///
/// Individual windows still construct their own `StudioWorkspaceModel`, so an
/// Assembly tab can retain its camera and panels while an Animate tab shows a
/// timeline. Project lifecycle and recents remain one application truth.
@MainActor
@Observable
public final class AnimaStudioApplicationState {
  var projectSession: StudioProjectSession?
  var designProfile: StudioDesignProfile
  var recentProjects: [RecentProjectSummary]
  var lifecycleErrorMessage: String?
  var startupWorkspace = StudioWorkspaceKind.assets

  public init() {
    let profile = StudioDesignPersistence.load()
    StudioDesignRuntime.shared.apply(profile)
    let opensPreview = ProcessInfo.processInfo.arguments.contains("--open-studio-project")
    projectSession = opensPreview ? AnimaStudioRootView.previewSession() : nil
    designProfile = profile
    recentProjects = RecentProjectsPersistence.load()
  }

  /// Keeps an outgoing workspace readable during SwiftUI's teardown pass.
  ///
  /// Clearing `projectSession` immediately swaps the root to Home, but SwiftUI
  /// may update dynamic properties in the outgoing workspace once more before
  /// discarding it. The captured session is safe for that final read. Writes
  /// are ignored after close so stale controls cannot reopen the project.
  func presentationBinding(
    fallback presentedSession: StudioProjectSession
  ) -> Binding<StudioProjectSession> {
    Binding(
      get: { self.projectSession ?? presentedSession },
      set: { updatedSession in
        guard self.projectSession != nil else { return }
        self.projectSession = updatedSession
      }
    )
  }
}

public struct AnimaStudioRootView: View {
  @Bindable private var applicationState: AnimaStudioApplicationState
  @State private var windowContext: StudioWindowContext
  private let requestedWorkspace: StudioWorkspaceKind?

  public init(
    applicationState: AnimaStudioApplicationState,
    windowRequest: StudioWorkspaceWindowRequest? = nil
  ) {
    _applicationState = Bindable(applicationState)
    _windowContext = State(initialValue: StudioWindowContext(request: windowRequest))
    requestedWorkspace = windowRequest.flatMap {
      StudioWorkspaceKind(rawValue: $0.workspaceRawValue)
    }
  }

  /// Preview/test convenience. The production app supplies one shared state to
  /// both WindowGroups so tabs and detached windows edit the same project.
  public init() {
    self.init(applicationState: AnimaStudioApplicationState())
  }

  public var body: some View {
    Group {
      if let presentedSession = applicationState.projectSession {
        StudioWorkspaceView(
          session: applicationState.presentationBinding(fallback: presentedSession),
          designProfile: liveDesignProfile,
          startupWorkspace: requestedWorkspace ?? applicationState.startupWorkspace,
          newProject: createProjectWithPanel,
          openProject: openProject,
          didPersistProject: recordRecent,
          closeProject: { applicationState.projectSession = nil }
        )
        .id(presentedSession.document.projectID)
      } else {
        StudioHomeView(
          recentProjects: applicationState.recentProjects,
          createProject: createProjectFromHome,
          openProject: openProject,
          openRecentProject: openRecent,
          removeRecentProject: removeRecent,
          refreshProjects: refreshRecentProjects,
          toggleTheme: toggleHomeTheme
        )
      }
    }
    .environment(\.studioWindowContext, windowContext)
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
      guard storedProfile != applicationState.designProfile else { return }
      StudioDesignRuntime.shared.apply(storedProfile)
      applicationState.designProfile = storedProfile
    }
    .alert(
      "Project Could Not Be Opened or Saved",
      isPresented: Binding(
        get: { applicationState.lifecycleErrorMessage != nil },
        set: { if !$0 { applicationState.lifecycleErrorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(applicationState.lifecycleErrorMessage ?? "Unknown project error")
    }
  }

  private func createProjectWithPanel() {
    guard let url = ProjectLifecycle.chooseNewProjectURL() else { return }
    do {
      let session = try ProjectLifecycle.createProject(at: url)
      applicationState.startupWorkspace = .assets
      applicationState.projectSession = session
      recordRecent(session)
    } catch {
      applicationState.lifecycleErrorMessage = error.localizedDescription
    }
  }

  private func createProjectFromHome(startingIn workspace: StudioWorkspaceKind) {
    do {
      let session = try ProjectLifecycle.createProjectInDefaultLocation()
      applicationState.startupWorkspace = workspace
      applicationState.projectSession = session
      recordRecent(session)
    } catch {
      applicationState.lifecycleErrorMessage = error.localizedDescription
    }
  }

  private func openProject() {
    guard let url = ProjectLifecycle.chooseProjectToOpen() else { return }
    do {
      let session = try ProjectLifecycle.openProject(at: url)
      applicationState.startupWorkspace = .assets
      applicationState.projectSession = session
      recordRecent(session)
    } catch {
      applicationState.lifecycleErrorMessage = error.localizedDescription
    }
  }

  private func openRecent(_ recent: RecentProjectSummary) {
    do {
      let session = try ProjectLifecycle.openRecent(recent)
      applicationState.startupWorkspace = .assets
      applicationState.projectSession = session
      recordRecent(session)
    } catch {
      if recent.resolvedProjectURL() == nil {
        removeRecent(recent.id)
      }
      applicationState.lifecycleErrorMessage = error.localizedDescription
    }
  }

  private func removeRecent(_ id: RecentProjectSummary.ID) {
    applicationState.recentProjects = RecentProjectsPersistence.remove(id: id)
  }

  private func recordRecent(_ session: StudioProjectSession) {
    applicationState.recentProjects = RecentProjectsPersistence.recordOpened(
      .project(session),
      in: applicationState.recentProjects
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
    applicationState.recentProjects = merged
    return merged
  }

  private func toggleHomeTheme() {
    liveDesignProfile.wrappedValue =
      applicationState.designProfile == .highContrast ? .standard : .highContrast
  }

  private var liveDesignProfile: Binding<StudioDesignProfile> {
    Binding(
      get: { applicationState.designProfile },
      set: { newProfile in
        let appliedProfile = newProfile.clamped()
        StudioDesignRuntime.shared.apply(appliedProfile)
        StudioDesignPersistence.save(appliedProfile)
        applicationState.designProfile = appliedProfile
      }
    )
  }

  fileprivate static func previewSession() -> StudioProjectSession {
    StudioProjectSession(
      document: ProjectLifecycle.makeEmptyDocument(name: "Untitled Character"),
      projectURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("AnimaStudio-Preview", isDirectory: true)
    )
  }
}
