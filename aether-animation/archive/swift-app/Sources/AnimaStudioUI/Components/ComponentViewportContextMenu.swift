import RealityKitViewport
import SwiftUI

private struct ComponentViewportContextMenuModifier: ViewModifier {
  @Bindable var workspace: StudioWorkspaceModel
  let pointerTarget: ViewportPointerTarget

  func body(content: Content) -> some View {
    content.contextMenu {
      switch SubObjectSelection.contextMenuTarget(
        pointerTarget: pointerTarget,
        selectedPartID: workspace.selectedPartID
      ) {
      case .selectedComponent:
        if let state = workspace.selectedComponentContextMenuState {
          componentMenu(state)
        } else {
          canvasMenu
        }
      case .canvas:
        canvasMenu
      }
    }
  }

  @ViewBuilder
  private func componentMenu(_ state: ComponentContextMenuState) -> some View {
    Label(
      "\(state.displayName) · \(state.primitiveKind.displayName)",
      systemImage: state.primitiveKind.systemImage
    )

    Divider()

    Button("Edit Properties…", systemImage: "slider.horizontal.3") {
      workspace.showComponentInspector(.properties)
    }
    Button("Go to Item in List", systemImage: "list.bullet.rectangle") {
      workspace.requestNavigatorReveal(.part(state.partID))
    }
    Menu(
      "Mates & Dependencies (\(state.dependencies.count))",
      systemImage: "link"
    ) {
      if state.dependencies.isEmpty {
        Text("No attached mates")
      } else {
        ForEach(state.dependencies) { dependency in
          Button(dependency.displayName, systemImage: "rotate.3d") {
            workspace.selectAttachedMate(dependency.id)
          }
        }
      }
    }

    Divider()

    Button(
      state.isVisible ? "Hide Component" : "Show Component",
      systemImage: state.isVisible ? "eye.slash" : "eye"
    ) {
      workspace.toggleSelectedComponentVisibility()
    }
    .disabled(state.isLocked)

    Button(
      state.isIsolated ? "Show All Components" : "Hide Other Components",
      systemImage: state.isIsolated ? "square.3.layers.3d.top.filled" : "viewfinder"
    ) {
      if state.isIsolated {
        workspace.showAllComponents()
      } else {
        workspace.toggleSelectedComponentIsolation()
      }
    }

    Button(
      state.isTransparent ? "Restore Opacity" : "Make Transparent",
      systemImage: state.isTransparent ? "circle.fill" : "circle.lefthalf.filled"
    ) {
      workspace.toggleSelectedComponentTransparency()
    }
    .disabled(state.isLocked)

    Button(
      workspace.rigGuideVisibility.showsConnectors ? "Hide Mates" : "Show Mates",
      systemImage: workspace.rigGuideVisibility.showsConnectors ? "link.badge.minus" : "link"
    ) {
      workspace.toggleRigConnectors()
    }

    Divider()

    Menu("Select", systemImage: "cursorarrow.click") {
      Button("Select All Components", systemImage: "square.stack.3d.up") {
        workspace.selectAllComponents()
      }
      Button("Clear Selection", systemImage: "xmark.circle") {
        workspace.clearSelection()
      }
    }

    Button("Zoom to Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
      workspace.showHomeView()
    }
    Button("Zoom to Selection", systemImage: "viewfinder") {
      workspace.frameSelection()
    }

    Divider()

    Button(state.lockActionTitle, systemImage: state.lockActionSystemImage) {
      workspace.toggleSelectedComponentLock()
    }

    Menu("Reset Transform", systemImage: "arrow.counterclockwise") {
      Button("Reset Position", systemImage: "move.3d") {
        workspace.resetSelectedComponentPosition()
      }
      Button("Reset Rotation", systemImage: "rotate.3d") {
        workspace.resetSelectedComponentRotation()
      }
      Divider()
      Button("Reset Position & Rotation", systemImage: "arrow.counterclockwise") {
        workspace.resetSelectedComponentTransform()
      }
    }
    .disabled(state.isLocked)

    Divider()

    Button(
      "Edit Appearance for \(state.displayName)…",
      systemImage: "paintpalette"
    ) {
      workspace.showComponentInspector(.appearance)
    }
  }

  @ViewBuilder
  private var canvasMenu: some View {
    Button("Show All", systemImage: "eye") {
      workspace.showAllComponents()
    }
    Button("Zoom to Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
      workspace.showHomeView()
    }
    Button("Isometric", systemImage: "cube") {
      workspace.showHomeView()
    }
  }
}

extension View {
  func componentViewportContextMenu(
    workspace: StudioWorkspaceModel,
    pointerTarget: ViewportPointerTarget = .canvas
  ) -> some View {
    modifier(
      ComponentViewportContextMenuModifier(
        workspace: workspace,
        pointerTarget: pointerTarget
      )
    )
  }
}

struct ViewportContextMenuRequest: Identifiable, Equatable {
  let id = UUID()
  let location: CGPoint
  let pointerTarget: ViewportPointerTarget

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }
}

/// Viewport-owned context presentation. The NSEvent adapter decides whether a
/// right-button sequence was a click or a camera drag; only true clicks create
/// this panel, so a completed orbit can never leak into a second menu system.
struct ComponentViewportContextMenuOverlay: View {
  @Bindable var workspace: StudioWorkspaceModel
  let request: ViewportContextMenuRequest
  let dismiss: () -> Void

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture(perform: dismiss)

        menuPanel
          .frame(width: 258)
          .position(
            x: min(max(request.location.x + 129, 137), proxy.size.width - 137),
            y: min(
              max(request.location.y + menuHeight / 2, menuHeight / 2 + 8),
              proxy.size.height - menuHeight / 2 - 8)
          )
      }
    }
    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
    .zIndex(50)
  }

  private var target: ViewportContextMenuTarget {
    SubObjectSelection.contextMenuTarget(
      pointerTarget: request.pointerTarget,
      selectedPartID: workspace.selectedPartID
    )
  }

  private var menuHeight: CGFloat {
    switch target {
    case .canvas: 154
    case .selectedComponent: 430
    }
  }

  @ViewBuilder
  private var menuPanel: some View {
    switch target {
    case .canvas:
      VStack(spacing: 3) {
        menuButton("Show All", systemImage: "eye") {
          workspace.showAllComponents()
        }
        menuButton("Zoom to Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
          workspace.showHomeView()
        }
        menuButton("Isometric", systemImage: "cube") {
          workspace.showHomeView()
        }
      }
      .studioPopupSurface()
    case .selectedComponent:
      if let state = workspace.selectedComponentContextMenuState {
        ScrollView {
          VStack(spacing: 3) {
            HStack(spacing: 8) {
              Image(systemName: state.primitiveKind.systemImage)
                .foregroundStyle(StudioPalette.semanticPart)
              Text(state.displayName)
                .font(.callout.weight(.semibold))
              Spacer()
              Text(state.primitiveKind.displayName)
                .font(.caption2)
                .foregroundStyle(StudioPalette.muted)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            menuDivider
            menuButton("Edit Properties…", systemImage: "slider.horizontal.3") {
              workspace.showComponentInspector(.properties)
            }
            menuButton("Go to Item in List", systemImage: "list.bullet.rectangle") {
              workspace.requestNavigatorReveal(.part(state.partID))
            }
            ForEach(state.dependencies) { dependency in
              menuButton(dependency.displayName, systemImage: "link") {
                workspace.selectAttachedMate(dependency.id)
              }
            }
            menuDivider
            menuButton(
              state.isVisible ? "Hide Component" : "Show Component",
              systemImage: state.isVisible ? "eye.slash" : "eye",
              isDisabled: state.isLocked
            ) {
              workspace.toggleSelectedComponentVisibility()
            }
            menuButton(
              state.isIsolated ? "Show All Components" : "Hide Other Components",
              systemImage: state.isIsolated ? "square.3.layers.3d.top.filled" : "viewfinder"
            ) {
              state.isIsolated
                ? workspace.showAllComponents()
                : workspace.toggleSelectedComponentIsolation()
            }
            menuButton(
              state.isTransparent ? "Restore Opacity" : "Make Transparent",
              systemImage: state.isTransparent ? "circle.fill" : "circle.lefthalf.filled",
              isDisabled: state.isLocked
            ) {
              workspace.toggleSelectedComponentTransparency()
            }
            menuButton(
              workspace.rigGuideVisibility.showsConnectors ? "Hide Mates" : "Show Mates",
              systemImage: "link"
            ) {
              workspace.toggleRigConnectors()
            }
            menuDivider
            menuButton("Select All Components", systemImage: "square.stack.3d.up") {
              workspace.selectAllComponents()
            }
            menuButton("Clear Selection", systemImage: "xmark.circle") {
              workspace.clearSelection()
            }
            menuButton("Zoom to Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
              workspace.showHomeView()
            }
            menuButton("Zoom to Selection", systemImage: "viewfinder") {
              workspace.frameSelection()
            }
            menuDivider
            menuButton(state.lockActionTitle, systemImage: state.lockActionSystemImage) {
              workspace.toggleSelectedComponentLock()
            }
            menuButton(
              "Reset Position & Rotation",
              systemImage: "arrow.counterclockwise",
              isDisabled: state.isLocked
            ) {
              workspace.resetSelectedComponentTransform()
            }
            menuButton("Edit Appearance…", systemImage: "paintpalette") {
              workspace.showComponentInspector(.appearance)
            }
          }
        }
        .frame(height: menuHeight)
        .studioPopupSurface()
      }
    }
  }

  private var menuDivider: some View {
    Divider()
      .overlay(StudioPalette.border)
      .padding(.vertical, 3)
  }

  private func menuButton(
    _ title: String,
    systemImage: String,
    isDisabled: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button {
      action()
      dismiss()
    } label: {
      HStack(spacing: 9) {
        Image(systemName: systemImage)
          .frame(width: 17)
        Text(title)
          .lineLimit(1)
        Spacer(minLength: 8)
      }
      .font(.callout)
      .padding(.horizontal, 7)
      .frame(height: 27)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
  }
}
