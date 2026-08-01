import AnimaCoreClient
import AppKit
import SwiftUI

/// Center view for the **VR Character** workspace — a live avatar you perform.
///
/// A VR character is an avatar (here a procedural face) driven by face-tracking
/// blendshapes. The engine side already works: the tracker's ARKit blendshapes
/// (`animacore/tracking.py`) become the evaluated `values` the avatar's controls
/// read, so this preview maps blendshapes → the face and renders via the bridge
/// (`canvas2d.new` → `render_frame`). The sliders below stand in for the tracker;
/// the Mac-webcam (Vision) capture that replaces them feeds the *same* values.
struct VRCharacterWorkspaceView: View {
  private enum Status: Equatable {
    case loading
    case ready
    case unavailable(String)
    case failed(String)
  }

  @State private var client: AnimaCoreClient?
  @State private var handle: String?
  @State private var image: NSImage?
  @State private var status: Status = .loading

  // ARKit-style blendshape coefficients (0..1) + head turn (-1..1).
  @State private var jawOpen = 0.1
  @State private var smile = 0.3
  @State private var blink = 0.0
  @State private var headYaw = 0.0
  @State private var time = 1.0

  private var renderKey: String { "\(jawOpen)|\(smile)|\(blink)|\(headYaw)|\(time)" }

  var body: some View {
    ZStack {
      StudioPalette.canvas.ignoresSafeArea()
      VStack(spacing: 20) {
        preview
        trackingPanel
        controls
      }
      .padding(32)
      .frame(maxWidth: 760)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .task { await setup() }
    .onChange(of: renderKey) { Task { await render() } }
  }

  private var preview: some View {
    VStack(spacing: 10) {
      Text("VR Avatar")
        .font(.title2.weight(.semibold))
        .foregroundStyle(StudioPalette.ink)
      Text("Live from AnimaCore · face blendshapes → avatar")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      previewSurface
        .frame(width: 256, height: 256)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.black))
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(StudioPalette.border))
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(StudioPalette.panel))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(StudioPalette.border))
  }

  @ViewBuilder
  private var previewSurface: some View {
    switch status {
    case .loading:
      ProgressView().controlSize(.large)
    case .ready:
      if let image {
        Image(nsImage: image)
          .resizable()
          .interpolation(.none)
          .scaledToFit()
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
    case .unavailable(let message), .failed(let message):
      VStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 28))
          .foregroundStyle(.orange)
        Text(message)
          .font(.caption)
          .multilineTextAlignment(.center)
          .foregroundStyle(StudioPalette.muted)
          .padding(.horizontal, 12)
      }
    }
  }

  private var trackingPanel: some View {
    HStack(spacing: 10) {
      Image(systemName: "video")
        .foregroundStyle(StudioPalette.muted)
      Text("Face tracking — Mac webcam (Vision) coming; drive with the sliders for now.")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      Spacer()
      Button("Start camera") {}
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(true)
        .help("Vision-based webcam tracking lands next")
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(StudioPalette.panel))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(StudioPalette.border))
  }

  private var controls: some View {
    VStack(spacing: 10) {
      slider("Jaw open", value: $jawOpen, range: 0...1)
      slider("Smile", value: $smile, range: 0...1)
      slider("Blink", value: $blink, range: 0...1)
      slider("Head turn", value: $headYaw, range: -1...1)
    }
    .padding(16)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(StudioPalette.panel))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(StudioPalette.border)
    )
    .disabled(handle == nil)
  }

  private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>)
    -> some View
  {
    HStack(spacing: 12) {
      Text(title)
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
        .frame(width: 110, alignment: .leading)
      Slider(value: value, in: range)
      Text(String(format: "%.2f", value.wrappedValue))
        .font(.caption.monospacedDigit())
        .foregroundStyle(StudioPalette.muted)
        .frame(width: 40, alignment: .trailing)
    }
  }

  // MARK: engine

  private func setup() async {
    guard client == nil else { return }
    do {
      let engine = try AnimaCoreClient()
      client = engine
      let created = try await engine.canvas2DNew(canvas: Self.faceDTO)
      handle = created.handle
      await render()
    } catch {
      status = .failed("Could not reach the engine.\n\(error.localizedDescription)")
    }
  }

  private func render() async {
    guard let client, let handle else { return }
    // Map the ARKit-style blendshapes to the procedural face's parameters —
    // the same mapping a face-tracking binding editor will make explicit.
    let values: [String: Double] = [
      "mouth_open": jawOpen,
      "mouth_curve": smile,
      "eye_open": 1.0 - blink,
      "look_x": headYaw,
    ]
    do {
      let frame = try await client.canvas2DRenderFrame(
        handle: handle, values: values, timeSeconds: time)
      guard let data = Data(base64Encoded: frame.pngBase64), let decoded = NSImage(data: data)
      else {
        status = .failed("Could not decode the rendered frame.")
        return
      }
      image = decoded
      status = .ready
    } catch {
      if let clientError = error as? AnimaCoreClientError,
        case .remote(let remote) = clientError,
        remote.code == "media_unavailable"
      {
        status = .unavailable(
          "The engine's media extra (Pillow) isn't installed in the selected Python.\n"
            + "Run: .venv/bin/pip install -e '.[media]'")
      } else {
        status = .failed(error.localizedDescription)
      }
    }
  }

  private static let faceDTO = AnimaCoreJSONValue.object([
    "width": .number(256),
    "height": .number(256),
    "sources": .array([
      .object([
        "id": .string("face"), "kind": .string("procedural"), "asset": .string("simple"),
      ])
    ]),
    "surfaces": .array([
      .object(["id": .string("face"), "source": .string("face")])
    ]),
  ])
}
