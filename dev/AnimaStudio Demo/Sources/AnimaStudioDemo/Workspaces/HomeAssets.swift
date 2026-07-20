import GeomKit
import SwiftUI

// MARK: - Home / project launch

struct HomeWorkspace: View {
  var go: (Workspace) -> Void
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 26) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Welcome back").font(.system(size: 13)).foregroundStyle(UI.text3)
          Text("What are we bringing to life today?")
            .font(.system(size: 28, weight: .semibold)).foregroundStyle(UI.text)
        }
        .padding(.top, 20)

        HStack(spacing: 14) {
          bigAction("Import model", "cube.transparent", "STEP · STL · OBJ · glTF", UI.accent2) {
            go(.assets)
          }
          bigAction("New character", "plus.viewfinder", "Start from an empty rig", UI.accent) {
            go(.rig)
          }
          bigAction("Open show", "rectangle.3.group", "Sequence + hardware", UI.warn) {
            go(.show)
          }
        }

        Text("RECENT").font(.system(size: 10.5, weight: .semibold)).tracking(0.6)
          .foregroundStyle(UI.text3)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
          projectCard("Rex", "animatronic dinosaur", "18 parts · 6 servos", UI.accent2)
          projectCard("Marble Bust", "AR avatar", "1 mesh · face rig", UI.accent)
          projectCard("Show — Lobby", "3 characters", "timeline · 4:20", UI.warn)
        }
      }
      .padding(28).frame(maxWidth: 980, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
  }

  func bigAction(_ title: String, _ icon: String, _ sub: String, _ tint: Color, _ tap: @escaping () -> Void) -> some View {
    Button(action: tap) {
      VStack(alignment: .leading, spacing: 12) {
        Image(systemName: icon).font(.system(size: 22)).foregroundStyle(tint)
        Spacer(minLength: 18)
        Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.text)
        Text(sub).font(.system(size: 11.5)).foregroundStyle(UI.text3)
      }
      .padding(18).frame(height: 150, alignment: .topLeading).frame(maxWidth: .infinity, alignment: .leading)
      .background(UI.panel, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.25), lineWidth: 1))
    }
    .buttonStyle(.plain)
  }

  func projectCard(_ name: String, _ kind: String, _ meta: String, _ tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack {
        LinearGradient(colors: [tint.opacity(0.4), UI.stageBottom],
          startPoint: .topLeading, endPoint: .bottomTrailing)
        Image(systemName: "cube.transparent").font(.system(size: 30)).foregroundStyle(.white.opacity(0.7))
      }
      .frame(height: 96)
      VStack(alignment: .leading, spacing: 3) {
        Text(name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(UI.text)
        Text(kind).font(.system(size: 11)).foregroundStyle(UI.text2)
        Text(meta).font(.system(size: 10.5)).foregroundStyle(UI.text3).padding(.top, 2)
      }
      .padding(12).frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(UI.panel, in: RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(UI.stroke, lineWidth: 1))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

// MARK: - Assets / import + parts

struct AssetsWorkspace: View {
  @State private var model = DemoModel.shared

  private var layout: LayoutState { LayoutState.shared }

  var body: some View {
    VStack(spacing: 0) {
      if layout.ribbonDocked {
        ToolRibbon(groups: assetTools)
        Divider().overlay(UI.stroke)
      }
      FloatingWorkspace(leftWidth: 250, rightWidth: 268, edgeToEdge: true,
        rightSelected: model.selected != nil) {
      // Left — the real list of imported models (starts empty)
      Panel(title: "Models", systemImage: "cube.transparent") {
        ScrollView {
          VStack(spacing: 0) {
            if model.parts.isEmpty {
              VStack(spacing: 8) {
                Image(systemName: "tray").font(.system(size: 22)).foregroundStyle(UI.text3)
                Text("No models yet").font(.system(size: 12, weight: .medium)).foregroundStyle(UI.text2)
                Text("Import a STEP file to begin").font(.system(size: 10.5))
                  .foregroundStyle(UI.text3).multilineTextAlignment(.center)
              }.frame(maxWidth: .infinity).padding(.vertical, 34).padding(.horizontal, 12)
            } else {
              ForEach(model.parts) { part in
                Row(icon: "cube", label: part.name, detail: "\(part.document.faces.count)f",
                  tint: UI.accent2, selected: model.selectedID == part.id, controls: true)
                  .onTapGesture { model.selectedID = part.id }
              }
            }
          }.padding(.vertical, 4)
        }
        Divider().overlay(UI.stroke)
        Button { model.importFiles() } label: {
          HStack { Image(systemName: model.loading ? "hourglass" : "plus"); Text("Import STEP…") }
            .font(.system(size: 12, weight: .medium)).foregroundStyle(UI.accent)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
        }.buttonStyle(.plain).disabled(model.loading)
      }
    } center: {
      ZStack(alignment: .bottom) {
        if let part = model.selected {
          EngineViewport(document: part.document)
        } else {
          EmptyStage(status: model.status, importAction: { model.importFiles() })
        }
        CenterTray(items: [
          TrayItem("plus", "Import"),
          TrayItem("cube", "Display") {
            VStack(alignment: .leading, spacing: 10) {
              Text("DISPLAY").font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(UI.text3)
              HStack(spacing: 8) {
                Pill(icon: "square.grid.3x3", label: "Shaded", active: true)
                Pill(icon: "cube", label: "Wireframe")
              }
            }.padding(14).frame(width: 240)
          },
          TrayItem("sun.max", "Environment") { EnvironmentPanel() },
          TrayItem("speedometer", "Performance") {
            VStack(alignment: .leading, spacing: 9) {
              HStack {
                Text("IMPORT · LIVE").font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(UI.text3)
                Spacer()
                Button {
                  withAnimation(.spring(response: 0.3)) { RenderState.shared.pinPerformance.toggle() }
                } label: {
                  Image(systemName: RenderState.shared.pinPerformance ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RenderState.shared.pinPerformance ? UI.accent : UI.text3)
                }.buttonStyle(.plain).help("Pin live stats to the viewport corner")
              }
              Field(label: "Faces", value: "\(model.selected?.document.faces.count ?? 0)")
              Field(label: "Edges", value: "\(model.selected?.document.edges.count ?? 0)")
              Field(label: "Triangles", value: "\(model.selected?.document.triangleCount ?? 0)")
              Field(label: "Read", value: String(format: "%.0f", model.selected?.document.metrics.readMilliseconds ?? 0), unit: "ms")
              Field(label: "Mesh", value: String(format: "%.0f", model.selected?.document.metrics.triangulationMilliseconds ?? 0), unit: "ms")
              Field(label: "Kernel", value: GeomKernel.version)
            }.padding(14).frame(width: 260)
          },
          TrayItem("viewfinder", "Fit"),
        ])
        .padding(.bottom, 18)
      }
      .overlay(alignment: .top) {
        if !layout.ribbonDocked { ToolRibbon(groups: assetTools).padding(.top, 16) }
      }
    } right: {
      // Right — real inspector for the selected imported part
      if let part = model.selected {
        Panel(title: "Part · \(part.name)", systemImage: "info.circle") {
          VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 9) {
              Field(label: "Source", value: part.name)
              Field(label: "Faces", value: "\(part.document.faces.count)")
              Field(label: "Edges", value: "\(part.document.edges.count)")
              Field(label: "Triangles", value: "\(part.document.triangleCount)")
              Field(label: "Import", value: String(format: "%.0f", part.document.metrics.totalMilliseconds), unit: "ms")
            }
            Divider().overlay(UI.stroke)
            Text("STATUS").font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(UI.text3)
            HStack(spacing: 8) {
              statusDot("Geometry OK", UI.ok, "checkmark.circle.fill")
              statusDot("Not rigged", UI.warn, "exclamationmark.triangle.fill")
            }
            Spacer()
            Button { model.remove(part.id) } label: {
              HStack(spacing: 6) { Image(systemName: "trash"); Text("Remove") }
                .font(.system(size: 12, weight: .medium)).foregroundStyle(UI.danger)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(UI.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain)
          }
          .padding(14)
        }
      }
      }
    }
  }

  // Asset tool catalog — transform verbs + inspect.
  private var assetTools: [RibbonGroup] {
    [
      RibbonGroup("Transform", "move.3d", .teal, [
        RibbonTool("cursorarrow", "Select"), RibbonTool("move.3d", "Move"),
        RibbonTool("rotate.3d", "Rotate"),
        RibbonTool("arrow.up.left.and.arrow.down.right", "Scale"),
      ]),
      RibbonGroup("Inspect", "magnifyingglass", .blue, [
        RibbonTool("ruler", "Measure"), RibbonTool("square.dashed", "Section"),
      ]),
    ]
  }

  var previewThumb: some View {
    ZStack {
      RadialGradient(colors: [UI.accent2.opacity(0.35), UI.stageBottom], center: .center, startRadius: 5, endRadius: 130)
      Image(systemName: "cube.transparent.fill").font(.system(size: 40)).foregroundStyle(UI.accent2.opacity(0.9))
    }
    .frame(height: 130).clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(UI.stroke, lineWidth: 1))
  }

  func importStat(_ k: String, _ v: String, tint: Color = UI.text) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(k.uppercased()).font(.system(size: 8.5, weight: .semibold)).tracking(0.5).foregroundStyle(UI.text3)
      Text(v).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(tint)
    }
    .padding(.horizontal, 10).padding(.vertical, 7)
    .background(UI.panel.opacity(0.85), in: RoundedRectangle(cornerRadius: 7))
    .overlay(RoundedRectangle(cornerRadius: 7).stroke(UI.stroke, lineWidth: 1))
  }

  func statusDot(_ label: String, _ tint: Color, _ icon: String) -> some View {
    HStack(spacing: 5) {
      Image(systemName: icon).font(.system(size: 10)).foregroundStyle(tint)
      Text(label).font(.system(size: 10.5)).foregroundStyle(UI.text2)
    }
    .padding(.horizontal, 8).padding(.vertical, 5)
    .background(tint.opacity(0.12), in: Capsule())
  }
}
