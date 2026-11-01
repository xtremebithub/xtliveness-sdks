import 'package:flutter/material.dart';
import 'package:xtliveness/xtliveness.dart';

import '../conn.dart';
import '../ui.dart';

const _modes = <String, String>{
  'search_then_enroll': 'Catch a duplicate, otherwise enrol the person.',
  'search': 'Who looks like this face? Nobody is added.',
  'enroll': 'Add this face under the person reference.',
  'authenticate': 'Is this the enrolled person? (1:1)',
};

/// Face search (1:N): private collections of faces on your account. Walk through it in order, or run it after a liveness check.
class SearchTab extends StatefulWidget {
  const SearchTab({super.key, required this.conn, required this.goConnect});
  final Conn conn;
  final VoidCallback goConnect;
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> with Runner<SearchTab> {
  @override
  Conn get conn => widget.conn;

  final _collection = TextEditingController(text: 'practice');
  final _person = TextEditingController(text: 'ann');
  final _attributes = TextEditingController();
  String _mode = 'search_then_enroll';
  String _face = 'test:face-a';
  bool _premiumEnrol = false;

  String get _name => _collection.text.trim();
  String get _ref => _person.text.trim();
  String get _photo => conn.image(conn.selfie, _face, what: 'the photo to use');
  Map<String, String> get _attrs => {
        for (final part in _attributes.text.split(','))
          if (part.contains('=') && part.split('=').first.trim().isNotEmpty) part.split('=').first.trim(): part.substring(part.indexOf('=') + 1).trim(),
      };

  Future<void> _go(String title, String method, String path, {Map<String, Object?>? body, required List<Fact> Function(ApiResult) summary, bool billed = true}) =>
      run(title, () async => conn.send(method, path, body), summary: summary, billed: billed);

  List<Fact> _created(ApiResult r) => [Fact('Collection', '${r.map['name'] ?? _name}', Tone.good)];

  List<Fact> _searchFacts(ApiResult r) {
    final d = r.map;
    final matches = d['matches'] is List ? d['matches'] as List : const [];
    return [
      Fact('Found', matches.isEmpty ? 'nobody looks like this face' : '${matches.length} possible match${matches.length == 1 ? '' : 'es'}', matches.isEmpty ? Tone.plain : Tone.warn),
      for (final m in matches.take(5))
        if (m is Map) Fact('  ${m['personRef']}', '${score(m['score'])}${m['attributes'] is Map && (m['attributes'] as Map).isNotEmpty ? '  ${m['attributes']}' : ''}'),
    ];
  }

  List<Fact> _enrolFacts(ApiResult r) {
    final d = r.map;
    return [Fact('Person', '${d['personRef'] ?? _ref}'), Fact('Enrolled', '${d['enrolled'] ?? true}', Tone.good)];
  }

  List<Fact> _authFacts(ApiResult r) {
    final d = r.map;
    return [Fact('Same person', d['match'] == true ? 'yes' : 'no', d['match'] == true ? Tone.good : Tone.bad), Fact('Score', score(d['score']))];
  }

  List<Fact> _listFacts(ApiResult r) {
    final list = r.data is List ? r.data as List : const [];
    return [
      Fact('Collections', '${list.length}'),
      for (final c in list.take(8))
        if (c is Map) Fact('  ${c['name']}', '${c['people'] ?? 0} people · ${c['environment']}'),
    ];
  }

  List<Fact> _removed(ApiResult r) => [Fact('Done', 'removed', Tone.good)];

  Future<ApiResult> _afterLiveness() async {
    final body = <String, Object?>{
      'externalRef': 'demo-fs-${DateTime.now().millisecondsSinceEpoch}',
      if (!conn.isLive) 'scenario': 'pass',
      'faceSearch': {'collection': _name, 'mode': _mode, if (_mode != 'search' || _ref.isNotEmpty) 'personRef': _ref, if (!conn.isLive) 'testFace': _face, if (_premiumEnrol) 'tier': 'premium'},
    };
    final created = await conn.send('POST', '/v1/sessions', body);
    if (!created.ok) return created;
    final d = created.map;
    final checkUrl = conn.uri(Uri.parse(d['checkUrl'] as String).path).toString();
    if (!mounted) return ApiResult.local('Cancelled.');
    final r = await XtlLiveness.open(context, checkUrl: checkUrl, sdkToken: d['sdkToken'] as String, allowInsecureHttp: conn.insecure);
    final note = switch (r) {
      XtlCompleted() => 'The check finished. The search or enrolment ran on the live face.',
      XtlCancelled() => 'The person cancelled.',
      XtlError(:final code) => 'The check reported an error: $code',
    };
    return (await conn.send('GET', '/v1/sessions/${d['sessionId']}')).withNote(note, null);
  }

  List<Fact> _afterFacts(ApiResult r) {
    final d = r.map;
    final l = d['liveness'];
    final fs = d['faceSearch'];
    return [
      if (l is Map) Fact('Liveness', '${l['decision']}  ·  ${score(l['score'])}', l['decision'] == 'live' ? Tone.good : Tone.bad),
      if (fs is Map) ...[
        Fact('Face search', '${fs['status']}  (${fs['mode'] ?? _mode})'),
        if (fs['matches'] is List) Fact('Matches', '${(fs['matches'] as List).length}', (fs['matches'] as List).isEmpty ? Tone.plain : Tone.warn),
        if (fs['enrolled'] != null) Fact('Enrolled', '${fs['enrolled']}'),
        if (fs['match'] != null) Fact('Same person', '${fs['match']}', fs['match'] == true ? Tone.good : Tone.bad),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = '/v1/face-search/collections';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ListenableBuilder(
        listenable: conn,
        builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NeedKey(conn: conn, goConnect: widget.goConnect),
          Section(
            title: 'Your practice names',
            icon: Icons.folder_shared_outlined,
            subtitle: 'Face search needs to be switched on for the account. A collection is a private group of faces; the person reference is your own id for someone in it.',
            children: [
              TextField(controller: _collection, autocorrect: false, decoration: deco('Collection', helper: 'a-z, 0-9, _ and -, up to 40 characters')),
              const SizedBox(height: 12),
              TextField(controller: _person, autocorrect: false, decoration: deco('Person reference', helper: 'Enrolling the same reference again replaces the face')),
              const SizedBox(height: 12),
              TextField(controller: _attributes, autocorrect: false, decoration: deco('Attributes when enrolling (optional)', hint: 'case=214, tag=vip', helper: 'Adding any makes this a premium enrolment')),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Premium enrolment'), subtitle: const Text('Billed at the premium price. Chosen per call: standard enrolments work at the same time.'), value: _premiumEnrol || _attrs.isNotEmpty, onChanged: (v) => setState(() => _premiumEnrol = v)),
              const SizedBox(height: 14),
              if (!conn.isLive) ...[
                const Text('Which simulated person?', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'test:face-a', label: Text('Person A')), ButtonSegment(value: 'test:face-b', label: Text('Person B'))],
                  selected: {_face},
                  onSelectionChanged: (s) => setState(() => _face = s.first),
                ),
              ] else
                PhotoTile(label: 'Photo to use', bytes: conn.selfie, name: conn.selfieName, camera: true, onPicked: conn.setSelfie, onClear: conn.clearSelfie),
            ],
          ),
          Section(
            title: 'Walk through it',
            icon: Icons.format_list_numbered,
            subtitle: 'Run these in order. Try Person A for steps 2 to 4, then Person B for step 3 and 4 to see a miss.',
            children: [
              StepTile(n: '1', title: 'Create the collection', text: 'Once per purpose, for example signups.', onPressed: busy ? null : () => _go('Create collection', 'POST', c, body: {'name': _name}, summary: _created)),
              StepTile(n: '2', title: 'Enrol a person', text: 'Add the face under the person reference.', onPressed: busy ? null : () => run('Enrol a person', () async => conn.send('POST', '$c/$_name/people', {'personRef': _ref, 'image': _photo, if (_attrs.isNotEmpty || _premiumEnrol) 'tier': 'premium', if (_attrs.isNotEmpty) 'attributes': _attrs}), summary: _enrolFacts)),
              StepTile(n: '3', title: 'Search', text: 'Who looks like this photo? Never adds anyone.', onPressed: busy ? null : () => run('Search', () async => conn.send('POST', '$c/$_name/search', {'image': _photo}), summary: _searchFacts)),
              StepTile(n: '4', title: 'Authenticate (1:1)', text: 'Is this photo that enrolled person?', onPressed: busy ? null : () => run('Authenticate', () async => conn.send('POST', '$c/$_name/people/${Uri.encodeComponent(_ref)}/authenticate', {'image': _photo}), summary: _authFacts)),
            ],
          ),
          Section(
            title: 'After a liveness check',
            icon: Icons.face_retouching_natural,
            subtitle: 'The same search or enrolment, run on the live face once the person passes. A spoof is never searched or enrolled.',
            children: [
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final e in _modes.keys) ChoiceChip(label: Text(e), selected: _mode == e, onSelected: (_) => setState(() => _mode = e)),
              ]),
              Padding(padding: const EdgeInsets.only(top: 8, bottom: 12), child: Text(_modes[_mode]!, style: Theme.of(context).textTheme.bodySmall)),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : () => run('Liveness check + face search', _afterLiveness, summary: _afterFacts), icon: const Icon(Icons.play_arrow), label: const Text('Start check'))),
            ],
          ),
          Section(
            title: 'Look after your data',
            icon: Icons.cleaning_services_outlined,
            subtitle: 'Forget a person when they ask, or remove a whole collection.',
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton(onPressed: busy ? null : () => run('Your collections', () async => conn.send('GET', c), summary: _listFacts, billed: false), child: const Text('List collections')),
                OutlinedButton(onPressed: busy ? null : () => run('Remove person', () async => conn.send('DELETE', '$c/$_name/people/${Uri.encodeComponent(_ref)}'), summary: _removed, billed: false), child: const Text('Remove person')),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: bad),
                  onPressed: busy ? null : () => run('Delete collection', () async => conn.send('DELETE', '$c/$_name'), summary: _removed, billed: false),
                  child: const Text('Delete collection'),
                ),
              ]),
            ],
          ),
          ...resultWidgets(),
        ]),
      ),
    );
  }
}
