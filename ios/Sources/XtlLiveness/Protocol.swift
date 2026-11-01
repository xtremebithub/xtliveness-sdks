import Foundation

/// What the hosted check reports. It never carries the verdict: your server learns that from the API or the webhook.
public enum XtlResult: Equatable {
    /// The person finished the check. Ask YOUR server for the verdict (GET /v1/sessions/{sessionId}); never decide from this.
    case completed(sessionId: String)
    case cancelled
    /// code is one of: token_invalid, token_used, session_expired, session_not_open, engine_unavailable, timeout, missing_token,
    /// camera_denied, load_failed, invalid_check_address, error.
    case error(code: String)
}

public struct XtlInvalidInput: Error, Equatable, CustomStringConvertible {
    public let description: String
}

/// A parsed check address.
public struct CheckAddress: Equatable {
    public let scheme: String
    public let host: String
    public let port: String?
    public let path: String

    /// scheme://host[:port], lower case
    public var origin: String { "\(scheme)://\(host)" + (port.map { ":\($0)" } ?? "") }

    public var sessionId: String { path.split(separator: "/").last.map { $0.lowercased() } ?? "" }

    /// Where the web view is sent. The one-time token rides in the fragment: it is never sent to a server or written to a log.
    public func loadURL(sdkToken: String) throws -> URL {
        guard !sdkToken.isEmpty else { throw XtlInvalidInput(description: "sdkToken is required") }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let token = sdkToken.addingPercentEncoding(withAllowedCharacters: allowed), let url = URL(string: origin + path + "#t=" + token) else {
            throw XtlInvalidInput(description: "sdkToken cannot be used")
        }
        return url
    }
}

private let addressPattern = try! NSRegularExpression(pattern: "^(https?)://([A-Za-z0-9.-]+)(?::(\\d{1,5}))?(/check/[0-9a-fA-F-]{36})$")
private let originPattern = try! NSRegularExpression(pattern: "^(https?)://([^/?#@\\s]+)", options: [.caseInsensitive])

private func group(_ m: NSTextCheckingResult, _ i: Int, in s: String) -> String? {
    let r = m.range(at: i)
    guard r.location != NSNotFound, let range = Range(r, in: s) else { return nil }
    return String(s[range])
}

/// Checks the address your server got from POST /v1/sessions. https only; plain http for localhost, or any host with `allowInsecureHTTP`
/// (development only, never in a release). No query, no fragment, no login.
public func parseCheckURL(_ raw: String, allowInsecureHTTP: Bool = false) throws -> CheckAddress {
    let whole = NSRange(raw.startIndex..., in: raw)
    guard let m = addressPattern.firstMatch(in: raw, range: whole) else {
        let lower = raw.lowercased()
        throw XtlInvalidInput(description: lower.hasPrefix("http://") || lower.hasPrefix("https://") ? "checkUrl is not a check address" : "checkUrl must be https")
    }
    let scheme = group(m, 1, in: raw)!.lowercased()
    let host = group(m, 2, in: raw)!.lowercased()
    let local = host == "localhost" || host == "127.0.0.1"
    guard scheme == "https" || local || allowInsecureHTTP else { throw XtlInvalidInput(description: "checkUrl must be https") }
    return CheckAddress(scheme: scheme, host: host, port: group(m, 3, in: raw), path: group(m, 4, in: raw)!)
}

/// The origin of any address, or nil when it is not an http(s) address.
public func originOf(_ raw: String) -> String? {
    guard let m = originPattern.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) else { return nil }
    return group(m, 1, in: raw)!.lowercased() + "://" + group(m, 2, in: raw)!.lowercased()
}

/// Reads one message from the page's XtlBridge channel. Returns nil for anything that is not a result for this session.
public func parseMessage(_ body: Any, expectedSessionId: String) -> XtlResult? {
    let object: Any
    if let text = body as? String {
        guard let data = text.data(using: .utf8), let parsed = try? JSONSerialization.jsonObject(with: data) else { return nil }
        object = parsed
    } else {
        object = body
    }
    guard let d = object as? [String: Any], d["type"] as? String == "xtl:result",
          let session = d["sessionId"] as? String, session.lowercased() == expectedSessionId.lowercased() else { return nil }
    switch d["status"] as? String {
    case "completed": return .completed(sessionId: session)
    case "cancelled": return .cancelled
    case "error":
        let code = d["code"] as? String ?? ""
        return .error(code: code.isEmpty ? "error" : code)
    default: return nil
    }
}
