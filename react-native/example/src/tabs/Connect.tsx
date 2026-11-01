import * as React from 'react';
import { Text, View } from 'react-native';

import { type Conn, useConn } from '../conn';
import { Btn, Field, KeyBadge, Note, Screen, Section, brand, good, ink, muted, warn, type Tone } from '../ui';

/** Step one: where the service is and which key to use. Nothing else works without a key. */
export function ConnectTab({ conn }: { conn: Conn }): React.ReactElement {
  useConn(conn);
  const [testing, setTesting] = React.useState(false);
  const [status, setStatus] = React.useState<{ text: string; tone: Tone } | null>(null);

  const test = async () => {
    if (!conn.hasKey) { setStatus({ text: 'Paste a key that starts with xtl_test_ or xtl_live_.', tone: 'warn' }); return; }
    setTesting(true); setStatus(null);
    // any answer other than "key not accepted" shows the address and the key are right
    const r = await conn.send('GET', '/v1/usage');
    setTesting(false);
    if (r.status === 0) setStatus({ text: String(r.body?.message ?? 'No answer from the service.'), tone: 'bad' });
    else if (r.status === 401) setStatus({ text: 'The service is there, but it does not accept this key.', tone: 'bad' });
    else setStatus({ text: `Connected. The service accepts this ${conn.isTest ? 'test' : 'live'} key.`, tone: 'good' });
  };

  return (
    <Screen>
      <View style={{ backgroundColor: brand, borderRadius: 20, padding: 20, marginBottom: 14 }}>
        <Text style={{ color: '#fff', fontSize: 22, fontWeight: '800' }}>Try every check</Text>
        <Text style={{ color: '#d7ece9', marginTop: 6, lineHeight: 20 }}>Liveness, face match, face search and Nigerian ID checks. Connect once, then use the tabs below.</Text>
      </View>
      <Section title="Connect" subtitle="Paste your API key. Nothing is saved: it is forgotten when you close the app.">
        <Field label="Service address" value={conn.base} onChangeText={(v) => conn.set({ base: v })} keyboardType="url" />
        <Field label="API key" value={conn.key} onChangeText={(v) => conn.set({ key: v })} placeholder="xtl_test_…" secureTextEntry autoComplete="off" />
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
          <KeyBadge conn={conn} />
          <View style={{ minWidth: 150 }}><Btn label="Test connection" onPress={test} busy={testing} /></View>
        </View>
        {status ? <Note tone={status.tone}>{status.text}</Note> : null}
        {conn.insecure ? <Note tone="warn">This address is plain http. That is fine for a service on your own computer (for example http://10.0.2.2:8200 from the Android emulator), never for a real key.</Note> : null}
      </Section>
      <Section title="Test or live?">
        <View><Text style={{ color: good, fontWeight: '700' }}>Test key (xtl_test_…)</Text><Text style={{ color: muted }}>Free. No real photos or ID numbers needed: the demo uses built-in sample faces and made-up people.</Text></View>
        <View><Text style={{ color: warn, fontWeight: '700' }}>Live key (xtl_live_…)</Text><Text style={{ color: muted }}>Real checks, billed to the account. You will be asked before each one, and you must choose real photos.</Text></View>
      </Section>
      <Section title="About this demo">
        <Text style={{ color: ink, lineHeight: 20 }}>In a real app, your server holds the API key and talks to the service; the app only shows the check. This demo does both from the phone so you can see every result in one place. Never ship a key inside an app.</Text>
      </Section>
    </Screen>
  );
}
