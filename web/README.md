# xtliveness-web

Face liveness check for websites. Opens the hosted check in an iframe (in your page or as a popup) with the camera, and tells your page when the person is done. No credentials in the browser: your server creates the session and reads the verdict.

## Flow
1. Your page asks **your server** to start a check.
2. Your server calls `POST /v1/sessions` with its API key and returns `checkUrl` and `sdkToken`.
3. The page opens the check with those two values (the token works once).
4. On `completed`, ask your server for the verdict (`GET /v1/sessions/{id}`), or wait for the webhook. **Never decide from the browser.**

## Install
```
npm install xtliveness-web
```
```ts
import { openCheck, runCheck } from 'xtliveness-web';

// callbacks
const check = openCheck({ checkUrl, sdkToken, container: 'box', onComplete: ({ sessionId }) => askYourServer(sessionId), onCancel, onError: ({ code }) => {} });
check.close();

// or a promise
const r = await runCheck({ checkUrl, sdkToken });   // { status: 'completed', sessionId } | { status: 'cancelled' } | { status: 'error', code }
```
Leave out `container` to show the check as a full-screen popup.

## React
```tsx
import { XtlCheck } from 'xtliveness-web/react';

<div style={{ height: 600 }}>
  <XtlCheck checkUrl={s.checkUrl} sdkToken={s.sdkToken}
            onComplete={({ sessionId }) => verify(sessionId)} onCancel={() => setOpen(false)} onError={({ code }) => show(code)} />
</div>
```
The check starts when the component mounts, once per `checkUrl`/`sdkToken`, and stops when it unmounts. React 17 or newer.

## Before it works
- The page's address (for example `https://app.example.com`, no path) must be listed under **Websites allowed to show your check** in the console. Otherwise the browser refuses to show the frame.
- The page must be served over https (or be `localhost`): browsers only give the camera to secure pages.
- Only an https check address is accepted (plain http for localhost, or any host with `allowInsecureHttp: true` in development).

## Safety
The token travels in the URL fragment (not sent to a server or logged). The frame is messaged only at the check page's own origin, and only a message from that frame, about this session, is believed.

## Errors (`code`)
`token_invalid`, `token_used`, `session_expired`, `session_not_open`, `engine_unavailable`, `timeout`, `missing_token`, `camera_denied`, `error`.

## Tests
`npm test` (rules, via Node) and `python3 test/browser.py` (the built package in Chromium against a stand-in check page).
