# Changelog
## 1.1.1
- The check's spoken guidance and end tone can play inside the Android and iOS WebView without an extra tap.
- The app reads the check's spoken guidance with the phone's own text-to-speech (flutter_tts), because the WebView's own speech is often silent. Needs a check page that sends `xtl:speak` (the xtliveness service from this release).

## 1.1.0
- Flutter web support.

## 1.0.0

- First release: `XtlLiveness.open`, the `XtlCheckView` widget, and the `XtlCompleted` / `XtlCancelled` / `XtlError` results.
