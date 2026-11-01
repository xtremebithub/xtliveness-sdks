import test from 'node:test';
import assert from 'node:assert/strict';
import { parseCheckUrl, frameUrl, parseMessage, parseSpeak, originOf, sessionIdOf } from '../dist/protocol.js';

const id = '123e4567-e89b-12d3-a456-426614174000';
test('check addresses', () => {
  assert.equal(parseCheckUrl('https://C.example.com/check/' + id).host, 'c.example.com');
  assert.equal(parseCheckUrl('http://localhost:8200/check/' + id).origin, 'http://localhost:8200');
  assert.equal(sessionIdOf(parseCheckUrl('https://c.example.com/check/' + id.toUpperCase())), id);
  for (const bad of ['https://c.example.com/check/' + id + '?x=1', 'https://c.example.com/check/' + id + '#t=1', 'https://user:pw@c.example.com/check/' + id, 'javascript:alert(1)', '', 'https://c.example.com/check/short'])
    assert.throws(() => parseCheckUrl(bad), /check address|https/, bad);
  assert.throws(() => parseCheckUrl('http://c.example.com/check/' + id), /https/);
  assert.equal(parseCheckUrl('http://10.0.2.2:8200/check/' + id, { allowInsecureHttp: true }).port, '8200');
  assert.equal(originOf('https://C.example.com:8443/a/b?c#d'), 'https://c.example.com:8443');
  assert.equal(originOf('intent://x'), null);
  assert.notEqual(originOf('https://c.example.com.evil.net/x'), 'https://c.example.com');
  assert.throws(() => parseCheckUrl('https://c.example.com/x'), /check address/);
});
test('token in fragment', () => {
  const u = frameUrl(parseCheckUrl('https://c.example.com/check/' + id), 'a b');
  assert.ok(u.endsWith('#t=a%20b') && !u.includes('?'));
});
test('messages', () => {
  assert.deepEqual(parseMessage({ type: 'xtl:result', sessionId: id, status: 'completed' }, id), { status: 'completed', sessionId: id });
  assert.equal(parseMessage({ type: 'xtl:result', sessionId: 'x', status: 'completed' }, id), null);
  assert.deepEqual(parseMessage({ type: 'xtl:result', sessionId: id, status: 'error', code: 'timeout' }, id), { status: 'error', code: 'timeout' });
});

test('speech requests', () => {
  assert.deepEqual(parseSpeak({ type: 'xtl:speak', text: 'Move closer', lang: 'en' }), { text: 'Move closer', lang: 'en' });
  assert.deepEqual(parseSpeak({ type: 'xtl:speak', text: 'Hold still', lang: 'fr-CA' }), { text: 'Hold still', lang: 'fr-CA' });
  assert.equal(parseSpeak({ type: 'xtl:speak', text: 'x', lang: '"><script>' }).lang, 'en');
  assert.equal(parseSpeak({ type: 'xtl:speak' }).text, '');
  assert.equal(parseSpeak({ type: 'xtl:speak', text: 'a'.repeat(900) }).text.length, 500);
  assert.equal(parseSpeak({ type: 'xtl:result', status: 'completed' }), null);
  assert.equal(parseSpeak(null), null);
  assert.equal(parseSpeak('xtl:speak'), null);
  assert.equal(parseMessage({ type: 'xtl:speak', text: 'x' }, id), null);
});
