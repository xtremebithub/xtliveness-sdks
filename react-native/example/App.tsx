// A demo that plays both roles so you can try every kind of result from one app:
//   * YOUR SERVER: it calls the xtliveness API with an API key. In a real app this part lives on your backend, never in the app.
//   * YOUR APP: it shows the check with the SDK (<XtlCheck>) and then asks for the verdict.
// A TEST key (xtl_test_...) is free and needs no real photos. A LIVE key (xtl_live_...) runs real, billed checks.
import * as React from 'react';
import { Image, Pressable, SafeAreaView, Text, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';

import { CheckProvider } from './src/check';
import { Conn, useConn } from './src/conn';
import { ConnectTab } from './src/tabs/Connect';
import { IdentityTab } from './src/tabs/Identity';
import { LivenessTab } from './src/tabs/Liveness';
import { SearchTab } from './src/tabs/Search';
import { KeyBadge, brand, ink, line, muted, page } from './src/ui';

const TABS = ['Connect', 'Liveness', 'Face search', 'Identity'] as const;
const ICONS = ['🔗', '🙂', '👥', '🪪'];

export default function App(): React.ReactElement {
  const conn = React.useRef(new Conn()).current;
  useConn(conn);
  const [tab, setTab] = React.useState(0);
  const goConnect = () => setTab(0);
  // every tab stays mounted, so what was typed and the last answer are still there when you come back
  const show = (i: number) => ({ flex: 1, display: tab === i ? ('flex' as const) : ('none' as const) });

  return (
    <CheckProvider>
      <SafeAreaView style={{ flex: 1, backgroundColor: page }}>
        <StatusBar style="dark" />
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 14, paddingVertical: 10, backgroundColor: '#fff', borderBottomWidth: 1, borderBottomColor: line }}>
          <Image source={require('./assets/icon.png')} style={{ width: 32, height: 32, borderRadius: 8 }} />
          <Text style={{ flex: 1, fontSize: 20, fontWeight: '800', color: ink }}>{TABS[tab]}</Text>
          <KeyBadge conn={conn} />
        </View>
        <View style={show(0)}><ConnectTab conn={conn} /></View>
        <View style={show(1)}><LivenessTab conn={conn} goConnect={goConnect} /></View>
        <View style={show(2)}><SearchTab conn={conn} goConnect={goConnect} /></View>
        <View style={show(3)}><IdentityTab conn={conn} goConnect={goConnect} /></View>
        <View style={{ flexDirection: 'row', backgroundColor: '#fff', borderTopWidth: 1, borderTopColor: line }}>
          {TABS.map((t, i) => (
            <Pressable key={t} accessibilityRole="tab" accessibilityState={{ selected: tab === i }} onPress={() => setTab(i)} style={{ flex: 1, alignItems: 'center', paddingVertical: 8 }}>
              <Text style={{ fontSize: 20, opacity: tab === i ? 1 : 0.5 }}>{ICONS[i]}</Text>
              <Text style={{ fontSize: 11, fontWeight: '700', color: tab === i ? brand : muted }}>{t}</Text>
            </Pressable>
          ))}
        </View>
      </SafeAreaView>
    </CheckProvider>
  );
}
