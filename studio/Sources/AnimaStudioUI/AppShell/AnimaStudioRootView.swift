import SwiftUI

public struct AnimaStudioRootView: View {
  @State private var hasOpenProject = false

  public init() {}

  public var body: some View {
    Group {
      if hasOpenProject {
        StudioWorkspaceView {
          hasOpenProject = false
        }
      } else {
        StudioHomeView {
          hasOpenProject = true
        }
      }
    }
  }
}
