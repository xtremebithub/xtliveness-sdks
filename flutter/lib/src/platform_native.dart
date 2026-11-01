import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'protocol.dart';

/// True on Android and iOS, the platforms with a WebView.
bool get xtlSupportedPlatform => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// The check inside a WebView (Android, iOS). Asks for the camera first, loads the hosted check and listens on the XtlBridge channel.
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
  WebViewController? _controller;
  FlutterTts? _tts;

  /// The check page asks the app to read its instructions aloud (the WebView's own speech is often silent). True when the message was a speech request.
  bool _speak(String raw) {
    final Object? d;
    try { d = jsonDecode(raw); } on FormatException { return false; }
    if (d is Map && d['type'] == 'xtl:log') {
      debugPrint('xtliveness: page texts: ${d['rows']}');
      return true;
    }
    if (d is! Map || d['type'] != 'xtl:speak') return false;
    final Map m = d;   // d is only promoted to a Map here, not inside the closure below
    final text = m['text'];
    final tts = _tts ??= FlutterTts();
    () async {
      try {
        await tts.stop();
        if (text is String && text.isNotEmpty) {
          final lang = m['lang'];
          if (lang is String && lang.isNotEmpty) { await tts.setLanguage(lang); }
          final r = await tts.speak(text);
          debugPrint('xtliveness: speak "$text" -> $r');
        }
      } catch (e) { debugPrint('xtliveness: speech failed: $e'); /* the check still works */ }
    }();
    return true;
  }
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Start the speech engine now: the first sentence is lost if it is asked to speak before the engine has connected.
    _tts = FlutterTts();
    unawaited(_tts!.setSpeechRate(0.5).catchError((Object _) => 0));
    unawaited(_start());
  }

  void _finish(XtlResult r) {
    if (_done) return;
    _done = true;
    widget.onResult(r);
  }

  Future<void> _start() async {
    if (!xtlSupportedPlatform) {
      _finish(const XtlError('unsupported_platform'));
      return;
    }
    // The camera first: a refusal is reported at once instead of leaving a blank page.
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      _finish(const XtlError('camera_denied'));
      return;
    }
    // The check speaks its instructions and plays a tone at the end: let the WebView play sound without a fresh tap (both platforms block it by default).
    final PlatformWebViewControllerCreationParams params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true, mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{})
        : const PlatformWebViewControllerCreationParams();
    final c = WebViewController.fromPlatformCreationParams(params, onPermissionRequest: (request) => request.grant())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel('XtlBridge', onMessageReceived: (m) {
        if (_speak(m.message)) return;
        final r = parseMessage(m.message, widget.sessionId);
        if (r != null) _finish(r);
      })
      ..setNavigationDelegate(NavigationDelegate(
        // the page stays on the check's own address; anything else is refused
        onNavigationRequest: (req) {
          final to = Uri.tryParse(req.url);
          return to != null && sameOrigin(to, widget.check) ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
        onPageFinished: (_) {
          debugPrint('xtliveness: page finished, native speech on');
          _controller?.runJavaScript('window.xtlNativeSpeech = true;');
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? false) _finish(const XtlError('load_failed'));
        },
      ));
    final platform = c.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }
    _controller = c;   // set before loading: onPageFinished below uses it
    await c.loadRequest(loadUrl(widget.check, widget.sdkToken));
    if (mounted) setState(() => _controller = c);
  }

  @override
  void dispose() {
    _tts?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return c == null ? const ColoredBox(color: Colors.white, child: Center(child: CircularProgressIndicator())) : WebViewWidget(controller: c);
  }
}
