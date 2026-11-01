import * as React from 'react';
import { Text } from 'react-native';

import { runLiveCheck, useOpenCheck } from '../check';
import { mapOf, useConn, type ApiResult, type Conn } from '../conn';
import { Btn, Chips, Note, NeedKey, PhotoTile, Screen, Section, Segmented, Toggle, score, useRunner, type Fact } from '../ui';

// Starts like a JPEG, which is all the TEST engine needs.
const DUMMY = '/9j/4AAQSkZJRgABAQ==';

const SCENARIOS: Record<string, string> = {
  pass: 'Live person, face matches',
  not_live: 'A spoof: liveness fails',
  inconclusive: 'The engine could not decide',
  no_match: 'Live, but a different face',
  no_face: 'Live, but no face in the photo',
  pending: 'Not finished yet',
};

/** Open a liveness check (camera, in the SDK's WebView) and, separately, compare two photos with no camera. */
export function LivenessTab({ conn, goConnect }: { conn: Conn; goConnect: () => void }): React.ReactElement {
  useConn(conn);
  const open = useOpenCheck();
  const { busy, run, view, scroll } = useRunner(conn);
  const [scenario, setScenario] = React.useState('pass');
  const [withRef, setWithRef] = React.useState(true);
  const [several, setSeveral] = React.useState(false);
  const [tier, setTier] = React.useState<'standard' | 'premium'>('standard');   // asked for on each call: both tiers can be used at the same time

  const verdict = (r: ApiResult): Fact[] => {
    const d = mapOf(r), l = d.liveness, m = d.match;
    return [
      { label: 'Status', value: String(d.status ?? '—') },
      ...(l ? [{ label: 'Liveness', value: `${l.decision}  ·  ${score(l.score)}`, tone: l.decision === 'live' ? 'good' as const : 'bad' as const }] : []),
      ...(m && m.decision !== 'not_requested' ? [{ label: 'Face match', value: `${m.decision}  ·  ${score(m.score)}`, tone: m.decision === 'match' ? 'good' as const : 'bad' as const }] : []),
      ...(d.failureReason ? [{ label: 'Reason', value: String(d.failureReason), tone: 'warn' as const }] : []),
    ];
  };

  const refs = (body: Record<string, unknown>) => {
    const ref = conn.image(conn.reference, DUMMY, 'a reference photo');
    if (several) body.referenceImages = [ref, ref]; else body.referenceImage = ref;
  };

  const check = () => {
    const body: Record<string, unknown> = { externalRef: `demo-${Date.now()}`, livenessTier: tier, matchTier: several ? 'premium' : tier, ...(conn.isLive ? {} : { scenario }) };
    if (withRef) refs(body);
    return runLiveCheck(conn, open, body, 'The check finished. This is the verdict from your server, which is what you decide on (never the app).');
  };

  const match = () => {
    const body: Record<string, unknown> = {
      externalRef: 'demo-match', tier: several ? 'premium' : tier, image: conn.image(conn.selfie, DUMMY, 'the photo to check'),
      ...(conn.isLive ? {} : { scenario: scenario === 'no_match' || scenario === 'no_face' ? scenario : 'pass' }),
    };
    refs(body);
    return conn.send('POST', '/v1/face-match', body);
  };

  const matchFacts = (r: ApiResult): Fact[] => {
    const d = mapOf(r);
    return [{ label: 'Decision', value: String(d.decision), tone: d.decision === 'match' ? 'good' : 'bad' }, { label: 'Score', value: `${score(d.score)}  (needs ${score(d.threshold)})` }];
  };

  return (
    <Screen scroll={scroll}>
      <NeedKey conn={conn} goConnect={goConnect} />
      <Section title="Liveness check" subtitle="Opens the camera check. Your server starts it, the app shows it, and your server reads the verdict.">
        {!conn.isLive ? (
          <>
            <Text style={{ fontWeight: '600' }}>What should the test show?</Text>
            <Chips value={scenario} options={Object.keys(SCENARIOS)} onChange={setScenario} />
            <Note>{SCENARIOS[scenario]}</Note>
          </>
        ) : null}
        <Text style={{ fontWeight: '600' }}>Tier for this call</Text>
        <Segmented value={tier} options={[['standard', 'Standard'], ['premium', 'Premium']]} onChange={setTier} />
        <Note>{tier === 'premium' ? 'Premium: face images kept 15 days, webhooks sent first. Billed at the premium price.' : 'Standard: no images kept. Each call picks its own tier, so both work side by side.'}</Note>
        <Toggle title="Also compare with a reference photo" text="Adds a face match after the person is judged live" value={withRef} onChange={setWithRef} />
        {withRef ? (
          <>
            <Toggle title="Send several reference photos" text="Needs the premium tier: the demo sends it for you" value={several} onChange={setSeveral} />
            <PhotoTile label="Reference photo" photo={conn.reference} sample={conn.isLive ? null : 'a dummy image'} onPicked={(p) => conn.set({ reference: p })} onClear={() => conn.set({ reference: null })} />
          </>
        ) : null}
        <Btn label="Start liveness check" busy={busy} onPress={() => run('Liveness check', check, verdict)} />
      </Section>
      <Section title="Face match, no camera" subtitle="Are these two photos the same person? One call, answered at once.">
        <PhotoTile label="Photo to check" photo={conn.selfie} camera sample={conn.isLive ? null : 'a dummy image'} onPicked={(p) => conn.set({ selfie: p })} onClear={() => conn.set({ selfie: null })} />
        <PhotoTile label="Photo to compare with" photo={conn.reference} sample={conn.isLive ? null : 'a dummy image'} onPicked={(p) => conn.set({ reference: p })} onClear={() => conn.set({ reference: null })} />
        <Btn kind="tonal" label="Compare the photos" busy={busy} onPress={() => run('Face match', async () => match(), matchFacts)} />
      </Section>
      {view}
    </Screen>
  );
}
