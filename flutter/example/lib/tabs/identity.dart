import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xtliveness/xtliveness.dart';

import '../conn.dart';
import '../ui.dart';

/// BVN and NIN: is the number valid, who is it, and is this selfie the person on the ID. You send only the number.
class IdentityTab extends StatefulWidget {
  const IdentityTab({super.key, required this.conn, required this.goConnect});
  final Conn conn;
  final VoidCallback goConnect;
  @override
  State<IdentityTab> createState() => _IdentityTabState();
}

class _IdentityTabState extends State<IdentityTab> with Runner<IdentityTab> {
  @override
  Conn get conn => widget.conn;

  final _number = TextEditingController(text: '22212345678');
  String _type = 'bvn';
  String _level = 'basic';
  String _face = 'test:face-a';
  bool _consent = true;                                   // the person agreed: live calls need it unless the account switched that off
  final _consentRef = TextEditingController(text: 'demo-consent');
  bool _idem = false;                                     // send an Idempotency-Key so a repeated tap is not billed twice
  String _idemBase = _newKey();

  static String _newKey() => 'demo-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _number.dispose();
    _consentRef.dispose();
    super.dispose();
  }

  String get _n => _number.text.trim();

  void _check() {
    if (!RegExp(r'^[0-9]{11}$').hasMatch(_n)) throw ApiProblem('Enter the 11 digits of the ${_type.toUpperCase()}.');
  }

  Future<ApiResult> _call(String path, Map<String, Object?> extra) async {
    _check();
    return conn.send(
      'POST',
      '/v1/identity/$path',
      {'type': _type, 'number': _n, 'externalRef': 'demo-${DateTime.now().millisecondsSinceEpoch}', if (_consent) 'consent': _consentBody(), ...extra},
      _idem ? {'Idempotency-Key': '$_idemBase-$path'} : null,   // one key per kind of call: the same key for another kind would be refused
    );
  }

  Map<String, Object?> _consentBody() => {'given': true, 'reference': _consentRef.text.trim().isEmpty ? 'demo-consent' : _consentRef.text.trim()};

  List<Fact> _validFacts(ApiResult r) => [Fact('This ${_type.toUpperCase()}', r.map['valid'] == true ? 'is valid' : 'is not valid', r.map['valid'] == true ? Tone.good : Tone.bad)];

  static const _labels = {
    'firstName': 'First name', 'middleName': 'Middle name', 'lastName': 'Last name', 'dateOfBirth': 'Date of birth', 'gender': 'Gender', 'phone': 'Phone',
    'email': 'Email', 'address': 'Address', 'nationality': 'Nationality', 'stateOfOrigin': 'State of origin', 'lgaOfOrigin': 'LGA of origin',
    'stateOfResidence': 'State of residence', 'maritalStatus': 'Marital status',
  };

  List<Fact> _lookupFacts(ApiResult r) {
    final d = r.map;
    if (d['found'] != true) return [const Fact('Found', 'no such person', Tone.bad)];
    final data = d['data'] is Map ? d['data'] as Map : const {};
    return [
      const Fact('Found', 'yes', Tone.good),
      for (final e in _labels.entries)
        if (data[e.key] != null) Fact(e.value, '${data[e.key]}'),
    ];
  }

  List<Fact> _faceFacts(ApiResult r) {
    final d = r.map;
    if (d['found'] != true) return [const Fact('Found', 'no such person', Tone.bad)];
    return [
      Fact('Selfie', d['match'] == true ? 'is the person on the ID' : 'is not the person on the ID', d['match'] == true ? Tone.good : Tone.bad),
      Fact('Score', '${score(d['score'])}  (needs ${score(d['threshold'])})'),
    ];
  }

  /// No selfie to upload: the person does a liveness check and is compared with the photo on the ID.
  Future<ApiResult> _live() async {
    _check();
    final created = await conn.send('POST', '/v1/sessions', {
      'externalRef': 'demo-id-live',
      'identity': {'type': _type, 'number': _n, if (_consent) 'consent': _consentBody()},
      if (!conn.isLive) 'scenario': 'pass',
    });
    if (!created.ok) return created;
    final d = created.map;
    final checkUrl = conn.uri(Uri.parse(d['checkUrl'] as String).path).toString();
    if (!mounted) return ApiResult.local('Cancelled.');
    final r = await XtlLiveness.open(context, checkUrl: checkUrl, sdkToken: d['sdkToken'] as String, allowInsecureHttp: conn.insecure);
    final note = switch (r) {
      XtlCompleted() => 'The check finished. Read the verdict from your server.',
      XtlCancelled() => 'The person cancelled.',
      XtlError(:final code) => 'The check reported an error: $code',
    };
    final got = await conn.send('GET', '/v1/sessions/${d['sessionId']}');
    return got.withNote(note, null);
  }

  List<Fact> _liveFacts(ApiResult r) {
    final d = r.map;
    final l = d['liveness'], m = d['match'];
    return [
      Fact('Status', '${d['status'] ?? '—'}'),
      if (l is Map) Fact('Liveness', '${l['decision']}  ·  ${score(l['score'])}', l['decision'] == 'live' ? Tone.good : Tone.bad),
      if (m is Map && m['decision'] != 'not_requested') Fact('Against the ID', '${m['decision']}  ·  ${score(m['score'])}', m['decision'] == 'match' ? Tone.good : Tone.bad),
      if (d['failureReason'] != null) Fact('Reason', '${d['failureReason']}', Tone.warn),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ListenableBuilder(
        listenable: conn,
        builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NeedKey(conn: conn, goConnect: widget.goConnect),
          Section(
            title: 'The ID',
            icon: Icons.badge_outlined,
            subtitle: 'You send only the number. The Identity product must be on the account.',
            children: [
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'bvn', label: Text('BVN')), ButtonSegment(value: 'nin', label: Text('NIN'))],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _number,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                decoration: deco('${_type.toUpperCase()} number', hint: '11 digits', icon: Icons.numbers, helper: conn.isLive ? 'A real lookup: it is billed and the person should have agreed to it.' : 'Test mode: any 11 digits is a made-up person. A number ending 0000 is not found.'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('The person agreed to this check'),
                subtitle: const Text('Live calls are refused without it. We keep your reference with the check.'),
                value: _consent,
                onChanged: (v) => setState(() => _consent = v),
              ),
              if (_consent) TextField(controller: _consentRef, decoration: deco('Your reference for their agreement', icon: Icons.fact_check_outlined)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Send an Idempotency-Key'),
                subtitle: const Text('Tap a button twice: the second answer is the same and is not billed again.'),
                value: _idem,
                onChanged: (v) => setState(() { _idem = v; _idemBase = _newKey(); }),
              ),
              if (_idem) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => _idemBase = _newKey()), icon: const Icon(Icons.refresh), label: const Text('Start a new request (new key)'))),
            ],
          ),
          Section(
            title: 'Is it valid?',
            icon: Icons.verified_outlined,
            subtitle: 'True or false. No details are returned.',
            children: [
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : () => run('Validate', () => _call('validate', {}), summary: _validFacts), icon: const Icon(Icons.check), label: const Text('Validate'))),
            ],
          ),
          Section(
            title: 'Who is it?',
            icon: Icons.person_search_outlined,
            subtitle: 'The details on record. Advanced adds email, address and place of origin and costs more.',
            children: [
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'basic', label: Text('Basic')), ButtonSegment(value: 'advanced', label: Text('Advanced'))],
                selected: {_level},
                onSelectionChanged: (s) => setState(() => _level = s.first),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : () => run('Look up', () => _call('lookup', {'level': _level, 'includePhoto': true}), summary: _lookupFacts), icon: const Icon(Icons.search), label: const Text('Look up'))),
            ],
          ),
          Section(
            title: 'Is this selfie the person?',
            icon: Icons.face_outlined,
            subtitle: 'The selfie is compared with the photo on the ID.',
            children: [
              if (!conn.isLive) ...[
                Text('Which simulated selfie? The photo on every test ID is Person A.', style: t.textTheme.bodyMedium),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'test:face-a', label: Text('Person A')), ButtonSegment(value: 'test:face-b', label: Text('Person B'))],
                  selected: {_face},
                  onSelectionChanged: (s) => setState(() => _face = s.first),
                ),
                const SizedBox(height: 12),
              ] else
                PhotoTile(label: 'Selfie', bytes: conn.selfie, name: conn.selfieName, camera: true, onPicked: conn.setSelfie, onClear: conn.clearSelfie),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : () => run('Selfie match', () => _call('face-match', {'image': conn.image(conn.selfie, _face, what: 'a selfie')}), summary: _faceFacts),
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Match the selfie'),
                ),
              ),
            ],
          ),
          Section(
            title: 'Match a live person',
            icon: Icons.videocam_outlined,
            subtitle: 'No selfie to upload: the person does a liveness check and their face is compared with the photo on the ID. Billed once, as the ID face match.',
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : () => run('Live match', _live, summary: _liveFacts),
                  icon: const Icon(Icons.face_retouching_natural),
                  label: const Text('Start the live check'),
                ),
              ),
            ],
          ),
          ...resultWidgets(),
        ]),
      ),
    );
  }
}
