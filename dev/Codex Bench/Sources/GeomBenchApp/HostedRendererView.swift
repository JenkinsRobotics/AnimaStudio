import AppKit
import CoreImage
import IOSurface
import SwiftUI

struct HostedRendererView: View {
  @Bindable var client: HostedRendererClient
  let theme: BenchTheme

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        HostedSurfaceCanvas(frame: client.frame, backgroundColor: theme.backgroundNSColor)
          .background(theme.backgroundColor)
        if client.frame == nil {
          VStack(spacing: 10) {
            if client.state != .stopped { ProgressView().controlSize(.small) }
            Text(
              client.state.label(readyLabel: client.readyLabel, loadingLabel: client.loadingLabel)
            )
            .font(.callout)
            .foregroundStyle(.secondary)
          }
        }
        CADInputOverlay(
          orbit: { dx, dy in client.orbit(deltaX: dx, deltaY: dy) },
          pan: { dx, dy, _ in client.pan(deltaX: dx, deltaY: dy) },
          roll: { delta in client.roll(deltaX: delta) },
          zoom: { delta in client.zoom(scrollDelta: delta) })
      }
      .onAppear { client.setViewportSize(proxy.size) }
      .onChange(of: proxy.size) { _, size in client.setViewportSize(size) }
    }
  }
}

private struct HostedSurfaceCanvas: NSViewRepresentable {
  let frame: HostedRendererFrame?
  let backgroundColor: NSColor

  func makeNSView(context: Context) -> HostedSurfaceNSView {
    HostedSurfaceNSView()
  }

  func updateNSView(_ view: HostedSurfaceNSView, context: Context) {
    view.setBackgroundColor(backgroundColor)
    view.present(frame)
  }
}

private final class HostedSurfaceNSView: NSView {
  private var representedSequence = -1
  private var retainedSurface: IOSurfaceRef?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.contentsGravity = .resizeAspect
    layer?.backgroundColor =
      NSColor(
        calibratedRed: 0.025, green: 0.035, blue: 0.055, alpha: 1
      ).cgColor
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func present(_ frame: HostedRendererFrame?) {
    guard let frame, frame.sequence != representedSequence else { return }
    representedSequence = frame.sequence
    retainedSurface = frame.surface
    let image = CIImage(ioSurface: frame.surface)
    let representation = NSCIImageRep(ciImage: image)
    let result = NSImage(size: NSSize(width: frame.width, height: frame.height))
    result.addRepresentation(representation)
    layer?.contents = result
  }

  func setBackgroundColor(_ color: NSColor) {
    layer?.backgroundColor = color.cgColor
  }
}
