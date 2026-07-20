import SwiftUI

struct AnimatePrototype: View {
  @Bindable var model: PrototypeModel

  var body: some View {
    DockingWorkspace(
      model: model, leftTitle: "Animation Browser", rightTitle: "Motion Inspector",
      leftWidth: 244, rightWidth: 286, centerInset: 0
    ) {
      clipBrowser
    } center: {
      VStack(spacing: 8) {
        MockViewport(
          mode: "ANIMATE · AUTO KEY", selected: "Greeting Pose",
          showsPerformanceHUD: $model.showsViewportPerformanceHUD
        )
        .frame(maxHeight: .infinity)
        TimelinePrototype(selectedTime: $model.selectedTime)
          .frame(height: 255)
          .padding(.horizontal, 10)
          .padding(.bottom, 10)
          .avoidsFloatingWorkspacePanels(.bottom)
      }
    } right: {
      animationInspector
    }
  }

  private var clipBrowser: some View {
    VStack(spacing: 8) {
      PrototypePanel("Animation Clips", subtitle: "ATLAS · 11 CLIPS", icon: "film.stack") {
        VStack(spacing: 2) {
          PrototypeRow(icon: "play.rectangle", title: "Greeting", detail: "8.0 s", selected: true)
          PrototypeRow(icon: "play.rectangle", title: "Idle Breathing", detail: "12.0 s")
          PrototypeRow(icon: "play.rectangle", title: "Curious Look", detail: "4.5 s")
          PrototypeRow(icon: "play.rectangle", title: "Point Left", detail: "3.2 s")
          PrototypeRow(icon: "play.rectangle", title: "Point Right", detail: "3.2 s")
          PrototypeRow(icon: "play.rectangle", title: "Shutdown", detail: "6.0 s")
          Divider().padding(.vertical, 4)
          HStack {
            Button("+ Clip") {}
            Button {
            } label: {
              Image(systemName: "square.on.square")
            }
            Spacer()
          }.padding(9)
        }
      }
      PrototypePanel("Layers", subtitle: "MOTION BLENDING", icon: "square.3.layers.3d") {
        VStack(spacing: 2) {
          PrototypeRow(
            icon: "circle.fill", title: "Base Motion", detail: "100%", statusColor: .green)
          PrototypeRow(
            icon: "circle.lefthalf.filled", title: "Face + Eyes", detail: "100%",
            statusColor: .purple)
          PrototypeRow(icon: "circle", title: "Live Puppet", detail: "0%")
        }.padding(.vertical, 5)
      }
      Spacer(minLength: 0)
    }
  }

  private var animationInspector: some View {
    VStack(spacing: 8) {
      PrototypePanel("Selected Keyframe", subtitle: "HEAD PAN · 2.40 S", icon: "diamond.fill") {
        VStack(spacing: 8) {
          PropertyField(label: "Time", value: String(format: "%.2f", model.selectedTime), unit: "s")
          PropertyField(label: "Value", value: "+22.0", unit: "deg")
          PropertyField(label: "Interpolation", value: "Bezier")
          HStack {
            Text("Ease").font(.system(size: 9))
            Spacer()
            LabelPill(text: "IN 42%")
            LabelPill(text: "OUT 58%")
          }
          MiniCurve()
        }.padding(10)
      }
      PrototypePanel("Pose Controls", subtitle: "LIVE AT PLAYHEAD", icon: "figure.arms.open") {
        VStack(spacing: 9) {
          poseSlider("Head Pan", value: 0.64, text: "+22°", color: .purple)
          poseSlider("Head Tilt", value: 0.42, text: "-8°", color: .cyan)
          poseSlider("Jaw", value: 0.18, text: "12%", color: .orange)
          poseSlider("Eye Aim", value: 0.56, text: "+4°", color: .blue)
        }.padding(10)
      }
      PrototypePanel("Record", subtitle: "PUPPETEERING", icon: "record.circle") {
        HStack {
          Button("Arm Capture") {}
          Spacer()
          LabelPill(text: "OFFLINE", color: .secondary)
        }.padding(10)
      }
      Spacer(minLength: 0)
    }
  }

  private func poseSlider(_ label: String, value: Double, text: String, color: Color) -> some View {
    VStack(spacing: 4) {
      HStack {
        Text(label)
        Spacer()
        Text(text).font(.system(size: 9, design: .monospaced))
      }.font(.system(size: 9))
      Slider(value: .constant(value)).tint(color)
    }
  }
}

private struct MiniCurve: View {
  var body: some View {
    Canvas { context, size in
      var grid = Path()
      for index in 0...4 {
        let y = CGFloat(index) / 4 * size.height
        grid.move(to: CGPoint(x: 0, y: y))
        grid.addLine(to: CGPoint(x: size.width, y: y))
      }
      context.stroke(grid, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
      var curve = Path()
      curve.move(to: CGPoint(x: 0, y: size.height * 0.78))
      curve.addCurve(
        to: CGPoint(x: size.width, y: size.height * 0.18),
        control1: CGPoint(x: size.width * 0.35, y: size.height * 0.82),
        control2: CGPoint(x: size.width * 0.62, y: size.height * 0.12))
      context.stroke(curve, with: .color(.blue), lineWidth: 2)
    }.frame(height: 72).background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
  }
}
