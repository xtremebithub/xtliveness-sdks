import * as React from 'react';
import { Text, View } from 'react-native';

import { runLiveCheck, useOpenCheck } from '../check';
import { dataOf, mapOf, useConn, type ApiResult, type Conn } from '../conn';
import { Btn, Chips, Field, Note, NeedKey, PhotoTile, Screen, Section, Segmented, StepRow, Toggle, score, useRunner, type Fact } from '../ui';

const MODES: Record<string, string> = {
  search_then_enroll: 'Catch a duplicate, otherwise enrol the person.',
  search: 'Who looks like this face? Nobody is added.',
  enroll: 'Add this face under the person reference.',
  authenticate: 'Is this the enrolled person? (1:1)',
};
const C = '/v1/face-search/collections';

/** Face search (1:N): private collections of faces on your account. Walk through it in order, or run it after a liveness check. */
export function SearchTab({ conn, goConnect }: { conn: Conn; goConnect: () => void }): React.ReactElement {
  useConn(conn);
  const open = useOpenCheck();
  const { busy, run, view, scroll } = useRunner(conn);
  const [collection, setCollection] = React.useState('practice');
  const [person, setPerson] = React.useState('ann');
  const [attributes, setAttributes] = React.useState('');
  const [mode, setMode] = React.useState('search_then_enroll');
  const [face, setFace] = React.useState<'test:face-a' | 'test:face-b'>('test:face-a');
  const [premium, setPremium] = React.useState(false);

  const name = collection.trim(), ref = person.trim();
  const photo = () => conn.image(conn.selfie, face, 'the photo to use');
  const attrs = (): Record<string, string> => {
    const out: Record<string, string> = {};
    for (const part of attributes.split(',')) { const i = part.indexOf('='); if (i > 0 && part.slice(0, i).trim()) out[part.slice(0, i).trim()] = part.slice(i + 1).trim(); }
    return out;
  };
  const go = (title: string, method: string, path: string, summary: (r: ApiResult) => Fact[], body?: Record<string, unknown>, billed = true) =>
    run(title, async () => conn.send(method, path, body), summary, billed);

  const created = (r: ApiResult): Fact[] => [{ label: 'Collection', value: String(mapOf(r).name ?? name), tone: 'good' }];
  const searchFacts = (r: ApiResult): Fact[] => {
    const matches: any[] = Array.isArray(mapOf(r).matches) ? mapOf(r).matches : [];
    return [
      { label: 'Found', value: matches.length ? `${matches.length} possible match${matches.length === 1 ? '' : 'es'}` : 'nobody looks like this face', tone: matches.length ? 'warn' : 'plain' },
      ...matches.slice(0, 5).map((m) => ({ label: '  ' + m.personRef, value: score(m.score) + (m.attributes && Object.keys(m.attributes).length ? '  ' + JSON.stringify(m.attributes) : '') })),
    ];
  };
  const enrolFacts = (r: ApiResult): Fact[] => [{ label: 'Person', value: String(mapOf(r).personRef ?? ref) }, { label: 'Enrolled', value: String(mapOf(r).enrolled ?? true), tone: 'good' }];
  const authFacts = (r: ApiResult): Fact[] => [{ label: 'Same person', value: mapOf(r).match === true ? 'yes' : 'no', tone: mapOf(r).match === true ? 'good' : 'bad' }, { label: 'Score', value: score(mapOf(r).score) }];
  const listFacts = (r: ApiResult): Fact[] => {
    const list: any[] = Array.isArray(dataOf(r)) ? dataOf(r) : [];
    return [{ label: 'Collections', value: String(list.length) }, ...list.slice(0, 8).map((c) => ({ label: '  ' + c.name, value: `${c.people ?? 0} people · ${c.environment}` }))];
  };
  const removed = (): Fact[] => [{ label: 'Done', value: 'removed', tone: 'good' }];

  const afterLiveness = () => runLiveCheck(conn, open, {
    externalRef: `demo-fs-${Date.now()}`,
    ...(conn.isLive ? {} : { scenario: 'pass' }),
    faceSearch: { collection: name, mode, ...(mode !== 'search' || ref ? { personRef: ref } : {}), ...(conn.isLive ? {} : { testFace: face }), ...(premium ? { tier: 'premium' } : {}) },
  }, 'The check finished. The search or enrolment ran on the live face.');

  const afterFacts = (r: ApiResult): Fact[] => {
    const d = mapOf(r), l = d.liveness, fs = d.faceSearch;
    return [
      ...(l ? [{ label: 'Liveness', value: `${l.decision}  ·  ${score(l.score)}`, tone: l.decision === 'live' ? 'good' as const : 'bad' as const }] : []),
      ...(fs ? [
        { label: 'Face search', value: `${fs.status}  (${fs.mode ?? mode})` },
        ...(Array.isArray(fs.matches) ? [{ label: 'Matches', value: String(fs.matches.length), tone: fs.matches.length ? 'warn' as const : 'plain' as const }] : []),
        ...(fs.enrolled != null ? [{ label: 'Enrolled', value: String(fs.enrolled) }] : []),
        ...(fs.match != null ? [{ label: 'Same person', value: String(fs.match), tone: fs.match === true ? 'good' as const : 'bad' as const }] : []),
      ] : []),
    ];
  };

  return (
    <Screen scroll={scroll}>
      <NeedKey conn={conn} goConnect={goConnect} />
      <Section title="Your practice names" subtitle="Face search needs to be switched on for the account. A collection is a private group of faces; the person reference is your own id for someone in it.">
        <Field label="Collection" value={collection} onChangeText={setCollection} helper="a-z, 0-9, _ and -, up to 40 characters" />
        <Field label="Person reference" value={person} onChangeText={setPerson} helper="Enrolling the same reference again replaces the face" />
        <Field label="Attributes when enrolling (optional)" value={attributes} onChangeText={setAttributes} placeholder="case=214, tag=vip" helper="Adding any makes this a premium enrolment" />
        <Toggle title="Premium enrolment" text="Billed at the premium price. Chosen per call: standard enrolments work at the same time." value={premium} onChange={setPremium} />
        {!conn.isLive ? (
          <>
            <Text style={{ fontWeight: '600' }}>Which simulated person?</Text>
            <Segmented value={face} options={[['test:face-a', 'Person A'], ['test:face-b', 'Person B']]} onChange={setFace} />
          </>
        ) : <PhotoTile label="Photo to use" photo={conn.selfie} camera onPicked={(p) => conn.set({ selfie: p })} onClear={() => conn.set({ selfie: null })} />}
      </Section>
      <Section title="Walk through it" subtitle="Run these in order. Try Person A for steps 2 to 4, then Person B for step 3 and 4 to see a miss.">
        <StepRow n="1" title="Create the collection" text="Once per purpose, for example signups." disabled={busy} onPress={() => go('Create collection', 'POST', C, created, { name })} />
        <StepRow n="2" title="Enrol a person" text="Add the face under the person reference." disabled={busy}
          onPress={() => run('Enrol a person', async () => { const a = attrs(); return conn.send('POST', `${C}/${name}/people`, { personRef: ref, image: photo(), ...(Object.keys(a).length || premium ? { tier: 'premium' } : {}), ...(Object.keys(a).length ? { attributes: a } : {}) }); }, enrolFacts)} />
        <StepRow n="3" title="Search" text="Who looks like this photo? Never adds anyone." disabled={busy} onPress={() => run('Search', async () => conn.send('POST', `${C}/${name}/search`, { image: photo() }), searchFacts)} />
        <StepRow n="4" title="Authenticate (1:1)" text="Is this photo that enrolled person?" disabled={busy}
          onPress={() => run('Authenticate', async () => conn.send('POST', `${C}/${name}/people/${encodeURIComponent(ref)}/authenticate`, { image: photo() }), authFacts)} />
      </Section>
      <Section title="After a liveness check" subtitle="The same search or enrolment, run on the live face once the person passes. A spoof is never searched or enrolled.">
        <Chips value={mode} options={Object.keys(MODES)} onChange={setMode} />
        <Note>{MODES[mode]}</Note>
        <Btn label="Liveness check + face search" busy={busy} onPress={() => run('Liveness check + face search', afterLiveness, afterFacts)} />
      </Section>
      <Section title="Look after your data" subtitle="Forget a person when they ask, or remove a whole collection.">
        <View style={{ gap: 8 }}>
          <Btn kind="outline" label="List collections" disabled={busy} onPress={() => go('Your collections', 'GET', C, listFacts, undefined, false)} />
          <Btn kind="outline" label="Remove person" disabled={busy} onPress={() => go('Remove person', 'DELETE', `${C}/${name}/people/${encodeURIComponent(ref)}`, removed, undefined, false)} />
          <Btn kind="danger" label="Delete collection" disabled={busy} onPress={() => go('Delete collection', 'DELETE', `${C}/${name}`, removed, undefined, false)} />
        </View>
      </Section>
      {view}
    </Screen>
  );
}
