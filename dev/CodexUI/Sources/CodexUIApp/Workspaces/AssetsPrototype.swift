import CodexUICore
import SwiftUI

struct AssetsPrototype: View {
  @Bindable var model: PrototypeModel

  var body: some View {
    DockingWorkspace(
      model: model, leftTitle: "Project Content", rightTitle: "Import + Preview",
      leftWidth: 256, rightWidth: 304
    ) {
      assetTree
    } center: {
      assetTable
        .avoidsFloatingWorkspacePanels()
    } right: {
      assetInspector
    }
  }

  private var assetTree: some View {
    PrototypePanel("Project Content", subtitle: "ATLAS SHOW PROJECT · V12", icon: "folder") {
      VStack(spacing: 2) {
        HStack {
          Image(systemName: "magnifyingglass")
          Text("Filter project contents")
        }
        .font(.system(size: 10)).foregroundStyle(.secondary)
        .padding(.horizontal, 9).frame(height: 30)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
        .padding(8)
        PrototypeRow(icon: "person.3", title: "Characters", detail: "2")
        PrototypeRow(
          icon: "person.fill", title: "Atlas", level: 1, selected: true, statusColor: .green)
        PrototypeRow(icon: "cube", title: "Parts", detail: "14", level: 2, selected: true)
        PrototypeRow(icon: "archivebox", title: "Source Assets", detail: "9", level: 2)
        PrototypeRow(icon: "photo", title: "Renders", detail: "3", level: 2)
        PrototypeRow(icon: "square.3.layers.3d", title: "Assemblies", detail: "2", level: 2)
        PrototypeRow(icon: "curlybraces", title: "Scripts", detail: "4", level: 2)
        PrototypeRow(icon: "waveform.path", title: "Animations", detail: "11", level: 2)
        Divider().padding(.vertical, 5)
        PrototypeRow(icon: "shippingbox", title: "Parts Library", detail: "USER")
        PrototypeRow(icon: "circle.grid.cross", title: "Castings", detail: "18", level: 1)
        PrototypeRow(icon: "gearshape.2", title: "Motors", detail: "7", level: 1)
        PrototypeRow(icon: "cube", title: "Structural", detail: "26", level: 1)
        PrototypeRow(icon: "display", title: "Displays", detail: "6", level: 1)
        Spacer()
        Button("+ Create New Character") {}.buttonStyle(.borderedProminent).padding(9)
      }
    }
  }

  private var assetTable: some View {
    PrototypePanel("Parts", subtitle: "ACTIVE CHARACTER · ATLAS", icon: "cube.transparent") {
      VStack(spacing: 0) {
        HStack {
          Label("Table", systemImage: "list.bullet")
          Label("Grid", systemImage: "square.grid.2x2").foregroundStyle(.secondary)
          Spacer()
          TextField("Filter parts", text: .constant("")).textFieldStyle(.roundedBorder).frame(
            width: 170)
          Button("+ Import") {}
        }
        .font(.system(size: 10)).padding(.horizontal, 10).frame(height: 39)
        assetHeader
        ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
          assetRow(part, index: index)
        }
        Spacer(minLength: 0)
      }
    }
  }

  private var assetHeader: some View {
    HStack(spacing: 0) {
      Text("PART").frame(maxWidth: .infinity, alignment: .leading)
      Text("SOURCE").frame(width: 145, alignment: .leading)
      Text("VERSION").frame(width: 72, alignment: .leading)
      Text("ASSEMBLY").frame(width: 110, alignment: .leading)
      Text("STATE").frame(width: 90, alignment: .leading)
    }
    .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
    .padding(.horizontal, 11).frame(height: 30).background(.black.opacity(0.13))
  }

  private func assetRow(_ part: PartRow, index: Int) -> some View {
    HStack(spacing: 0) {
      HStack(spacing: 9) {
        RoundedRectangle(cornerRadius: 4).fill(part.color.opacity(0.25)).frame(
          width: 30, height: 30
        )
        .overlay(Image(systemName: part.icon).foregroundStyle(part.color))
        Text(part.name).fontWeight(index == 0 ? .semibold : .regular)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Text(part.source).frame(width: 145, alignment: .leading).foregroundStyle(.secondary)
      LabelPill(text: "V\(part.version)").frame(width: 72, alignment: .leading)
      Text(part.assembly).frame(width: 110, alignment: .leading)
      Label(
        part.state,
        systemImage: part.state == "Ready" ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
      )
      .foregroundStyle(part.state == "Ready" ? Color.green : Color.orange)
      .frame(width: 90, alignment: .leading)
    }
    .font(.system(size: 10)).padding(.horizontal, 11).frame(height: 45)
    .background(
      index == 0
        ? Color.blue.opacity(0.13) : (index.isMultiple(of: 2) ? Color.white.opacity(0.018) : .clear)
    )
    .overlay(alignment: .bottom) { Divider().opacity(0.35) }
    .onTapGesture { model.selectedPart = part.name }
  }

  private var assetInspector: some View {
    VStack(spacing: 8) {
      PrototypePanel(
        "Load 3D Assembly", subtitle: "STL · OBJ · USD · USDZ", icon: "square.and.arrow.down"
      ) {
        VStack(spacing: 9) {
          RoundedRectangle(cornerRadius: 7).stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .foregroundStyle(.secondary.opacity(0.55)).frame(height: 108)
            .overlay(
              VStack(spacing: 7) {
                Image(systemName: "arrow.down.doc").font(.system(size: 24)).foregroundStyle(.blue)
                Text("Drop model files here").font(.system(size: 11, weight: .semibold))
                Text("or click to choose files").font(.system(size: 9)).foregroundStyle(.secondary)
              })
          HStack {
            Label("Units prompted", systemImage: "ruler")
            Spacer()
            Text("Batch supported")
          }
          .font(.system(size: 8)).foregroundStyle(.secondary)
        }.padding(10)
      }
      PrototypePanel(
        "Preview", subtitle: model.selectedPart, icon: "eye",
        minimumContentHeight: CGFloat(FloatingPanelSizing.spatialPreviewMinimumContentHeight)
      ) {
        MockViewport(mode: "ASSET PREVIEW", selected: model.selectedPart)
          .padding(8)
      }
      Spacer(minLength: 0)
    }
  }

  private var parts: [PartRow] {
    [
      PartRow("Head Pan Assembly", "head_pan.usdz", 4, "Head", "Ready", "rotate.3d", .orange),
      PartRow("Head Tilt Yoke", "tilt_yoke.step", 2, "Head", "Ready", "move.3d", .purple),
      PartRow("Jaw Mechanism", "jaw.stl", 3, "Head", "Updated", "gearshape.2", .blue),
      PartRow("Torso Shell", "torso.usdz", 1, "Body", "Ready", "cube", .cyan),
      PartRow("Left Arm Link", "arm_left.obj", 2, "Body", "Ready", "figure.arms.open", .green),
      PartRow("Right Arm Link", "arm_right.obj", 2, "Body", "Ready", "figure.arms.open", .green),
      PartRow("LED Eye Matrix", "eye_panel.usdz", 6, "Face", "Ready", "circle.grid.3x3", .pink),
      PartRow("Chest Display", "screen.usdz", 1, "Body", "Ready", "display", .indigo),
    ]
  }
}

private struct PartRow {
  let name: String
  let source: String
  let version: Int
  let assembly: String
  let state: String
  let icon: String
  let color: Color

  init(
    _ name: String, _ source: String, _ version: Int, _ assembly: String, _ state: String,
    _ icon: String, _ color: Color
  ) {
    self.name = name
    self.source = source
    self.version = version
    self.assembly = assembly
    self.state = state
    self.icon = icon
    self.color = color
  }
}
