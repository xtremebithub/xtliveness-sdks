import * as React from 'react';
import { ActivityIndicator, Alert, Image, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View, type TextInputProps, type ViewStyle } from 'react-native';
import * as Clipboard from 'expo-clipboard';
import * as ImageManipulator from 'expo-image-manipulator';
import * as ImagePicker from 'expo-image-picker';

import { ApiProblem, local, isOk, mapOf, pretty, problemOf, type ApiResult, type Conn, type Photo } from './conn';

export const brand = '#0F766E', good = '#15803D', bad = '#B91C1C', warn = '#B45309', ink = '#10201f', muted = '#5b6b6a', line = '#d9e2e1', page = '#F6F8F8';

export type Tone = 'plain' | 'good' | 'bad' | 'warn';
export const toneColor = (t: Tone): string => (t === 'good' ? good : t === 'bad' ? bad : t === 'warn' ? warn : ink);
export interface Fact { label: string; value: string; tone?: Tone }
export const score = (v: unknown): string => (typeof v === 'number' ? v.toFixed(1) : '—');

// ------------------------------------------------------------------------------------------------------------------- building blocks
export function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }): React.ReactElement {
  return (
    <View style={s.card}>
      <Text style={s.h2}>{title}</Text>
      {subtitle ? <Text style={s.sub}>{subtitle}</Text> : null}
      <View style={{ gap: 12, marginTop: 12 }}>{children}</View>
    </View>
  );
}

export function Btn({ label, onPress, disabled, kind = 'primary', busy }: { label: string; onPress: () => void; disabled?: boolean; kind?: 'primary' | 'tonal' | 'outline' | 'danger'; busy?: boolean }): React.ReactElement {
  const off = disabled || busy;
  const bg = kind === 'primary' ? brand : kind === 'tonal' ? '#d7ece9' : 'transparent';
  const fg = kind === 'primary' ? '#fff' : kind === 'danger' ? bad : brand;
  return (
    <Pressable accessibilityRole="button" accessibilityState={{ disabled: !!off, busy: !!busy }} onPress={off ? undefined : onPress}
      style={({ pressed }) => [s.btn, { backgroundColor: bg, borderColor: kind === 'outline' || kind === 'danger' ? (kind === 'danger' ? bad : line) : bg, opacity: off ? 0.5 : pressed ? 0.85 : 1 }]}>
      {busy ? <ActivityIndicator color={fg} size="small" /> : null}
      <Text style={[s.btnText, { color: fg }]}>{label}</Text>
    </Pressable>
  );
}

export function Field({ label, helper, ...p }: { label: string; helper?: string } & TextInputProps): React.ReactElement {
  return (
    <View>
      <Text style={s.label}>{label}</Text>
      <TextInput {...p} placeholderTextColor="#94a3a2" autoCapitalize="none" autoCorrect={false} style={s.input} />
      {helper ? <Text style={s.hint}>{helper}</Text> : null}
    </View>
  );
}

export function Segmented<T extends string>({ value, options, onChange }: { value: T; options: [T, string][]; onChange: (v: T) => void }): React.ReactElement {
  return (
    <View style={s.seg}>
      {options.map(([v, label]) => (
        <Pressable key={v} accessibilityRole="button" accessibilityState={{ selected: v === value }} onPress={() => onChange(v)} style={[s.segItem, v === value && { backgroundColor: brand }]}>
          <Text style={[s.segText, v === value && { color: '#fff' }]}>{label}</Text>
        </Pressable>
      ))}
    </View>
  );
}

export function Chips<T extends string>({ value, options, onChange }: { value: T; options: T[]; onChange: (v: T) => void }): React.ReactElement {
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
      {options.map((v) => (
        <Pressable key={v} accessibilityRole="button" accessibilityState={{ selected: v === value }} onPress={() => onChange(v)} style={[s.chip, v === value && { backgroundColor: '#d7ece9', borderColor: brand }]}>
          <Text style={{ color: v === value ? brand : ink, fontWeight: '600' }}>{v}</Text>
        </Pressable>
      ))}
    </View>
  );
}

export function Toggle({ title, text, value, onChange }: { title: string; text?: string; value: boolean; onChange: (v: boolean) => void }): React.ReactElement {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
      <View style={{ flex: 1 }}>
        <Text style={{ color: ink, fontSize: 15, fontWeight: '600' }}>{title}</Text>
        {text ? <Text style={s.hint}>{text}</Text> : null}
      </View>
      <Switch value={value} onValueChange={onChange} trackColor={{ true: brand, false: '#cbd5d4' }} />
    </View>
  );
}

export function Note({ children, tone = 'plain' }: { children: React.ReactNode; tone?: Tone }): React.ReactElement {
  return <Text style={{ color: tone === 'plain' ? muted : toneColor(tone), fontSize: 13, lineHeight: 18 }}>{children}</Text>;
}

export function StepRow({ n, title, text, onPress, disabled }: { n: string; title: string; text: string; onPress: () => void; disabled?: boolean }): React.ReactElement {
  return (
    <Pressable accessibilityRole="button" onPress={disabled ? undefined : onPress} style={[s.step, disabled && { opacity: 0.5 }]}>
      <View style={s.stepNo}><Text style={{ color: '#fff', fontWeight: '800' }}>{n}</Text></View>
      <View style={{ flex: 1 }}>
        <Text style={{ color: ink, fontWeight: '700' }}>{title}</Text>
        <Text style={s.hint}>{text}</Text>
      </View>
    </Pressable>
  );
}

export function KeyBadge({ conn }: { conn: Conn }): React.ReactElement {
  const [text, color] = conn.isTest ? ['TEST key · free', good] : conn.isLive ? ['LIVE key · billed', warn] : ['No key yet', '#8a9998'];
  return <View style={[s.badge, { borderColor: color }]}><Text style={{ color, fontWeight: '700', fontSize: 12 }}>{text}</Text></View>;
}

/** Shown at the top of a tab until a key is pasted. */
export function NeedKey({ conn, goConnect }: { conn: Conn; goConnect: () => void }): React.ReactElement | null {
  if (conn.hasKey) return null;
  return (
    <View style={[s.card, { backgroundColor: '#fdf1dc', borderColor: '#f0d79b' }]}>
      <Text style={s.h2}>Add an API key first</Text>
      <Text style={s.sub}>A test key (xtl_test_…) is free and needs no real photos.</Text>
      <View style={{ marginTop: 10 }}><Btn label="Add key" kind="tonal" onPress={goConnect} /></View>
    </View>
  );
}

// ------------------------------------------------------------------------------------------------------------------------ photos
/** Resized to at most 1600 px wide and sent as JPEG: a phone photo is far larger than the service accepts. */
async function pick(source: 'library' | 'camera'): Promise<Photo | null> {
  const perm = source === 'camera' ? await ImagePicker.requestCameraPermissionsAsync() : await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!perm.granted) throw new ApiProblem(source === 'camera' ? 'The camera is not allowed for this app.' : 'Photos are not allowed for this app.');
  const opts = { mediaTypes: ['images'] as any, quality: 0.9, cameraType: ImagePicker.CameraType.front };
  const r = source === 'camera' ? await ImagePicker.launchCameraAsync(opts) : await ImagePicker.launchImageLibraryAsync(opts);
  if (r.canceled || !r.assets?.length) return null;
  const a = r.assets[0];
  const out = await ImageManipulator.manipulateAsync(a.uri, a.width > 1600 ? [{ resize: { width: 1600 } }] : [], { compress: 0.85, format: ImageManipulator.SaveFormat.JPEG, base64: true });
  if (!out.base64) throw new ApiProblem('Could not read the photo.');
  return { base64: out.base64, name: a.fileName || 'photo.jpg' };
}

export function PhotoTile({ label, photo, camera, sample, onPicked, onClear }: { label: string; photo: Photo | null; camera?: boolean; sample?: string | null; onPicked: (p: Photo) => void; onClear: () => void }): React.ReactElement {
  const get = async (src: 'library' | 'camera') => {
    try { const p = await pick(src); if (p) onPicked(p); } catch (e) { Alert.alert('Could not get the photo', String((e as Error).message || e)); }
  };
  return (
    <View style={s.photo}>
      <View style={s.thumb}>
        {photo ? <Image source={{ uri: 'data:image/jpeg;base64,' + photo.base64 }} style={{ width: 64, height: 64 }} resizeMode="cover" /> : <Text style={{ fontSize: 26 }}>🙂</Text>}
      </View>
      <View style={{ flex: 1 }}>
        <Text style={{ color: ink, fontWeight: '600' }}>{label}</Text>
        <Text style={s.hint} numberOfLines={2}>{photo ? photo.name : sample ? `Using the built-in sample (${sample}) with a test key` : 'Nothing chosen'}</Text>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 14, marginTop: 4 }}>
          <Pressable accessibilityRole="button" onPress={() => get('library')}><Text style={s.link}>Choose</Text></Pressable>
          {camera ? <Pressable accessibilityRole="button" onPress={() => get('camera')}><Text style={s.link}>Camera</Text></Pressable> : null}
          {photo ? <Pressable accessibilityRole="button" onPress={onClear}><Text style={s.link}>Remove</Text></Pressable> : null}
        </View>
      </View>
    </View>
  );
}

// ----------------------------------------------------------------------------------------------------------------------- results
/** The answer to the last call: a headline, the facts that matter, and the full reply underneath. */
export function ResultPanel({ title, result, facts }: { title: string; result: ApiResult; facts: Fact[] }): React.ReactElement {
  const [open, setOpen] = React.useState(false);
  const ok = isOk(result);
  const c = ok ? good : bad;
  const photo = ok ? mapOf(result).photo : null;
  return (
    <View style={[s.card, { borderColor: c, backgroundColor: ok ? '#eef8f1' : '#fdf0f0' }]}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
        <Text style={{ color: c, fontSize: 18 }}>{ok ? '✔' : '✖'}</Text>
        <Text style={[s.h2, { flex: 1 }]}>{title}</Text>
        {result.status > 0 ? <Text style={{ color: c, fontWeight: '700' }}>{result.status}</Text> : null}
      </View>
      {result.note ? <Text style={{ color: ink, marginTop: 6 }}>{result.note}</Text> : null}
      {!ok ? <Text style={{ color: c, fontWeight: '600', marginTop: 8 }}>{problemOf(result)}</Text> : null}
      {typeof photo === 'string' ? (
        <View style={{ marginTop: 10 }}>
          <Image source={{ uri: 'data:image/jpeg;base64,' + photo }} style={{ width: 110, height: 140, borderRadius: 12 }} resizeMode="cover" />
          <Text style={s.hint}>Photo on the ID</Text>
        </View>
      ) : null}
      {ok && facts.length ? (
        <View style={{ marginTop: 10, gap: 6 }}>
          {facts.map((f, i) => (
            <View key={i} style={{ flexDirection: 'row', gap: 8 }}>
              <Text style={{ width: 116, color: muted }}>{f.label}</Text>
              <Text style={{ flex: 1, fontWeight: '700', color: toneColor(f.tone ?? 'plain') }}>{f.value}</Text>
            </View>
          ))}
        </View>
      ) : null}
      <Pressable accessibilityRole="button" onPress={() => setOpen(!open)} style={{ marginTop: 12 }}>
        <Text style={{ color: ink }}>{open ? '▾' : '▸'} Full reply{result.request ? ' · ' + result.request : ''}</Text>
      </Pressable>
      {open ? (
        <View style={{ marginTop: 8 }}>
          <View style={s.code}><Text selectable style={{ fontFamily: 'Courier', fontSize: 12, color: ink }}>{pretty(result)}</Text></View>
          <Pressable accessibilityRole="button" onPress={() => { Clipboard.setStringAsync(pretty(result)).then(() => Alert.alert('Copied')); }} style={{ alignSelf: 'flex-end', marginTop: 6 }}><Text style={s.link}>Copy</Text></Pressable>
        </View>
      ) : null}
    </View>
  );
}

/** Ask before anything that is billed. Test keys never ask. */
export function confirmLive(): Promise<boolean> {
  return new Promise((resolve) => {
    Alert.alert('This uses a live key', 'It runs a real check and is billed to the account. Use a test key to try things for free.',
      [{ text: 'Cancel', style: 'cancel', onPress: () => resolve(false) }, { text: 'Run it', onPress: () => resolve(true) }], { cancelable: true, onDismiss: () => resolve(false) });
  });
}

/** What every tab does when a button is pressed: check the key, ask if billed, show progress, keep the answer, scroll to it. */
export function useRunner(conn: Conn) {
  const [busy, setBusy] = React.useState(false);
  const [shown, setShown] = React.useState<{ title: string; result: ApiResult; facts: Fact[] } | null>(null);
  const scroll = React.useRef<ScrollView>(null);
  const toScroll = React.useRef(false);
  const alive = React.useRef(true);
  React.useEffect(() => () => { alive.current = false; }, []);

  const run = React.useCallback(async (title: string, job: () => Promise<ApiResult>, summary: (r: ApiResult) => Fact[], billed = true) => {
    if (!conn.hasKey) { Alert.alert('Add an API key on the Connect tab first.'); return; }
    if (billed && conn.isLive && !(await confirmLive())) return;
    setBusy(true);
    let r: ApiResult;
    try { r = await job(); } catch (e) { r = local(e instanceof ApiProblem ? e.message : `Something went wrong: ${String(e)}`); }
    if (!alive.current) return;
    toScroll.current = true;
    setBusy(false);
    setShown({ title, result: r, facts: isOk(r) ? summary(r) : [] });
  }, [conn]);

  const view = (
    <>
      {busy ? <ActivityIndicator color={brand} style={{ marginBottom: 14 }} /> : null}
      {shown && !busy ? (
        <View onLayout={(e) => { if (toScroll.current) { toScroll.current = false; scroll.current?.scrollTo({ y: Math.max(0, e.nativeEvent.layout.y - 8), animated: true }); } }}>
          <ResultPanel title={shown.title} result={shown.result} facts={shown.facts} />
        </View>
      ) : null}
    </>
  );
  return { busy, run, view, scroll };
}

export function Screen({ scroll, children }: { scroll?: React.RefObject<ScrollView | null>; children: React.ReactNode }): React.ReactElement {
  return <ScrollView ref={scroll} contentContainerStyle={{ padding: 16, paddingBottom: 40 }} keyboardShouldPersistTaps="handled">{children}</ScrollView>;
}

export const s = StyleSheet.create({
  card: { backgroundColor: '#fff', borderRadius: 16, borderWidth: 1, borderColor: line, padding: 16, marginBottom: 14 } as ViewStyle,
  h2: { fontSize: 17, fontWeight: '800', color: ink },
  sub: { color: muted, fontSize: 13, lineHeight: 18, marginTop: 4 },
  label: { color: muted, fontSize: 12, fontWeight: '600', marginBottom: 4 },
  hint: { color: muted, fontSize: 12, lineHeight: 16, marginTop: 2 },
  input: { borderWidth: 1, borderColor: '#c3cfce', borderRadius: 12, paddingHorizontal: 12, paddingVertical: 10, fontSize: 16, color: ink, backgroundColor: '#fff' },
  btn: { flexDirection: 'row', gap: 8, alignItems: 'center', justifyContent: 'center', borderRadius: 12, borderWidth: 1, paddingVertical: 13, paddingHorizontal: 16 },
  btnText: { fontSize: 15, fontWeight: '700' },
  seg: { flexDirection: 'row', borderWidth: 1, borderColor: '#c3cfce', borderRadius: 12, overflow: 'hidden' },
  segItem: { flex: 1, paddingVertical: 10, alignItems: 'center', backgroundColor: '#fff' },
  segText: { fontWeight: '700', color: ink },
  chip: { borderWidth: 1, borderColor: '#c3cfce', borderRadius: 999, paddingVertical: 7, paddingHorizontal: 12, backgroundColor: '#fff' },
  step: { flexDirection: 'row', gap: 12, alignItems: 'center', borderWidth: 1, borderColor: line, borderRadius: 12, padding: 12 },
  stepNo: { width: 28, height: 28, borderRadius: 14, backgroundColor: brand, alignItems: 'center', justifyContent: 'center' },
  badge: { borderWidth: 1, borderRadius: 999, paddingVertical: 4, paddingHorizontal: 10 },
  photo: { flexDirection: 'row', gap: 12, alignItems: 'center', borderWidth: 1, borderColor: line, borderRadius: 12, padding: 10 },
  thumb: { width: 64, height: 64, borderRadius: 10, backgroundColor: '#e8eeed', overflow: 'hidden', alignItems: 'center', justifyContent: 'center' },
  link: { color: brand, fontWeight: '700' },
  code: { backgroundColor: '#eef2f1', borderRadius: 10, padding: 10 },
});

