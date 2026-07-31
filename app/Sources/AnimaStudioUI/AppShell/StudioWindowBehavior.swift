import AppKit
import Observation
import SwiftUI

/// Value passed through SwiftUI's dedicated workspace `WindowGroup`.
///
/// A fresh UUID makes every request a distinct native window. Supplying a
/// target window number asks the new window to join that window's native tab
/// group as soon as AppKit attaches its content.
public struct StudioWorkspaceWindowRequest: Codable, Hashable, Sendable {
  public let id: UUID
  public let workspaceRawValue: String
  public let projectDisplayName: String?
  public let targetTabWindowNumber: Int?

  public init(
    id: UUID = UUID(),
    workspaceRawValue: String,
    projectDisplayName: String? = nil,
    targetTabWindowNumber: Int? = nil
  ) {
    self.id = id
    self.workspaceRawValue = workspaceRawValue
    self.projectDisplayName = projectDisplayName
    self.targetTabWindowNumber = targetTabWindowNumber
  }
}

@MainActor
@Observable
final class StudioWindowContext {
  private(set) weak var window: NSWindow?
  let request: StudioWorkspaceWindowRequest?
  private var didApplyRequest = false

  init(request: StudioWorkspaceWindowRequest? = nil) {
    self.request = request
  }

  var canDetachCurrentTab: Bool {
    (window?.tabbedWindows?.count ?? 0) > 1
  }

  func bind(window: NSWindow) {
    self.window = window
    window.tabbingMode = .preferred
    if let request {
      let workspaceTitle =
        StudioWorkspaceKind(rawValue: request.workspaceRawValue)?.descriptor.title
        ?? "Workspace"
      let projectTitle = request.projectDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
      window.title =
        if let projectTitle, !projectTitle.isEmpty {
          "\(projectTitle) — \(workspaceTitle)"
        } else {
          workspaceTitle
        }
    }
    applyRequestIfNeeded(to: window)
  }

  private func applyRequestIfNeeded(to newWindow: NSWindow) {
    guard !didApplyRequest else { return }
    didApplyRequest = true
    guard
      let targetWindowNumber = request?.targetTabWindowNumber,
      targetWindowNumber != newWindow.windowNumber
    else { return }

    // `openWindow` returns before AppKit publishes the new NSWindow. Binding
    // happens from `viewDidMoveToWindow`, so this is the first reliable point
    // at which both windows exist.
    DispatchQueue.main.async {
      guard
        let targetWindow = NSApp.windows.first(where: {
          $0.windowNumber == targetWindowNumber
        })
      else { return }
      targetWindow.tabbingMode = .preferred
      targetWindow.addTabbedWindow(newWindow, ordered: .above)
      newWindow.makeKeyAndOrderFront(nil)
    }
  }
}

private struct StudioWindowContextKey: EnvironmentKey {
  static let defaultValue: StudioWindowContext? = nil
}

extension EnvironmentValues {
  var studioWindowContext: StudioWindowContext? {
    get { self[StudioWindowContextKey.self] }
    set { self[StudioWindowContextKey.self] = newValue }
  }
}

enum StudioWindowDoubleClickAction: Equatable, Sendable {
  case zoom
  case minimize
  case none

  static func resolve(preference: String?) -> Self {
    switch preference?.lowercased() {
    case "minimize": .minimize
    case "none": .none
    default: .zoom
    }
  }
}

/// Restores native title-bar interaction to empty regions of Studio's custom
/// header while leaving its SwiftUI controls in front and fully interactive.
struct StudioWindowControlArea: NSViewRepresentable {
  @Environment(\.studioWindowContext) private var windowContext

  func makeNSView(context: Context) -> NSView {
    StudioWindowControlView { window in
      windowContext?.bind(window: window)
    }
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    guard let controlView = nsView as? StudioWindowControlView else { return }
    controlView.didAttachToWindow = { window in
      windowContext?.bind(window: window)
    }
    if let window = controlView.window {
      windowContext?.bind(window: window)
    }
  }
}

private final class StudioWindowControlView: NSView {
  var didAttachToWindow: (NSWindow) -> Void

  init(didAttachToWindow: @escaping (NSWindow) -> Void) {
    self.didAttachToWindow = didAttachToWindow
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let window {
      didAttachToWindow(window)
    }
  }

  override func mouseDown(with event: NSEvent) {
    guard let window else {
      super.mouseDown(with: event)
      return
    }

    guard event.clickCount == 2 else {
      window.performDrag(with: event)
      return
    }

    switch StudioWindowDoubleClickAction.resolve(
      preference: UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick")
    ) {
    case .zoom:
      window.zoom(nil)
    case .minimize:
      window.miniaturize(nil)
    case .none:
      break
    }
  }
}
