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

/// How an imported asset relates to its source file. Chosen at import time.
enum AssetImportMode: String, CaseIterable, Identifiable {
  case copy = "Copy", reference = "Reference"
  var id: String { rawValue }
  var label: String { rawValue }
  var detail: String {
    switch self {
    case .copy: return "Copy into the project — portable, source untouched"
    case .reference: return "Link to the file in place — no copy, not portable"
    }
  }
  var icon: String { self == .copy ? "doc.on.doc" : "link" }
}

@MainActor @Observable final class DemoModel {
  static let shared = DemoModel()   // one library, shared across every workspace
  var parts: [ImportedPart] = []
  var selectedID: UUID?
  var status = "No model loaded — import a STEP file"
  var projectName = "Untitled"
  var loading = false
  /// How new imports are stored. Copy = self-contained project (default).
  var importMode: AssetImportMode = .copy
  /// Which center representation the Character workspace shows.
  var centerView = "3D"
  var importTotal = 0
  var importDone = 0
  var importingName = ""
  // Character workspace sidebar. Model-owned, not @State, so it survives the
  // float/dock flip that rebuilds the workspace view.
  let characterPanels = PanelStackState(
    order: CharacterSection.railOrder,
    defaults: [], side: .left)

  /// Organisable tree of the imported parts (folders live here; leaves mirror
  /// `parts`). Kept in sync as parts are added/removed.
  let partsTree = TreeModel()
  func syncPartsTree() {
    let present = Set(partsLeafPayloads())
    for part in parts where !present.contains(part.id) {
      partsTree.nodes.append(TreeNode(name: part.name, icon: "cube",
        detail: "\(part.document.faces.count)f", payload: part.id))
    }
    // Drop leaves whose part is gone.
    let live = Set(parts.map(\.id))
    partsTree.nodes = TreeModel.removing(deadLeafIDs(live: live), from: partsTree.nodes)
  }
  private func partsLeafPayloads() -> [UUID] {
    func walk(_ ns: [TreeNode]) -> [UUID] { ns.flatMap { [$0.payload].compactMap { $0 } + walk($0.children) } }
    return walk(partsTree.nodes)
  }
  private func deadLeafIDs(live: Set<UUID>) -> Set<UUID> {
    func walk(_ ns: [TreeNode]) -> [UUID] {
      ns.flatMap { n -> [UUID] in
        (n.payload != nil && !live.contains(n.payload!) ? [n.id] : []) + walk(n.children)
      }
    }
    return Set(walk(partsTree.nodes))
  }
  @ObservationIgnored private var importError: String?

  /// 0...1 across the whole import batch (nil while the first file is parsing).
  var importProgress: Double? {
    importTotal > 0 ? Double(importDone) / Double(importTotal) : nil
  }

  var selected: ImportedPart? { parts.first { $0.id == selectedID } }

  func importFiles() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.allowedContentTypes = ["step", "stp"].compactMap { UTType(filenameExtension: $0) }
    guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
    let urls = panel.urls

    // Ask the operator how the files should be stored.
    let alert = NSAlert()
    alert.messageText = "Import \(urls.count) file\(urls.count == 1 ? "" : "s")"
    alert.informativeText = StudioProject.shared.isOpen
      ? "Copy the files into this project (portable, source untouched), or reference them where they are?"
      : "No project is open, so files will be referenced in place. Create/open a project to copy them in."
    if StudioProject.shared.isOpen {
      alert.addButton(withTitle: "Copy into Project")
      alert.addButton(withTitle: "Reference in Place")
      alert.addButton(withTitle: "Cancel")
      switch alert.runModal() {
      case .alertFirstButtonReturn: importMode = .copy
      case .alertSecondButtonReturn: importMode = .reference
      default: return
      }
    } else {
      importMode = .reference
      alert.addButton(withTitle: "Import"); alert.addButton(withTitle: "Cancel")
      guard alert.runModal() == .alertFirstButtonReturn else { return }
    }
    load(urls)
  }

  /// Where a file is loaded from: a copy inside the project's assets folder
  /// (Copy mode) or the original location (Reference mode).
  private func resolvedSource(_ url: URL) -> URL {
    guard importMode == .copy, let assets = StudioProject.shared.modelsURL else { return url }
    try? FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
    var dest = assets.appendingPathComponent(url.lastPathComponent)
    var n = 2
    while FileManager.default.fileExists(atPath: dest.path),
      (try? Data(contentsOf: dest)) != (try? Data(contentsOf: url)) {
      let base = url.deletingPathExtension().lastPathComponent
      dest = assets.appendingPathComponent("\(base) \(n).\(url.pathExtension)"); n += 1
    }
    if !FileManager.default.fileExists(atPath: dest.path) {
      try? FileManager.default.copyItem(at: url, to: dest)
    }
    return FileManager.default.fileExists(atPath: dest.path) ? dest : url
  }

  /// Re-imports the part files recorded in a project document. `persist: false`
  /// so it neither re-copies nor autosaves (it's reading existing paths).
  func reimport(paths: [String], projectName: String) {
    self.projectName = projectName
    parts.removeAll()
    partsTree.nodes.removeAll()
    selectedID = nil
    let urls = paths.map { URL(fileURLWithPath: $0) }
      .filter { FileManager.default.fileExists(atPath: $0.path) }
    guard !urls.isEmpty else {
      status = paths.isEmpty
        ? "Opened \(projectName) — no parts in this project"
        : "Opened \(projectName) — part files not found at their saved paths"
      return
    }
    load(urls, persist: false)
  }

  func load(_ urls: [URL], persist: Bool = true) {
    guard !urls.isEmpty else { return }
    let deflection = RenderState.shared.deflectionMillimetres / 1000.0   // mm → metres
    loading = true
    importTotal = urls.count
    importDone = 0
    importError = nil
    status = "Importing \(urls.count) file\(urls.count == 1 ? "" : "s")…"

    Task { @MainActor in
      // One file at a time so progress advances and the first part appears early.
      for url in urls {
        importingName = url.lastPathComponent
        // Copy into the project (or reference in place) BEFORE loading, so the
        // part's sourceURL — which is what gets persisted — is the stored copy.
        let source = persist ? resolvedSource(url) : url
        do {
          let document = try await Task.detached(priority: .userInitiated) {
            try GeometryDocument.loadSTEP(source, linearDeflectionMetres: deflection)
          }.value
          let part = ImportedPart(name: url.lastPathComponent, document: document)
          parts.append(part)
          selectedID = part.id
          syncPartsTree()
          // Commit the asset's nodes as parts of the active character.
          ProjectModel.shared.addAsset(part)
        } catch {
          importError = "\(url.lastPathComponent): \(error.localizedDescription)"
        }
        importDone += 1
      }
      loading = false
      importingName = ""
      importTotal = 0
      importDone = 0
      if let importError {
        status = "Import failed — \(importError)"
      } else if let s = selected {
        status = "\(s.name) · \(s.document.faces.count) faces · \(s.document.triangleCount) tris"
      }
      // Persist the new parts into the project so they reload next open.
      if persist { ProjectStore.autosave() }
    }
  }

  func documentsByName() -> [String: GeometryDocument] {
    Dictionary(parts.map { ($0.name, $0.document) }, uniquingKeysWith: { a, _ in a })
  }

  /// Per-asset, per-node bounding boxes in part space (used for centering + pivots).
  func nodeBounds() -> [String: [Int: (SIMD3<Float>, SIMD3<Float>)]] {
    var out: [String: [Int: (SIMD3<Float>, SIMD3<Float>)]] = [:]
    for part in parts {
      var byNode: [Int: (SIMD3<Float>, SIMD3<Float>)] = [:]
      let g = part.document.renderGeometry
      for batch in g.batches where batch.assemblyNode >= 0 {
        var lo = byNode[batch.assemblyNode]?.0 ?? SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var hi = byNode[batch.assemblyNode]?.1 ?? SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for i in batch.vertexRange {
          lo = simd_min(lo, g.positions[i])
          hi = simd_max(hi, g.positions[i])
        }
        byNode[batch.assemblyNode] = (lo, hi)
      }
      out[part.name] = byNode
    }
    return out
  }

  func remove(_ id: UUID) {
    parts.removeAll { $0.id == id }
    if selectedID == id { selectedID = parts.last?.id }
    syncPartsTree()
  }
}

struct PartViewport: View {
  var document: GeometryDocument
  var assetName: String
  var session: BenchSession
  @State private var yaw: Float = 0.7
  @State private var pitch: Float = 0.42
  @State private var dist: Float = 2.6
  @State private var target = SIMD3<Float>(0, 0, 0)
  @State private var builtTris = -1
  @State private var builtSelection = ""

  var body: some View {
    // Read selection here in `body` so SwiftUI actually observes it. Reading it
    // only inside the RealityView update closure does NOT register a dependency,
    // so deselecting never re-ran the update and the highlight stuck on.
    let selected = session.isModelSelected
    let pick = SelectionModel.shared
    let selectionKey = "\(pick.assemblyNode ?? -1)|\(pick.faceID.map(String.init) ?? "-")|\(pick.level)"
    // Read env prefs here so the RealityView update re-runs when they change.
    let render = RenderState.shared
    let showGrid = render.showGrid
    let showOrigin = render.showOrigin
    let groundShadow = render.groundShadow
    let keyLightScale = Float(render.keyLightScale)
    return ZStack {
      render.theme.backgroundColor
      if showGrid { PerspectiveGrid() }
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
      content.add(Self.makeOriginAxes())
    } update: { content in
      let theme = RenderState.shared.theme
      if builtTris != document.triangleCount || builtSelection != selectionKey {
        Task { @MainActor in
          builtTris = document.triangleCount
          builtSelection = selectionKey
        }
        content.entities.filter { $0.name == "part" }.forEach { $0.removeFromParent() }
        // One entity per assembly node so mates can move parts independently.
        let container = Entity()
        container.name = "part"
        for group in Self.nodeGroups(document) {
          if let entity = Self.entity(for: group, document: document, theme: theme,
            selected: selected, pick: pick) {
            entity.components.set(GroundingShadowComponent(castsShadow: true))
            container.addChild(entity)
          }
        }
        let bounds = container.visualBounds(relativeTo: nil)
        let scale = 1.0 / max(bounds.boundingRadius, 0.0001)
        container.scale = SIMD3(repeating: scale)
        container.position = -bounds.center * scale
        content.add(container)
      }
      // Re-apply themed materials + the live rig pose every update.
      if let container = content.entities.first(where: { $0.name == "part" }) {
        let pose = RigModel.shared.poseByNode(assetName: assetName)
        for group in Self.nodeGroups(document) {
          guard let child = container.children.first(where: { $0.name == "node-\(group.node)" })
          else { continue }
          child.transform = Transform(matrix: pose[group.node] ?? matrix_identity_float4x4)
        }
      }
      if let origin = content.entities.first(where: { $0.name == "origin" }) {
        origin.isEnabled = showOrigin
      }
      // Live grounding-shadow toggle across the current parts.
      if let container = content.entities.first(where: { $0.name == "part" }) {
        for node in container.children {
          if groundShadow {
            node.components.set(GroundingShadowComponent(castsShadow: true))
          } else {
            node.components.remove(GroundingShadowComponent.self)
          }
        }
      }
      for (name, light) in [("light-key", theme.key), ("light-fill", theme.fill), ("light-rim", theme.rim)] {
        if let e = content.entities.first(where: { $0.name == name }) {
          e.components.set(DirectionalLightComponent(
            color: Self.nsColor3(light.color), intensity: light.intensity * keyLightScale))
          e.look(at: .zero, from: light.directionFrom, relativeTo: nil)
        }
      }
      if let camera = content.entities.first(where: { $0.name == "camera" }) {
        let pos = target + orbitDir() * dist
        camera.position = pos
        camera.look(at: target, from: pos, relativeTo: nil)
      }
    }
    .overlay { GeometryReader { geo in navigation(viewport: geo.size) } }
    .overlay(alignment: .topLeading) { engineBadge.padding(12).allowsHitTesting(false) }
    .overlay(alignment: .topLeading) { moveGizmoLayer }
    .overlay(alignment: .topTrailing) {
      if RenderState.shared.showViewCube {
        ViewCube(yaw: yaw, pitch: pitch) { newYaw, newPitch in
          withAnimation(.easeInOut(duration: 0.28)) { yaw = newYaw; pitch = newPitch }
        }
        .padding(.top, 18).padding(.trailing, 18)
      }
    }
    }
  }

  /// Move controls, anchored where the body was double-clicked.
  @ViewBuilder private var moveGizmoLayer: some View {
    let pick = SelectionModel.shared
    if pick.showsMoveControls, let point = pick.gizmoPoint {
      MoveGizmo(
        onNudge: { dx, dy in nudgeSelectedPart(dx: dx, dy: dy) },
        onDismiss: { withAnimation(.easeOut(duration: 0.12)) { pick.clear() } })
        .position(x: point.x, y: point.y)
    }
  }

  /// Drag the selected part in the camera's screen plane (character space).
  private func nudgeSelectedPart(dx: CGFloat, dy: CGFloat) {
    guard let partID = SelectionModel.shared.partID,
      let index = ProjectModel.shared.activeIndex,
      let part = ProjectModel.shared.characters[index].parts.firstIndex(where: { $0.id == partID })
    else { return }
    let dir = orbitDir()
    let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), dir))
    let up = simd_cross(dir, right)
    let metresPerPoint = dist * 0.0016
    let delta = (right * Float(dx) - up * Float(dy)) * metresPerPoint
    ProjectModel.shared.characters[index].parts[part].restTransform.translation += delta
  }

  /// Mouse navigation + CAD picking. Extracted from `body` to keep the
  /// type-checker fast.
  private func navigation(viewport: CGSize) -> some View {
    CADNavigationView(
      onRotate: { dx, dy in
        let n = NavState.shared
        yaw -= Float(dx) * 0.008 * Float(n.orbitSpeed) * (n.invertOrbitX ? -1 : 1)
        let next = pitch + Float(dy) * 0.008 * Float(n.orbitSpeed) * (n.invertOrbitY ? -1 : 1)
        pitch = max(-1.5, min(1.5, next))
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
          target = .zero
          dist = 2.6
          yaw = 0.7
          pitch = 0.42
        }
      },
      onClick: { point in select(at: point, viewport: viewport, body: false) },
      onDoubleClick: { point in select(at: point, viewport: viewport, body: true) })
  }

  /// Ray-cast the click; single click picks a face, double click the whole body.
  private func select(at point: CGPoint, viewport: CGSize, body: Bool) {
    let geometry = document.renderGeometry
    let ray = Picking.cameraRay(
      point: point, viewport: viewport,
      position: target + orbitDir() * dist, target: target)
    let container = Picking.containerMatrix(for: geometry)
    let pose = RigModel.shared.poseByNode(assetName: assetName)
    guard let hit = Picking.pick(ray: ray, geometry: geometry, container: container, pose: pose)
    else {
      SelectionModel.shared.clear()
      return
    }
    let part = RigModel.shared.parts.first {
      $0.assetName == assetName && $0.node == hit.node
    }?.id
    withAnimation(.easeOut(duration: 0.12)) {
      if body {
        SelectionModel.shared.selectBody(node: hit.node, part: part, at: point)
      } else {
        SelectionModel.shared.selectFace(hit.face, node: hit.node, part: part, at: point)
      }
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

  // Batches grouped by assembly node — one rendered entity per part so the rig
  // can pose parts independently. Within a node, each batch keeps its STEP color.
  struct NodeGroup { let node: Int; let batches: [RenderBatch] }

  static func nodeGroups(_ doc: GeometryDocument) -> [NodeGroup] {
    var byNode: [Int: [RenderBatch]] = [:]
    for batch in doc.renderGeometry.batches { byNode[batch.assemblyNode, default: []].append(batch) }
    return byNode.keys.sorted().map { NodeGroup(node: $0, batches: byNode[$0] ?? []) }
  }

  static func entity(for group: NodeGroup, document: GeometryDocument, theme: BenchTheme,
    selected: Bool, pick: SelectionModel) -> ModelEntity?
  {
    let g = document.renderGeometry
    var descriptors: [MeshDescriptor] = []
    var materials: [RealityKit.Material] = []

    for (i, batch) in group.batches.enumerated() {
      let base = UInt32(batch.vertexRange.lowerBound)
      let positions = Array(g.positions[batch.vertexRange])
      let normals = Array(g.normals[batch.vertexRange])

      // Split this batch's triangles by whether the pick highlights their face.
      var plain: [UInt32] = []
      var highlighted: [UInt32] = []
      var k = batch.indexRange.lowerBound
      while k + 2 < batch.indexRange.upperBound {
        let a = g.indices[k], b = g.indices[k + 1], c = g.indices[k + 2]
        let face = Int(a) < g.faceIDs.count ? g.faceIDs[Int(a)] : 0
        let hot = pick.highlights(face: face, node: group.node)
        if hot {
          highlighted.append(contentsOf: [a - base, b - base, c - base])
        } else {
          plain.append(contentsOf: [a - base, b - base, c - base])
        }
        k += 3
      }

      func add(_ indices: [UInt32], highlight: Bool) {
        guard !indices.isEmpty else { return }
        var d = MeshDescriptor(name: "n\(group.node)-b\(i)-\(highlight ? "hot" : "base")")
        d.positions = MeshBuffers.Positions(positions)
        d.normals = MeshBuffers.Normals(normals)
        d.primitives = .triangles(indices)
        d.materials = .allFaces(UInt32(materials.count))
        descriptors.append(d)
        materials.append(highlight
          ? highlightMaterial(theme: theme)
          : material(batch.materialColor, theme: theme, selected: selected))
      }
      add(plain, highlight: false)
      add(highlighted, highlight: true)
    }

    guard !descriptors.isEmpty, let mesh = try? MeshResource.generate(from: descriptors) else {
      return nil
    }
    let entity = ModelEntity(mesh: mesh, materials: materials)
    entity.name = "node-\(group.node)"
    return entity
  }

  /// One material per batch — imported colour passed through the theme
  /// (`overrideColor == nil` preserves the STEP colour per part).
  static func material(_ imported: SIMD4<UInt8>?, theme: BenchTheme, selected: Bool)
    -> RealityKit.Material
  {
    var m = PhysicallyBasedMaterial()
    let importedF = imported.map {
      SIMD4<Float>(Float($0.x) / 255, Float($0.y) / 255, Float($0.z) / 255, Float($0.w) / 255)
    } ?? theme.neutralColor
    let disp = theme.displayColor(for: importedF)
    m.roughness = .init(floatLiteral: theme.roughness)
    m.metallic = .init(floatLiteral: theme.metallic)
    m.baseColor = .init(tint: nsColor4(disp))
    return m
  }

  /// The picked face/body — the theme's selection colour, as in CAD.
  static func highlightMaterial(theme: BenchTheme) -> RealityKit.Material {
    var m = PhysicallyBasedMaterial()
    let tint = nsColor3(theme.selectionColor)
    m.baseColor = .init(tint: tint)
    m.emissiveColor = .init(color: tint)
    m.emissiveIntensity = 0.35
    m.roughness = .init(floatLiteral: 0.35)
    m.metallic = .init(floatLiteral: 0)
    return m
  }

  /// X/Y/Z axes at the character origin (unlit so they read at any lighting).
  static func makeOriginAxes(length: Float = 0.62, thickness: Float = 0.005) -> Entity {
    let origin = Entity()
    origin.name = "origin"
    let axes: [(SIMD3<Float>, SIMD3<Float>, NSColor)] = [
      ([length, thickness, thickness], [length / 2, 0, 0], .systemRed),
      ([thickness, length, thickness], [0, length / 2, 0], .systemGreen),
      ([thickness, thickness, length], [0, 0, length / 2], .systemBlue),
    ]
    for (size, position, color) in axes {
      let mesh = MeshResource.generateBox(size: size)
      let entity = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)])
      entity.position = position
      origin.addChild(entity)
    }
    return origin
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
  var onClick: (CGPoint) -> Void = { _ in }
  var onDoubleClick: (CGPoint) -> Void = { _ in }

  func makeNSView(context: Context) -> NavNSView { let v = NavNSView(); apply(v); return v }
  func updateNSView(_ v: NavNSView, context: Context) { apply(v) }
  private func apply(_ v: NavNSView) {
    v.onRotate = onRotate; v.onPan = onPan; v.onZoom = onZoom; v.onFit = onFit
    v.onClick = onClick; v.onDoubleClick = onDoubleClick
  }

  final class NavNSView: NSView {
    var onRotate: ((CGFloat, CGFloat) -> Void)?
    var onPan: ((CGFloat, CGFloat) -> Void)?
    var onZoom: ((CGFloat) -> Void)?
    var onFit: (() -> Void)?
    var onClick: ((CGPoint) -> Void)?
    var onDoubleClick: ((CGPoint) -> Void)?
    private var dragged = false   // distinguishes a select-click from a rotate-drag
    override var acceptsFirstResponder: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { self }
    override func mouseDown(with e: NSEvent) { dragged = false }
    override func mouseDragged(with e: NSEvent) { dragged = true; onRotate?(e.deltaX, e.deltaY) }
    override func mouseUp(with e: NSEvent) {
      guard !dragged else { return }
      // AppKit y grows upward; SwiftUI/pick space grows downward.
      let local = convert(e.locationInWindow, from: nil)
      let point = CGPoint(x: local.x, y: bounds.height - local.y)
      if e.clickCount >= 2 { onDoubleClick?(point) } else { onClick?(point) }
    }
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
