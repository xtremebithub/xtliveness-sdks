/**
 * xtliveness for websites. No dependencies, no credentials: your server creates the session and returns checkUrl and sdkToken.
 *
 *   const check = openCheck({ checkUrl, sdkToken, onComplete: ({ sessionId }) => askYourServer(sessionId) });
 *   // or: const result = await runCheck({ checkUrl, sdkToken });
 *
 * "Completed" only means the check ran. The verdict comes from your server (GET /v1/sessions/{id}) or your webhook; never decide from the browser.
 * The page that shows the check must be listed under "Websites allowed to show your check" in the console.
 */
import { frameUrl, parseCheckUrl, parseMessage, sessionIdOf, type XtlResult } from './protocol.js';

export { parseCheckUrl, parseMessage, frameUrl, sessionIdOf };
export type { XtlResult };

export interface OpenOptions {
  checkUrl: string;
  sdkToken: string;
  /** An element or its id. Leave out for a full-screen popup. */
  container?: HTMLElement | string;
  onComplete?: (r: { sessionId: string }) => void;
  onCancel?: () => void;
  onError?: (e: { code: string }) => void;
  onClose?: () => void;
  allowInsecureHttp?: boolean;
}

export interface OpenCheck {
  close(): void;
}

export const version = '1.0.0';

export function openCheck(options: OpenOptions): OpenCheck {
  if (!options || typeof options !== 'object') throw new Error('options are required');
  const url = parseCheckUrl(options.checkUrl, { allowInsecureHttp: options.allowInsecureHttp });
  const expected = sessionIdOf(url);
  const origin = url.origin;

  const iframe = document.createElement('iframe');
  iframe.setAttribute('allow', 'camera; microphone');
  iframe.setAttribute('title', 'Face check');
  iframe.style.cssText = 'width:100%;height:100%;border:0;background:#fff;';
  iframe.src = frameUrl(url, options.sdkToken);

  let host: HTMLElement | null = null;
  let overlay: HTMLElement | null = null;
  let closed = false;

  if (options.container) {
    host = typeof options.container === 'string' ? document.getElementById(options.container) : options.container;
    if (!host) throw new Error('container not found');
    host.replaceChildren(iframe);
  } else {
    overlay = document.createElement('div');
    overlay.style.cssText = 'position:fixed;inset:0;z-index:2147483000;background:rgba(0,0,0,.75);';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.appendChild(iframe);
    document.body.appendChild(overlay);
  }

  const sendInit = () => iframe.contentWindow?.postMessage({ type: 'xtl:init' }, origin);

  const onMessage = (e: MessageEvent) => {
    // only the frame we made, speaking from the check page's own origin, about this session
    if (e.source !== iframe.contentWindow || e.origin !== origin) return;
    const r = parseMessage(e.data, expected);
    if (!r) return;
    if (r.status === 'completed') options.onComplete?.({ sessionId: r.sessionId });
    else if (r.status === 'cancelled') options.onCancel?.();
    else options.onError?.({ code: r.code });
    close();
  };

  function close(): void {
    if (closed) return;
    closed = true;
    window.removeEventListener('message', onMessage);
    iframe.removeEventListener('load', sendInit);
    if (overlay && overlay.parentNode) overlay.parentNode.removeChild(overlay);
    else if (host) host.replaceChildren();
    options.onClose?.();
  }

  window.addEventListener('message', onMessage);
  iframe.addEventListener('load', sendInit);
  return { close };
}

/** The same, as a promise: resolves once with the result. Closing it yourself counts as cancelled. */
export function runCheck(options: Omit<OpenOptions, 'onComplete' | 'onCancel' | 'onError' | 'onClose'>): Promise<XtlResult> {
  return new Promise((resolve) => {
    let settled = false;
    const done = (r: XtlResult) => { if (!settled) { settled = true; resolve(r); } };
    openCheck({
      ...options,
      onComplete: ({ sessionId }) => done({ status: 'completed', sessionId }),
      onCancel: () => done({ status: 'cancelled' }),
      onError: ({ code }) => done({ status: 'error', code }),
      onClose: () => done({ status: 'cancelled' }),
    });
  });
}
