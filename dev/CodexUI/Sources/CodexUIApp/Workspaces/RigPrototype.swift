import SwiftUI

struct RigPrototype: View {
  @Bindable var model: PrototypeModel

  var body: some View {
    DockingWorkspace(
      model: model, leftTitle: "Character Browser", rightTitle: "Mate Inspector",
      leftWidth: 252, rightWidth: 302, centerInset: 0
    ) {
      rigTree
    } center: {
      MockViewport(
        mode: "RIG · CONNECTOR EDIT", selected: model.selectedPart,
        showsPerformanceHUD: $model.showsViewportPerformanceHUD
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } right: {
      rigInspector
    }
  }

  private var rigTree: some View {
    PrototypePanel(
      "Character Browser", subtitle: "SEMANTIC RIG", icon: "point.3.connected.trianglepath.dotted"
    ) {
      VStack(spacing: 2) {
        HStack {
          Image(systemName: "magnifyingglass")
          Text("Filter :part :mate :locked")
        }
        .font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 9)
        .frame(height: 30).background(.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 5))
        .padding(8)
        PrototypeRow(icon: "cube.fill", title: "Atlas", detail: "ROOT", statusColor: .green)
        PrototypeRow(icon: "lock.fill", title: "Torso", detail: "Grounded", level: 1)
        PrototypeRow(icon: "cube", title: "Neck Base", level: 1)
        PrototypeRow(icon: "link", title: "Neck Yaw", detail: "Revolute", level: 2)
        PrototypeRow(icon: "cube", title: "Head Pan Assembly", level: 2, selected: true)
        PrototypeRow(icon: "link", title: "Head Tilt", detail: "Revolute", level: 3)
        PrototypeRow(icon: "cube", title: "Head Tilt Yoke", level: 3)
        PrototypeRow(icon: "link", title: "Jaw Hinge", detail: "Revolute", level: 4)
        PrototypeRow(icon: "cube", title: "Jaw Mechanism", level: 4)
        PrototypeRow(icon: "link", title: "Left Shoulder", detail: "Ball", level: 2)
        PrototypeRow(icon: "cube", title: "Left Arm", level: 2)
        PrototypeRow(icon: "link", title: "Right Shoulder", detail: "Ball", level: 2)
        PrototypeRow(icon: "cube", title: "Right Arm", level: 2)
        Divider().padding(.vertical, 4)
        PrototypeRow(icon: "equal", title: "Relations", detail: "3")
        PrototypeRow(icon: "gearshape.2", title: "Eyes Coupled", detail: "Gear", level: 1)
        PrototypeRow(
          icon: "arrow.left.arrow.right", title: "Jaw Linkage", detail: "Linear", level: 1)
        Spacer()
        HStack {
          Button("+") {}
          Button("Group") {}
          Spacer()
          Button {
          } label: {
            Image(systemName: "ellipsis")
          }
        }
        .padding(9)
      }
    }
  }

  private var rigInspector: some View {
    VStack(spacing: 8) {
      PrototypePanel("Revolute Mate", subtitle: "HEAD YAW · 1 DOF", icon: "rotate.3d") {
        VStack(spacing: 8) {
          HStack {
            LabelPill(text: "CONNECTED", color: .green)
            Spacer()
            Button("✓") {}
            Button("×") {}
          }
          connector("Connector A", value: "Neck Base · Top center")
          connector("Connector B", value: "Head Pan · Origin")
          Toggle("Offset", isOn: .constant(true)).font(.system(size: 10))
          PropertyField(label: "X", value: "0.0", unit: "mm")
          PropertyField(label: "Y", value: "18.5", unit: "mm")
          PropertyField(label: "Z", value: "0.0", unit: "mm")
          PropertyField(label: "Rotate about", value: "Z", unit: "")
          PropertyField(label: "Angle", value: "0.0", unit: "deg")
          Toggle("Simulation connection", isOn: .constant(true)).font(.system(size: 10))
        }.padding(10)
      }
      PrototypePanel(
        "Motion Limits", subtitle: "NEUTRAL + SAFE RANGE", icon: "gauge.with.dots.needle.33percent"
      ) {
        VStack(spacing: 8) {
          PropertyField(label: "Minimum", value: "-75.0", unit: "deg")
          PropertyField(label: "Neutral", value: "0.0", unit: "deg")
          PropertyField(label: "Maximum", value: "+75.0", unit: "deg")
          HStack {
            Text("Preview").font(.system(size: 9))
            Slider(value: .constant(0.52))
            Text("3°").font(.system(size: 9, design: .monospaced))
          }
        }.padding(10)
      }
      PrototypePanel("Actuator Intent", subtitle: "HARDWARE-NEUTRAL", icon: "cable.connector") {
        HStack {
          LabelPill(text: "UNMAPPED", color: .orange)
          Spacer()
          Button("Map later") {}
        }.padding(10)
      }
      Spacer(minLength: 0)
    }
  }

  private func connector(_ title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title.uppercased()).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
      HStack {
        Image(systemName: "scope").foregroundStyle(.blue)
        Text(value).lineLimit(1)
        Spacer()
        Image(systemName: "arrow.triangle.2.circlepath")
      }
      .font(.system(size: 10)).padding(.horizontal, 8).frame(height: 29)
      .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
    }
  }
}
