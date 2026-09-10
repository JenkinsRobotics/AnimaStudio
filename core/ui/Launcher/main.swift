// Aether UI launcher: a thin WKWebView shell that serves the built
// widget gallery (core/ui/dist) over localhost and displays it, so
// double-clicking the .app opens the design-review gallery. The gallery
// is static — no engine process, just a stdlib file server.

import AppKit
import WebKit

let galleryPort = 8792

final class LauncherDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate,
  WKNavigationDelegate
{
  private let windowChrome = StudioWindowChrome()
  private var window: NSWindow!
  private var webView: WKWebView!
  private var server: Process?
  private var loadAttempts = 0

  func applicationDidFinishLaunching(_ notification: Notification) {
    let repoRoot = Bundle.main.bundleURL.deletingLastPathComponent()
    startServer(repoRoot: repoRoot)

    let configuration = WKWebViewConfiguration()
    windowChrome.install(in: configuration)
    webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = self

    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1200, height: 950),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    window.title = "Aether UI"
    windowChrome.attach(to: window)
    window.contentView = webView
    window.center()
    window.delegate = self
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.load() }
  }

  private func startServer(repoRoot: URL) {
    let dist = repoRoot.appendingPathComponent("core/ui/dist")
    let process = Process()
    // ponytail: stdlib http.server is plenty for a local static gallery
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = [
      "-m", "http.server", String(galleryPort),
      "--bind", "127.0.0.1", "-d", dist.path,
    ]
    process.currentDirectoryURL = repoRoot
    try? process.run()
    server = process
  }

  private func load() {
    loadAttempts += 1
    webView.load(URLRequest(url: URL(string: "http://127.0.0.1:\(galleryPort)/")!))
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    if loadAttempts < 10 {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.load() }
    } else {
      webView.loadHTMLString(
        """
        <body style="background:#101318;color:#e7edf3;font-family:sans-serif;
                     display:grid;place-items:center;height:100vh">
        <div><h3>Gallery did not start</h3>
        <p>Expected <code>core/ui/dist</code> beside this app in the
        repository checkout — run
        <code>core/ui/Launcher/build-launcher.sh</code> to rebuild.</p>
        </div></body>
        """, baseURL: nil)
    }
  }

  func windowWillClose(_ notification: Notification) {
    NSApp.terminate(nil)
  }

  func applicationWillTerminate(_ notification: Notification) {
    server?.terminate()
  }
}

let app = NSApplication.shared
let delegate = LauncherDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
