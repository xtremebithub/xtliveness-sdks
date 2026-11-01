# xtliveness-react-native

Face liveness check for React Native apps (Android and iOS). Runs the hosted check in a WebView with the camera and tells your app when the person is done. The app holds no API key and no verdict.

## Flow
1. The app asks **your server** to start a check.
2. Your server calls `POST /v1/sessions` with its API key and returns `checkUrl` and `sdkToken`.
3. The app shows `<XtlCheck checkUrl sdkToken ... />` (the token works once).
4. On `onComplete`, ask your server for the verdict (`GET /v1/sessions/{id}`) or use the webhook. **Never decide in the app.**

```tsx
import { XtlCheck } from 'xtliveness-react-native';

<XtlCheck style={{ flex: 1 }} checkUrl={s.checkUrl} sdkToken={s.sdkToken}
  onComplete={({ sessionId }) => verifyOnServer(sessionId)} onCancel={() => nav.goBack()} onError={({ code }) => show(code)} />
```

## Install
```
npm install xtliveness-react-native react-native-webview
cd ios && pod install
```
**Android** `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
```
The component asks for the camera permission itself; a refusal gives `onError({ code: 'camera_denied' })`.

**iOS** (13 or higher; the camera in a WebView needs iOS 15), `Info.plist`:
```xml
<key>NSCameraUsageDescription</key><string>We use the camera to check that it is really you.</string>
```

## Spoken guidance (recommended)
The check reads its instructions aloud ("Move closer", "Hold still") and plays a tone at the end. Inside a WebView that speech is often silent, so let the phone speak instead: pass `speech` to `XtlCheck`.

With **expo-speech** (`npx expo install expo-speech`):
```tsx
import * as Speech from 'expo-speech';
const speech = { speak: (text: string, lang: string) => { Speech.stop(); Speech.speak(text, { language: lang }); }, stop: () => { Speech.stop(); } };

<XtlCheck speech={speech} ... />
```
With **react-native-tts**:
```tsx
import Tts from 'react-native-tts';
const speech = { speak: (text: string, lang: string) => { Tts.stop(); Tts.setDefaultLanguage(lang); Tts.speak(text); }, stop: () => { Tts.stop(); } };
```
Any object with `speak(text, lang)` (and optionally `stop()`) works. Without `speech` nothing changes: the check uses the WebView's own speech. The check page needs the xtliveness service from this release (it sends the `xtl:speak` messages).

## Demo app
`example/` is an Expo app that plays both roles (your server and your app) so you can try every kind of result: liveness with every test scenario, face match, face search, and the BVN/NIN identity checks, including matching a live person to the photo on an ID. A test key is free and needs no real photos.
```
cd example
./setup.sh          # builds the SDK above, installs, and lets Expo pick matching versions
npx expo start      # then open it in Expo Go, or press a / i for an emulator
```
To get an APK like the Flutter demo: `./setup.sh apk` builds one on your computer (needs JDK 17 and the Android SDK), or `npx eas-cli build -p android --profile preview` builds it in Expo's cloud (free Expo account) and gives a download link.

Use a physical phone for the camera check (emulator cameras are unreliable). To reach a service on your own computer, use its LAN address (or `http://10.0.2.2:PORT` from the Android emulator); the demo allows plain http only for development. In a real app your server holds the API key; the demo does not.

## Safety
- The token travels in the URL fragment and works once.
- Only an https check address is accepted (plain http for localhost; `allowInsecureHttp` for development only).
- The WebView cannot leave the check's own origin, runs without cache or stored cookies.

## Errors (`code`)
`token_invalid`, `token_used`, `session_expired`, `session_not_open`, `engine_unavailable`, `timeout`, `missing_token`, `camera_denied`, `load_failed`, `invalid_check_address`, `error`.

## Tests
`npm test` runs the address, token, message and speech-request rules. The component itself needs a device or emulator.

## Metro and the `dist` folder
The package loads its compiled files (`dist`, built when the package is made). If you work on the SDK from a clone, run `npm run build` first.
