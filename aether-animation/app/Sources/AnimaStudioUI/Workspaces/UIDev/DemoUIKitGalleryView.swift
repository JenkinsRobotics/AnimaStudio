import SwiftUI

/// Additive gallery of the Demo app's design-system vocabulary. Every imported
/// specimen is rendered here; production components remain available in the
/// surrounding UI Dev sections for side-by-side consolidation later.
struct DemoUIKitGalleryView: View {
  @State private var chip = "Standard"
  @State private var segment = 0
  @State private var toggle = true

  private let columns = [GridItem(.adaptive(minimum: 290), spacing: 16, alignment: .top)]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        StudioSectionHeader(
          title: "Demo UI Kit",
          detail: "Namespaced specimens imported additively from AnimaStudio Demo.",
          systemImage: "shippingbox.and.arrow.backward"
        )
        DemoKitCallout(
          title: "Living component inventory",
          detail:
            "These are reusable specimens, not screenshots. Existing production components are intentionally preserved beside them."
        )

        gallerySection("Layout, rows, and controls") {
          LazyVGrid(columns: columns, spacing: 16) {
            DemoKitPanelCard("Panel Card", subtitle: "HEADER · BODY") {
              VStack(spacing: 5) {
                DemoKitListRow(icon: "cube", title: "Head", detail: "V4", selected: true)
                DemoKitTreeRow(depth: 0, icon: "folder", title: "Assembly", expanded: true)
                DemoKitTreeRow(depth: 1, icon: "cube", title: "Jaw")
                DemoKitPanelAction(icon: "plus", label: "Add component")
              }
            }
            DemoKitPanel("Fields") {
              VStack(spacing: 7) {
                DemoKitRow(icon: "gearshape", label: "Servo", value: "01")
                DemoKitField(label: "Angle", value: "42.0", unit: "deg")
                DemoKitSearchField()
                DemoKitStepperField()
                DemoKitToggleRow(title: "Visible", value: $toggle)
              }
            }
            DemoKitPanelCard("Chips and commands") {
              VStack(alignment: .leading, spacing: 10) {
                HStack {
                  DemoKitPill(text: "CONNECTED", tint: .green)
                  DemoKitStageChip(icon: "cube", title: "Character", selected: true)
                }
                DemoKitChipPicker(selection: $chip, values: ["Compact", "Standard", "Expanded"])
                DemoKitSegmentedIcons(
                  icons: ["list.bullet", "square.grid.2x2", "chart.xyaxis.line"],
                  selection: $segment)
                HStack {
                  DemoKitCommandButton(icon: "cube", title: "Part")
                  DemoKitCommandButton(icon: "link", title: "Mate", tint: .purple)
                }
              }
            }
            DemoKitToolCluster(
              title: "Create",
              tools: [("cube", "Box"), ("cylinder", "Cylinder"), ("scope", "Origin")])
          }
        }

        gallerySection("Overlays and status") {
          LazyVGrid(columns: columns, spacing: 16) {
            DemoKitNotificationCard()
            DemoKitDialogCard()
            DemoKitProgressCard(progress: 0.68)
            DemoKitPanelCard("Transient UI") {
              HStack {
                DemoKitToast(text: "Assembly saved")
                Spacer()
              }
            }
            DemoKitPerformanceHUD()
            DemoKitSystemStatusView()
          }
        }

        gallerySection("Inspectors and visualization") {
          LazyVGrid(columns: columns, spacing: 16) {
            DemoKitMateInspector()
            DemoKitCurveCard()
            DemoKitEnvironmentPanel()
            DemoKitVisualizationPanel()
            DemoKitPanelCard("Visualization icon") {
              HStack {
                DemoKitVisualizationIcon()
                DemoKitMaterialSphere(color: .blue)
                Spacer()
              }
            }
            DemoKitPanelCard("Inspector controls") {
              VStack(spacing: 10) {
                DemoKitInspectorTabs()
                DemoKitServoTrack()
                DemoKitNodeLibraryRow()
              }
            }
          }
        }

        gallerySection("Nodes and spatial widgets") {
          LazyVGrid(columns: columns, spacing: 16) {
            DemoKitGraphNode(title: "Actor")
            DemoKitLogicNode()
            DemoKitPanelCard("View Cube") {
              HStack {
                DemoKitViewCube()
                Spacer()
                DemoKitAxisGizmo()
                Spacer()
                DemoKitMoveGizmo()
              }
            }
          }
        }

        gallerySection("Timelines and documents") {
          VStack(spacing: 14) {
            DemoKitDocumentTabBar()
            DemoKitDopeSheetTimeline()
            DemoKitFeatureTimeline()
          }
        }
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .background(StudioPalette.canvas)
  }

  private func gallerySection<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title.uppercased())
        .font(.caption.weight(.bold))
        .tracking(0.9)
        .foregroundStyle(StudioPalette.muted)
      content()
    }
  }
}
