import Foundation
import GeomBenchCore
import OSLog
import SwiftUI
import WebKit

/// Pipeline 10: Open CASCADE owns STEP/XDE import and topology extraction;
/// this view sends the shared compact geometry directly to navigator.gpu.
/// No JavaScript rendering framework or WebGL fallback is involved.
struct RawWebGPUBenchView: NSViewRepresentable {
  @Bindable var session: BenchSession
  let document: GeometryDocument?

  func makeCoordinator() -> Coordinator { Coordinator(session: session) }

  func makeNSView(context: Context) -> WKWebView {
    let scripts = WKUserContentController()
    scripts.add(context.coordinator, name: "codexBenchRawWebGPU")
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
      subsystem: "com.animastudio.GeomBench", category: "RawWebGPU")
    private weak var webView: WKWebView?
    private let session: BenchSession
    private var pageReady = false
    private var pendingDocument: GeometryDocument?
    private var pendingClear = false
    private var deliveredSignature: String?
    private var theme = BenchTheme.studioBlue
    private var deliveredTheme: BenchTheme?
    private var deliveredBenchmarkPulse = 0

    init(session: BenchSession) { self.session = session }

    func attach(_ webView: WKWebView) { self.webView = webView }

    func loadPage() {
      guard let webView else { return }
      guard let directory = Self.resourceDirectory else {
        session.status = "Raw WebGPU assets are missing. Repackage Codex Bench."
        return
      }
      session.status = "Requesting a raw WebGPU device from Apple WebKit…"
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
      guard message.name == "codexBenchRawWebGPU",
        let body = message.body as? [String: Any],
        let type = body["type"] as? String
      else { return }
      switch type {
      case "ready":
        pageReady = true
        session.rendererBackend = "Raw WebGPU"
        session.status = "Raw WebGPU ready. Open CASCADE owns STEP import."
        Self.logger.notice("Raw WebGPU device and pipelines are ready")
        deliverIfPossible()
      case "loaded":
        let triangles = body["triangles"] as? Int ?? 0
        let milliseconds = body["milliseconds"] as? Double ?? 0
        session.telemetry.overrideLoadMilliseconds = milliseconds
        session.status = String(
          format: "Raw WebGPU: %d STEP triangles uploaded in %.1f ms", triangles, milliseconds)
      case "frames":
        if let count = body["count"] as? Int { session.tickFrames(count) }
      case "error":
        let value = body["message"] as? String ?? "Raw WebGPU renderer failed."
        session.rendererDiagnostic = value
        session.status = value
        Self.logger.error("\(value, privacy: .public)")
      default:
        break
      }
    }

    func applyBenchmarkPulse(_ pulse: Int) {
      guard pulse != deliveredBenchmarkPulse, pageReady, let webView else { return }
      deliveredBenchmarkPulse = pulse
      webView.evaluateJavaScript("window.codexBenchRawWebGPU.orbit(1.2,0.18);")
    }

    private func deliverIfPossible() {
      guard pageReady, let webView else { return }
      deliverThemeIfPossible()
      if pendingClear {
        pendingClear = false
        deliveredSignature = nil
        webView.evaluateJavaScript("window.codexBenchRawWebGPU.clearMesh();")
        return
      }
      guard let document = pendingDocument else { return }
      let signature = document.identity.uuidString
      guard signature != deliveredSignature else { return }
      do {
        let data = try JSONEncoder().encode(WebGeometryPayload(document: document))
        guard let json = String(data: data, encoding: .utf8) else { return }
        deliveredSignature = signature
        webView.evaluateJavaScript("window.codexBenchRawWebGPU.loadMesh(\(json));") {
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
        webView.evaluateJavaScript("window.codexBenchRawWebGPU.setTheme(\(json));")
        deliveredTheme = theme
      } catch {
        fail(error)
      }
    }

    private func fail(_ error: any Error) {
      let value = "Raw WebGPU host failed: \(error.localizedDescription)"
      session.rendererDiagnostic = value
      session.status = value
      Self.logger.error("\(value, privacy: .public)")
    }

    private static var resourceDirectory: URL? {
      let candidate = Bundle.main.resourceURL?.appendingPathComponent("RawWebGPU")
      guard let candidate,
        FileManager.default.fileExists(atPath: candidate.appendingPathComponent("index.html").path)
      else { return nil }
      return candidate
    }
  }
}
