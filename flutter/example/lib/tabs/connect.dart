import 'package:flutter/material.dart';

import '../conn.dart';
import '../ui.dart';

/// Step one: where the service is and which key to use. Nothing else works without a key.
class ConnectTab extends StatefulWidget {
  const ConnectTab({super.key, required this.conn});
  final Conn conn;
  @override
  State<ConnectTab> createState() => _ConnectTabState();
}

class _ConnectTabState extends State<ConnectTab> {
  bool _hide = true, _testing = false;
  String? _status;
  Tone _tone = Tone.plain;

  Conn get conn => widget.conn;

  Future<void> _test() async {
    if (!conn.hasKey) {
      setState(() { _status = 'Paste a key that starts with xtl_test_ or xtl_live_.'; _tone = Tone.warn; });
      return;
    }
    setState(() { _testing = true; _status = null; });
    // any answer other than "key not accepted" shows the address and the key are right
    final r = await conn.send('GET', '/v1/usage');
    if (!mounted) return;
    setState(() {
      _testing = false;
      if (r.status == 0) { _status = r.problem; _tone = Tone.bad; }
      else if (r.status == 401) { _status = 'The service is there, but it does not accept this key.'; _tone = Tone.bad; }
      else { _status = 'Connected. The service accepts this ${conn.isTest ? 'test' : 'live'} key.'; _tone = Tone.good; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [brand, Color(0xFF0E4F63)]), borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.verified_user_outlined, color: Colors.white, size: 34),
            const SizedBox(height: 10),
            Text('Try every check', style: t.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Liveness, face match, face search and Nigerian ID checks. Connect once, then use the tabs below.', style: TextStyle(color: Colors.white70)),
          ]),
        ),
        Section(
          title: 'Connect',
          icon: Icons.link,
          subtitle: 'Paste your API key. Nothing is saved: it is forgotten when you close the app.',
          children: [
            TextField(controller: conn.base, keyboardType: TextInputType.url, autocorrect: false, decoration: deco('Service address', icon: Icons.dns_outlined)),
            const SizedBox(height: 12),
            TextField(
              controller: conn.key,
              obscureText: _hide,
              autocorrect: false,
              enableSuggestions: false,
              decoration: deco('API key', hint: 'xtl_test_…', icon: Icons.key).copyWith(suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _hide = !_hide))),
            ),
            const SizedBox(height: 12),
            Row(children: [
              ListenableBuilder(listenable: conn, builder: (c, _) => KeyBadge(conn: conn)),
              const Spacer(),
              FilledButton.icon(onPressed: _testing ? null : _test, icon: _testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering), label: const Text('Test connection')),
            ]),
            if (_status != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status!, style: TextStyle(color: toneColor(context, _tone), fontWeight: FontWeight.w600))),
            ListenableBuilder(
              listenable: conn,
              builder: (c, _) => conn.insecure
                  ? Padding(padding: const EdgeInsets.only(top: 12), child: Text('This address is plain http. That is fine for a service on your own computer (use http://localhost:8200 with adb reverse), never for a real one.', style: t.textTheme.bodySmall?.copyWith(color: warn)))
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        Section(title: 'Test or live?', icon: Icons.help_outline, children: [
          _row(context, Icons.science_outlined, good, 'Test key (xtl_test_…)', 'Free. No real photos or ID numbers needed: the demo uses built-in sample faces and made-up people.'),
          const SizedBox(height: 10),
          _row(context, Icons.bolt, warn, 'Live key (xtl_live_…)', 'Real checks, billed to the account. You will be asked before each one, and you must choose real photos.'),
        ]),
        Section(title: 'About this demo', icon: Icons.info_outline, children: [
          Text('In a real app, your server holds the API key and talks to the service; the app only opens the check. This demo does both from the phone so you can see every result in one place. Never ship a key inside an app.', style: t.textTheme.bodyMedium),
        ]),
      ]),
    );
  }

  Widget _row(BuildContext context, IconData icon, Color color, String title, String text) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
      ]);
}
