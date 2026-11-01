# xtliveness for Flutter

Opens the hosted face check (a WebView on Android and iOS, an iframe on the web) with the camera and tells your app when the person has finished. The app holds no API key and no verdict: your server creates the session and reads the result.

## Flow
1. Your app asks **your server** to start a check.
2. Your server calls `POST /v1/sessions` with its API key and returns `checkUrl` and `sdkToken` to the app.
3. The app calls `XtlLiveness.open(context, checkUrl: ..., sdkToken: ...)`.
4. On `XtlCompleted`, the app asks your server for the verdict (`GET /v1/sessions/{id}`), or your server learns it from the webhook. Never decide from the app's result.

```dart
final r = await XtlLiveness.open(context, checkUrl: s.checkUrl, sdkToken: s.sdkToken);
switch (r) {
  case XtlCompleted(:final sessionId): /* ask your server */
  case XtlCancelled(): break;
  case XtlError(:final code): /* camera_denied, session_expired, token_used, timeout, ... */
}
```

To place the check inside your own screen instead of a full-screen page, use the `XtlCheckView` widget (`checkUrl`, `sdkToken`, `onResult`).

## Platforms
- **Android and iOS**: a WebView; the app asks for the camera first.
- **Flutter web**: an iframe in the page; the browser asks the person for the camera. The page must be served over https (or be `localhost`), and its address (for example `https://app.example.com`, no path) must be listed under **Websites allowed to show your check** in the console, or the browser will refuse to show the check. Run the example with `flutter run -d chrome`.
- Desktop apps (Windows, macOS, Linux): not supported; `XtlLiveness.open` returns `XtlError('unsupported_platform')`.

## Install
```
flutter pub add xtliveness
```

**Android** (`android/app/build.gradle`: `minSdk 21` or higher), `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-feature android:name="android.hardware.camera.front" android:required="false"/>
<queries><intent><action android:name="android.intent.action.TTS_SERVICE"/></intent></queries>   <!-- lets the app find the phone's speech engine -->
```
**iOS** (13 or higher; the camera in a WebView needs iOS 15), `Info.plist`:
```xml
<key>NSCameraUsageDescription</key><string>We use the camera to check that it is really you.</string>
```
For `permission_handler` on iOS add this to the `Podfile` `post_install` block: `'PERMISSION_CAMERA=1'` in `GCC_PREPROCESSOR_DEFINITIONS` (see the permission_handler README).

## Safety
- The token travels in the URL fragment (not sent to any server or logged) and can be used once; a second start returns `token_used`.
- Only an https check address is accepted. Plain http is allowed for localhost, or any host when you pass `allowInsecureHttp: true` (development only).
- The WebView cannot leave the check's own address.
- Test keys give test sessions (use `scenario` in `POST /v1/sessions`), so the flow can be tried without AWS.

## Tests
`flutter test` runs the address, token and message rules (`test/protocol_test.dart`).

## Publishing (for the maintainers)
1. Check the addresses in `pubspec.yaml` (homepage, repository, issue tracker, documentation): they appear on the package page and cannot be changed for a version already published.
2. `flutter pub get && flutter analyze && flutter test`
3. `flutter pub publish --dry-run` and fix anything it reports.
4. `flutter pub publish`. Publish under a verified publisher (pub.dev, Create publisher, your domain), then transfer the package to it.
5. For each release, raise `version` and add a `CHANGELOG.md` entry. A published version can never be changed or reused.

## Trying every result
`example/` is a demo that plays your server and your app at once, so you can try every kind of result in one app. It has four tabs: **Connect** (service address, API key, a test-connection button, and a badge that says whether the key is a free test key or a billed live key), **Liveness** (the camera check with a scenario picker, optional reference photos, and face match on its own), **Face search** (a numbered walk-through, a liveness check followed by a search or enrolment, and clean-up) and **Identity** (BVN or NIN: validate, look up with the ID photo, match a selfie to the ID photo, and match a live person to it). The Identity tab also shows the two things a real integration needs: the person's consent, sent with every call (live calls are refused without it), and an optional `Idempotency-Key`, so a repeated tap gives the same answer and is not billed twice. Each answer shows as a result card with the facts that matter and the full reply underneath. A **test** key needs no real photos or ID numbers; a **live** key asks before every billed call. In a real app the server calls stay on your backend, because they need your API key.

```
cd example
./setup.sh            # once: adds android/ios/web, the camera permissions and the Podfile setting, then fetches packages
flutter run -d <phone or emulator>
./setup.sh apk        # or: builds small per-architecture APKs in example/build/app/outputs/flutter-apk/; install app-arm64-v8a-release.apk (almost every phone)
```
It talks to `https://liveness.xtremebithub.com` by default. Override at build time: `--dart-define=XTL_BASE=http://localhost:8200 --dart-define=XTL_KEY=xtl_test_...`.
On the **Face search** tab (switch it on for the account first) a **test** key uses two simulated people, so you can run the whole flow with no photos: create a collection, enroll "ann" as Person A, search as Person A (found, score 96) and as Person B (nobody), authenticate Person B as "ann" (no match), then run the check after liveness in the mode you want. With a **live** key it uses the real photo you choose: enroll a clear photo of yourself, then search or authenticate with a second photo of you, and with someone else's to see no match. On the **Identity** tab (the Identity product must be on the account) a test key treats any 11 digits as a made-up person (a number ending 0000 is not found) and the photo on every test ID is Person A; a live key does real, billed lookups, so use it only with a person's agreement. `setup.sh` also sets the launcher icon and web favicon from `example/assets/icon.png`.

On the web the demo's calls to the service run in the browser, so the service must allow cross-origin requests from the demo's address; if it does not, run the demo on Android or iOS (a real app calls its own server, which has no such limit).

For a service on your own computer, run `adb reverse tcp:8200 tcp:8200` and use `http://localhost:8200`. It must be localhost (or https): the WebView only allows the camera on a secure address, which `http://10.0.2.2:8200` or a network address is not. The demo accepts plain http only because it is a demo: pass `allowInsecureHttp: true` yourself for development, never in a release.
