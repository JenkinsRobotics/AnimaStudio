import CodexUICore
import SwiftUI

/// Shared canvas-first layout used by every CodexUI workspace.
///
/// Side regions have one source view and three presentations: docked in the
/// layout flow, floating over the canvas, or hidden. Floating panels remain
/// inside the application window; this prototype does not create detached
/// operating-system windows.
struct DockingWorkspace<Left: View, Center: View, Right: View>: View {
  @Environment(\.prototypeTheme) private var theme
  @Bindable var model: PrototypeModel
  var leftTitle = "Browser"
  var rightTitle = "Inspector"
  var leftWidth: CGFloat = 246
  var rightWidth: CGFloat = 286
  var centerInset: CGFloat = 10
  @ViewBuilder let left: Left
  @ViewBuilder let center: Center
  @ViewBuilder let right: Right
  @State private var revealedCanvasSide: DockSide?

  init(
    model: PrototypeModel,
    leftTitle: String = "Browser",
    rightTitle: String = "Inspector",
    leftWidth: CGFloat = 246,
    rightWidth: CGFloat = 286,
    centerInset: CGFloat = 10,
    @ViewBuilder left: () -> Left,
    @ViewBuilder center: () -> Center,
    @ViewBuilder right: () -> Right
  ) {
    self.model = model
    self.leftTitle = leftTitle
    self.rightTitle = rightTitle
    self.leftWidth = leftWidth
    self.rightWidth = rightWidth
    self.centerInset = centerInset
    self.left = left()
    self.center = center()
    self.right = right()
  }

  var body: some View {
    HStack(spacing: 0) {
      if model.leftPanelPlacement == .docked {
        dockedRegion(
          title: leftTitle, side: .left, width: leftWidth, content: AnyView(left))
        divider
      }

      ZStack {
        center
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(centerInset)
          .environment(\.workspacePanelObstructions, panelObstructions)

        if model.leftPanelPlacement == .floating {
          GeometryReader { proxy in
            floatingRegion(
              title: leftTitle, side: .left, width: leftWidth,
              availableSize: proxy.size, content: AnyView(left)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          }
        }

        if model.rightPanelPlacement == .floating {
          GeometryReader { proxy in
            floatingRegion(
              title: rightTitle, side: .right, width: rightWidth,
              availableSize: proxy.size, content: AnyView(right)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          }
        }

        canvasEdgeReveals
      }
      .coordinateSpace(name: floatingWidgetCoordinateSpaceName)
      .clipped()

      if model.rightPanelPlacement == .docked {
        divider
        dockedRegion(
          title: rightTitle, side: .right, width: rightWidth, content: AnyView(right))
      }
    }
    .background(theme.canvas)
    .animation(.spring(response: 0.34, dampingFraction: 0.88), value: model.leftPanelPlacement)
    .animation(.spring(response: 0.34, dampingFraction: 0.88), value: model.rightPanelPlacement)
    .animation(.spring(response: 0.32, dampingFraction: 0.9), value: model.ribbonPlacement)
    .onChange(of: model.detectedLayoutPreset) { _, preset in
      if preset != .canvas {
        revealedCanvasSide = nil
      }
    }
  }

  private var divider: some View {
    Rectangle().fill(theme.line).frame(width: 1)
  }

  private var panelObstructions: PanelObstructionInsets {
    PanelObstructionInsets(
      leftPlacement: model.leftPanelPlacement,
      rightPlacement: model.rightPanelPlacement,
      ribbonPlacement: model.ribbonPlacement,
      floatingRibbonEdge: model.floatingRibbonEdge,
      leftPanelWidth: Double(leftWidth),
      rightPanelWidth: Double(rightWidth)
    )
  }

  private func dockedRegion(
    title: String, side: DockSide, width: CGFloat, content: AnyView
  ) -> some View {
    DockRegionChrome(
      floating: false, enablesWidgetDragging: false, workspaceSize: .zero
    ) {
      content
    }
    .accessibilityLabel(title)
    .frame(width: width)
    .frame(maxHeight: .infinity)
    .transition(.move(edge: side == .left ? .leading : .trailing).combined(with: .opacity))
  }

  private func floatingRegion(
    title: String, side: DockSide, width: CGFloat, availableSize: CGSize, content: AnyView
  ) -> some View {
    DockRegionChrome(
      floating: true, enablesWidgetDragging: side == .right, workspaceSize: availableSize
    ) {
      content
    }
    .accessibilityLabel(title)
    .frame(width: width)
    .frame(
      height: CGFloat(
        FloatingPanelSizing.height(availableHeight: Double(availableSize.height))
      )
    )
    .padding(.top, 12)
    .padding(.bottom, 12)
    .padding(side == .left ? .leading : .trailing, 12)
    .transition(.move(edge: side == .left ? .leading : .trailing).combined(with: .opacity))
  }

  private var canvasEdgeReveals: some View {
    GeometryReader { proxy in
      ZStack {
        canvasEdgeReveal(
          title: leftTitle, side: .left, width: leftWidth,
          placement: model.leftPanelPlacement, availableSize: proxy.size,
          content: AnyView(left)
        )
        canvasEdgeReveal(
          title: rightTitle, side: .right, width: rightWidth,
          placement: model.rightPanelPlacement, availableSize: proxy.size,
          content: AnyView(right)
        )
      }
    }
  }

  @ViewBuilder
  private func canvasEdgeReveal(
    title: String, side: DockSide, width: CGFloat, placement: PanelPlacement,
    availableSize: CGSize, content: AnyView
  ) -> some View {
    if CanvasPanelRevealPolicy.isEnabled(
      layoutPreset: model.detectedLayoutPreset, panelPlacement: placement)
    {
      ZStack(alignment: side == .left ? .leading : .trailing) {
        Color.clear
        if revealedCanvasSide == side {
          floatingRegion(
            title: title, side: side, width: width, availableSize: availableSize,
            content: content)
        } else {
          Capsule()
            .fill(theme.iconText.opacity(0.32))
            .frame(width: 2, height: 54)
            .padding(side == .left ? .leading : .trailing, 3)
        }
      }
      .frame(width: revealedCanvasSide == side ? width + 12 : 12)
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .onHover { isInside in
        withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
          if isInside {
            revealedCanvasSide = side
          } else if revealedCanvasSide == side {
            revealedCanvasSide = nil
          }
        }
      }
      .frame(
        maxWidth: .infinity, maxHeight: .infinity,
        alignment: side == .left ? .leading : .trailing
      )
      .transition(.opacity)
    }
  }
}

private struct WorkspacePanelObstructionsKey: EnvironmentKey {
  static let defaultValue = PanelObstructionInsets(
    leftPlacement: .hidden,
    rightPlacement: .hidden,
    ribbonPlacement: .hidden,
    leftPanelWidth: 0,
    rightPanelWidth: 0
  )
}

extension EnvironmentValues {
  fileprivate var workspacePanelObstructions: PanelObstructionInsets {
    get { self[WorkspacePanelObstructionsKey.self] }
    set { self[WorkspacePanelObstructionsKey.self] = newValue }
  }
}

private struct FloatingPanelSafeAreaModifier: ViewModifier {
  @Environment(\.workspacePanelObstructions) private var obstructions
  let edges: Edge.Set

  func body(content: Content) -> some View {
    content
      .padding(
        EdgeInsets(
          top: edges.contains(.top) ? obstructions.top : 0,
          leading: edges.contains(.leading) ? obstructions.leading : 0,
          bottom: edges.contains(.bottom) ? obstructions.bottom : 0,
          trailing: edges.contains(.trailing) ? obstructions.trailing : 0
        )
      )
      .animation(.spring(response: 0.34, dampingFraction: 0.88), value: obstructions)
  }
}

extension View {
  /// Keeps tables, timelines, and other structured controls within the visible
  /// area while allowing spatial canvases to remain full-bleed behind panels.
  func avoidsFloatingWorkspacePanels(_ edges: Edge.Set = .all) -> some View {
    modifier(FloatingPanelSafeAreaModifier(edges: edges))
  }
}

enum DockSide: Equatable {
  case left
  case right
}

private struct DockRegionChrome<Content: View>: View {
  @Environment(\.prototypeTheme) private var theme
  let floating: Bool
  let enablesWidgetDragging: Bool
  let workspaceSize: CGSize
  @ViewBuilder let content: Content

  var body: some View {
    Group {
      if floating {
        floatingBody
      } else {
        dockedBody
      }
    }
    .foregroundStyle(theme.primaryText)
  }

  private var dockedBody: some View {
    content
      .padding(6)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(theme.panel)
      .environment(\.workspacePanelPresentation, .docked)
      .environment(\.floatingWidgetDragEnabled, false)
      .background(theme.panel)
      .clipShape(Rectangle())
      .overlay(Rectangle().stroke(theme.line, lineWidth: 1))
  }

  private var floatingBody: some View {
    content
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .environment(\.workspacePanelPresentation, .floating)
      .environment(\.floatingWidgetDragEnabled, enablesWidgetDragging)
      .environment(\.floatingWidgetWorkspaceSize, workspaceSize)
  }
}
