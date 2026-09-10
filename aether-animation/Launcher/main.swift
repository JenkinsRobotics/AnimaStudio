// Aether Animation launcher: a thin WKWebView shell (mirroring the
// Aether CAD.app pattern) that ALSO owns the product's engine process —
// it spawns `python -m animacore.httpbridge --app <dist>` and loads the
// served app, so double-clicking the .app is the whole story. UI lives in
// the web app; this file is chrome and process supervision only.

import AppKit
import WebKit

let enginePort = 8791

final class LauncherDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate,
  WKNavigationDelegate
{
  private let windowChrome = StudioWindowChrome()
  private var window: NSWindow!
  private var webView: WKWebView!
  private var engine: Process?
  private var loadAttempts = 0

  func applicationDidFinishLaunching(_ notification: Notification) {
    let repoRoot = Bundle.main.bundleURL.deletingLastPathComponent()
    startEngine(repoRoot: repoRoot)

    let configuration = WKWebViewConfiguration()
    windowChrome.install(in: configuration)
    webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = self

    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    window.title = "Aether Animation"
    windowChrome.attach(to: window)
    window.contentView = webView
    window.center()
    window.delegate = self
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    // The engine needs a beat before it accepts connections.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.load() }
  }

  private func startEngine(repoRoot: URL) {
    let python = repoRoot.appendingPathComponent(".venv/bin/python")
    let dist = repoRoot.appendingPathComponent("aether-animation/web/dist")
    guard FileManager.default.isExecutableFile(atPath: python.path) else {
      return  // load() will surface the failure in the window
    }
    let process = Process()
    process.executableURL = python
    process.arguments = [
      "-m", "animacore.httpbridge",
      "--port", String(enginePort),
      "--app", dist.path,
    ]
    process.currentDirectoryURL = repoRoot
    try? process.run()
    engine = process
  }

  private func load() {
    loadAttempts += 1
    webView.load(URLRequest(url: URL(string: "http://127.0.0.1:\(enginePort)/")!))
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    if loadAttempts < 10 {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { self.load() }
    } else {
      webView.loadHTMLString(
        """
        <body style="background:#101318;color:#e7edf3;font-family:sans-serif;
                     display:grid;place-items:center;height:100vh">
        <div><h3>Engine did not start</h3>
        <p>Expected <code>.venv/bin/python</code> and
        <code>aether-animation/web/dist</code> beside this app in the
        repository checkout.</p></div></body>
        """, baseURL: nil)
    }
  }

  func windowWillClose(_ notification: Notification) {
    NSApp.terminate(nil)
  }

  func applicationWillTerminate(_ notification: Notification) {
    engine?.terminate()
  }
}

let app = NSApplication.shared
let delegate = LauncherDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
