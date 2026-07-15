import SwiftUI

private struct ComponentViewportContextMenuModifier: ViewModifier {
  @Bindable var workspace: StudioWorkspaceModel

  @ViewBuilder
  func body(content: Content) -> some View {
    if let state = workspace.selectedComponentContextMenuState {
      content.contextMenu {
        Label(
          "\(state.displayName) · \(state.primitiveKind.displayName)",
          systemImage: state.primitiveKind.systemImage
        )

        Divider()

        Button("Edit Properties…", systemImage: "slider.horizontal.3") {
          workspace.showComponentInspector(.properties)
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
          state.isIsolated
            ? "Exit Isolation"
            : state.hasActiveIsolation ? "Isolate This Component" : "Isolate Component",
          systemImage: state.isIsolated ? "square.3.layers.3d.top.filled" : "viewfinder"
        ) {
          workspace.toggleSelectedComponentIsolation()
        }

        Button(
          state.isTransparent ? "Restore Opacity" : "Make Transparent",
          systemImage: state.isTransparent ? "circle.fill" : "circle.lefthalf.filled"
        ) {
          workspace.toggleSelectedComponentTransparency()
        }
        .disabled(state.isLocked)

        Divider()

        Menu("Select", systemImage: "cursorarrow.click") {
          Button("Select All Components", systemImage: "square.stack.3d.up") {
            workspace.selectAllComponents()
          }
          Button("Clear Selection", systemImage: "xmark.circle") {
            workspace.clearSelection()
          }
        }

        Button("Home View", systemImage: "house") {
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
