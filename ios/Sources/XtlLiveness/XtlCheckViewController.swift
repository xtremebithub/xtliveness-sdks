#if canImport(UIKit) && canImport(WebKit)
import AVFoundation
import UIKit
import WebKit

/// The face check on iOS 13 and later (the camera inside a web view needs iOS 15). Add `NSCameraUsageDescription` to your Info.plist.
///
/// `checkURL` and `sdkToken` come from `POST /v1/sessions` on YOUR server (never call that from the app: it needs your API key). The token works once.
/// `onResult` runs once, on the main thread. The view controller does not dismiss itself: do that in `onResult`.
public final class XtlCheckViewController: UIViewController {

    private let address: CheckAddress?
    private let sdkToken: String
    private let onResult: (XtlResult) -> Void
    private var webView: WKWebView?
    private var done = false

    public init(checkURL: String, sdkToken: String, allowInsecureHTTP: Bool = false, onResult: @escaping (XtlResult) -> Void) {
        self.address = try? parseCheckURL(checkURL, allowInsecureHTTP: allowInsecureHTTP)
        self.sdkToken = sdkToken
        self.onResult = onResult
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("use init(checkURL:sdkToken:allowInsecureHTTP:onResult:)") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let close = UIButton(type: .system)
        close.setTitle("Close", for: .normal)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(close)
        NSLayoutConstraint.activate([
            close.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
        ])
        begin()
    }

    @objc private func closeTapped() { finish(.cancelled) }

    private func finish(_ r: XtlResult) {
        if done { return }
        done = true
        onResult(r)
    }

    private func begin() {
        guard let address = address else { finish(.error(code: "invalid_check_address")); return }
        let url: URL
        do { url = try address.loadURL(sdkToken: sdkToken) } catch { finish(.error(code: "missing_token")); return }
        // the camera first: a refusal is reported at once instead of leaving a blank page
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self, !self.done else { return }
                if granted { self.load(url, address) } else { self.finish(.error(code: "camera_denied")) }
            }
        }
    }

    private func load(_ url: URL, _ address: CheckAddress) {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .nonPersistent()
        // The check page reports through a channel called XtlBridge; make it before the page loads and forward to WebKit's own.
        let bridge = "window.XtlBridge = { postMessage: function (m) { window.webkit.messageHandlers.XtlBridge.postMessage(m); } };"
        config.userContentController.addUserScript(WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(WeakHandler(self), name: "XtlBridge")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.isOpaque = true
        wv.backgroundColor = .white
        wv.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(wv, at: 0)
        NSLayoutConstraint.activate([
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor), wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44), wv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        webView = wv
        wv.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "XtlBridge")
        webView?.stopLoading()
    }

    fileprivate func received(_ body: Any) {
        guard let address = address, let r = parseMessage(body, expectedSessionId: address.sessionId) else { return }
        finish(r)
    }
}

/// Keeps the web view's strong reference to its message handler from keeping the view controller alive.
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: XtlCheckViewController?
    init(_ target: XtlCheckViewController) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) { target?.received(message.body) }
}

extension XtlCheckViewController: WKNavigationDelegate {
    // the page stays on the check's own address; anything else is refused
    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let address = address, let url = action.request.url, originOf(url.absoluteString) == address.origin else { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if response.isForMainFrame, let http = response.response as? HTTPURLResponse, http.statusCode >= 400 { finish(.error(code: "load_failed")) }
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }

    private func failed(_ error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        finish(.error(code: "load_failed"))
    }
}

extension XtlCheckViewController: WKUIDelegate {
    // only the check's own origin, and only the camera (iOS 15 and later; earlier versions ask through the system prompt)
    @available(iOS 15.0, *)
    public func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                        decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let port = origin.port == 0 ? "" : ":\(origin.port)"
        let theirs = "\(origin.protocol)://\(origin.host)\(port)".lowercased()
        decisionHandler(theirs == address?.origin && type == .camera ? .grant : .deny)
    }
}

public enum XtlLiveness {
    /// Shows the check full screen. Dismisses itself, then calls `completion` once with the result.
    public static func present(from presenter: UIViewController, checkURL: String, sdkToken: String, allowInsecureHTTP: Bool = false,
                               completion: @escaping (XtlResult) -> Void) {
        var holder: XtlCheckViewController?
        let vc = XtlCheckViewController(checkURL: checkURL, sdkToken: sdkToken, allowInsecureHTTP: allowInsecureHTTP) { result in
            holder?.dismiss(animated: true) { completion(result); holder = nil }
        }
        holder = vc
        presenter.present(vc, animated: true)
    }
}
#endif
