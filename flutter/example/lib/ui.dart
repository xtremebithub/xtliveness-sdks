// Shared look and small building blocks, so every tab reads the same way.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'conn.dart';

const brand = Color(0xFF0F766E);
const good = Color(0xFF15803D);
const bad = Color(0xFFB91C1C);
const warn = Color(0xFFB45309);

enum Tone { good, bad, warn, plain }

Color toneColor(BuildContext c, Tone t) => switch (t) {
      Tone.good => good,
      Tone.bad => bad,
      Tone.warn => warn,
      Tone.plain => Theme.of(c).colorScheme.onSurface,
    };

class Fact {
  const Fact(this.label, this.value, [this.tone = Tone.plain]);
  final String label;
  final String value;
  final Tone tone;
}

InputDecoration deco(String label, {String? hint, String? helper, IconData? icon}) => InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 3,
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    );

/// A titled card. Everything in the demo sits in one of these.
class Section extends StatelessWidget {
  const Section({super.key, required this.title, this.subtitle, this.icon, required this.children});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[
              CircleAvatar(radius: 18, backgroundColor: t.colorScheme.primaryContainer, child: Icon(icon, size: 20, color: t.colorScheme.onPrimaryContainer)),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 14),
          ...children,
        ]),
      ),
    );
  }
}

/// A numbered step with a button, for the walk-through style of the face search tab.
class StepTile extends StatelessWidget {
  const StepTile({super.key, required this.n, required this.title, required this.text, required this.onPressed, this.label = 'Run'});
  final String n;
  final String title;
  final String text;
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        CircleAvatar(radius: 14, backgroundColor: t.colorScheme.secondaryContainer, child: Text(n, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.colorScheme.onSecondaryContainer))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(text, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        ])),
        const SizedBox(width: 8),
        FilledButton.tonal(onPressed: onPressed, child: Text(label)),
      ]),
    );
  }
}

/// Which kind of key is pasted, and what that means for the person using the demo.
class KeyBadge extends StatelessWidget {
  const KeyBadge({super.key, required this.conn});
  final Conn conn;

  @override
  Widget build(BuildContext context) {
    final (String text, Color color, IconData icon) = conn.isTest
        ? ('TEST key · free', good, Icons.science_outlined)
        : conn.isLive
            ? ('LIVE key · billed', warn, Icons.bolt)
            : ('No key yet', Colors.grey, Icons.key_off_outlined);
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      side: BorderSide(color: color),
      backgroundColor: Colors.transparent,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Shown at the top of a tab until a key is pasted.
class NeedKey extends StatelessWidget {
  const NeedKey({super.key, required this.conn, required this.goConnect});
  final Conn conn;
  final VoidCallback goConnect;

  @override
  Widget build(BuildContext context) {
    if (conn.hasKey) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.tertiaryContainer,
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading: const Icon(Icons.key),
        title: const Text('Add an API key first'),
        subtitle: const Text('A test key (xtl_test_…) is free and needs no real photos.'),
        trailing: TextButton(onPressed: goConnect, child: const Text('Add key')),
      ),
    );
  }
}

/// A photo chooser: thumbnail, gallery, camera, remove.
class PhotoTile extends StatelessWidget {
  const PhotoTile({super.key, required this.label, required this.bytes, required this.name, required this.onPicked, required this.onClear, this.camera = false, this.sample});
  final String label;
  final Uint8List? bytes;
  final String name;
  final void Function(Uint8List bytes, String name) onPicked;
  final VoidCallback onClear;
  final bool camera;
  final String? sample;   // what a test key uses when nothing is picked

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final f = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85, preferredCameraDevice: CameraDevice.front);
      if (f == null) return;
      onPicked(await f.readAsBytes(), f.name);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get the photo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: t.colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 64,
            height: 64,
            child: bytes == null
                ? ColoredBox(color: t.colorScheme.surfaceContainerHighest, child: Icon(Icons.face_retouching_natural, color: t.colorScheme.onSurfaceVariant))
                : Image.memory(bytes!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(bytes == null ? (sample == null ? 'Nothing chosen' : 'Using the built-in sample ($sample) with a test key') : name,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          Wrap(spacing: 4, children: [
            TextButton.icon(onPressed: () => _pick(context, ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('Choose')),
            if (camera) TextButton.icon(onPressed: () => _pick(context, ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined, size: 18), label: const Text('Camera')),
            if (bytes != null) TextButton(onPressed: onClear, child: const Text('Remove')),
          ]),
        ])),
      ]),
    );
  }
}

/// The answer to the last call: a headline, the facts that matter, and the full reply underneath.
class ResultPanel extends StatelessWidget {
  const ResultPanel({super.key, required this.title, required this.result, required this.facts});
  final String title;
  final ApiResult result;
  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ok = result.ok;
    final Color c = ok ? good : bad;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: Color.alphaBlend(c.withAlpha(18), t.colorScheme.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.withAlpha(120))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(ok ? Icons.check_circle : Icons.error, color: c),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            if (result.status > 0) Text('${result.status}', style: TextStyle(color: c, fontWeight: FontWeight.w700)),
          ]),
          if (result.note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(result.note!)),
          if (!ok) Padding(padding: const EdgeInsets.only(top: 8), child: Text(result.problem, style: TextStyle(color: c, fontWeight: FontWeight.w600))),
          if (ok && result.map['photo'] is String) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(base64Decode(result.map['photo'] as String), width: 110, height: 140, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
            Text('Photo on the ID', style: t.textTheme.bodySmall),
          ],
          if (ok && facts.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final f in facts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 120, child: Text(f.label, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant))),
                  Expanded(child: Text(f.value, style: TextStyle(fontWeight: FontWeight.w700, color: toneColor(context, f.tone)))),
                ]),
              ),
          ],
          const SizedBox(height: 6),
          Theme(
            data: t.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Full reply${result.request == null ? '' : ' · ${result.request}'}', style: t.textTheme.bodyMedium),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                  child: SelectableText(result.pretty, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: result.pretty));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Ask before anything that is billed. Test keys never ask.
Future<bool> confirmLive(BuildContext context) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.bolt, color: warn),
      title: const Text('This uses a live key'),
      content: const Text('It runs a real check and is billed to the account. Use a test key to try things for free.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Run it')),
      ],
    ),
  );
  return go == true;
}

/// What every tab does when a button is pressed: check the key, ask if billed, show progress, keep the answer, scroll to it.
mixin Runner<T extends StatefulWidget> on State<T> {
  Conn get conn;
  final GlobalKey resultKey = GlobalKey();
  bool busy = false;
  ApiResult? result;
  String resultTitle = '';
  List<Fact> facts = const [];

  Future<void> run(String title, Future<ApiResult> Function() job, {required List<Fact> Function(ApiResult) summary, bool billed = true}) async {
    if (!conn.hasKey) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an API key on the Connect tab first.')));
      return;
    }
    if (billed && conn.isLive && !await confirmLive(context)) return;
    if (!mounted) return;
    setState(() => busy = true);
    ApiResult r;
    try {
      r = await job();
    } on ApiProblem catch (e) {
      r = ApiResult.local(e.message);
    } catch (e) {
      r = ApiResult.local('Something went wrong: $e');
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      result = r;
      resultTitle = title;
      facts = r.ok ? summary(r) : const [];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = resultKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  /// The result card and the busy bar, to put at the end of a tab's list.
  List<Widget> resultWidgets() => [
        if (busy) const Padding(padding: EdgeInsets.only(bottom: 14), child: LinearProgressIndicator()),
        if (result != null && !busy) KeyedSubtree(key: resultKey, child: ResultPanel(title: resultTitle, result: result!, facts: facts)),
      ];
}

String score(Object? v) => v is num ? v.toStringAsFixed(1) : '—';
