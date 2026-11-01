# Runs the built SDK in headless Chromium against a stand-in check page on another origin. Run after `npm run build`:  python3 test/browser.py
import http.server, threading, os, json
from playwright.sync_api import sync_playwright

here = os.path.dirname(os.path.abspath(__file__)); dist = os.path.join(here, '..', 'dist', 'esm')
ID = '123e4567-e89b-12d3-a456-426614174000'
CHECK = f'''<!doctype html><body><script>
const sid = '{ID}'; let host = null;
addEventListener('message', (e) => {{
  if (e.data && e.data.type === 'xtl:init') {{ host = e.origin; parent.postMessage({{ type: 'xtl:result', sessionId: sid, status: location.hash.includes('t=done') ? 'completed' : 'error', code: 'token_used' }}, host);
    parent.postMessage({{ type: 'xtl:result', sessionId: 'someone-else', status: 'completed' }}, host); }}
}});
</script>hash:'''
class Check(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.send_header('Content-Type', 'text/html'); self.end_headers(); self.wfile.write(CHECK.encode())
    def log_message(self, *a): pass
class Host(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            body = b'<!doctype html><div id="box" style="width:400px;height:400px"></div>'; ct = 'text/html'
        else:
            f = os.path.join(dist, self.path.lstrip('/'));
            if not os.path.isfile(f): self.send_response(404); self.end_headers(); return
            body = open(f, 'rb').read(); ct = 'text/javascript'
        self.send_response(200); self.send_header('Content-Type', ct); self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass
for port, h in ((9401, Host), (9402, Check)):
    threading.Thread(target=http.server.ThreadingHTTPServer(('127.0.0.1', port), h).serve_forever, daemon=True).start()
fails = []
def check(ok, what):
    print(('ok    ' if ok else 'FAIL  ') + what)
    if not ok: fails.append(what)
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(); pg.goto('http://localhost:9401/')
    url = f'http://localhost:9402/check/{ID}'
    r = pg.evaluate('''async (url) => { const m = await import('/index.js'); const got = [];
      const r = await m.runCheck({ checkUrl: url, sdkToken: 'done', container: 'box' }); return { r, frames: document.querySelectorAll('iframe').length, src: null }; }''', url)
    check(r['r'] == {'status': 'completed', 'sessionId': ID}, 'a result from the check origin arrives, the message for another session is ignored')
    check(r['frames'] == 0, 'the frame is removed once the result arrives')
    r2 = pg.evaluate('''async (url) => { const m = await import('/index.js'); const c = m.openCheck({ checkUrl: url, sdkToken: 'tok en' }); const f = document.querySelector('iframe');
      const out = { src: f.getAttribute('src'), allow: f.getAttribute('allow') }; c.close(); out.after = document.querySelectorAll('iframe').length; return out; }''', url)
    check('#t=tok%20en' in r2['src'] and '?' not in r2['src'], 'token is in the fragment, URL-encoded')
    check('camera' in r2['allow'], 'the frame may use the camera')
    check(r2['after'] == 0, 'close() removes the popup')
    b.close()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK'); raise SystemExit(1 if fails else 0)
