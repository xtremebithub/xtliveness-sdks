# xtliveness SDKs

One folder per SDK. All of them do the same thing: run the hosted face check with the camera and tell your app or page when the person is done. None holds an API key or decides a verdict.

| Folder | For | How it shows the check | Package |
|---|---|---|---|
| `web` | Websites, any framework, plus a React component | iframe (in your page, or a popup) | `xtliveness-web` (npm) |
| `react-native` | React Native apps (Android, iOS) | `react-native-webview` | `xtliveness-react-native` (npm) |
| `flutter` | Flutter apps on Android, iOS and the web | WebView on mobile, iframe on web | `xtliveness` (pub.dev) |
| `android` | Native Android apps (Kotlin) | `WebView` | `com.xtremebit:xtliveness` (Maven) |
| `ios` | Native iOS apps (Swift) | `WKWebView` | `XtlLiveness` (Swift Package) |

## The flow, the same everywhere
1. The app or page asks **your server** to start a check.
2. Your server calls `POST /v1/sessions` (API key, server side only) and returns `checkUrl` and `sdkToken`.
3. The SDK opens the check with those two values. The token works once and travels in the URL fragment.
4. On "completed", ask **your server** for the verdict (`GET /v1/sessions/{id}`) or wait for the webhook. The result in the app only says the check ran.

Results: `completed(sessionId)`, `cancelled`, `error(code)`. Codes: `token_invalid`, `token_used`, `session_expired`, `session_not_open`, `engine_unavailable`, `timeout`, `missing_token`, `camera_denied`, `load_failed`, `invalid_check_address`, `error`.

## How the check page talks to each SDK
The check page reports through a channel called `XtlBridge` when it is in a native web view, and through `postMessage` to its parent when it is in an iframe. Each mobile SDK creates that channel for the page (Android `addJavascriptInterface`, iOS a script message handler, React Native a small injected script), so the service needs no change for any of them.

## Spoken guidance in mobile apps
The check reads its instructions aloud and a WebView's own speech is often silent. The Flutter SDK speaks for the page with the phone's text-to-speech automatically; the React Native SDK does the same when you pass `speech` (expo-speech or react-native-tts, see its README). Both rely on the page's `xtl:speak` message. Flutter and React Native each have a demo app (`flutter/example`, `react-native/example`) with Liveness, Face search and Identity tabs.

## Websites and Flutter web
The page that shows the check must be listed under **Websites allowed to show your check** (console, Check settings) and be served over https (or be `localhost`), or the browser will refuse the frame or the camera.

## Tests
Each SDK keeps its address, token and message rules in one small file with unit tests: `web` and `react-native` (`npm test`), `flutter` (`flutter test`), `android` (`./gradlew :xtliveness:test`), `ios` (`swift test` on a Mac). CI is in `.github/workflows/sdks.yml`.

## Releasing
Raise the version in the package file, add a changelog line, then publish. The licence is BSD 3-Clause.

- **Flutter (pub.dev).** First release of the package: from `flutter/`, run `flutter pub publish --dry-run`, fix what it lists, then `flutter pub publish` (sign in with the Google account that should own the package; better, publish under a verified publisher). After that, on the package's **Admin** tab turn on *Automated publishing* from GitHub Actions (repository `xtremebithub/xtliveness-sdks`, tag pattern `flutter-v{{version}}`) and release by pushing a tag: `git tag flutter-v1.1.2 && git push origin flutter-v1.1.2`. The workflow `publish-flutter.yml` checks the tag against `pubspec.yaml`, runs analyze and tests, and publishes.
- **web and react-native (npm):** `npm publish` from the folder. **android:** Maven (the `maven-publish` block is ready). **ios:** a git tag for Swift Package Manager.
