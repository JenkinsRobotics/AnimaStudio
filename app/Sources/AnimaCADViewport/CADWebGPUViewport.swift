import AnimaCAD
import Foundation
import SwiftUI
import WebKit

public struct CADWebGPUViewport: NSViewRepresentable {
  public let backend: CADRenderBackend
  public let document: CADGeometryDocument?
  public let theme: CADViewportTheme
  /// Unit view direction (target→camera, Y-up) the ViewCube wants applied.
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
  public let selectedPartOrigin: CADPartOriginPresentation?
  public let onStatus: @MainActor (String) -> Void
  public let onFrameCount: @MainActor (Int) -> Void
  /// Reports the JS camera direction back so the ViewCube tracks free orbits.
  public let onCameraDirection: @MainActor ([Double]) -> Void
  /// Normalized top-left screen coordinate of the selected Part/group origin.
  public let onSelectedOriginScreenPosition: @MainActor (CADNormalizedViewportPoint?) -> Void
  /// A part clicked in the viewport (partID, extend-selection).
  public let onPick: @MainActor (Int, Bool) -> Void

  public init(
    backend: CADRenderBackend,
    document: CADGeometryDocument?,
    theme: CADViewportTheme,
    viewDirection: [Double]? = nil,
    cameraCommandRevision: Int = 0,
    hiddenPartIDs: Set<Int> = [],
    selectedPartIDs: Set<Int> = [],
    groundedPartIDs: Set<Int> = [],
    referenceGeometry: CADWorkspaceReferenceGeometry = .init(
      visibility: .init(), modelDiagonalMeters: 1),
    partTransforms: [CADPartTransformPresentation] = [],
    selectedPartOrigin: CADPartOriginPresentation? = nil,
    onStatus: @escaping @MainActor (String) -> Void = { _ in },
    onFrameCount: @escaping @MainActor (Int) -> Void = { _ in },
    onCameraDirection: @escaping @MainActor ([Double]) -> Void = { _ in },
    onSelectedOriginScreenPosition:
      @escaping @MainActor (CADNormalizedViewportPoint?) -> Void = { _ in },
    onPick: @escaping @MainActor (Int, Bool) -> Void = { _, _ in }
  ) {
    precondition(backend == .threeJSWebGPU || backend == .rawWebGPU)
    self.backend = backend
    self.document = document
    self.theme = theme
    self.viewDirection = viewDirection
    self.cameraCommandRevision = cameraCommandRevision
    self.hiddenPartIDs = hiddenPartIDs
    self.selectedPartIDs = selectedPartIDs
    self.groundedPartIDs = groundedPartIDs
    self.referenceGeometry = referenceGeometry
    self.partTransforms = partTransforms
    self.selectedPartOrigin = selectedPartOrigin
    self.onStatus = onStatus
    self.onFrameCount = onFrameCount
    self.onCameraDirection = onCameraDirection
    self.onSelectedOriginScreenPosition = onSelectedOriginScreenPosition
    self.onPick = onPick
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(
      backend: backend, onStatus: onStatus, onFrameCount: onFrameCount,
      onCameraDirection: onCameraDirection,
      onSelectedOriginScreenPosition: onSelectedOriginScreenPosition,
      onPick: onPick)
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
    context.coordinator.set(document: document)
    context.coordinator.set(
      viewDirection: viewDirection, commandRevision: cameraCommandRevision)
    context.coordinator.set(
      hidden: hiddenPartIDs, selected: selectedPartIDs, grounded: groundedPartIDs)
    context.coordinator.set(referenceGeometry: referenceGeometry)
    context.coordinator.set(partTransforms: partTransforms)
    context.coordinator.set(selectedPartOrigin: selectedPartOrigin)
    context.coordinator.loadPage()
    return view
  }

  public func updateNSView(_ view: WKWebView, context: Context) {
    context.coordinator.set(theme: theme)
    context.coordinator.set(document: document)
    context.coordinator.set(
      viewDirection: viewDirection, commandRevision: cameraCommandRevision)
    context.coordinator.set(
      hidden: hiddenPartIDs, selected: selectedPartIDs, grounded: groundedPartIDs)
    context.coordinator.set(referenceGeometry: referenceGeometry)
    context.coordinator.set(partTransforms: partTransforms)
    context.coordinator.set(selectedPartOrigin: selectedPartOrigin)
  }

  @MainActor
  public final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let backend: CADRenderBackend
    let onStatus: @MainActor (String) -> Void
    let onFrameCount: @MainActor (Int) -> Void
    let onCameraDirection: @MainActor ([Double]) -> Void
    let onSelectedOriginScreenPosition: @MainActor (CADNormalizedViewportPoint?) -> Void
    let onPick: @MainActor (Int, Bool) -> Void
    weak var webView: WKWebView?
    var pageReady = false
    var pendingDocument: CADGeometryDocument?
    var pendingClear = false
    var deliveredIdentity: UUID?
    var theme = CADViewportTheme.studioBlue
    var deliveredTheme: CADViewportTheme?
    var desiredViewDirection: [Double]?
    var deliveredViewDirection: [Double]?
    var desiredCommandRevision = 0
    var deliveredCommandRevision: Int?
    /// Last direction JS reported from a user orbit; used to skip re-pushing an
    /// echo of that orbit back to JS (which would fight the user's drag).
    var lastReportedDirection: [Double]?
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

    init(
      backend: CADRenderBackend,
      onStatus: @escaping @MainActor (String) -> Void,
      onFrameCount: @escaping @MainActor (Int) -> Void,
      onCameraDirection: @escaping @MainActor ([Double]) -> Void,
      onSelectedOriginScreenPosition:
        @escaping @MainActor (CADNormalizedViewportPoint?) -> Void,
      onPick: @escaping @MainActor (Int, Bool) -> Void
    ) {
      self.backend = backend
      self.onStatus = onStatus
      self.onFrameCount = onFrameCount
      self.onCameraDirection = onCameraDirection
      self.onSelectedOriginScreenPosition = onSelectedOriginScreenPosition
      self.onPick = onPick
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

    func set(viewDirection: [Double]?, commandRevision: Int) {
      desiredViewDirection = viewDirection
      desiredCommandRevision = commandRevision
      deliverViewDirectionIfPossible()
    }

    private func deliverViewDirectionIfPossible() {
      guard pageReady, let webView, let direction = desiredViewDirection,
        direction.count == 3,
        // Push ONLY on a new discrete camera command (ViewCube click / viewpoint
        // button). Continuous sync from JS orbit reports must never push back —
        // that fights the user's drag and the model jitters.
        desiredCommandRevision != deliveredCommandRevision
      else { return }
      deliveredCommandRevision = desiredCommandRevision
      deliveredViewDirection = direction
      let payload = "[\(direction[0]),\(direction[1]),\(direction[2])]"
      webView.evaluateJavaScript("window.\(javaScriptObject).setViewDirection(\(payload));")
    }

    private static func approximatelyEqual(_ lhs: [Double], _ rhs: [Double]?) -> Bool {
      guard let rhs, lhs.count == rhs.count else { return false }
      return zip(lhs, rhs).allSatisfy { abs($0 - $1) < 0.001 }
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
        onFrameCount(body["count"] as? Int ?? 0)
      case "camera":
        if let direction = body["direction"] as? [Double], direction.count == 3 {
          lastReportedDirection = direction
          onCameraDirection(direction)
        }
      case "selectedOriginScreen":
        if body["visible"] as? Bool == true,
          let x = body["x"] as? Double,
          let y = body["y"] as? Double
        {
          onSelectedOriginScreenPosition(CADNormalizedViewportPoint(x: x, y: y))
        } else {
          onSelectedOriginScreenPosition(nil)
        }
      case "pick":
        let partID = body["partID"] as? Int ?? 0
        onPick(partID, body["extend"] as? Bool ?? false)
      case "error":
        onStatus(body["message"] as? String ?? "\(backend.title) failed.")
      default:
        break
      }
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
      deliverViewDirectionIfPossible()
      deliverPartStateIfPossible()
      deliverReferenceGeometryIfPossible()
      deliverPartTransformsIfPossible()
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
