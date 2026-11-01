import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'protocol.dart';

/// Flutter web is supported: the check runs in an iframe, in the browser.
bool get xtlSupportedPlatform => true;

int _counter = 0;

/// The check inside an iframe (Flutter web). The browser asks the person for the camera itself, and the page must be served over https (or be
/// localhost). The page that hosts your Flutter app must be listed under "Websites allowed to show your check" in the console.
///
/// The iframe is only ever messaged at the check page's own origin, and only a message from that origin about this session is believed.
class XtlPlatformCheck extends StatefulWidget {
  const XtlPlatformCheck({super.key, required this.check, required this.sessionId, required this.sdkToken, required this.onResult});

  final Uri check;
  final String sessionId;
  final String sdkToken;
  final void Function(XtlResult result) onResult;

  @override
  State<XtlPlatformCheck> createState() => _State();
}

class _State extends State<XtlPlatformCheck> {
  late final String _viewType = 'xtl-check-${_counter++}';
  late final String _origin = widget.check.origin;
  late final web.HTMLIFrameElement _frame;
  late final JSFunction _listener;
  late final JSFunction _onLoad;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _frame = web.HTMLIFrameElement()
      ..src = loadUrl(widget.check, widget.sdkToken).toString()
      ..allow = 'camera; microphone'
      ..title = 'Face check'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => _frame);

    _listener = ((web.MessageEvent e) {
      if (e.origin != _origin) return;
      final data = e.data.dartify();
      if (data is! Map) return;
      final String raw;
      try {
        raw = jsonEncode(data);
      } on Object {
        return;
      }
      final r = parseMessage(raw, widget.sessionId);
      if (r != null) _finish(r);
    }).toJS;
    web.window.addEventListener('message', _listener);

    // the check page waits for this before it sends anything back
    _onLoad = ((web.Event _) {
      _frame.contentWindow?.postMessage({'type': 'xtl:init'}.jsify(), _origin.toJS);
    }).toJS;
    _frame.addEventListener('load', _onLoad);
  }

  void _finish(XtlResult r) {
    if (_done) return;
    _done = true;
    widget.onResult(r);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    _frame.removeEventListener('load', _onLoad);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
