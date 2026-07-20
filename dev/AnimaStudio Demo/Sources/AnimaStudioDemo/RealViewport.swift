// The functional layer: a real Open CASCADE part loaded via GeomKit and
// rendered in RealityKit — replacing the faux ViewportMock once a part exists.
import AppKit
import GeomKit
import RealityKit
import SwiftUI
import UniformTypeIdentifiers
import simd

struct ImportedPart: Identifiable {
  let id = UUID()
  let name: String
  let document: GeometryDocument
}

@MainActor @Observable final class DemoModel {
  static let shared = DemoModel()   // one library, shared across every workspace
  var parts: [ImportedPart] = []
  var selectedID: UUID?
  var status = "No model loaded — import a STEP file"
  var loading = false

  var selected: ImportedPart? { parts.first { $0.id == selectedID } }

  func importFiles() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.allowedContentTypes = ["step", "stp"].compactMap { UTType(filenameExtension: $0) }
    guard panel.runModal() == .OK else { return }
    let urls = panel.urls
    let deflection = RenderState.shared.deflectionMillimetres / 1000.0   // mm → metres
    loading = true
    status = "Importing \(urls.count) file\(urls.count == 1 ? "" : "s")…"
    Task.detached {
      var results: [(String, Result<GeometryDocument, Error>)] = []
      for url in urls {
        do {
          results.append(
            (url.lastPathComponent, .success(try GeometryDocument.loadSTEP(url, linearDeflectionMetres: deflection))))
        } catch { results.append((url.lastPathComponent, .failure(error))) }
      }
      await MainActor.run {
        var lastError: String?
        for (name, res) in results {
          switch res {
          case .success(let doc):
            let part = ImportedPart(name: name, document: doc)
            self.parts.append(part)
            self.selectedID = part.id
          case .failure(let err):
            lastError = "\(name): \(err.localizedDescription)"
          }
        }
        self.loading = false
        if let e = lastError {
          self.status = "Import failed — \(e)"
        } else if let s = self.selected {
          self.status = "\(s.name) · \(s.document.faces.count) faces · \(s.document.triangleCount) tris"
        }
      }
    }
  }

  func remove(_ id: UUID) {
    parts.removeAll { $0.id == id }
    if selectedID == id { selectedID = parts.last?.id }
  }
}

struct PartViewport: View {
  var document: GeometryDocument
  var session: BenchSession
  @State private var yaw: Float = 0.7
  @State private var pitch: Float = 0.42
  @State private var dist: Float = 2.6
  @State private var target = SIMD3<Float>(0, 0, 0)
  @State private var builtTris = -1

  var body: some View {
    ZStack {
      RenderState.shared.theme.backgroundColor
      PerspectiveGrid()
      RealityView { content in
      let camera = PerspectiveCamera()
      camera.name = "camera"
      camera.camera.near = 0.001
      camera.camera.far = 1000
      content.add(camera)
      for name in ["light-key", "light-fill", "light-rim"] {
        let light = Entity()
        light.name = name
        content.add(light)
      }
    } update: { content in
      let theme = RenderState.shared.theme
      if builtTris != document.triangleCount {
        Task { @MainActor in builtTris = document.triangleCount }
        content.entities.filter { $0.name == "part" }.forEach { $0.removeFromParent() }
        if let mesh = try? Self.mesh(from: document) {
          let entity = ModelEntity(mesh: mesh, materials: Self.materials(document, theme: theme, selected: session.isModelSelected))
          entity.name = "part"
          entity.components.set(GroundingShadowComponent(castsShadow: true))   // soft contact shadow
          let bounds = entity.visualBounds(relativeTo: nil)
          let scale = 1.0 / max(bounds.boundingRadius, 0.0001)
          entity.scale = SIMD3(repeating: scale)
          entity.position = -bounds.center * scale
          content.add(entity)
        }
      }
      // Re-apply themed material + lights every update (theme is live-editable).
      if let part = content.entities.first(where: { $0.name == "part" }) as? ModelEntity {
        part.model?.materials = Self.materials(document, theme: theme, selected: session.isModelSelected)
      }
      for (name, light) in [("light-key", theme.key), ("light-fill", theme.fill), ("light-rim", theme.rim)] {
        if let e = content.entities.first(where: { $0.name == name }) {
          e.components.set(DirectionalLightComponent(color: Self.nsColor3(light.color), intensity: light.intensity))
          e.look(at: .zero, from: light.directionFrom, relativeTo: nil)
        }
      }
      if let camera = content.entities.first(where: { $0.name == "camera" }) {
        let pos = target + orbitDir() * dist
        camera.position = pos
        camera.look(at: target, from: pos, relativeTo: nil)
      }
    }
    .overlay {
      CADNavigationView(
        onRotate: { dx, dy in
          let n = NavState.shared
          yaw -= Float(dx) * 0.008 * Float(n.orbitSpeed) * (n.invertOrbitX ? -1 : 1)
          pitch = max(-1.5, min(1.5,
            pitch + Float(dy) * 0.008 * Float(n.orbitSpeed) * (n.invertOrbitY ? -1 : 1)))
        },
        onPan: { dx, dy in
          let n = NavState.shared
          let dir = orbitDir()
          let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), dir))
          let up = simd_cross(dir, right)
          target += (-right * Float(dx) + up * Float(dy)) * (dist * 0.0016 * Float(n.panSpeed))
        },
        onZoom: { delta in
          let n = NavState.shared
          let d = Float(delta) * (n.invertZoom ? -1 : 1)
          dist = max(0.35, min(20, dist * (1 - d * 0.01 * Float(n.zoomSpeed))))
        },
        onFit: {
          withAnimation(.easeInOut(duration: 0.25)) {
            target = .zero; dist = 2.6; yaw = 0.7; pitch = 0.42
          }
        },
        onClick: { session.toggleModelSelection() }   // whole-object select (like the bench)
      )
    }
    .overlay(alignment: .topLeading) { engineBadge.padding(12).allowsHitTesting(false) }
    }
  }

  private func orbitDir() -> SIMD3<Float> {
    SIMD3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
  }

  private var engineBadge: some View {
    let e = RenderState.shared.engine
    return HStack(spacing: 5) {
      Image(systemName: "cube.transparent").font(.system(size: 9, weight: .semibold))
      Text(e.available ? e.rawValue : "\(e.rawValue) → RealityKit")
        .font(.system(size: 9.5, weight: .medium))
    }
    .foregroundStyle(UI.text2)
    .padding(.horizontal, 8).padding(.vertical, 4)
    .background(.regularMaterial, in: Capsule())
    .overlay(Capsule().stroke(UI.stroke, lineWidth: 1))
  }

  // One mesh part per RenderGeometry batch (a rigid part + material identity), so
  // imported STEP/XDE face colors survive. Buffers are flattened once at import.
  static func mesh(from doc: GeometryDocument) throws -> MeshResource {
    let g = doc.renderGeometry
    var descriptors: [MeshDescriptor] = []
    for (i, batch) in g.batches.enumerated() {
      let base = UInt32(batch.vertexRange.lowerBound)
      var d = MeshDescriptor(name: "batch\(i)")
      d.positions = MeshBuffers.Positions(Array(g.positions[batch.vertexRange]))
      d.normals = MeshBuffers.Normals(Array(g.normals[batch.vertexRange]))
      d.primitives = .triangles(g.indices[batch.indexRange].map { $0 - base })
      d.materials = .allFaces(UInt32(i))   // maps to materials[i]
      descriptors.append(d)
    }
    if descriptors.isEmpty {   // fallback: one part, whole mesh
      var d = MeshDescriptor(name: "part")
      d.positions = MeshBuffers.Positions(g.positions)
      d.normals = MeshBuffers.Normals(g.normals)
      d.primitives = .triangles(g.indices)
      descriptors = [d]
    }
    return try MeshResource.generate(from: descriptors)
  }

  // One material per batch — imported color passed through the theme (which may
  // override it). `overrideColor == nil` preserves the STEP color per part.
  // Note: whole-part "selected" no longer recolors — that washed real CAD colors.
  // Selection highlighting will target the picked sub-part once 3D picking lands.
  static func materials(_ doc: GeometryDocument, theme: BenchTheme, selected: Bool) -> [RealityKit.Material] {
    let batches = doc.renderGeometry.batches
    if batches.isEmpty { return [material(nil, theme: theme, selected: selected)] }
    return batches.map { material($0.materialColor, theme: theme, selected: selected) }
  }

  static func material(_ imported: SIMD4<UInt8>?, theme: BenchTheme, selected: Bool) -> RealityKit.Material {
    var m = PhysicallyBasedMaterial()
    let importedF = imported.map {
      SIMD4<Float>(Float($0.x) / 255, Float($0.y) / 255, Float($0.z) / 255, Float($0.w) / 255)
    } ?? theme.neutralColor
    let disp = theme.displayColor(for: importedF)   // overrideColor ?? imported
    var base = nsColor4(disp)
    m.roughness = .init(floatLiteral: theme.roughness)
    m.metallic = .init(floatLiteral: theme.metallic)
    if selected {   // selection highlight — mix toward the theme's selection color + glow
      let sel = nsColor3(theme.selectionColor)
      base = base.blended(withFraction: 0.55, of: sel) ?? base
      m.emissiveColor = .init(color: sel)
      m.emissiveIntensity = 0.35
    }
    m.baseColor = .init(tint: base)
    return m
  }

  static func nsColor4(_ c: SIMD4<Float>) -> NSColor {
    NSColor(srgbRed: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: CGFloat(c.w))
  }
  static func nsColor3(_ c: SIMD3<Float>) -> NSColor {
    NSColor(srgbRed: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: 1)
  }
}

// CAD mouse navigation captured at the AppKit layer — SwiftUI's DragGesture
// can't distinguish mouse buttons. Left/right-drag = rotate · middle-drag = pan
// · scroll & pinch = zoom · double middle-click = fit. (Selection comes later.)
struct CADNavigationView: NSViewRepresentable {
  var onRotate: (CGFloat, CGFloat) -> Void
  var onPan: (CGFloat, CGFloat) -> Void
  var onZoom: (CGFloat) -> Void
  var onFit: () -> Void
  var onClick: () -> Void = {}

  func makeNSView(context: Context) -> NavNSView { let v = NavNSView(); apply(v); return v }
  func updateNSView(_ v: NavNSView, context: Context) { apply(v) }
  private func apply(_ v: NavNSView) {
    v.onRotate = onRotate; v.onPan = onPan; v.onZoom = onZoom; v.onFit = onFit; v.onClick = onClick
  }

  final class NavNSView: NSView {
    var onRotate: ((CGFloat, CGFloat) -> Void)?
    var onPan: ((CGFloat, CGFloat) -> Void)?
    var onZoom: ((CGFloat) -> Void)?
    var onFit: (() -> Void)?
    var onClick: (() -> Void)?
    private var dragged = false   // distinguishes a select-click from a rotate-drag
    override var acceptsFirstResponder: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { self }
    override func mouseDown(with e: NSEvent) { dragged = false }
    override func mouseDragged(with e: NSEvent) { dragged = true; onRotate?(e.deltaX, e.deltaY) }
    override func mouseUp(with e: NSEvent) { if !dragged { onClick?() } }
    override func rightMouseDragged(with e: NSEvent) { onRotate?(e.deltaX, e.deltaY) }
    override func otherMouseDragged(with e: NSEvent) { onPan?(e.deltaX, e.deltaY) }
    override func otherMouseDown(with e: NSEvent) { if e.clickCount == 2 { onFit?() } }
    override func scrollWheel(with e: NSEvent) {
      onZoom?(e.hasPreciseScrollingDeltas ? e.scrollingDeltaY : e.deltaY)
    }
    override func magnify(with e: NSEvent) { onZoom?(e.magnification * 30) }
  }
}

// Shown in the canvas when no model is loaded — no faux part, just a prompt.
struct EmptyStage: View {
  var status: String
  var importAction: () -> Void
  var body: some View {
    ZStack {
      LinearGradient(colors: [UI.viewportTop, UI.viewportBottom], startPoint: .top, endPoint: .bottom)
      VStack(spacing: 12) {
        Image(systemName: "cube.transparent").font(.system(size: 46)).foregroundStyle(UI.text3)
        Text("No model loaded").font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.text2)
        Text(status).font(.system(size: 11)).foregroundStyle(UI.text3)
          .multilineTextAlignment(.center)
        Button(action: importAction) {
          HStack(spacing: 6) { Image(systemName: "plus"); Text("Import STEP…") }
            .font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(UI.accent, in: Capsule())
        }.buttonStyle(.plain).padding(.top, 4)
      }
    }
  }
}
