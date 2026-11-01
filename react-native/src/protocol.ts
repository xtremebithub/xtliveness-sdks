/** The rules shared by the component and its tests. No DOM and no URL class (React Native's URL is incomplete), so they run anywhere. */

/** What the hosted check reports. It never carries the verdict: your server learns that from the API or the webhook. */
export type XtlResult =
  | { status: 'completed'; sessionId: string }
  | { status: 'cancelled' }
  | { status: 'error'; code: string };

export interface CheckAddress {
  scheme: 'http' | 'https';
  host: string;
  port: string | null;
  /** scheme://host[:port], lower case */
  origin: string;
  /** /check/<session id> */
  path: string;
}

export interface ParseOptions {
  /** Development only: accept plain http on any host. Never in a release. */
  allowInsecureHttp?: boolean;
}

const ADDRESS = /^(https?):\/\/([A-Za-z0-9.-]+)(?::(\d{1,5}))?(\/check\/[0-9a-fA-F-]{36})$/;

/** Checks the address your server got from POST /v1/sessions: https (plain http for localhost, or anywhere with allowInsecureHttp), no query, no fragment, no login. */
export function parseCheckUrl(raw: string, options: ParseOptions = {}): CheckAddress {
  const m = ADDRESS.exec(typeof raw === 'string' ? raw : '');
  if (!m) {
    if (typeof raw === 'string' && /^https?:\/\//i.test(raw) === false) throw new Error('checkUrl must be https');
    throw new Error('checkUrl is not a check address');
  }
  const scheme = m[1].toLowerCase() as 'http' | 'https';
  const host = m[2].toLowerCase();
  const local = host === 'localhost' || host === '127.0.0.1';
  if (!(scheme === 'https' || local || options.allowInsecureHttp)) throw new Error('checkUrl must be https');
  const port = m[3] ?? null;
  return { scheme, host, port, origin: scheme + '://' + host + (port ? ':' + port : ''), path: m[4] };
}

export const sessionIdOf = (a: CheckAddress): string => a.path.split('/').pop()!.toLowerCase();

/** The address the WebView loads. The one-time token rides in the fragment: it is never sent to a server or written to a log. */
export function frameUrl(a: CheckAddress, sdkToken: string): string {
  if (!sdkToken) throw new Error('sdkToken is required');
  return a.origin + a.path + '#t=' + encodeURIComponent(sdkToken);
}

/** The origin of any address, or null when it is not an http(s) address. */
export function originOf(raw: string): string | null {
  const m = /^(https?):\/\/([^\/?#@\s]+)/i.exec(raw);
  return m ? m[1].toLowerCase() + '://' + m[2].toLowerCase() : null;
}

/** Reads one message from the check page. Returns null for anything that is not a result for this session. */
export function parseMessage(data: unknown, expectedSessionId: string): XtlResult | null {
  if (!data || typeof data !== 'object') return null;
  const d = data as Record<string, unknown>;
  if (d.type !== 'xtl:result' || String(d.sessionId).toLowerCase() !== expectedSessionId.toLowerCase()) return null;
  switch (d.status) {
    case 'completed': return { status: 'completed', sessionId: String(d.sessionId) };
    case 'cancelled': return { status: 'cancelled' };
    case 'error': return { status: 'error', code: typeof d.code === 'string' && d.code ? d.code : 'error' };
    default: return null;
  }
}

/** Something that can read a sentence aloud (expo-speech, react-native-tts, or your own). The WebView's own speech is often silent, so the app speaks for it. */
export interface XtlSpeech {
  /** Read this text aloud. lang is a language tag such as "en". Replace anything still being read. */
  speak(text: string, lang: string): void;
  /** Stop reading. Called when the check ends. */
  stop?(): void;
}

/** Reads a request from the check page to speak a sentence. Returns null for anything else. */
export function parseSpeak(data: unknown): { text: string; lang: string } | null {
  if (!data || typeof data !== 'object') return null;
  const d = data as Record<string, unknown>;
  if (d.type !== 'xtl:speak') return null;
  const text = typeof d.text === 'string' ? d.text.slice(0, 500) : '';
  const lang = typeof d.lang === 'string' && /^[A-Za-z]{2,3}([-_][A-Za-z0-9]{2,8})?$/.test(d.lang) ? d.lang : 'en';
  return { text, lang };
}
