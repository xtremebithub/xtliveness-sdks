/** The rules shared by the iframe code and its tests. No DOM, so they can be tested alone. */

/** What the hosted check reports. It never carries the verdict: your server learns that from the API or the webhook. */
export type XtlResult =
  | { status: 'completed'; sessionId: string }
  | { status: 'cancelled' }
  | { status: 'error'; code: string };

const CHECK_PATH = /^\/check\/[0-9a-fA-F-]{36}$/;

export interface ParseOptions {
  /** Development only: accept plain http on any host. Never in production. */
  allowInsecureHttp?: boolean;
}

/** Checks the address your server got from POST /v1/sessions. https only; plain http for localhost (or any host with allowInsecureHttp). */
export function parseCheckUrl(raw: string, options: ParseOptions = {}): URL {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error('checkUrl is not a valid URL');
  }
  const local = url.hostname === 'localhost' || url.hostname === '127.0.0.1';
  if (!(url.protocol === 'https:' || (url.protocol === 'http:' && (local || options.allowInsecureHttp)))) throw new Error('checkUrl must be https');
  if (!CHECK_PATH.test(url.pathname)) throw new Error('checkUrl is not a check address');
  return url;
}

export const sessionIdOf = (check: URL): string => check.pathname.split('/').pop()!.toLowerCase();

/** The address the frame loads. The one-time token rides in the fragment: it is never sent to a server or written to a log. */
export function frameUrl(check: URL, sdkToken: string): string {
  if (!sdkToken) throw new Error('sdkToken is required');
  return check.origin + check.pathname + '#t=' + encodeURIComponent(sdkToken);
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
