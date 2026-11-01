// Shows the check full screen and tells the caller how it ended. In your own app you would put <XtlCheck> in a screen of your navigator.
import * as React from 'react';
import { Modal, Pressable, SafeAreaView, Text, View } from 'react-native';
import * as Speech from 'expo-speech';
import { XtlCheck, type XtlSpeech } from 'xtliveness-react-native';

import { isOk, mapOf, withNote, type ApiResult, type Conn } from './conn';
import { ink, line } from './ui';

export type Outcome = { status: 'completed'; sessionId: string } | { status: 'cancelled' } | { status: 'error'; code: string };
type Open = (o: { checkUrl: string; sdkToken: string; allowInsecureHttp: boolean }) => Promise<Outcome>;

const Ctx = React.createContext<Open>(() => Promise.resolve({ status: 'cancelled' }));
export const useOpenCheck = (): Open => React.useContext(Ctx);

// The check page asks the app to read its instructions aloud: the phone's own speech is far more reliable than the WebView's.
const speech: XtlSpeech = {
  speak: (text, lang) => { Speech.stop(); Speech.speak(text, { language: lang, rate: 0.95 }); },
  stop: () => { Speech.stop(); },
};

export function CheckProvider({ children }: { children: React.ReactNode }): React.ReactElement {
  const [req, setReq] = React.useState<{ checkUrl: string; sdkToken: string; allowInsecureHttp: boolean; resolve: (o: Outcome) => void } | null>(null);
  const open = React.useCallback<Open>((o) => new Promise<Outcome>((resolve) => setReq({ ...o, resolve })), []);
  const end = (o: Outcome) => { req?.resolve(o); setReq(null); };
  return (
    <Ctx.Provider value={open}>
      {children}
      <Modal visible={!!req} animationType="slide" onRequestClose={() => end({ status: 'cancelled' })}>
        <SafeAreaView style={{ flex: 1, backgroundColor: '#fff' }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: 12, borderBottomWidth: 1, borderBottomColor: line }}>
            <Text style={{ fontWeight: '800', fontSize: 16, color: ink }}>Face check</Text>
            <Pressable accessibilityRole="button" onPress={() => end({ status: 'cancelled' })}><Text style={{ color: '#0F766E', fontWeight: '700' }}>Cancel</Text></Pressable>
          </View>
          {req ? (
            <XtlCheck key={req.sdkToken} style={{ flex: 1 }} checkUrl={req.checkUrl} sdkToken={req.sdkToken} allowInsecureHttp={req.allowInsecureHttp} speech={speech}
              onComplete={({ sessionId }) => end({ status: 'completed', sessionId })} onCancel={() => end({ status: 'cancelled' })} onError={({ code }) => end({ status: 'error', code })} />
          ) : null}
        </SafeAreaView>
      </Modal>
    </Ctx.Provider>
  );
}

/**
 * The whole liveness flow, as a real app does it: (1) YOUR SERVER starts a session, (2) the APP shows the check with the one-time token,
 * (3) YOUR SERVER reads the verdict. The demo plays both roles. The verdict is never taken from the app's own result.
 */
export async function runLiveCheck(conn: Conn, open: Open, body: Record<string, unknown>, finished: string): Promise<ApiResult> {
  const created = await conn.send('POST', '/v1/sessions', body);
  if (!isOk(created)) return created;
  const d = mapOf(created);
  // the service builds checkUrl from its own setting; point it at the address this phone really uses
  const path = /^https?:\/\/[^/]+(\/.*)$/.exec(String(d.checkUrl))?.[1] ?? '';
  const r = await open({ checkUrl: conn.url(path), sdkToken: String(d.sdkToken), allowInsecureHttp: conn.insecure });
  const note = r.status === 'completed' ? finished : r.status === 'cancelled' ? 'The person cancelled.' : `The check reported an error: ${r.code}`;
  return withNote(await conn.send('GET', `/v1/sessions/${d.sessionId}`), note, null);
}
