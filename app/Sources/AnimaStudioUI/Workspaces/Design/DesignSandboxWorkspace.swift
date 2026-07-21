import Observation
import SwiftUI

struct StudioDesignSandboxShape: Identifiable, Equatable, Sendable {
  let id: UUID
  var toolName: String
  var name: String
  var position: CGPoint
  var size = CGSize(width: 150, height: 96)
  var material = "Not set"
  var appearance = "Default"
  var opacity = 1.0
  var isVisible = true
  var rotationDegrees = 0.0
}

@MainActor
@Observable
final class StudioDesignSandboxModel {
  static let shared = StudioDesignSandboxModel()

  var shapes: [StudioDesignSandboxShape] = []
  var selectedShapeID: UUID?

  var selectedShape: StudioDesignSandboxShape? {
    selectedShapeID.flatMap { id in shapes.first { $0.id == id } }
  }

  func place(toolName: String, at point: CGPoint) {
    let sequence = shapes.filter { $0.toolName == toolName }.count + 1
    let shape = StudioDesignSandboxShape(
      id: UUID(),
      toolName: toolName,
      name: "\(toolName) \(sequence)",
      position: point
    )
    shapes.append(shape)
    selectedShapeID = shape.id
  }

  func update(_ shape: StudioDesignSandboxShape) {
    guard let index = shapes.firstIndex(where: { $0.id == shape.id }) else { return }
    shapes[index] = shape
  }

  func deleteSelection() {
    guard let selectedShapeID else { return }
    shapes.removeAll { $0.id == selectedShapeID }
    self.selectedShapeID = nil
  }
}

/// A deliberately labelled sandbox surface for future in-app CAD work.
/// It demonstrates the production shell and tool lifecycle without claiming
/// to be a geometric kernel or adding CAD semantics to the Swift front end.
struct StudioDesignSandboxCanvas: View {
  private var model = StudioDesignSandboxModel.shared

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        StudioDesignGrid()
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0)
              .onEnded { value in
                handleCanvasClick(value.location, in: proxy.size)
              }
          )

        ForEach(model.shapes) { shape in
          shapeCard(shape)
            .position(shape.position)
            .onTapGesture { model.selectedShapeID = shape.id }
        }

        Label("DESIGN SANDBOX · PLACEHOLDER GEOMETRY", systemImage: "hammer")
          .font(.caption2.weight(.bold))
          .tracking(0.8)
          .foregroundStyle(StudioPalette.muted)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(StudioPalette.panel.opacity(0.92), in: Capsule())
          .padding(16)
          .allowsHitTesting(false)
      }
      .clipped()
    }
    .background(StudioPalette.canvas)
  }

  private func shapeCard(_ shape: StudioDesignSandboxShape) -> some View {
    let selected = model.selectedShapeID == shape.id
    return VStack(alignment: .leading, spacing: 10) {
      HStack {
        Image(
          systemName: DemoWorkspaceToolCatalog.designGroups
            .flatMap(\.tools)
            .first(where: { $0.title == shape.toolName })?.systemImage ?? "cube")
        Text(shape.name).font(.subheadline.weight(.semibold))
        Spacer()
      }
      Text("Sandbox feature card")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      HStack(spacing: 5) {
        StudioDesignSandboxChip("X \(Int(shape.position.x))")
        StudioDesignSandboxChip("Y \(Int(shape.position.y))")
      }
    }
    .foregroundStyle(Color.primary)
    .padding(13)
    .frame(width: shape.size.width, height: shape.size.height)
    .opacity(shape.isVisible ? shape.opacity : 0.25)
    .background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(selected ? StudioPalette.accent : StudioPalette.border, lineWidth: selected ? 2 : 1)
    }
    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    .rotationEffect(.degrees(shape.rotationDegrees))
  }

  private func handleCanvasClick(_ point: CGPoint, in size: CGSize) {
    if let tool = StudioToolState.shared.armedTool,
      case .arm(.designPlaceholder(let toolID)) = tool.behavior
    {
      model.place(
        toolName: toolID,
        at: CGPoint(
          x: min(max(point.x, 90), max(90, size.width - 90)),
          y: min(max(point.y, 70), max(70, size.height - 70))
        )
      )
      StudioToolState.shared.committed()
    } else {
      model.selectedShapeID = nil
    }
  }
}

private struct StudioDesignGrid: View {
  var body: some View {
    Canvas { context, size in
      var path = Path()
      let step: CGFloat = 24
      for x in stride(from: CGFloat.zero, through: size.width, by: step) {
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
      }
      for y in stride(from: CGFloat.zero, through: size.height, by: step) {
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
      }
      context.stroke(path, with: .color(StudioPalette.border.opacity(0.55)), lineWidth: 0.5)
    }
  }
}

private struct StudioDesignSandboxChip: View {
  let title: String
  init(_ title: String) { self.title = title }
  var body: some View {
    Text(title)
      .font(.caption2.monospaced())
      .foregroundStyle(StudioPalette.muted)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(StudioPalette.panelInset, in: Capsule())
  }
}

struct StudioDesignSandboxBrowser: View {
  let tab: String
  private var model = StudioDesignSandboxModel.shared

  init(tab: String) { self.tab = tab }

  var body: some View {
    VStack(spacing: 0) {
      WorkspacePanelHeader(title: tab, systemImage: icon)
      if rows.isEmpty {
        ContentUnavailableView(
          "No \(tab.lowercased()) yet",
          systemImage: icon,
          description: Text("Use the Design sandbox tools to create a placeholder.")
        )
      } else {
        List(
          selection: Binding(
            get: { model.selectedShapeID.map { Set([$0]) } ?? [] },
            set: { model.selectedShapeID = $0.first }
          )
        ) {
          ForEach(rows) { shape in
            Label(shape.name, systemImage: iconForShape(shape))
              .tag(shape.id)
          }
          .onDelete { offsets in
            let ids = Set(offsets.compactMap { rows.indices.contains($0) ? rows[$0].id : nil })
            model.shapes.removeAll { ids.contains($0.id) }
            if model.selectedShapeID.map(ids.contains) == true { model.selectedShapeID = nil }
          }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
      }
    }
    .studioPanelSurface()
  }

  private var rows: [StudioDesignSandboxShape] {
    switch tab {
    case "Mates": []
    default: model.shapes
    }
  }

  private var icon: String {
    switch tab {
    case "Documents": "doc.on.doc"
    case "Features": "list.bullet.rectangle"
    case "Bodies": "cube"
    default: "link"
    }
  }

  private func iconForShape(_ shape: StudioDesignSandboxShape) -> String {
    DemoWorkspaceToolCatalog.designGroups.flatMap(\.tools)
      .first(where: { $0.title == shape.toolName })?.systemImage ?? "cube"
  }
}

struct StudioDesignPartPropertiesPanel: View {
  private var model = StudioDesignSandboxModel.shared

  var body: some View {
    VStack(spacing: 0) {
      WorkspacePanelHeader(title: "Part Properties", systemImage: "slider.horizontal.3")
      if let selected = model.selectedShape {
        Form {
          Section("General") {
            TextField("Name", text: binding(selected, \.name))
            Picker("Material", selection: binding(selected, \.material)) {
              ForEach(["Not set", "Aluminum", "Steel", "ABS Plastic", "PLA"], id: \.self) {
                Text($0).tag($0)
              }
            }
            Picker("Appearance", selection: binding(selected, \.appearance)) {
              ForEach(["Default", "Painted", "Anodized", "Brushed", "Matte"], id: \.self) {
                Text($0).tag($0)
              }
            }
            Slider(value: binding(selected, \.opacity), in: 0.1...1) {
              Text("Opacity")
            }
            Toggle("Visible", isOn: binding(selected, \.isVisible))
          }
          Section("Transform") {
            LabeledContent("X", value: "\(Int(selected.position.x)) px")
            LabeledContent("Y", value: "\(Int(selected.position.y)) px")
            Stepper(
              "Rotation \(Int(selected.rotationDegrees))°",
              value: binding(selected, \.rotationDegrees),
              in: -180...180,
              step: 1
            )
          }
          Section {
            Button("Delete", systemImage: "trash", role: .destructive) {
              model.deleteSelection()
            }
          }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
      } else {
        ContentUnavailableView(
          "Nothing selected",
          systemImage: "cursorarrow.click",
          description: Text("Select a sandbox feature to edit its properties.")
        )
      }
    }
    .studioPanelSurface()
  }

  private func binding<Value>(
    _ shape: StudioDesignSandboxShape,
    _ keyPath: WritableKeyPath<StudioDesignSandboxShape, Value>
  ) -> Binding<Value> {
    Binding(
      get: {
        model.shapes.first(where: { $0.id == shape.id })?[keyPath: keyPath]
          ?? shape[keyPath: keyPath]
      },
      set: { value in
        var updated = model.shapes.first(where: { $0.id == shape.id }) ?? shape
        updated[keyPath: keyPath] = value
        model.update(updated)
      }
    )
  }
}
