// The connection every tab shares: where the service is, which API key to use, the photos picked, and the one place that calls the API.
// In a real app this part lives on YOUR server. The demo does it from the phone only so you can try everything from one place.
import * as React from 'react';

/** A problem the person can fix (a missing photo, say), shown instead of a call. */
export class ApiProblem extends Error {}

export interface ApiResult {
  status: number;
  body?: Record<string, any>;
  raw: string;
  note?: string | null;      // for example "The person cancelled."
  request?: string | null;   // "POST /v1/identity/validate", shown above the reply
}

export const local = (message: string): ApiResult => ({ status: 0, body: { success: false, message, errors: [] }, raw: message });
export const isOk = (r: ApiResult): boolean => r.status >= 200 && r.status < 300 && !!r.body && r.body.success !== false;
export const dataOf = (r: ApiResult): any => r.body?.data;
export const mapOf = (r: ApiResult): Record<string, any> => (dataOf(r) && typeof dataOf(r) === 'object' && !Array.isArray(dataOf(r)) ? dataOf(r) : {});
export const withNote = (r: ApiResult, note?: string | null, request?: string | null): ApiResult => ({ ...r, note: note ?? r.note, request: request ?? r.request });
export const pretty = (r: ApiResult): string => (r.body ? JSON.stringify(r.body, null, 2) : r.raw);

/** The first error the service gave, in its own words. */
export function problemOf(r: ApiResult): string {
  const errors = r.body?.errors;
  if (Array.isArray(errors) && errors.length && errors[0] && typeof errors[0] === 'object') return String(errors[0].message ?? errors[0].code ?? 'The request failed.');
  const message = String(r.body?.message ?? '');
  if (message) return message;
  return r.status === 0 ? 'No answer from the service.' : `The service answered ${r.status}.`;
}

export interface Photo { base64: string; name: string }

type Listener = () => void;

export class Conn {
  base = 'https://liveness.xtremebithub.com';
  key = '';
  selfie: Photo | null = null;
  reference: Photo | null = null;
  private listeners = new Set<Listener>();
  private version = 0;

  subscribe = (l: Listener): (() => void) => { this.listeners.add(l); return () => { this.listeners.delete(l); }; };
  snapshot = (): number => this.version;
  private changed(): void { this.version++; this.listeners.forEach((l) => l()); }

  get isTest(): boolean { return this.key.trim().startsWith('xtl_test_'); }
  get isLive(): boolean { return this.key.trim().startsWith('xtl_live_'); }
  get hasKey(): boolean { return this.isTest || this.isLive; }
  get insecure(): boolean { return this.base.trim().startsWith('http://'); }

  set(patch: Partial<Pick<Conn, 'base' | 'key' | 'selfie' | 'reference'>>): void { Object.assign(this, patch); this.changed(); }

  url(path: string): string { return this.base.trim().replace(/\/+$/, '') + path; }

  /** The photo to send: the one picked, else (test key only) a built-in sample such as test:face-a. */
  image(picked: Photo | null, sample: string, what = 'a photo'): string {
    if (picked) return picked.base64;
    if (this.isLive) throw new ApiProblem(`A live key needs real photos: choose ${what} first.`);
    return sample;
  }

  /** One call to the service. Never throws for a bad status: the caller shows what the service said. extra: for example Idempotency-Key. */
  async send(method: string, path: string, body?: Record<string, unknown>, extra?: Record<string, string>): Promise<ApiResult> {
    const label = `${method} ${path}`;
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), 60000);
    try {
      const res = await fetch(this.url(path), {
        method,
        headers: { Authorization: `Bearer ${this.key.trim()}`, 'Content-Type': 'application/json', ...(extra ?? {}) },
        body: body ? JSON.stringify(body) : undefined,
        signal: ctl.signal,
      });
      const text = await res.text();
      try {
        const decoded = JSON.parse(text);
        if (decoded && typeof decoded === 'object' && !Array.isArray(decoded)) return { status: res.status, body: decoded, raw: text, request: label };
      } catch { /* not JSON: show the raw text */ }
      return { status: res.status, raw: text.length > 600 ? text.slice(0, 600) : text, request: label };
    } catch (e) {
      return withNote(local(`Could not reach the service. Check the address and your connection.\n(${String(e)})`), null, label);
    } finally {
      clearTimeout(timer);
    }
  }
}

/** Re-draws the screen whenever the connection changes. */
export function useConn(conn: Conn): Conn {
  React.useSyncExternalStore(conn.subscribe, conn.snapshot);
  return conn;
}
