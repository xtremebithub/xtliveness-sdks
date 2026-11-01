import * as React from 'react';
import { Text } from 'react-native';

import { runLiveCheck, useOpenCheck } from '../check';
import { ApiProblem, mapOf, useConn, type ApiResult, type Conn } from '../conn';
import { Btn, Field, Note, NeedKey, PhotoTile, Screen, Section, Segmented, Toggle, score, useRunner, type Fact } from '../ui';

const LABELS: Record<string, string> = {
  firstName: 'First name', middleName: 'Middle name', lastName: 'Last name', dateOfBirth: 'Date of birth', gender: 'Gender', phone: 'Phone',
  email: 'Email', address: 'Address', nationality: 'Nationality', stateOfOrigin: 'State of origin', lgaOfOrigin: 'LGA of origin',
  stateOfResidence: 'State of residence', maritalStatus: 'Marital status',
};
const newKey = (): string => `demo-${Date.now()}${Math.floor(Math.random() * 1000)}`;

/** BVN and NIN: is the number valid, who is it, and is this selfie the person on the ID. You send only the number. */
export function IdentityTab({ conn, goConnect }: { conn: Conn; goConnect: () => void }): React.ReactElement {
  useConn(conn);
  const open = useOpenCheck();
  const { busy, run, view, scroll } = useRunner(conn);
  const [number, setNumber] = React.useState('22212345678');
  const [type, setType] = React.useState<'bvn' | 'nin'>('bvn');
  const [level, setLevel] = React.useState<'basic' | 'advanced'>('basic');
  const [face, setFace] = React.useState<'test:face-a' | 'test:face-b'>('test:face-a');
  const [consent, setConsent] = React.useState(true);          // the person agreed: live calls need it unless the account switched that off
  const [consentRef, setConsentRef] = React.useState('demo-consent');
  const [idem, setIdem] = React.useState(false);               // send an Idempotency-Key so a repeated tap is not billed twice
  const [idemBase, setIdemBase] = React.useState(newKey());

  const n = number.trim();
  const check = () => { if (!/^[0-9]{11}$/.test(n)) throw new ApiProblem(`Enter the 11 digits of the ${type.toUpperCase()}.`); };
  const consentBody = () => ({ given: true, reference: consentRef.trim() || 'demo-consent' });

  const call = (path: string, extra: Record<string, unknown>): Promise<ApiResult> => {
    check();
    return conn.send('POST', `/v1/identity/${path}`,
      { type, number: n, externalRef: `demo-${Date.now()}`, ...(consent ? { consent: consentBody() } : {}), ...extra },
      idem ? { 'Idempotency-Key': `${idemBase}-${path}` } : undefined);   // one key per kind of call: the same key for another kind would be refused
  };

  const validFacts = (r: ApiResult): Fact[] => [{ label: `This ${type.toUpperCase()}`, value: mapOf(r).valid === true ? 'is valid' : 'is not valid', tone: mapOf(r).valid === true ? 'good' : 'bad' }];

  const lookupFacts = (r: ApiResult): Fact[] => {
    const d = mapOf(r);
    if (d.found !== true) return [{ label: 'Found', value: 'no such person', tone: 'bad' }];
    const data = d.data && typeof d.data === 'object' ? d.data : {};
    return [{ label: 'Found', value: 'yes', tone: 'good' }, ...Object.keys(LABELS).filter((k) => data[k] != null).map((k) => ({ label: LABELS[k], value: String(data[k]) }))];
  };

  const faceFacts = (r: ApiResult): Fact[] => {
    const d = mapOf(r);
    if (d.found !== true) return [{ label: 'Found', value: 'no such person', tone: 'bad' }];
    return [{ label: 'Selfie', value: d.match === true ? 'is the person on the ID' : 'is not the person on the ID', tone: d.match === true ? 'good' : 'bad' }, { label: 'Score', value: `${score(d.score)}  (needs ${score(d.threshold)})` }];
  };

  /** No selfie to upload: the person does a liveness check and is compared with the photo on the ID. */
  const live = () => {
    check();
    return runLiveCheck(conn, open, { externalRef: 'demo-id-live', identity: { type, number: n, ...(consent ? { consent: consentBody() } : {}) }, ...(conn.isLive ? {} : { scenario: 'pass' }) },
      'The check finished. Read the verdict from your server.');
  };

  const liveFacts = (r: ApiResult): Fact[] => {
    const d = mapOf(r), l = d.liveness, m = d.match;
    return [
      { label: 'Status', value: String(d.status ?? '—') },
      ...(l ? [{ label: 'Liveness', value: `${l.decision}  ·  ${score(l.score)}`, tone: l.decision === 'live' ? 'good' as const : 'bad' as const }] : []),
      ...(m && m.decision !== 'not_requested' ? [{ label: 'Against the ID', value: `${m.decision}  ·  ${score(m.score)}`, tone: m.decision === 'match' ? 'good' as const : 'bad' as const }] : []),
      ...(d.failureReason ? [{ label: 'Reason', value: String(d.failureReason), tone: 'warn' as const }] : []),
    ];
  };

  return (
    <Screen scroll={scroll}>
      <NeedKey conn={conn} goConnect={goConnect} />
      <Section title="The ID" subtitle="You send only the number. The Identity product must be on the account.">
        <Segmented value={type} options={[['bvn', 'BVN'], ['nin', 'NIN']]} onChange={setType} />
        <Field label={`${type.toUpperCase()} number`} value={number} onChangeText={(v) => setNumber(v.replace(/[^0-9]/g, '').slice(0, 11))} keyboardType="number-pad" maxLength={11} placeholder="11 digits"
          helper={conn.isLive ? 'A real lookup: it is billed and the person should have agreed to it.' : 'Test mode: any 11 digits is a made-up person.'} />
        <Toggle title="The person agreed to this check" text="Live calls are refused without it. We keep your reference with the check." value={consent} onChange={setConsent} />
        {consent ? <Field label="Your reference for their agreement" value={consentRef} onChangeText={setConsentRef} /> : null}
        <Toggle title="Send an Idempotency-Key" text="Tap a button twice: the second answer is the same and is not billed again." value={idem} onChange={(v) => { setIdem(v); setIdemBase(newKey()); }} />
        {idem ? <Btn kind="outline" label="Start a new request (new key)" onPress={() => setIdemBase(newKey())} /> : null}
      </Section>
      <Section title="Is it valid?" subtitle="True or false. No details are returned.">
        <Btn label="Validate" busy={busy} onPress={() => run('Validate', async () => call('validate', {}), validFacts)} />
      </Section>
      <Section title="Who is it?" subtitle="The details on record. Advanced adds email, address and place of origin and costs more.">
        <Segmented value={level} options={[['basic', 'Basic'], ['advanced', 'Advanced']]} onChange={setLevel} />
        <Btn label="Look up" busy={busy} onPress={() => run('Look up', async () => call('lookup', { level, includePhoto: true }), lookupFacts)} />
      </Section>
      <Section title="Is this selfie the person?" subtitle="The selfie is compared with the photo on the ID.">
        {!conn.isLive ? (
          <>
            <Text>Which simulated selfie? The photo on every test ID is Person A.</Text>
            <Segmented value={face} options={[['test:face-a', 'Person A'], ['test:face-b', 'Person B']]} onChange={setFace} />
          </>
        ) : <PhotoTile label="Selfie" photo={conn.selfie} camera onPicked={(p) => conn.set({ selfie: p })} onClear={() => conn.set({ selfie: null })} />}
        <Btn label="Match the selfie" busy={busy} onPress={() => run('Selfie match', async () => call('face-match', { image: conn.image(conn.selfie, face, 'a selfie') }), faceFacts)} />
      </Section>
      <Section title="Match a live person" subtitle="No selfie to upload: the person does a liveness check and their face is compared with the photo on the ID. Billed once, as the ID face match.">
        <Btn label="Start the live check" busy={busy} onPress={() => run('Live match', async () => live(), liveFacts)} />
        <Note>The camera check opens full screen and closes by itself when it is done.</Note>
      </Section>
      {view}
    </Screen>
  );
}
