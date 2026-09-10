import AppKit
import WebKit

final class AetherCADApplication: NSObject, NSApplicationDelegate, WKNavigationDelegate,
    WKUIDelegate, WKDownloadDelegate
{
    private static let enginePort = 8790
    private var window: NSWindow?
    private var webView: WKWebView?
    private var engine: Process?
    private var loadAttempts = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try startEngine()
            showWindow()
            scheduleLoad(after: 0.35)
        } catch {
            presentLaunchError(error)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if engine?.isRunning == true { engine?.terminate() }
        engine = nil
    }

    private func startEngine() throws {
        let repoRoot = Bundle.main.bundleURL.deletingLastPathComponent()
        let python = repoRoot.appendingPathComponent(".venv/bin/python")
        guard FileManager.default.isExecutableFile(atPath: python.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "Aether CAD expected .venv/bin/python beside the app in the repository checkout."
            ])
        }
        guard let resourceURL = Bundle.main.resourceURL else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "The Aether CAD web bundle is missing."
            ])
        }
        let webRoot = resourceURL.appendingPathComponent("Web", isDirectory: true)
        guard FileManager.default.fileExists(atPath: webRoot.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "The Aether CAD web bundle is missing."
            ])
        }

        let process = Process()
        process.executableURL = python
        process.arguments = [
            "-m", "animacore.httpbridge",
            "--port", String(Self.enginePort),
            "--root", repoRoot.path,
            "--app", webRoot.path,
        ]
        process.currentDirectoryURL = repoRoot
        try process.run()
        engine = process
    }

    private let windowChrome = StudioWindowChrome()

    @MainActor
    private func showWindow() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        windowChrome.install(in: configuration)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsMagnification = false
        self.webView = webView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Aether CAD"
        windowChrome.attach(to: window)
        window.setFrameAutosaveName("AetherCADMainWindow")
        window.contentView = webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    private func scheduleLoad(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.loadAttempts += 1
            self.webView?.load(URLRequest(url: URL(string: "http://127.0.0.1:\(Self.enginePort)/")!))
        }
    }

    @MainActor
    private func presentLaunchError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Aether CAD Could Not Launch"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        NSApp.terminate(nil)
    }

    private func retryOrPresent(_ error: Error) {
        if loadAttempts < 12, engine?.isRunning == true {
            scheduleLoad(after: 0.45)
        } else {
            presentLaunchError(error)
        }
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        retryOrPresent(error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        retryOrPresent(error)
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        guard let window else {
            completionHandler(nil)
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        panel.beginSheetModal(for: window) { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow, preferences)
    }

    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        guard let window else {
            completionHandler(nil)
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.beginSheetModal(for: window) { result in
            completionHandler(result == .OK ? panel.url : nil)
        }
    }
}

@main
enum AetherCADMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AetherCADApplication()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
    }
}
