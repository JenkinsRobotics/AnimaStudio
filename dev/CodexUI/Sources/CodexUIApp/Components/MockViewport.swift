import SwiftUI

struct MockViewport: View {
  @Environment(\.prototypeTheme) private var theme
  var mode = "RIG VIEW"
  var selected = "Head Pan Assembly"
  var showsStage = false
  @Binding private var showsPerformanceHUD: Bool
  private let supportsPerformanceHUD: Bool

  init(
    mode: String = "RIG VIEW",
    selected: String = "Head Pan Assembly",
    showsStage: Bool = false,
    showsPerformanceHUD: Binding<Bool>? = nil
  ) {
    self.mode = mode
    self.selected = selected
    self.showsStage = showsStage
    _showsPerformanceHUD = showsPerformanceHUD ?? .constant(false)
    supportsPerformanceHUD = showsPerformanceHUD != nil
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        LinearGradient(
          colors: [theme.canvas, theme.canvas.opacity(0.72), theme.panel],
          startPoint: .top, endPoint: .bottom)
        Canvas { context, size in
          drawGrid(context: &context, size: size)
          drawRobot(context: &context, size: size)
          if showsStage { drawStage(context: &context, size: size) }
        }
        VStack {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
              LabelPill(text: mode, color: theme.accent)
              Text(selected).font(.system(size: 11, weight: .semibold))
              Text("Character space · millimetres").font(.system(size: 9)).foregroundStyle(
                theme.secondaryText)
            }
            Spacer()
            ViewCube()
          }
          Spacer()
          HStack {
            HStack(spacing: 11) {
              Image(systemName: "house")
              Image(systemName: "cube")
              Image(systemName: "square.split.diagonal")
              Image(systemName: "camera")
              if supportsPerformanceHUD {
                Button {
                  showsPerformanceHUD.toggle()
                } label: {
                  Image(systemName: "gauge.with.dots.needle.50percent")
                    .foregroundStyle(showsPerformanceHUD ? theme.accent : theme.primaryText)
                }
                .buttonStyle(.plain)
                .help(showsPerformanceHUD ? "Hide performance HUD" : "Show performance HUD")
              }
              Image(systemName: "questionmark.circle")
            }
            .font(.system(size: 11)).foregroundStyle(theme.primaryText)
            .padding(.horizontal, 12).frame(height: 31)
            .background(.black.opacity(0.45), in: Capsule())
            Spacer()
            Label("Shaded with edges", systemImage: "cube.transparent")
              .font(.system(size: 9)).foregroundStyle(theme.secondaryText)
          }
        }
        .padding(12)

        if showsPerformanceHUD {
          ViewportPerformanceHUD(viewportMode: mode)
            .padding(.trailing, 12)
            .padding(.bottom, 52)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
      .animation(.spring(response: 0.28, dampingFraction: 0.88), value: showsPerformanceHUD)
    }
  }

  private func drawGrid(context: inout GraphicsContext, size: CGSize) {
    let horizon = size.height * 0.62
    for index in 0...18 {
      let t = CGFloat(index) / 18
      let y = horizon + pow(t, 1.65) * size.height * 0.38
      var line = Path()
      line.move(to: CGPoint(x: 0, y: y))
      line.addLine(to: CGPoint(x: size.width, y: y))
      context.stroke(
        line, with: .color(theme.line.opacity(index % 3 == 0 ? 0.95 : 0.48)), lineWidth: 0.7)
    }
    for index in -14...14 {
      let center = size.width / 2
      let bottomX = center + CGFloat(index) * size.width / 13
      let topX = center + CGFloat(index) * size.width / 70
      var line = Path()
      line.move(to: CGPoint(x: topX, y: horizon))
      line.addLine(to: CGPoint(x: bottomX, y: size.height))
      context.stroke(
        line, with: .color(theme.line.opacity(index == 0 ? 1 : 0.55)),
        lineWidth: index == 0 ? 1.2 : 0.7)
    }
  }

  private func drawRobot(context: inout GraphicsContext, size: CGSize) {
    let scale = min(size.width, size.height) / 650
    let center = CGPoint(x: size.width * 0.52, y: size.height * 0.47)
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, radius: CGFloat = 8)
      -> Path
    {
      Path(
        roundedRect: CGRect(
          x: center.x + x * scale, y: center.y + y * scale, width: width * scale,
          height: height * scale), cornerRadius: radius * scale)
    }
    let surface =
      theme == .cadLight
      ? Color(red: 0.54, green: 0.62, blue: 0.72) : Color(red: 0.28, green: 0.40, blue: 0.52)
    let dark =
      theme == .cadLight
      ? Color(red: 0.26, green: 0.30, blue: 0.34) : Color(red: 0.09, green: 0.12, blue: 0.16)

    context.fill(rect(-92, -15, 184, 210, radius: 25), with: .color(surface))
    context.stroke(
      rect(-92, -15, 184, 210, radius: 25), with: .color(theme.primaryText.opacity(0.48)),
      lineWidth: 1.5)
    context.fill(rect(-66, 28, 132, 68, radius: 15), with: .color(dark))

    context.fill(rect(-65, -130, 130, 104, radius: 24), with: .color(theme.orange.opacity(0.92)))
    context.stroke(
      rect(-65, -130, 130, 104, radius: 24), with: .color(Color.white.opacity(0.72)), lineWidth: 2)
    context.fill(rect(-44, -105, 88, 48, radius: 10), with: .color(dark))
    context.fill(
      Path(
        ellipseIn: CGRect(
          x: center.x - 27 * scale, y: center.y - 89 * scale, width: 16 * scale, height: 16 * scale)
      ), with: .color(theme.cyan))
    context.fill(
      Path(
        ellipseIn: CGRect(
          x: center.x + 11 * scale, y: center.y - 89 * scale, width: 16 * scale, height: 16 * scale)
      ), with: .color(theme.cyan))

    for side: CGFloat in [-1, 1] {
      let shoulderX = center.x + side * 118 * scale
      let shoulderY = center.y + 13 * scale
      context.fill(
        Path(
          ellipseIn: CGRect(
            x: shoulderX - 26 * scale, y: shoulderY - 26 * scale, width: 52 * scale,
            height: 52 * scale)), with: .color(theme.purple))
      var upper = Path()
      upper.move(to: CGPoint(x: shoulderX, y: shoulderY))
      upper.addLine(to: CGPoint(x: shoulderX + side * 47 * scale, y: shoulderY + 92 * scale))
      context.stroke(
        upper, with: .color(surface), style: StrokeStyle(lineWidth: 32 * scale, lineCap: .round))
      let elbow = CGPoint(x: shoulderX + side * 47 * scale, y: shoulderY + 92 * scale)
      context.fill(
        Path(
          ellipseIn: CGRect(
            x: elbow.x - 18 * scale, y: elbow.y - 18 * scale, width: 36 * scale, height: 36 * scale)
        ), with: .color(theme.accent))
      var lower = Path()
      lower.move(to: elbow)
      lower.addLine(to: CGPoint(x: elbow.x + side * 19 * scale, y: elbow.y + 84 * scale))
      context.stroke(
        lower, with: .color(surface), style: StrokeStyle(lineWidth: 25 * scale, lineCap: .round))
    }

    let axisOrigin = CGPoint(x: center.x + 8 * scale, y: center.y - 18 * scale)
    let axes: [(CGPoint, Color)] = [
      (CGPoint(x: axisOrigin.x + 66 * scale, y: axisOrigin.y), .red),
      (CGPoint(x: axisOrigin.x - 39 * scale, y: axisOrigin.y - 45 * scale), .green),
      (CGPoint(x: axisOrigin.x, y: axisOrigin.y - 72 * scale), .blue),
    ]
    for (point, color) in axes {
      var path = Path()
      path.move(to: axisOrigin)
      path.addLine(to: point)
      context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
      context.fill(
        Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)),
        with: .color(color))
    }
  }

  private func drawStage(context: inout GraphicsContext, size: CGSize) {
    let frame = CGRect(
      x: size.width * 0.14, y: size.height * 0.12, width: size.width * 0.72,
      height: size.height * 0.58)
    context.stroke(
      Path(roundedRect: frame, cornerRadius: 16), with: .color(theme.purple.opacity(0.6)),
      lineWidth: 2)
    for x in [frame.minX + 35, frame.maxX - 35] {
      var beam = Path()
      beam.move(to: CGPoint(x: x, y: frame.minY))
      beam.addLine(to: CGPoint(x: size.width * 0.5, y: frame.maxY))
      context.stroke(
        beam, with: .color(theme.cyan.opacity(0.18)),
        style: StrokeStyle(lineWidth: 26, lineCap: .round))
    }
  }
}

private struct ViewCube: View {
  @Environment(\.prototypeTheme) private var theme

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 7).fill(theme.raised.opacity(0.92))
      VStack(spacing: 1) {
        Text("TOP").font(.system(size: 7, weight: .bold))
        HStack(spacing: 3) {
          Text("FRONT").font(.system(size: 7, weight: .bold))
          Text("RIGHT").font(.system(size: 7, weight: .bold)).rotationEffect(.degrees(-90))
        }
      }
      .foregroundStyle(theme.primaryText)
    }
    .frame(width: 72, height: 72)
    .overlay(RoundedRectangle(cornerRadius: 7).stroke(theme.line))
  }
}
