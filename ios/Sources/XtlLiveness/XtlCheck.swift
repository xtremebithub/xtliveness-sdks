#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import SwiftUI

/// The face check inside a SwiftUI screen (iOS 13 and later):
///
///     XtlCheck(checkURL: s.checkUrl, sdkToken: s.sdkToken) { result in ... }
///
/// It starts when it appears; give it its own screen or sheet (for example `.fullScreenCover`) and remove it when `onResult` runs.
public struct XtlCheck: UIViewControllerRepresentable {
    public let checkURL: String
    public let sdkToken: String
    public var allowInsecureHTTP = false
    public let onResult: (XtlResult) -> Void

    public init(checkURL: String, sdkToken: String, allowInsecureHTTP: Bool = false, onResult: @escaping (XtlResult) -> Void) {
        self.checkURL = checkURL
        self.sdkToken = sdkToken
        self.allowInsecureHTTP = allowInsecureHTTP
        self.onResult = onResult
    }

    public func makeUIViewController(context: Context) -> XtlCheckViewController {
        XtlCheckViewController(checkURL: checkURL, sdkToken: sdkToken, allowInsecureHTTP: allowInsecureHTTP, onResult: onResult)
    }

    public func updateUIViewController(_ vc: XtlCheckViewController, context: Context) {}
}
#endif
