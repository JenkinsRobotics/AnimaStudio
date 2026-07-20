import Foundation
import GeomBenchCore
import OSLog
import SwiftUI
import WebKit

/// Pipeline 7: Open CASCADE owns STEP/XDE import and topology extraction;
/// Three.js provides an optional higher-level WebGPU scene renderer. Its
/// WebGPURenderer reports when WKWebView falls back to WebGL 2.
struct ThreeJSBenchView: NSViewRepresentable {
  @Bindable var session: BenchSession
  let document: GeometryDocument?

  func makeCoordinator() -> Coordinator { Coordinator(session: session) }

  func makeNSView(context: Context) -> WKWebView {
    let scripts = WKUserContentController()
    scripts.add(context.coordinator, name: "codexBenchThreeJS")
    let configuration = WKWebViewConfiguration()
    configuration.userContentController = scripts
    configuration.websiteDataStore = .nonPersistent()
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.navigationDelegate = context.coordinator
    view.setValue(false, forKey: "drawsBackground")
    context.coordinator.attach(view)
    context.coordinator.set(theme: session.theme)
    context.coordinator.set(document: document)
    context.coordinator.loadPage()
    return view
  }

  func updateNSView(_ view: WKWebView, context: Context) {
    context.coordinator.set(theme: session.theme)
    context.coordinator.set(document: document)
    context.coordinator.applyBenchmarkPulse(session.benchmarkPulse)
  }

  @MainActor
  final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private static let logger = Logger(
      subsystem: "com.animastudio.GeomBench", category: "ThreeJS")
    private weak var webView: WKWebView?
    private let session: BenchSession
    private var pageReady = false
    private var pendingDocument: GeometryDocument?
    private var pendingClear = false
    private var deliveredSignature: String?
    private var theme = BenchTheme.studioBlue
    private var deliveredTheme: BenchTheme?
    private var deliveredBenchmarkPulse = 0
    private var backendName = "WebGPU probe pending"

    init(session: BenchSession) { self.session = session }

    func attach(_ webView: WKWebView) { self.webView = webView }

    func loadPage() {
      guard let webView else { return }
      guard let directory = Self.resourceDirectory else {
        session.status =
          "Three.js assets are missing. Run scripts/build-threejs.sh and repackage Codex Bench."
        return
      }
      session.status = "Starting the bundled Three.js WebGPU renderer…"
      webView.loadFileURL(
        directory.appendingPathComponent("index.html"), allowingReadAccessTo: directory)
    }

    func set(document: GeometryDocument?) {
      pendingDocument = document
      pendingClear = document == nil
      deliverIfPossible()
    }

    func set(theme: BenchTheme) {
      self.theme = theme
      deliverThemeIfPossible()
    }

    func webView(
      _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error
    ) {
      fail(error)
    }

    func webView(
      _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: any Error
    ) {
      fail(error)
    }

    func userContentController(
      _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
      guard message.name == "codexBenchThreeJS",
        let body = message.body as? [String: Any],
        let type = body["type"] as? String
      else { return }
      switch type {
      case "ready":
        pageReady = true
        let version = body["version"] as? String ?? "unknown"
        backendName = body["backend"] as? String ?? "unknown backend"
        session.rendererBackend = backendName
        session.status =
          "Three.js r\(version) ready on \(backendName). Open CASCADE owns STEP import."
        deliverIfPossible()
      case "loaded":
        let triangles = body["triangles"] as? Int ?? 0
        let milliseconds = body["milliseconds"] as? Double ?? 0
        session.telemetry.overrideLoadMilliseconds = milliseconds
        session.status = String(
          format: "Three.js %@: %d STEP triangles uploaded in %.1f ms", backendName, triangles,
          milliseconds)
      case "frames":
        if let count = body["count"] as? Int { session.tickFrames(count) }
      case "error":
        session.status = body["message"] as? String ?? "Three.js renderer failed."
      default:
        break
      }
    }

    func applyBenchmarkPulse(_ pulse: Int) {
      guard pulse != deliveredBenchmarkPulse, pageReady, let webView else { return }
      deliveredBenchmarkPulse = pulse
      webView.evaluateJavaScript("window.codexBenchThreeJS.orbit(1.2,0.18);")
    }

    private func deliverIfPossible() {
      guard pageReady, let webView else { return }
      deliverThemeIfPossible()
      if pendingClear {
        pendingClear = false
        deliveredSignature = nil
        webView.evaluateJavaScript("window.codexBenchThreeJS.clearMesh();")
        return
      }
      guard let document = pendingDocument else { return }
      let signature = document.identity.uuidString
      guard signature != deliveredSignature else { return }
      do {
        let data = try JSONEncoder().encode(WebGeometryPayload(document: document))
        guard let json = String(data: data, encoding: .utf8) else { return }
        deliveredSignature = signature
        webView.evaluateJavaScript("window.codexBenchThreeJS.loadMesh(\(json));") {
          [weak self] _, error in
          guard let error else { return }
          Task { @MainActor in self?.fail(error) }
        }
      } catch {
        fail(error)
      }
    }

    private func deliverThemeIfPossible() {
      guard pageReady, deliveredTheme != theme, let webView else { return }
      do {
        let data = try JSONEncoder().encode(WebRenderThemePayload(theme: theme))
        guard let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.codexBenchThreeJS.setTheme(\(json));")
        deliveredTheme = theme
      } catch {
        fail(error)
      }
    }

    private func fail(_ error: any Error) {
      session.status = "Three.js host failed: \(error.localizedDescription)"
      Self.logger.error("\(self.session.status, privacy: .public)")
    }

    private static var resourceDirectory: URL? {
      let candidate = Bundle.main.resourceURL?.appendingPathComponent("ThreeJSWeb")
      guard let candidate,
        FileManager.default.fileExists(atPath: candidate.appendingPathComponent("index.html").path)
      else { return nil }
      return candidate
    }
  }
}
