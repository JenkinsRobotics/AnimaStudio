import AetherKernel
import Foundation
import SwiftUI
import WebKit

public struct CADWebGPUViewport: NSViewRepresentable {
  public let backend: CADRenderBackend
  public let document: CADGeometryDocument?
  public let theme: CADViewportTheme
  public let navigation: CADViewportNavigationConfiguration
  /// View direction and optional roll `[x, y, z, roll]` the ViewCube wants
  /// applied relative to the fixed world frame.
  public let viewDirection: [Double]?
  /// Discrete camera-command counter — the direction is pushed to JS only when
  /// this changes (a ViewCube click), never during a free orbit.
  public let cameraCommandRevision: Int
  /// CAD partIDs (assemblyNode + 1) hidden / selected in the assembly tree.
  public let hiddenPartIDs: Set<Int>
  public let selectedPartIDs: Set<Int>
  public let groundedPartIDs: Set<Int>
  public let referenceGeometry: CADWorkspaceReferenceGeometry
  public let partTransforms: [CADPartTransformPresentation]
  public let partAppearances: [CADPartAppearancePresentation]
  public let selectedPartOrigin: CADPartOriginPresentation?
  public let onStatus: @MainActor (String) -> Void
  public let onFrameCount: @MainActor (Int, Double?) -> Void
  /// Reports the JS camera back so the ViewCube tracks free orbit and roll.
  public let onCameraOrientation: @MainActor (CADCameraOrientationPresentation) -> Void
  /// Normalized top-left projection of the selected Part's local XYZ frame.
  public let onSelectedGizmoProjection: @MainActor (CADProjectedLocalFrame?) -> Void
  /// A part clicked in the viewport (partID, extend-selection).
  public let onPick: @MainActor (Int, Bool) -> Void
  public let onBoxPick: @MainActor (Set<Int>, Bool) -> Void
  public let onContextMenu: @MainActor (Int?, CGPoint) -> Void
  public let onBeginDirectPartDrag: @MainActor (Int) -> Bool
  public let onUpdateDirectPartDrag: @MainActor (CGSize, CGSize) -> Void
  public let onEndDirectPartDrag: @MainActor () -> Void

  public init(
    backend: CADRenderBackend,
    document: CADGeometryDocument?,
    theme: CADViewportTheme,
    navigation: CADViewportNavigationConfiguration = .onshape,
    viewDirection: [Double]? = nil,
    cameraCommandRevision: Int = 0,
    hiddenPartIDs: Set<Int> = [],
    selectedPartIDs: Set<Int> = [],
    groundedPartIDs: Set<Int> = [],
    referenceGeometry: CADWorkspaceReferenceGeometry = .init(
      visibility: .init(), modelDiagonalMeters: 1),
    partTransforms: [CADPartTransformPresentation] = [],
    partAppearances: [CADPartAppearancePresentation] = [],
    selectedPartOrigin: CADPartOriginPresentation? = nil,
    onStatus: @escaping @MainActor (String) -> Void = { _ in },
    onFrameCount: @escaping @MainActor (Int, Double?) -> Void = { _, _ in },
    onCameraOrientation:
      @escaping @MainActor (CADCameraOrientationPresentation) -> Void = { _ in },
    onSelectedGizmoProjection:
      @escaping @MainActor (CADProjectedLocalFrame?) -> Void = { _ in },
    onPick: @escaping @MainActor (Int, Bool) -> Void = { _, _ in },
    onBoxPick: @escaping @MainActor (Set<Int>, Bool) -> Void = { _, _ in },
    onContextMenu: @escaping @MainActor (Int?, CGPoint) -> Void = { _, _ in },
    onBeginDirectPartDrag: @escaping @MainActor (Int) -> Bool = { _ in false },
    onUpdateDirectPartDrag: @escaping @MainActor (CGSize, CGSize) -> Void = { _, _ in },
    onEndDirectPartDrag: @escaping @MainActor () -> Void = {}
  ) {
    precondition(backend == .threeJSWebGPU || backend == .rawWebGPU)
    self.backend = backend
    self.document = document
    self.theme = theme
    self.navigation = navigation
    self.viewDirection = viewDirection
    self.cameraCommandRevision = cameraCommandRevision
    self.hiddenPartIDs = hiddenPartIDs
    self.selectedPartIDs = selectedPartIDs
    self.groundedPartIDs = groundedPartIDs
    self.referenceGeometry = referenceGeometry
    self.partTransforms = partTransforms
    self.partAppearances = partAppearances
    self.selectedPartOrigin = selectedPartOrigin
    self.onStatus = onStatus
    self.onFrameCount = onFrameCount
    self.onCameraOrientation = onCameraOrientation
    self.onSelectedGizmoProjection = onSelectedGizmoProjection
    self.onPick = onPick
    self.onBoxPick = onBoxPick
    self.onContextMenu = onContextMenu
    self.onBeginDirectPartDrag = onBeginDirectPartDrag
    self.onUpdateDirectPartDrag = onUpdateDirectPartDrag
    self.onEndDirectPartDrag = onEndDirectPartDrag
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(
      backend: backend, onStatus: onStatus, onFrameCount: onFrameCount,
      onCameraOrientation: onCameraOrientation,
      onSelectedGizmoProjection: onSelectedGizmoProjection,
      onPick: onPick,
      onBoxPick: onBoxPick,
      onContextMenu: onContextMenu,
      onBeginDirectPartDrag: onBeginDirectPartDrag,
      onUpdateDirectPartDrag: onUpdateDirectPartDrag,
      onEndDirectPartDrag: onEndDirectPartDrag)
  }

  public func makeNSView(context: Context) -> WKWebView {
    let scripts = WKUserContentController()
    scripts.add(context.coordinator, name: context.coordinator.messageName)
    let configuration = WKWebViewConfiguration()
    configuration.userContentController = scripts
    configuration.websiteDataStore = .nonPersistent()
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.navigationDelegate = context.coordinator
    view.setValue(false, forKey: "drawsBackground")
    context.coordinator.attach(view)
    context.coordinator.set(theme: theme)
    context.coordinator.set(navigation: navigation)
    context.coordinator.set(document: document)
    context.coordinator.set(
      viewDirection: viewDirection, commandRevision: cameraCommandRevision)
    context.coordinator.set(
      hidden: hiddenPartIDs, selected: selectedPartIDs, grounded: groundedPartIDs)
    context.coordinator.set(referenceGeometry: referenceGeometry)
    context.coordinator.set(partTransforms: partTransforms)
    context.coordinator.set(partAppearances: partAppearances)
    context.coordinator.set(selectedPartOrigin: selectedPartOrigin)
    context.coordinator.loadPage()
    return view
  }

  public func updateNSView(_ view: WKWebView, context: Context) {
    context.coordinator.set(theme: theme)
    context.coordinator.set(navigation: navigation)
    context.coordinator.set(document: document)
    context.coordinator.set(
      viewDirection: viewDirection, commandRevision: cameraCommandRevision)
    context.coordinator.set(
      hidden: hiddenPartIDs, selected: selectedPartIDs, grounded: groundedPartIDs)
    context.coordinator.set(referenceGeometry: referenceGeometry)
    context.coordinator.set(partTransforms: partTransforms)
    context.coordinator.set(partAppearances: partAppearances)
    context.coordinator.set(selectedPartOrigin: selectedPartOrigin)
  }

  @MainActor
  public final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let backend: CADRenderBackend
    let onStatus: @MainActor (String) -> Void
    let onFrameCount: @MainActor (Int, Double?) -> Void
    let onCameraOrientation: @MainActor (CADCameraOrientationPresentation) -> Void
    let onSelectedGizmoProjection: @MainActor (CADProjectedLocalFrame?) -> Void
    let onPick: @MainActor (Int, Bool) -> Void
    let onBoxPick: @MainActor (Set<Int>, Bool) -> Void
    let onContextMenu: @MainActor (Int?, CGPoint) -> Void
    let onBeginDirectPartDrag: @MainActor (Int) -> Bool
    let onUpdateDirectPartDrag: @MainActor (CGSize, CGSize) -> Void
    let onEndDirectPartDrag: @MainActor () -> Void
    weak var webView: WKWebView?
    var pageReady = false
    var pendingDocument: CADGeometryDocument?
    var pendingClear = false
    var deliveredIdentity: UUID?
    var theme = CADViewportTheme.defaultTheme
    var deliveredTheme: CADViewportTheme?
    var navigation = CADViewportNavigationConfiguration.onshape
    var deliveredNavigation: CADViewportNavigationConfiguration?
    var desiredViewDirection: [Double]?
    var desiredCommandRevision = 0
    var deliveredCommandRevision: Int?
    var desiredHidden: Set<Int> = []
    var desiredSelected: Set<Int> = []
    var desiredGrounded: Set<Int> = []
    var deliveredHidden: Set<Int>?
    var deliveredSelected: Set<Int>?
    var deliveredGrounded: Set<Int>?
    var desiredReferenceGeometry: CADWorkspaceReferenceGeometry?
    var deliveredReferenceGeometry: CADWorkspaceReferenceGeometry?
    var desiredSelectedPartOrigin: CADPartOriginPresentation?
    var deliveredSelectedPartOrigin: CADPartOriginPresentation?
    var hasDeliveredSelectedPartOrigin = false
    var desiredPartTransforms: [CADPartTransformPresentation] = []
    var deliveredPartTransforms: [CADPartTransformPresentation]?
    var desiredPartAppearances: [CADPartAppearancePresentation] = []
    var deliveredPartAppearances: [CADPartAppearancePresentation]?

    init(
      backend: CADRenderBackend,
      onStatus: @escaping @MainActor (String) -> Void,
      onFrameCount: @escaping @MainActor (Int, Double?) -> Void,
      onCameraOrientation:
        @escaping @MainActor (CADCameraOrientationPresentation) -> Void,
      onSelectedGizmoProjection:
        @escaping @MainActor (CADProjectedLocalFrame?) -> Void,
      onPick: @escaping @MainActor (Int, Bool) -> Void,
      onBoxPick: @escaping @MainActor (Set<Int>, Bool) -> Void,
      onContextMenu: @escaping @MainActor (Int?, CGPoint) -> Void,
      onBeginDirectPartDrag: @escaping @MainActor (Int) -> Bool,
      onUpdateDirectPartDrag: @escaping @MainActor (CGSize, CGSize) -> Void,
      onEndDirectPartDrag: @escaping @MainActor () -> Void
    ) {
      self.backend = backend
      self.onStatus = onStatus
      self.onFrameCount = onFrameCount
      self.onCameraOrientation = onCameraOrientation
      self.onSelectedGizmoProjection = onSelectedGizmoProjection
      self.onPick = onPick
      self.onBoxPick = onBoxPick
      self.onContextMenu = onContextMenu
      self.onBeginDirectPartDrag = onBeginDirectPartDrag
      self.onUpdateDirectPartDrag = onUpdateDirectPartDrag
      self.onEndDirectPartDrag = onEndDirectPartDrag
    }

    var messageName: String {
      backend == .rawWebGPU ? "codexBenchRawWebGPU" : "codexBenchThreeJS"
    }

    var javaScriptObject: String {
      backend == .rawWebGPU ? "codexBenchRawWebGPU" : "codexBenchThreeJS"
    }

    func attach(_ view: WKWebView) { webView = view }

    func loadPage() {
      guard let webView else { return }
      guard let directory = resourceDirectory else {
        onStatus("\(backend.title) resources are missing from the app bundle.")
        return
      }
      onStatus("Starting \(backend.title)…")
      webView.loadFileURL(
        directory.appendingPathComponent("index.html"), allowingReadAccessTo: directory)
    }

    func set(document: CADGeometryDocument?) {
      pendingDocument = document
      pendingClear = document == nil
      deliverIfPossible()
    }

    func set(theme: CADViewportTheme) {
      self.theme = theme
      deliverThemeIfPossible()
    }

    func set(navigation: CADViewportNavigationConfiguration) {
      self.navigation = navigation
      deliverNavigationIfPossible()
    }

    func set(viewDirection: [Double]?, commandRevision: Int) {
      desiredViewDirection = viewDirection
      desiredCommandRevision = commandRevision
      deliverViewDirectionIfPossible()
    }

    private func deliverViewDirectionIfPossible() {
      guard pageReady, let webView, let direction = desiredViewDirection,
        direction.count >= 3,
        // Push ONLY on a new discrete camera command (ViewCube click / viewpoint
        // button). Continuous sync from JS orbit reports must never push back —
        // that fights the user's drag and the model jitters.
        desiredCommandRevision != deliveredCommandRevision
      else { return }
      deliveredCommandRevision = desiredCommandRevision
      var components = [direction[0], direction[1], direction[2]]
      if direction.count >= 4 { components.append(direction[3]) }
      let payload = "[" + components.map { String($0) }.joined(separator: ",") + "]"
      webView.evaluateJavaScript("window.\(javaScriptObject).setViewDirection(\(payload));")
    }

    func set(hidden: Set<Int>, selected: Set<Int>, grounded: Set<Int>) {
      desiredHidden = hidden
      desiredSelected = selected
      desiredGrounded = grounded
      deliverPartStateIfPossible()
    }

    private func deliverPartStateIfPossible() {
      guard pageReady, let webView,
        desiredHidden != deliveredHidden || desiredSelected != deliveredSelected
          || desiredGrounded != deliveredGrounded
      else { return }
      deliveredHidden = desiredHidden
      deliveredSelected = desiredSelected
      deliveredGrounded = desiredGrounded
      let hidden = desiredHidden.sorted().map(String.init).joined(separator: ",")
      let selected = desiredSelected.sorted().map(String.init).joined(separator: ",")
      let grounded = desiredGrounded.sorted().map(String.init).joined(separator: ",")
      webView.evaluateJavaScript(
        "window.\(javaScriptObject).setPartState([\(hidden)],[\(selected)],[\(grounded)]);")
    }

    func set(referenceGeometry: CADWorkspaceReferenceGeometry) {
      desiredReferenceGeometry = referenceGeometry
      deliverReferenceGeometryIfPossible()
    }

    private func deliverReferenceGeometryIfPossible() {
      guard backend == .threeJSWebGPU, pageReady, let webView,
        let referenceGeometry = desiredReferenceGeometry,
        referenceGeometry != deliveredReferenceGeometry
      else { return }
      do {
        let data = try JSONEncoder().encode(referenceGeometry)
        guard let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript(
          "window.\(javaScriptObject).setReferenceGeometry(\(json));")
        deliveredReferenceGeometry = referenceGeometry
      } catch {
        onStatus("Could not encode CAD reference geometry: \(error.localizedDescription)")
      }
    }

    func set(selectedPartOrigin: CADPartOriginPresentation?) {
      desiredSelectedPartOrigin = selectedPartOrigin
      deliverSelectedPartOriginIfPossible()
    }

    private func deliverSelectedPartOriginIfPossible() {
      guard backend == .threeJSWebGPU, pageReady, let webView,
        !hasDeliveredSelectedPartOrigin || desiredSelectedPartOrigin != deliveredSelectedPartOrigin
      else { return }
      do {
        let json: String
        if let desiredSelectedPartOrigin {
          let data = try JSONEncoder().encode(desiredSelectedPartOrigin)
          guard let encoded = String(data: data, encoding: .utf8) else { return }
          json = encoded
        } else {
          json = "null"
        }
        webView.evaluateJavaScript(
          "window.\(javaScriptObject).setSelectedPartOrigin(\(json));")
        deliveredSelectedPartOrigin = desiredSelectedPartOrigin
        hasDeliveredSelectedPartOrigin = true
      } catch {
        onStatus("Could not encode CAD part origin: \(error.localizedDescription)")
      }
    }

    func set(partTransforms: [CADPartTransformPresentation]) {
      desiredPartTransforms = partTransforms
      deliverPartTransformsIfPossible()
    }

    func set(partAppearances: [CADPartAppearancePresentation]) {
      desiredPartAppearances = partAppearances
      deliverPartAppearancesIfPossible()
    }

    private func deliverPartAppearancesIfPossible() {
      guard backend == .threeJSWebGPU, pageReady, let webView,
        desiredPartAppearances != deliveredPartAppearances
      else { return }
      do {
        let data = try JSONEncoder().encode(desiredPartAppearances)
        guard let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript(
          "window.\(javaScriptObject).setPartAppearances(\(json));")
        deliveredPartAppearances = desiredPartAppearances
      } catch {
        onStatus("Could not encode CAD part appearances: \(error.localizedDescription)")
      }
    }

    private func deliverPartTransformsIfPossible() {
      guard backend == .threeJSWebGPU, pageReady, let webView,
        desiredPartTransforms != deliveredPartTransforms
      else { return }
      do {
        let data = try JSONEncoder().encode(desiredPartTransforms)
        guard let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript(
          "window.\(javaScriptObject).setPartTransforms(\(json));")
        deliveredPartTransforms = desiredPartTransforms
      } catch {
        onStatus("Could not encode CAD part transforms: \(error.localizedDescription)")
      }
    }

    public func userContentController(
      _ userContentController: WKUserContentController,
      didReceive message: WKScriptMessage
    ) {
      guard message.name == messageName,
        let body = message.body as? [String: Any],
        let type = body["type"] as? String
      else { return }
      switch type {
      case "ready":
        pageReady = true
        let reported = body["backend"] as? String ?? backend.title
        onStatus("\(backend.title) ready on \(reported). Open CASCADE owns STEP import.")
        deliverIfPossible()
      case "loaded":
        let triangles = body["triangles"] as? Int ?? 0
        let milliseconds = body["milliseconds"] as? Double ?? 0
        onStatus(
          String(
            format: "%@: %d triangles uploaded in %.1f ms", backend.title, triangles, milliseconds))
      case "frames":
        let elapsedMilliseconds = body["elapsedMilliseconds"] as? Double
        onFrameCount(
          body["count"] as? Int ?? 0,
          elapsedMilliseconds.map { $0 / 1_000 })
      case "camera":
        if let direction = body["direction"] as? [Double], direction.count == 3 {
          onCameraOrientation(
            CADCameraOrientationPresentation(
              direction: SIMD3(
                Float(direction[0]),
                Float(direction[1]),
                Float(direction[2])
              ),
              rollRadians: Float(body["roll"] as? Double ?? 0)
            )
          )
        }
      case "selectedOriginScreen":
        if body["visible"] as? Bool == true,
          let origin = Self.viewportPoint(body["origin"]),
          let axes = body["axes"] as? [String: Any],
          let xAxis = Self.viewportPoint(axes["x"]),
          let yAxis = Self.viewportPoint(axes["y"]),
          let zAxis = Self.viewportPoint(axes["z"])
        {
          onSelectedGizmoProjection(
            CADProjectedLocalFrame(
              origin: origin,
              xAxis: xAxis,
              yAxis: yAxis,
              zAxis: zAxis))
        } else {
          onSelectedGizmoProjection(nil)
        }
      case "pick":
        let partID = body["partID"] as? Int ?? 0
        onPick(partID, body["extend"] as? Bool ?? false)
      case "boxPick":
        let partIDs = Set(body["partIDs"] as? [Int] ?? [])
        onBoxPick(partIDs, body["extend"] as? Bool ?? false)
      case "context":
        let partID = body["partID"] as? Int
        onContextMenu(
          partID == 0 ? nil : partID,
          CGPoint(
            x: body["x"] as? Double ?? 0,
            y: body["y"] as? Double ?? 0))
      case "partDragBegin":
        _ = onBeginDirectPartDrag(body["partID"] as? Int ?? 0)
      case "partDrag":
        onUpdateDirectPartDrag(
          CGSize(
            width: body["deltaX"] as? Double ?? 0,
            height: body["deltaY"] as? Double ?? 0),
          CGSize(
            width: body["viewportWidth"] as? Double ?? 1,
            height: body["viewportHeight"] as? Double ?? 1))
      case "partDragEnd":
        onEndDirectPartDrag()
      case "error":
        onStatus(body["message"] as? String ?? "\(backend.title) failed.")
      default:
        break
      }
    }

    private static func viewportPoint(_ value: Any?) -> CADNormalizedViewportPoint? {
      guard let value = value as? [String: Any],
        let x = value["x"] as? Double,
        let y = value["y"] as? Double
      else { return nil }
      return CADNormalizedViewportPoint(x: x, y: y)
    }

    public func webView(
      _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error
    ) { onStatus("\(backend.title) failed: \(error.localizedDescription)") }

    public func webView(
      _ webView: WKWebView,
      didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: any Error
    ) { onStatus("\(backend.title) failed: \(error.localizedDescription)") }

    private func deliverIfPossible() {
      guard pageReady, let webView else { return }
      deliverThemeIfPossible()
      deliverNavigationIfPossible()
      deliverViewDirectionIfPossible()
      deliverPartStateIfPossible()
      deliverReferenceGeometryIfPossible()
      deliverPartTransformsIfPossible()
      deliverPartAppearancesIfPossible()
      deliverSelectedPartOriginIfPossible()
      if pendingClear {
        pendingClear = false
        deliveredIdentity = nil
        webView.evaluateJavaScript("window.\(javaScriptObject).clearMesh();")
        return
      }
      guard let document = pendingDocument, deliveredIdentity != document.identity else { return }
      do {
        let data = try JSONEncoder().encode(CADWebGeometryPayload(document: document))
        guard let json = String(data: data, encoding: .utf8) else { return }
        deliveredIdentity = document.identity
        webView.evaluateJavaScript("window.\(javaScriptObject).loadMesh(\(json));")
      } catch {
        onStatus("Could not encode CAD geometry: \(error.localizedDescription)")
      }
    }

    private func deliverThemeIfPossible() {
      guard pageReady, deliveredTheme != theme, let webView else { return }
      do {
        let data = try JSONEncoder().encode(CADWebThemePayload(theme: theme))
        guard let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.\(javaScriptObject).setTheme(\(json));")
        deliveredTheme = theme
      } catch {
        onStatus("Could not encode CAD theme: \(error.localizedDescription)")
      }
    }

    private func deliverNavigationIfPossible() {
      guard pageReady, deliveredNavigation != navigation, let webView else { return }
      do {
        let data = try JSONEncoder().encode(CADWebNavigationPayload(navigation))
        guard let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.\(javaScriptObject).setNavigation(\(json));")
        deliveredNavigation = navigation
      } catch {
        onStatus("Could not encode CAD navigation: \(error.localizedDescription)")
      }
    }

    private var resourceDirectory: URL? {
      let name = backend == .rawWebGPU ? "RawWebGPU" : "ThreeJSWeb"
      let candidates = [
        Bundle.main.resourceURL?.appendingPathComponent("CADWeb/\(name)"),
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
          .appendingPathComponent("App/Resources/CADWeb/\(name)").standardizedFileURL,
      ].compactMap { $0 }
      return candidates.first {
        FileManager.default.fileExists(atPath: $0.appendingPathComponent("index.html").path)
      }
    }
  }
}
