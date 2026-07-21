import SwiftUI

// MARK: - Demo domain specimens

struct DemoKitMateInspector: View {
  @State private var angle = 42.0
  var body: some View {
    DemoKitPanelCard("Knee · Revolute", subtitle: "Z AXIS") {
      VStack(spacing: 8) {
        DemoKitField(
          label: "Angle", value: angle.formatted(.number.precision(.fractionLength(1))), unit: "deg"
        )
        Slider(value: $angle, in: -5...140)
        HStack {
          DemoKitField(label: "Min", value: "-5°")
          DemoKitField(label: "Max", value: "140°")
        }
      }
    }
  }
}

struct DemoKitCurveCard: View {
  var body: some View {
    DemoKitPanelCard("Curve · Knee") {
      Canvas { context, size in
        var p = Path()
        p.move(to: CGPoint(x: 0, y: size.height * 0.7))
        p.addCurve(
          to: CGPoint(x: size.width, y: size.height * 0.25),
          control1: CGPoint(x: size.width * 0.25, y: 0),
          control2: CGPoint(x: size.width * 0.7, y: size.height))
        context.stroke(p, with: .color(StudioPalette.accent), lineWidth: 2)
      }.frame(height: 80)
    }
  }
}

struct DemoKitEnvironmentPanel: View {
  @State private var intensity = 0.8
  var body: some View {
    DemoKitPanelCard("Environment", subtitle: "STUDIO LIGHTING") {
      VStack(alignment: .leading, spacing: 8) {
        DemoKitChipPicker(selection: .constant("Studio"), values: ["Studio", "Mood", "Stage"])
        Slider(value: $intensity)
        DemoKitField(label: "Intensity", value: "\(Int(intensity * 100))", unit: "%")
      }
    }
  }
}

struct DemoKitMaterialSphere: View {
  let color: Color
  var body: some View {
    Circle().fill(
      RadialGradient(
        colors: [.white, color, .black], center: .topLeading, startRadius: 2, endRadius: 54)
    ).overlay(Circle().stroke(.white.opacity(0.25))).frame(width: 76, height: 76).shadow(radius: 8)
  }
}

struct DemoKitVisualizationIcon: View {
  var body: some View {
    Circle().fill(
      AngularGradient(
        colors: [.pink, .yellow, .green, .cyan, .blue, .purple, .pink], center: .center)
    ).frame(width: 24, height: 24)
  }
}

struct DemoKitVisualizationPanel: View {
  var body: some View {
    DemoKitPanelCard("Visualization", subtitle: "MATERIAL · ENVIRONMENT") {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
        ForEach([Color.red, .gray, .blue, .orange], id: \.description) {
          DemoKitMaterialSphere(color: $0)
        }
      }
    }
  }
}

struct DemoKitPerformanceHUD: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      DemoKitField(label: "PIPELINE", value: "MetalKit")
      DemoKitField(label: "FPS", value: "60.0")
      DemoKitField(label: "CPU", value: "4.3", unit: "%")
      DemoKitField(label: "MEMORY", value: "98.4", unit: "MB")
    }.padding(10).background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
  }
}

struct DemoKitSystemStatusView: View {
  var body: some View {
    HStack {
      Circle().fill(.green).frame(width: 7)
      Text("ENGINE READY")
      Spacer()
      Text("NO DRIVER")
      DemoKitPill(text: "MASTER SAFE", tint: .green)
    }.font(.caption2.weight(.bold)).padding(8).background(StudioPalette.panelInset, in: Capsule())
  }
}

struct DemoKitDopeSheetTimeline: View {
  var body: some View {
    DemoKitTimelineFrame(title: "Dope Sheet") {
      Canvas { context, size in
        for row in 0..<4 {
          for column in [1, 4, 7] {
            let rect = CGRect(
              x: CGFloat(column) * size.width / 9,
              y: CGFloat(row) * 28 + 12,
              width: 7,
              height: 7
            )
            let color: Color = row.isMultiple(of: 2) ? .cyan : .purple
            context.fill(Path(ellipseIn: rect), with: .color(color))
          }
        }
        var playhead = Path()
        playhead.move(to: CGPoint(x: size.width * 0.42, y: 0))
        playhead.addLine(to: CGPoint(x: size.width * 0.42, y: size.height))
        context.stroke(playhead, with: .color(.blue), lineWidth: 2)
      }
      .frame(height: 120)
    }
  }
}

private struct DemoKitTimelineFrame<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content
  init(title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(StudioPalette.muted)
      content
    }.padding(10).background(StudioPalette.panel, in: RoundedRectangle(cornerRadius: 11)).overlay(
      RoundedRectangle(cornerRadius: 11).stroke(StudioPalette.border))
  }
}

struct DemoKitGraphNode: View {
  let title: String
  var tint = StudioPalette.accent
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(title.uppercased()).font(.caption.weight(.bold))
        Spacer()
        Image(systemName: "bolt")
      }
      Divider()
      HStack {
        Circle().fill(tint).frame(width: 8)
        Text("INPUT")
        Spacer()
        Text("OUTPUT")
        Circle().stroke(tint).frame(width: 8, height: 8)
      }.font(.caption2)
    }.padding(11).frame(width: 190).background(
      StudioPalette.panel, in: RoundedRectangle(cornerRadius: 12)
    ).overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 2))
  }
}

struct DemoKitServoTrack: View {
  var body: some View { DemoKitRow(icon: "gearshape", label: "Head Pan", value: "+22°") }
}
struct DemoKitLogicNode: View {
  var body: some View { DemoKitGraphNode(title: "IF / ELSE", tint: .purple) }
}
struct DemoKitNodeLibraryRow: View {
  var body: some View { DemoKitListRow(icon: "waveform", title: "Speech to Text", detail: "INPUT") }
}

struct DemoKitFeatureTimeline: View {
  var body: some View {
    DemoKitTimelineFrame(title: "Feature Timeline") {
      HStack {
        ForEach(["Sketch", "Extrude", "Fillet", "Mate"], id: \.self) { DemoKitPill(text: $0) }
        Spacer()
      }
    }
  }
}

struct DemoKitDocumentTabBar: View {
  var body: some View {
    HStack(spacing: 0) {
      ForEach(["assembly", "head", "show"], id: \.self) {
        Text($0).font(.caption).padding(.horizontal, 16).frame(height: 30).background(
          $0 == "assembly" ? StudioPalette.panelInset : Color.clear)
      }
      Spacer()
      Image(systemName: "plus")
    }.background(StudioPalette.panel)
  }
}

struct DemoKitInspectorTabs: View {
  @State private var selection = 0
  var body: some View {
    DemoKitSegmentedIcons(
      icons: ["slider.horizontal.3", "paintpalette", "info.circle"], selection: $selection)
  }
}

struct DemoKitSearchField: View {
  @State private var text = ""
  var body: some View { TextField("Search", text: $text).textFieldStyle(.roundedBorder) }
}

struct DemoKitStepperField: View {
  @State private var value = 12.0
  var body: some View {
    Stepper("Offset \(value.formatted()) mm", value: $value, step: 1).font(.caption)
  }
}

struct DemoKitAxisGizmo: View {
  var body: some View {
    Canvas { context, size in
      let c = CGPoint(x: size.width / 2, y: size.height / 2)
      for (end, color) in [
        (CGPoint(x: size.width - 5, y: c.y), Color.red), (CGPoint(x: c.x, y: 5), .green),
        (CGPoint(x: 8, y: size.height - 8), .blue),
      ] {
        var p = Path()
        p.move(to: c)
        p.addLine(to: end)
        context.stroke(p, with: .color(color), lineWidth: 3)
      }
    }.frame(width: 90, height: 90)
  }
}

struct DemoKitViewCube: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 5).fill(StudioPalette.panelInset).frame(width: 78, height: 78)
        .rotationEffect(.degrees(30))
      Text("TOP").font(.caption2.weight(.bold)).offset(y: -18)
      Text("FRONT").font(.caption2.weight(.bold)).offset(y: 17)
    }
  }
}

struct DemoKitMoveGizmo: View {
  var body: some View {
    ZStack {
      DemoKitAxisGizmo()
      Circle().stroke(.orange, lineWidth: 3).frame(width: 68, height: 68)
      Image(systemName: "move.3d").font(.title2)
    }
  }
}
