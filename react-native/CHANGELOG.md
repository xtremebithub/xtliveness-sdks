# Changelog
## 1.1.0
- The app can read the check's spoken guidance aloud with the phone's own speech: pass `speech` (expo-speech or react-native-tts, see the README) to `XtlCheck`. The WebView's own speech is often silent. Needs a check page that sends `xtl:speak` (the xtliveness service from this release). Without `speech` nothing changes.
- The package now loads its compiled files (`dist`) in React Native, so Metro no longer has to resolve TypeScript `.js` import names.
- A demo app (`example/`, Expo) with Liveness, Face search and Identity tabs, the same as the Flutter demo.

## 1.0.0
- First release: the `XtlCheck` component and the address, token and message rules.
