import test from 'node:test';
import assert from 'node:assert/strict';
import { parseCheckUrl, frameUrl, parseMessage, sessionIdOf, openCheck, runCheck } from '../dist/esm/index.js';

const id = '123e4567-e89b-12d3-a456-426614174000';

test('parseCheckUrl accepts https check addresses', () => {
  assert.equal(parseCheckUrl('https://check.example.com/check/' + id).pathname, '/check/' + id);
});
test('http only on localhost, or when allowed', () => {
  assert.equal(parseCheckUrl('http://localhost:8200/check/' + id).port, '8200');
  assert.throws(() => parseCheckUrl('http://check.example.com/check/' + id), /https/);
  assert.equal(parseCheckUrl('http://10.0.2.2:8200/check/' + id, { allowInsecureHttp: true }).hostname, '10.0.2.2');
});
test('other paths, schemes and junk are refused', () => {
  assert.throws(() => parseCheckUrl('https://x.example/other'), /check address/);
  assert.throws(() => parseCheckUrl('javascript:alert(1)'), /https/);
  assert.throws(() => parseCheckUrl('https://x.example/check/short'), /check address/);
  assert.throws(() => parseCheckUrl('not a url'), /valid URL/);
});
test('the token goes in the fragment, not the query', () => {
  const u = frameUrl(parseCheckUrl('https://c.example.com/check/' + id), 'ab+c/=');
  assert.ok(u.includes('#t=ab%2Bc%2F%3D'));
  assert.ok(!u.includes('?'));
  assert.throws(() => frameUrl(parseCheckUrl('https://c.example.com/check/' + id), ''), /required/);
});
test('messages: only results for this session count', () => {
  const m = (o) => parseMessage(o, id);
  assert.deepEqual(m({ type: 'xtl:result', sessionId: id.toUpperCase(), status: 'completed' }), { status: 'completed', sessionId: id.toUpperCase() });
  assert.deepEqual(m({ type: 'xtl:result', sessionId: id, status: 'cancelled' }), { status: 'cancelled' });
  assert.deepEqual(m({ type: 'xtl:result', sessionId: id, status: 'error', code: 'token_used' }), { status: 'error', code: 'token_used' });
  assert.deepEqual(m({ type: 'xtl:result', sessionId: id, status: 'error' }), { status: 'error', code: 'error' });
  assert.equal(m({ type: 'xtl:result', sessionId: 'other', status: 'completed' }), null);
  assert.equal(m({ type: 'something', sessionId: id, status: 'completed' }), null);
  assert.equal(m({ type: 'xtl:result', sessionId: id, status: 'weird' }), null);
  assert.equal(m(null), null);
  assert.equal(m('text'), null);
  assert.equal(sessionIdOf(parseCheckUrl('https://c.example.com/check/' + id.toUpperCase())), id);
});
test('openCheck refuses a bad address before touching the page', async () => {
  assert.throws(() => openCheck({ checkUrl: 'http://evil.example/check/' + id, sdkToken: 't' }), /https/);
  await assert.rejects(() => runCheck({ checkUrl: 'x', sdkToken: 't' }), /valid URL/);
});
