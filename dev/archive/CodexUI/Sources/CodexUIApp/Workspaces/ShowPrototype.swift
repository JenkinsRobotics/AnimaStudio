import SwiftUI

struct ShowPrototype: View {
  @Bindable var model: PrototypeModel

  var body: some View {
    DockingWorkspace(
      model: model, leftTitle: "Show Browser", rightTitle: "Cue Inspector",
      leftWidth: 244, rightWidth: 296, centerInset: 0
    ) {
      cueBrowser
    } center: {
      VStack(spacing: 8) {
        MockViewport(
          mode: "SHOW · STAGE PREVIEW", selected: "Museum Welcome", showsStage: true,
          showsPerformanceHUD: $model.showsViewportPerformanceHUD
        )
        .frame(maxHeight: .infinity)
        showTimeline
          .frame(height: 230)
          .padding(.horizontal, 10)
          .padding(.bottom, 10)
          .avoidsFloatingWorkspacePanels(.bottom)
      }
    } right: {
      showInspector
    }
  }

  private var cueBrowser: some View {
    PrototypePanel("Show Browser", subtitle: "MUSEUM WELCOME · V7", icon: "theatermasks") {
      VStack(spacing: 2) {
        PrototypeRow(icon: "rectangle.3.group", title: "Scenes", detail: "5")
        PrototypeRow(
          icon: "play.rectangle", title: "01 · Guest Arrives", detail: "12 s", level: 1,
          selected: true)
        PrototypeRow(icon: "play.rectangle", title: "02 · Welcome", detail: "26 s", level: 1)
        PrototypeRow(icon: "play.rectangle", title: "03 · Demonstration", detail: "48 s", level: 1)
        PrototypeRow(icon: "play.rectangle", title: "04 · Q + A", detail: "∞", level: 1)
        PrototypeRow(icon: "play.rectangle", title: "05 · Goodbye", detail: "18 s", level: 1)
        Divider().padding(.vertical, 4)
        PrototypeRow(icon: "flag", title: "Operator Cues", detail: "8")
        PrototypeRow(icon: "bolt", title: "Triggers", detail: "5")
        PrototypeRow(icon: "repeat", title: "Fallback Loops", detail: "3")
        Spacer()
        HStack {
          Button("+ Scene") {}
          Button("+ Cue") {}
          Spacer()
        }.padding(9)
      }
    }
  }

  private var showTimeline: some View {
    PrototypePanel("Show Sequence", subtitle: "MULTI-MEDIA CUES", icon: "timeline.selection") {
      VStack(spacing: 0) {
        HStack {
          Button {
          } label: {
            Image(systemName: "backward.end.fill")
          }
          Button {
          } label: {
            Image(systemName: "play.fill")
          }
          Button {
          } label: {
            Image(systemName: "stop.fill")
          }
          Divider().frame(height: 18)
          Text("00:00:08.12").font(.system(size: 10, design: .monospaced))
          Spacer()
          LabelPill(text: "REHEARSAL", color: .orange)
        }
        .buttonStyle(.plain).padding(.horizontal, 10).frame(height: 32)
        cueTrack(
          "Character", color: .purple,
          blocks: [(0.02, 0.25, "Idle"), (0.29, 0.34, "Greeting"), (0.67, 0.27, "Listen")])
        cueTrack(
          "Dialogue", color: .orange,
          blocks: [(0.08, 0.50, "welcome.wav"), (0.64, 0.28, "prompt.wav")])
        cueTrack(
          "Screen", color: .blue, blocks: [(0.0, 0.30, "Logo"), (0.32, 0.60, "Welcome Loop")])
        cueTrack(
          "Lighting", color: .cyan, blocks: [(0.0, 0.20, "Standby"), (0.22, 0.70, "Warm Stage")])
        cueTrack("Events", color: .green, blocks: [(0.12, 0.08, "Door"), (0.76, 0.10, "Ready")])
      }
    }
  }

  private func cueTrack(_ name: String, color: Color, blocks: [(Double, Double, String)])
    -> some View
  {
    HStack(spacing: 0) {
      HStack {
        Circle().fill(color).frame(width: 7, height: 7)
        Text(name)
        Spacer()
      }
      .font(.system(size: 9)).padding(.horizontal, 8).frame(width: 105)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Rectangle().fill(.black.opacity(0.09))
          ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
            Text(block.2).font(.system(size: 8, weight: .medium)).lineLimit(1)
              .padding(.horizontal, 6)
              .frame(width: proxy.size.width * block.1, height: 22, alignment: .leading)
              .background(color.opacity(0.33), in: RoundedRectangle(cornerRadius: 4))
              .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.65)))
              .offset(x: proxy.size.width * block.0)
          }
        }
      }.frame(height: 28)
    }
  }

  private var showInspector: some View {
    VStack(spacing: 8) {
      PrototypePanel("Selected Cue", subtitle: "GREETING · CHARACTER", icon: "figure.wave") {
        VStack(spacing: 8) {
          PropertyField(label: "Clip", value: "Greeting")
          PropertyField(label: "Start", value: "7.20", unit: "s")
          PropertyField(label: "Duration", value: "8.00", unit: "s")
          PropertyField(label: "Blend In", value: "0.35", unit: "s")
          PropertyField(label: "Blend Out", value: "0.50", unit: "s")
          Toggle("Wait for completion", isOn: .constant(true)).font(.system(size: 10))
        }.padding(10)
      }
      PrototypePanel("Operator", subtitle: "LIVE SHOW CONTROL", icon: "person.badge.key") {
        VStack(spacing: 8) {
          HStack {
            LabelPill(text: "SAFE TO RUN", color: .green)
            Spacer()
            LabelPill(text: "3 DEVICES")
          }
          Button("GO · Next Cue") {}.buttonStyle(.borderedProminent).controlSize(.large)
          HStack {
            Button("Hold") {}
            Button("Fade Out") {}
            Button("Stop") {}
          }
        }.padding(10)
      }
      Spacer(minLength: 0)
    }
  }
}
