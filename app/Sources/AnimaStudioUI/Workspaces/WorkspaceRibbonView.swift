import SwiftUI

struct WorkspaceRibbonCatalogView: View {
  @Bindable var workspace: StudioWorkspaceModel
  let importModel: () -> Void
  let importAnimaCharacter: () -> Void

  var body: some View {
    ScrollView(.horizontal) {
      HStack(alignment: .center, spacing: 0) {
        ForEach(WorkspaceRibbonCatalog.groups(for: workspace.activeWorkspace)) { group in
          CreationToolGroup(
            title: group.title,
            systemImage: group.systemImage,
            tint: tint(for: group.role),
            detail: availabilitySummary(for: group)
          ) {
            ForEach(group.tools) { tool in
              CreationToolButton(
                title: displayTitle(for: tool),
                systemImage: displayImage(for: tool),
                tint: tint(for: group.role),
                isEnabled: isEnabled(tool),
                isSelected: isSelected(tool),
                help: help(for: tool)
              ) {
                perform(tool.action)
              }
            }
          }
        }
      }
      .padding(.vertical, 8)
    }
    .scrollIndicators(.hidden)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(workspace.activeWorkspace.descriptor.title) workspace tools")
  }

  private func availabilitySummary(for group: WorkspaceRibbonGroupDescriptor) -> String? {
    let liveCount = group.tools.count(where: \.isImplemented)
    guard liveCount < group.tools.count else { return nil }
    guard liveCount > 0 else { return "Planned" }
    return "\(liveCount) live · \(group.tools.count - liveCount) planned"
  }

  private func tint(for role: WorkspaceRibbonGroupRole) -> Color {
    switch role {
    case .accent: StudioPalette.accent
    case .assets: StudioPalette.sourceModel
    case .components: StudioPalette.semanticPart
    case .mates: StudioPalette.joint
    case .hardware: StudioPalette.hardware
    case .planned: StudioPalette.muted
    }
  }

  private func displayTitle(for tool: WorkspaceRibbonToolDescriptor) -> String {
    tool.action == .togglePlayback && workspace.isPlaying ? "Pause" : tool.title
  }

  private func displayImage(for tool: WorkspaceRibbonToolDescriptor) -> String {
    tool.action == .togglePlayback && workspace.isPlaying ? "pause.fill" : tool.systemImage
  }

  private func isEnabled(_ tool: WorkspaceRibbonToolDescriptor) -> Bool {
    guard let action = tool.action else { return false }
    return switch action {
    case .importAnimaCharacter:
      workspace.animaCoreState != .connecting
    case .importModel:
      !workspace.isLoadingModelHierarchy
    case .frameSelection:
      workspace.canFrameSelection
    case .stopPlayback, .togglePlayback, .toggleLoop, .previousKeyframe, .nextKeyframe,
      .toggleGrid, .toggleBottomEditor:
      true
    }
  }

  private func isSelected(_ tool: WorkspaceRibbonToolDescriptor) -> Bool {
    switch tool.action {
    case .toggleLoop: workspace.loopsPreviewPlayback
    case .toggleGrid: workspace.showsPreviewGrid
    case .toggleBottomEditor: workspace.activePresentation.showsBottomEditor
    default: false
    }
  }

  private func help(for tool: WorkspaceRibbonToolDescriptor) -> String {
    if tool.action == .togglePlayback && workspace.isPlaying {
      return "Pause the active animation."
    }
    guard tool.isImplemented else {
      return "\(tool.help) Planned; its backend or document command is not connected yet."
    }
    return tool.help
  }

  private func perform(_ action: WorkspaceRibbonAction?) {
    guard let action else { return }
    switch action {
    case .importAnimaCharacter:
      importAnimaCharacter()
    case .importModel:
      importModel()
    case .stopPlayback:
      workspace.stopPlayback()
    case .togglePlayback:
      workspace.togglePlayback()
    case .toggleLoop:
      workspace.loopsPreviewPlayback.toggle()
    case .previousKeyframe:
      workspace.seekAdjacentKeyframe(forward: false)
    case .nextKeyframe:
      workspace.seekAdjacentKeyframe(forward: true)
    case .frameSelection:
      workspace.frameSelection()
    case .toggleGrid:
      workspace.showsPreviewGrid.toggle()
    case .toggleBottomEditor:
      workspace.toggleBottomEditor()
    }
  }
}
