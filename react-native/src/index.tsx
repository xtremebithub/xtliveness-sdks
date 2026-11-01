/**
 * xtliveness for React Native (Android and iOS). Your server creates the session and returns checkUrl and sdkToken; the app never holds an API key.
 *
 *   <XtlCheck checkUrl={s.checkUrl} sdkToken={s.sdkToken}
 *             onComplete={({ sessionId }) => askYourServer(sessionId)} onCancel={...} onError={({ code }) => ...} />
 *
 * "Completed" only means the check ran. The verdict comes from your server (GET /v1/sessions/{id}) or your webhook; never decide in the app.
 */
import * as React from 'react';
import { ActivityIndicator, PermissionsAndroid, Platform, View, type StyleProp, type ViewStyle } from 'react-native';
import { WebView, type WebViewMessageEvent } from 'react-native-webview';
import { frameUrl, originOf, parseCheckUrl, parseMessage, parseSpeak, sessionIdOf, type XtlResult, type XtlSpeech } from './protocol.js';

export { parseCheckUrl, parseMessage, parseSpeak, frameUrl, sessionIdOf };
export type { XtlResult, XtlSpeech };

export interface XtlCheckProps {
  checkUrl: string;
  sdkToken: string;
  onComplete?: (r: { sessionId: string }) => void;
  onCancel?: () => void;
  /** code is one of: token_invalid, token_used, session_expired, session_not_open, engine_unavailable, timeout, missing_token, camera_denied, load_failed, invalid_check_address, error. */
  onError?: (e: { code: string }) => void;
  /** Development only: accept plain http on any host. Never in a release build. */
  allowInsecureHttp?: boolean;
  /**
   * Reads the check's instructions aloud with the phone's own speech (the WebView's speech is often silent). Give it expo-speech or react-native-tts
   * (see the README). Without it the check uses the WebView's own speech.
   */
  speech?: XtlSpeech;
  style?: StyleProp<ViewStyle>;
}

// The check page reports through a channel called XtlBridge. React Native's WebView offers window.ReactNativeWebView, so the channel is made
// before the page loads and forwards to it.
const BRIDGE = `(function(){window.XtlBridge={postMessage:function(m){window.ReactNativeWebView.postMessage(m);}};true;})();`;
// the same, and it tells the page that the app reads its instructions aloud
const BRIDGE_WITH_SPEECH = `(function(){window.XtlBridge={postMessage:function(m){window.ReactNativeWebView.postMessage(m);}};window.xtlNativeSpeech=true;true;})();`;

async function askCamera(): Promise<boolean> {
  if (Platform.OS !== 'android') return true;   // iOS asks by itself, using NSCameraUsageDescription
  const r = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.CAMERA);
  return r === PermissionsAndroid.RESULTS.GRANTED;
}

export function XtlCheck({ checkUrl, sdkToken, onComplete, onCancel, onError, allowInsecureHttp, speech, style }: XtlCheckProps): React.ReactElement {
  const callbacks = React.useRef({ onComplete, onCancel, onError });
  callbacks.current = { onComplete, onCancel, onError };
  const done = React.useRef(false);
  const voice = React.useRef(speech);
  voice.current = speech;

  const parsed = React.useMemo(() => {
    try {
      const url = parseCheckUrl(checkUrl, { allowInsecureHttp });
      return { origin: url.origin, uri: frameUrl(url, sdkToken), session: sessionIdOf(url) };
    } catch {
      return null;
    }
  }, [checkUrl, sdkToken, allowInsecureHttp]);

  React.useEffect(() => () => { try { voice.current?.stop?.(); } catch { /* ignore */ } }, []);

  const [camera, setCamera] = React.useState<'asking' | 'granted' | 'denied'>('asking');

  const finish = React.useCallback((r: XtlResult) => {
    if (done.current) return;
    done.current = true;
    try { voice.current?.stop?.(); } catch { /* the check result matters more than the voice */ }
    if (r.status === 'completed') callbacks.current.onComplete?.({ sessionId: r.sessionId });
    else if (r.status === 'cancelled') callbacks.current.onCancel?.();
    else callbacks.current.onError?.({ code: r.code });
  }, []);

  React.useEffect(() => {
    done.current = false;
    if (!parsed) { finish({ status: 'error', code: 'invalid_check_address' }); return undefined; }
    let alive = true;
    askCamera().then((ok) => {
      if (!alive) return;
      if (ok) setCamera('granted');
      else { setCamera('denied'); finish({ status: 'error', code: 'camera_denied' }); }
    }, () => { if (alive) { setCamera('denied'); finish({ status: 'error', code: 'camera_denied' }); } });
    return () => { alive = false; };
  }, [parsed, finish]);

  const onMessage = React.useCallback((e: WebViewMessageEvent) => {
    if (!parsed) return;
    let data: unknown;
    try { data = JSON.parse(e.nativeEvent.data); } catch { return; }
    const say = parseSpeak(data);
    if (say) {
      if (voice.current && !done.current) {
        try { voice.current.stop?.(); if (say.text) voice.current.speak(say.text, say.lang); } catch { /* the check still works without a voice */ }
      }
      return;
    }
    const r = parseMessage(data, parsed.session);
    if (r) finish(r);
  }, [parsed, finish]);

  if (!parsed || camera !== 'granted') {
    return React.createElement(View, { style: [{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#fff' }, style] }, camera === 'asking' && parsed ? React.createElement(ActivityIndicator, null) : null);
  }
  return React.createElement(WebView, {
    style,
    source: { uri: parsed.uri },
    originWhitelist: [parsed.origin + '/*'],
    javaScriptEnabled: true,
    injectedJavaScriptBeforeContentLoaded: speech ? BRIDGE_WITH_SPEECH : BRIDGE,
    onMessage,
    // the page stays on the check's own address; anything else is refused
    onShouldStartLoadWithRequest: (req: { url: string }) => originOf(req.url) === parsed.origin,
    onError: () => finish({ status: 'error', code: 'load_failed' }),
    onHttpError: () => finish({ status: 'error', code: 'load_failed' }),
    mediaCapturePermissionGrantType: 'grant',
    allowsInlineMediaPlayback: true,
    mediaPlaybackRequiresUserAction: false,
    setSupportMultipleWindows: false,
    cacheEnabled: false,
    incognito: true,
  });
}
