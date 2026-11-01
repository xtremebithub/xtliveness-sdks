import 'package:flutter/material.dart';
import 'package:xtliveness/xtliveness.dart';

import '../conn.dart';
import '../ui.dart';

// Starts like a JPEG, which is all the TEST engine needs.
const _dummy = '/9j/4AAQSkZJRgABAQ==';

const _scenarios = <String, String>{
  'pass': 'Live person, face matches',
  'not_live': 'A spoof: liveness fails',
  'inconclusive': 'The engine could not decide',
  'no_match': 'Live, but a different face',
  'no_face': 'Live, but no face in the photo',
  'pending': 'Not finished yet',
};

/// Open a liveness check (camera, in the package's WebView) and, separately, compare two photos with no camera.
class LivenessTab extends StatefulWidget {
  const LivenessTab({super.key, required this.conn, required this.goConnect});
  final Conn conn;
  final VoidCallback goConnect;
  @override
  State<LivenessTab> createState() => _LivenessTabState();
}

class _LivenessTabState extends State<LivenessTab> with Runner<LivenessTab> {
  @override
  Conn get conn => widget.conn;

  String _scenario = 'pass';
  bool _withReference = true, _several = false;
  String _tier = 'standard';   // asked for on each call: both tiers can be used at the same time, each billed at its own price

  List<Fact> _verdict(ApiResult r) {
    final d = r.map;
    final l = d['liveness'], m = d['match'];
    return [
      Fact('Status', '${d['status'] ?? '—'}'),
      if (l is Map) Fact('Liveness', '${l['decision']}  ·  ${score(l['score'])}', l['decision'] == 'live' ? Tone.good : Tone.bad),
      if (m is Map && m['decision'] != 'not_requested') Fact('Face match', '${m['decision']}  ·  ${score(m['score'])}', m['decision'] == 'match' ? Tone.good : Tone.bad),
      if (d['failureReason'] != null) Fact('Reason', '${d['failureReason']}', Tone.warn),
    ];
  }

  Future<ApiResult> _check() async {
    final body = <String, Object?>{'externalRef': 'demo-${DateTime.now().millisecondsSinceEpoch}', 'livenessTier': _tier, 'matchTier': _several ? 'premium' : _tier, if (!conn.isLive) 'scenario': _scenario};
    if (_withReference) {
      final ref = conn.image(conn.reference, _dummy, what: 'a reference photo');
      if (_several) {
        body['referenceImages'] = [ref, ref];
      } else {
        body['referenceImage'] = ref;
      }
    }
    final created = await conn.send('POST', '/v1/sessions', body);
    if (!created.ok) return created;
    final d = created.map;
    // the service builds checkUrl from its own setting; point it at the address this phone really uses
    final checkUrl = conn.uri(Uri.parse(d['checkUrl'] as String).path).toString();
    if (!mounted) return ApiResult.local('Cancelled.');
    final r = await XtlLiveness.open(context, checkUrl: checkUrl, sdkToken: d['sdkToken'] as String, allowInsecureHttp: conn.insecure);
    final note = switch (r) {
      XtlCompleted() => 'The check finished. This is the verdict from your server, which is what you decide on (never the app).',
      XtlCancelled() => 'The person cancelled.',
      XtlError(:final code) => 'The check reported an error: $code',
    };
    final got = await conn.send('GET', '/v1/sessions/${d['sessionId']}');
    return got.withNote(note, null);
  }

  Future<ApiResult> _match() {
    final body = <String, Object?>{
      'externalRef': 'demo-match',
      'tier': _several ? 'premium' : _tier,
      'image': conn.image(conn.selfie, _dummy, what: 'the photo to check'),
      if (!conn.isLive) 'scenario': _scenario == 'no_match' || _scenario == 'no_face' ? _scenario : 'pass',
    };
    final ref = conn.image(conn.reference, _dummy, what: 'a reference photo');
    if (_several) {
      body['referenceImages'] = [ref, ref];
    } else {
      body['referenceImage'] = ref;
    }
    return conn.send('POST', '/v1/face-match', body);
  }

  List<Fact> _matchFacts(ApiResult r) {
    final d = r.map;
    return [
      Fact('Decision', '${d['decision']}', d['decision'] == 'match' ? Tone.good : Tone.bad),
      Fact('Score', '${score(d['score'])}  (needs ${score(d['threshold'])})'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ListenableBuilder(
        listenable: conn,
        builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NeedKey(conn: conn, goConnect: widget.goConnect),
          Section(
            title: 'Liveness check',
            icon: Icons.face_retouching_natural,
            subtitle: 'Opens the camera check. Your server starts it, the app shows it, and your server reads the verdict.',
            children: [
              if (!conn.isLive) ...[
                const Text('What should the test show?', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final e in _scenarios.entries) ChoiceChip(label: Text(e.key), selected: _scenario == e.key, onSelected: (_) => setState(() => _scenario = e.key)),
                ]),
                Padding(padding: const EdgeInsets.only(top: 6, bottom: 8), child: Text(_scenarios[_scenario]!, style: Theme.of(context).textTheme.bodySmall)),
              ],
              const Text('Tier for this call', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'standard', label: Text('Standard')), ButtonSegment(value: 'premium', label: Text('Premium'))],
                selected: {_tier},
                onSelectionChanged: (s) => setState(() => _tier = s.first),
              ),
              Padding(padding: const EdgeInsets.only(top: 6, bottom: 8), child: Text(_tier == 'premium' ? 'Premium: face images kept 15 days, webhooks sent first. Billed at the premium price.' : 'Standard: no images kept. Each call picks its own tier, so you can mix them.', style: Theme.of(context).textTheme.bodySmall)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Also compare with a reference photo'), subtitle: const Text('Adds a face match after the person is judged live'), value: _withReference, onChanged: (v) => setState(() => _withReference = v)),
              if (_withReference) ...[
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Send several reference photos'), subtitle: const Text('Needs the premium tier: the demo sends it for you'), value: _several, onChanged: (v) => setState(() => _several = v)),
                PhotoTile(label: 'Reference photo', bytes: conn.reference, name: conn.referenceName, sample: conn.isLive ? null : 'a dummy image', onPicked: conn.setReference, onClear: conn.clearReference),
              ],
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : () => run('Liveness check', _check, summary: _verdict), icon: const Icon(Icons.play_arrow), label: const Text('Start liveness check'))),
            ],
          ),
          Section(
            title: 'Face match, no camera',
            icon: Icons.compare,
            subtitle: 'Are these two photos the same person? One call, answered at once.',
            children: [
              PhotoTile(label: 'Photo to check', bytes: conn.selfie, name: conn.selfieName, camera: true, sample: conn.isLive ? null : 'a dummy image', onPicked: conn.setSelfie, onClear: conn.clearSelfie),
              PhotoTile(label: 'Photo to compare with', bytes: conn.reference, name: conn.referenceName, sample: conn.isLive ? null : 'a dummy image', onPicked: conn.setReference, onClear: conn.clearReference),
              SizedBox(width: double.infinity, child: FilledButton.tonalIcon(onPressed: busy ? null : () => run('Face match', _match, summary: _matchFacts), icon: const Icon(Icons.compare_arrows), label: const Text('Compare the photos'))),
            ],
          ),
          ...resultWidgets(),
        ]),
      ),
    );
  }
}
