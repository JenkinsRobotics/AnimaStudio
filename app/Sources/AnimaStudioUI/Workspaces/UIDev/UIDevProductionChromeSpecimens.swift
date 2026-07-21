import SwiftUI

/// UI Dev uses the production shell components directly. Changes made to the
/// shared chrome therefore appear here and in every real workspace together.
struct UIDevProductionChromeSpecimen: View {
  @State private var workspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)
  @State private var isUIDevWorkspace = false
  @State private var showsGuide = false

  var body: some View {
    GeometryReader { proxy in
      let designWidth: CGFloat = 1_180
      let scale = min(1, proxy.size.width / designWidth)
      VStack(spacing: 0) {
        StudioDocumentBar(
          workspace: workspace,
          isUIDevWorkspace: $isUIDevWorkspace,
          showsWorkspaceGuide: $showsGuide,
          isSaving: false,
          isDirty: false,
          newProject: {},
          openProject: {},
          saveProject: {},
          saveProjectAs: {},
          closeProject: {}
        )
        ZStack {
          StudioPalette.canvas
          if showsGuide {
            WorkspaceGuideCard(
              workspace: workspace,
              isUIDevWorkspace: $isUIDevWorkspace,
              dismiss: { showsGuide = false }
            )
            .padding(10)
          }
        }
        .frame(height: 72)
        StudioStatusBar(workspace: workspace, isUIDevWorkspace: isUIDevWorkspace)
      }
      .frame(width: designWidth, height: 151)
      .scaleEffect(scale, anchor: .topLeading)
    }
    .frame(height: 170)
  }
}

struct UIDevWorkspaceLayoutSpecimen: View {
  var body: some View {
    HStack(spacing: 12) {
      layoutCard(.floating)
      layoutCard(.docked)
      layoutCard(.canvas)
    }
  }

  private func layoutCard(_ preset: StudioLayoutPreset) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(preset.title, systemImage: preset.systemImage)
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint(for: preset))
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(StudioPalette.canvas)
        grid
        if preset != .canvas {
          panel(side: .leading, floating: preset == .floating)
          panel(side: .trailing, floating: preset == .floating)
        } else {
          HStack {
            Capsule().fill(StudioPalette.muted.opacity(0.35)).frame(width: 2, height: 34)
            Spacer()
            Capsule().fill(StudioPalette.muted.opacity(0.35)).frame(width: 2, height: 34)
          }
          .padding(.horizontal, 3)
        }
        if preset.ribbonPlacement == .floating {
          Capsule()
            .fill(StudioPalette.panelInset)
            .overlay(Capsule().stroke(StudioPalette.border))
            .frame(width: 92, height: 20)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)
        }
      }
      .frame(height: 250)
      Text(layoutDetail(preset))
        .font(.caption2)
        .foregroundStyle(StudioPalette.muted)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudioPalette.border))
  }

  private var grid: some View {
    Canvas { context, size in
      var path = Path()
      for x in stride(from: CGFloat.zero, through: size.width, by: 18) {
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
      }
      for y in stride(from: CGFloat.zero, through: size.height, by: 18) {
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
      }
      context.stroke(path, with: .color(StudioPalette.border), lineWidth: 0.5)
    }
  }

  private func panel(side: Alignment, floating: Bool) -> some View {
    RoundedRectangle(cornerRadius: floating ? 8 : 0)
      .fill(StudioPalette.panel)
      .overlay(RoundedRectangle(cornerRadius: floating ? 8 : 0).stroke(StudioPalette.border))
      .shadow(color: .black.opacity(floating ? 0.26 : 0), radius: 8, y: 4)
      .frame(width: 48, height: floating ? 170 : nil)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: side)
      .padding(floating ? 8 : 0)
  }

  private func tint(for preset: StudioLayoutPreset) -> Color {
    switch preset {
    case .floating: StudioPalette.semanticPart
    case .docked: StudioPalette.joint
    case .canvas: StudioPalette.hardware
    }
  }

  private func layoutDetail(_ preset: StudioLayoutPreset) -> String {
    switch preset {
    case .floating: "Full-bleed spatial canvas with content-sized overlay widgets."
    case .docked: "Panels reserve space; tables and timelines remain unobstructed."
    case .canvas: "Hidden panels reveal from the window edges on hover."
    }
  }
}

struct UIDevFloatingRibbonSpecimen: View {
  @State private var workspace = StudioWorkspaceModel(resolvesDefaultAnimaCoreClient: false)
  @State private var isUIDevWorkspace = false
  @State private var section = UIDevSection.templateMatrix

  var body: some View {
    ZStack {
      StudioPalette.canvas
      WorkspaceFloatingToolBar(
        workspace: workspace,
        isUIDevWorkspace: $isUIDevWorkspace,
        uiDevSection: $section,
        importModel: {},
        importAnimaCharacter: {},
        toggleAgentPanel: {}
      )
    }
    .frame(height: 150)
    .clipShape(RoundedRectangle(cornerRadius: 9))
  }
}
