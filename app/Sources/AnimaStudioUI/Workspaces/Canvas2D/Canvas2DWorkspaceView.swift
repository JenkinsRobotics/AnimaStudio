import AnimaCoreClient
import AppKit
import SwiftUI

/// Center view for the **2D Character** workspace.
///
/// A live preview: it builds a procedural-face `Canvas2D` in the canonical
/// AnimaCore engine over the `canvas2d.*` bridge verbs and rasterizes it to an
/// image (`canvas2d.new` → `canvas2d.render_frame`), then drives the same
/// evaluated parameter stream a rig produces — `mouth_open` (viseme),
/// `mouth_curve`, `eye_open`, and time (blink/breathing) — from the sliders.
/// Nothing here defines animation meaning; the pixels come from the engine
/// (`animacore/raster`), so the app shows exactly what hardware would.
///
/// Scaffold: it spawns its own engine client and renders a built-in face. The
/// Surfaces/Media/Faces/Output editors and load-from-`.character.anima` land next.
struct Canvas2DWorkspaceView: View {
  private enum Status: Equatable {
    case loading
    case ready
    case unavailable(String)
    case failed(String)
  }

  /// The example characters — a built-in procedural face and two built from the
  /// imported Mochi test media (`examples/assets/2d`). Paths are repo-root
  /// relative; the engine helper's working dir is the repo root in a dev build.
  private enum Subject: String, CaseIterable, Identifiable {
    case face
    case pixelPet
    case dino

    var id: String { rawValue }

    var title: String {
      switch self {
      case .face: "Face"
      case .pixelPet: "Pixel Pet"
      case .dino: "Dino GIF"
      }
    }
  }

  @State private var client: AnimaCoreClient?
  @State private var handle: String?
  @State private var image: NSImage?
  @State private var status: Status = .loading
  @State private var subject: Subject = .face

  @State private var mouthOpen = 0.15
  @State private var mouthCurve = 0.4
  @State private var eyeOpen = 1.0
  @State private var time = 1.0

  private var renderKey: String { "\(mouthOpen)|\(mouthCurve)|\(eyeOpen)|\(time)" }

  var body: some View {
    ZStack {
      StudioPalette.canvas.ignoresSafeArea()
      VStack(spacing: 20) {
        subjectPicker
        previewPanel
        controls
        capabilityRow
      }
      .padding(32)
      .frame(maxWidth: 760)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .task { await setup() }
    .onChange(of: subject) { Task { await rebuild() } }
    .onChange(of: renderKey) { Task { await render() } }
  }

  private var subjectPicker: some View {
    Picker("Character", selection: $subject) {
      ForEach(Subject.allCases) { Text($0.title).tag($0) }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .frame(maxWidth: 360)
    .disabled(client == nil)
  }

  // MARK: preview

  private var previewPanel: some View {
    VStack(spacing: 10) {
      Text("2D Preview")
        .font(.title2.weight(.semibold))
        .foregroundStyle(StudioPalette.ink)
      Text("Live from AnimaCore · canvas2d.render_frame")
        .font(.caption)
        .foregroundStyle(StudioPalette.muted)
      previewSurface
        .frame(width: 256, height: 256)
        .background(
          RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.black)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(StudioPalette.border)
        )
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous).fill(StudioPalette.panel)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(StudioPalette.border)
    )
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

  // MARK: controls

  private var controls: some View {
    VStack(spacing: 10) {
      slider("Mouth open", value: $mouthOpen, range: 0...1)
      slider("Smile ↔ Frown", value: $mouthCurve, range: -1...1)
      slider("Eye open", value: $eyeOpen, range: 0...1)
      slider("Time (blink · breathe)", value: $time, range: 0...8)
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous).fill(StudioPalette.panel)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(StudioPalette.border)
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
        .frame(width: 150, alignment: .leading)
      Slider(value: value, in: range)
      Text(String(format: "%.2f", value.wrappedValue))
        .font(.caption.monospacedDigit())
        .foregroundStyle(StudioPalette.muted)
        .frame(width: 40, alignment: .trailing)
    }
  }

  private var capabilityRow: some View {
    HStack(spacing: 10) {
      chip("Surfaces", "square.on.square")
      chip("Media", "photo.on.rectangle.angled")
      chip("Faces", "face.smiling")
      chip("Output", "circle.grid.3x3.fill")
    }
  }

  private func chip(_ title: String, _ systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
      .font(.caption)
      .foregroundStyle(StudioPalette.muted)
      .padding(.vertical, 8)
      .padding(.horizontal, 12)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(StudioPalette.panel)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(StudioPalette.border)
      )
  }

  // MARK: engine

  private func setup() async {
    guard client == nil else { return }
    do {
      client = try AnimaCoreClient()
      await rebuild()
    } catch {
      status = .failed("Could not reach the engine.\n\(error.localizedDescription)")
    }
  }

  /// Build a fresh canvas for the selected subject, then render it.
  private func rebuild() async {
    guard let client else { return }
    status = .loading
    do {
      let created = try await client.canvas2DNew(canvas: canvasDTO(for: subject))
      handle = created.handle
      await render()
    } catch {
      status = .failed(error.localizedDescription)
    }
  }

  private func render() async {
    guard let client, let handle else { return }
    do {
      let frame = try await client.canvas2DRenderFrame(
        handle: handle,
        values: ["mouth_open": mouthOpen, "mouth_curve": mouthCurve, "eye_open": eyeOpen],
        timeSeconds: time
      )
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
            + "Run: .venv/bin/pip install -e '.[media]'"
        )
      } else {
        status = .failed(error.localizedDescription)
      }
    }
  }

  private func canvasDTO(for subject: Subject) -> AnimaCoreJSONValue {
    switch subject {
    case .face: Self.faceDTO
    case .pixelPet: Self.pixelPetDTO
    case .dino: Self.dinoDTO
    }
  }

  private static func source(_ id: String, _ kind: String, _ asset: String) -> AnimaCoreJSONValue {
    .object(["id": .string(id), "kind": .string(kind), "asset": .string(asset)])
  }

  private static func surface(_ id: String, _ source: String, z: Double = 0) -> AnimaCoreJSONValue {
    .object(["id": .string(id), "source": .string(source), "z": .number(z)])
  }

  private static func canvas(
    sources: [AnimaCoreJSONValue], surfaces: [AnimaCoreJSONValue]
  ) -> AnimaCoreJSONValue {
    .object([
      "width": .number(256), "height": .number(256),
      "sources": .array(sources), "surfaces": .array(surfaces),
    ])
  }

  private static let faceDTO = canvas(
    sources: [source("face", "procedural", "simple")],
    surfaces: [surface("face", "face")]
  )

  private static let pixelPetDTO = canvas(
    sources: [
      source("bg", "image", "examples/assets/2d/png/colorwheel.png"),
      source("face", "procedural", "simple"),
    ],
    surfaces: [surface("bg", "bg", z: 0), surface("face", "face", z: 10)]
  )

  private static let dinoDTO = canvas(
    sources: [source("screen", "gif", "examples/assets/2d/gifs/DinoRun2.gif")],
    surfaces: [surface("screen", "screen")]
  )
}
