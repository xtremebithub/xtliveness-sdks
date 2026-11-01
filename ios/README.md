# XtlLiveness for iOS (Swift)

Runs the hosted face check in a web view with the camera and tells your app when the person is done. The app holds no API key and no verdict: your server creates the session and reads the result.

## Flow
1. The app asks **your server** to start a check.
2. Your server calls `POST /v1/sessions` with its API key and returns `checkUrl` and `sdkToken`.
3. The app starts the check with those two values (the token works once).
4. On `.completed`, ask your server for the verdict (`GET /v1/sessions/{id}`) or use the webhook. **Never decide in the app.**

```swift
XtlLiveness.present(from: self, checkURL: s.checkUrl, sdkToken: s.sdkToken) { result in
    switch result {
    case .completed(let id): askYourServer(id)
    case .cancelled: break
    case .error(let code): show(code)       // camera_denied, session_expired, token_used, timeout, ...
    }
}
```
SwiftUI: `XtlCheck(checkURL:sdkToken:) { result in ... }` inside a `.fullScreenCover`. UIKit: `XtlCheckViewController` if you want to place it yourself (you dismiss it in `onResult`).

## Install
Swift Package Manager: add this package (iOS 13 or later; the camera inside a web view needs iOS 15) and import `XtlLiveness`.

`Info.plist`:
```xml
<key>NSCameraUsageDescription</key><string>We use the camera to check that it is really you.</string>
```

## Safety
- Token in the URL fragment (never sent to a server or logged), used once.
- Only an https check address is accepted (plain http for localhost; `allowInsecureHTTP` for development only).
- The web view cannot leave the check's own origin; the camera is granted to that origin only; nothing is stored between checks.
- A message is believed only if it is a result for this session.

## Demo and tests
`Example/DemoApp.swift` is a one-screen demo (setup steps are at the top of the file). `swift test` on a Mac runs the address, token and message rules (`ProtocolTests.swift`).
