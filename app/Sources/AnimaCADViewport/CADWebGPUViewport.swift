import AnimaCAD
import Foundation
import SwiftUI
import WebKit

public struct CADWebGPUViewport: NSViewRepresentable {
  public let backend: CADRenderBackend
  public let document: CADGeometryDocument?
  public let theme: CADViewportTheme
  public let onStatus: @MainActor (String) -> Void
  public let onFrameCount: @MainActor (Int) -> Void

  public init(
    backend: CADRenderBackend,
    document: CADGeometryDocument?,
    theme: CADViewportTheme,
    onStatus: @escaping @MainActor (String) -> Void = { _ in },
    onFrameCount: @escaping @MainActor (Int) -> Void = { _ in }
  ) {
    precondition(backend == .threeJSWebGPU || backend == .rawWebGPU)
    self.backend = backend
    self.document = document
    self.theme = theme
    self.onStatus = onStatus
    self.onFrameCount = onFrameCount
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(backend: backend, onStatus: onStatus, onFrameCount: onFrameCount)
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
    context.coordinator.loadPage()
    return view
  }

  public func updateNSView(_ view: WKWebView, context: Context) {
    context.coordinator.set(theme: theme)
    context.coordinator.set(document: document)
  }

  @MainActor
  public final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let backend: CADRenderBackend
    let onStatus: @MainActor (String) -> Void
    let onFrameCount: @MainActor (Int) -> Void
    weak var webView: WKWebView?
    var pageReady = false
    var pendingDocument: CADGeometryDocument?
    var pendingClear = false
    var deliveredIdentity: UUID?
    var theme = CADViewportTheme.studioBlue
    var deliveredTheme: CADViewportTheme?

    init(
      backend: CADRenderBackend,
      onStatus: @escaping @MainActor (String) -> Void,
      onFrameCount: @escaping @MainActor (Int) -> Void
    ) {
      self.backend = backend
      self.onStatus = onStatus
      self.onFrameCount = onFrameCount
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
