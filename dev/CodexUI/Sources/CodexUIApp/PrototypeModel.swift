import CodexUICore
import Observation

@MainActor @Observable
final class PrototypeModel {
  var workspace: UIWorkspace = .assets
  var theme: PrototypeTheme = .studio
  var showsTour = true
  var leftPanelPlacement: PanelPlacement = .floating
  var rightPanelPlacement: PanelPlacement = .floating
  var ribbonPlacement: PanelPlacement = .floating
  var floatingRibbonEdge: FloatingRibbonEdge = .top
  var workspaceTabLabelMode: WorkspaceTabLabelMode = .automatic
  var showsViewportPerformanceHUD = true
  var selectedPart = "Head Pan Assembly"
  var masterLive = false
  var previewActive = true
  var selectedTime = 2.4
  private var tour = WorkspaceTour()

  var tourProgress: String { tour.progressLabel }

  var detectedLayoutPreset: WorkspaceLayoutPreset? {
    WorkspaceLayoutPreset.allCases.first {
      $0.leftPanel == leftPanelPlacement && $0.rightPanel == rightPanelPlacement
        && $0.ribbon == ribbonPlacement
    }
  }

  var layoutLabel: String { detectedLayoutPreset?.label ?? "Custom" }

  var browserVisible: Bool {
    get { leftPanelPlacement != .hidden }
    set { leftPanelPlacement = newValue ? .floating : .hidden }
  }

  var inspectorVisible: Bool {
    get { rightPanelPlacement != .hidden }
    set { rightPanelPlacement = newValue ? .floating : .hidden }
  }

  func selectWorkspace(_ value: UIWorkspace) {
    workspace = value
    tour.select(value)
  }

  func nextWorkspace() {
    tour.advance()
    workspace = tour.workspace
  }

  func previousWorkspace() {
    tour.retreat()
    workspace = tour.workspace
  }

  func applyLayoutPreset(_ preset: WorkspaceLayoutPreset) {
    leftPanelPlacement = preset.leftPanel
    rightPanelPlacement = preset.rightPanel
    ribbonPlacement = preset.ribbon
  }

  func cycleLayoutPreset() {
    applyLayoutPreset((detectedLayoutPreset ?? .canvas).next)
  }

  func cycleLeftPanelDocking() {
    leftPanelPlacement = leftPanelPlacement == .docked ? .floating : .docked
  }

  func cycleRightPanelDocking() {
    rightPanelPlacement = rightPanelPlacement == .docked ? .floating : .docked
  }

  func cycleRibbonDocking() {
    ribbonPlacement = ribbonPlacement == .docked ? .floating : .docked
  }
}
