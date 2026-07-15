import SwiftUI

private struct ComponentViewportContextMenuModifier: ViewModifier {
  @Bindable var workspace: StudioWorkspaceModel

  @ViewBuilder
  func body(content: Content) -> some View {
    if let state = workspace.selectedComponentContextMenuState {
      content.contextMenu {
        Label(state.displayName, systemImage: state.primitiveKind.systemImage)
          .foregroundStyle(.secondary)

        Divider()

        Button("Properties…", systemImage: "slider.horizontal.3") {
          workspace.showComponentInspector(.properties)
        }
        Button("Appearance…", systemImage: "paintpalette") {
          workspace.showComponentInspector(.appearance)
        }
        Button("Frame Selection", systemImage: "viewfinder") {
          workspace.frameSelection()
        }

        Divider()

        Button(
          state.isVisible ? "Hide Component" : "Show Component",
          systemImage: state.isVisible ? "eye.slash" : "eye"
        ) {
          workspace.toggleSelectedComponentVisibility()
        }
        .disabled(state.isLocked)

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

        Button("Clear Selection", systemImage: "xmark.circle") {
          workspace.clearSelection()
        }
      }
    } else {
      content
    }
  }
}

extension View {
  func componentViewportContextMenu(workspace: StudioWorkspaceModel) -> some View {
    modifier(ComponentViewportContextMenuModifier(workspace: workspace))
  }
}
