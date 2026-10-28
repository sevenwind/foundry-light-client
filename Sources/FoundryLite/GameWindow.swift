import AppKit
import WebKit

/// Окно игры: единственный WKWebView на сервер. Закрытие окна освобождает веб-процесс целиком
final class GameWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    var onClose: (() -> Void)?
    var onShowLauncher: (() -> Void)?

    private let server: Server
    private let url: URL
    private var webView: WKWebView!
    private var titleObservation: NSKeyValueObservation?
    private var popups: [PopupWindow] = []
    private let zoomKey: String

    init(server: Server, url: URL) {
        self.server = server
        self.url = url
        self.zoomKey = "zoom-\(server.key)"

        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        cfg.mediaTypesRequiringUserActionForPlayback = []  // звуки и музыка Foundry без клика
        cfg.preferences.isElementFullscreenEnabled = true
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = true
        cfg.preferences.isFraudulentWebsiteWarningEnabled = false  // без сетевых проверок Safe Browsing

        let dark = NSColor(white: 0.1, alpha: 1)
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
                           styleMask: [.titled, .closable, .miniaturizable, .resizable],
                           backing: .buffered, defer: false)
        win.title = server.name
        win.minSize = NSSize(width: 640, height: 400)
        win.backgroundColor = dark
        win.collectionBehavior = [.fullScreenPrimary]
        win.isReleasedWhenClosed = false
        win.center()
        win.setFrameAutosaveName("Game-\(server.key)")

        webView = WKWebView(frame: .zero, configuration: cfg)
        webView.underPageBackgroundColor = dark
        webView.autoresizingMask = [.width, .height]
        win.contentView = webView
        let saved = UserDefaults.standard.double(forKey: zoomKey)
        webView.pageZoom = saved > 0 ? saved : 1

        super.init(window: win)
        win.delegate = self
        webView.navigationDelegate = self
        webView.uiDelegate = self
        titleObservation = webView.observe(\.title) { [weak self] wv, _ in
            guard let self else { return }
            window?.title = (wv.title?.isEmpty == false ? wv.title : nil) ?? self.server.name
        }
        webView.load(URLRequest(url: url))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        titleObservation = nil
        popups.forEach { $0.window.close() }
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        window?.contentView = nil
        webView = nil
        onClose?()
    }

    // MARK: - Действия меню

    @objc func reloadPage(_ sender: Any?) { webView.reload() }
    @objc func reloadPageFromOrigin(_ sender: Any?) { webView.reloadFromOrigin() }
    @objc func zoomIn(_ sender: Any?) { setZoom(webView.pageZoom + 0.1) }
    @objc func zoomOut(_ sender: Any?) { setZoom(webView.pageZoom - 0.1) }
    @objc func zoomReset(_ sender: Any?) { setZoom(1) }

    private func setZoom(_ z: CGFloat) {
        let clamped = min(max(z, 0.5), 3)
        webView.pageZoom = clamped
        UserDefaults.standard.set(clamped, forKey: zoomKey)
    }

    // MARK: - Навигация

    private func sameOrigin(_ other: URL) -> Bool {
        other.host == url.host && other.port == url.port
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
        } else if navigationAction.navigationType == .linkActivated,
                  navigationAction.targetFrame?.isMainFrame == true,
                  let target = navigationAction.request.url, !sameOrigin(target) {
            NSWorkspace.shared.open(target)  // внешние ссылки открываем в обычном браузере
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showLoadError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showLoadError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    private func showLoadError(_ error: Error) {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
        guard let window, window.attachedSheet == nil else { return }
        let alert = NSAlert()
        alert.messageText = "Не удалось подключиться"
        alert.informativeText = "\(url.absoluteString)\n\(ns.localizedDescription)"
        alert.addButton(withTitle: "Повторить")
        alert.addButton(withTitle: "К списку серверов")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            if response == .alertFirstButtonReturn {
                self.webView?.load(URLRequest(url: url))
            } else {
                window.close()
            }
        }
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let target = navigationAction.request.url
        guard target == nil || target?.host == nil || sameOrigin(target!) else {
            NSWorkspace.shared.open(target!)
            return nil
        }
        let popup = PopupWindow(configuration: configuration)
        popup.onClose = { [weak self, weak popup] in self?.popups.removeAll { $0 === popup } }
        popups.append(popup)
        popup.window.makeKeyAndOrderFront(nil)
        return popup.webView
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        guard let window else { return completionHandler(nil) }
        panel.beginSheetModal(for: window) { completionHandler($0 == .OK ? panel.urls : nil) }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        guard let window else { return completionHandler() }
        alert.beginSheetModal(for: window) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Отмена")
        guard let window else { return completionHandler(false) }
        alert.beginSheetModal(for: window) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.prompt)
    }

    // MARK: - Загрузки

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let ext = (suggestedFilename as NSString).pathExtension
        let base = (suggestedFilename as NSString).deletingPathExtension
        var dest = dir.appendingPathComponent(suggestedFilename)
        var n = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = dir.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        completionHandler(dest)
    }
}

/// Всплывающее окно (window.open) того же сервера, например вынесенный журнал
final class PopupWindow: NSObject, NSWindowDelegate, WKUIDelegate {
    let window: NSWindow
    let webView: WKWebView
    var onClose: (() -> Void)?

    init(configuration: WKWebViewConfiguration) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.center()
        super.init()
        window.delegate = self
        webView.uiDelegate = self
    }

    func webViewDidClose(_ webView: WKWebView) { window.close() }

    func windowWillClose(_ notification: Notification) {
        webView.stopLoading()
        window.contentView = nil
        onClose?()
    }
}
