# xtliveness for Android (Kotlin)

Runs the hosted face check in a WebView with the camera and tells your app when the person is done. The app holds no API key and no verdict: your server creates the session and reads the result.

## Flow
1. The app asks **your server** to start a check.
2. Your server calls `POST /v1/sessions` with its API key and returns `checkUrl` and `sdkToken`.
3. The app starts the check with those two values (the token works once).
4. On `Completed`, ask your server for the verdict (`GET /v1/sessions/{id}`) or use the webhook. **Never decide in the app.**

```kotlin
private val check = registerForActivityResult(XtlCheckContract()) { r ->
    when (r) {
        is XtlResult.Completed -> askYourServer(r.sessionId)
        XtlResult.Cancelled -> {}
        is XtlResult.Error -> show(r.code)      // camera_denied, session_expired, token_used, timeout, ...
    }
}
check.launch(XtlRequest(session.checkUrl, session.sdkToken))
```
To place the check inside your own layout, use `XtlCheckView` (ask for the CAMERA permission first, then `view.start(checkUrl, sdkToken) { result -> ... }`).

## Install
`minSdk 21`. Publish the library to the repository you use (the `maven-publish` block in `xtliveness/build.gradle.kts` is ready: `./gradlew :xtliveness:publishReleasePublicationToMavenLocal`), then:
```kotlin
implementation("com.xtremebit:xtliveness:1.0.0")
```
The library's manifest already adds the CAMERA and INTERNET permissions and the check screen. For development against `http://localhost` with `adb reverse tcp:8200 tcp:8200`, set `android:usesCleartextTraffic="true"` in a debug build only and pass `allowInsecureHttp = true`; the camera in a WebView works only on https or localhost.

## Safety
- Token in the URL fragment (never sent to a server or logged), used once.
- Only an https check address is accepted (http for localhost, or `allowInsecureHttp` in development).
- The WebView cannot leave the check's own origin; the camera is granted to that origin only; no file access; no cache.
- A message is believed only if it is a result for this session.

## Demo and tests
`app/` is a one-screen demo: paste a `checkUrl` and `sdkToken` and start. `./gradlew :xtliveness:test` runs the address, token and message rules (`ProtocolTest.kt`). Open the `android` folder in Android Studio to build.
