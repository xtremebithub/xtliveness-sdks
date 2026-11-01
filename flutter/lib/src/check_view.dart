import 'package:flutter/material.dart';

import 'platform_native.dart' if (dart.library.js_interop) 'platform_web.dart';
import 'protocol.dart';

export 'platform_native.dart' if (dart.library.js_interop) 'platform_web.dart' show xtlSupportedPlatform;

/// The face check, inside your own screen. On Android and iOS it runs in a WebView and asks for the camera; on Flutter web it runs in an iframe.
///
/// [checkUrl] and [sdkToken] come from `POST /v1/sessions` on YOUR server (never call that from the app: it needs your API key).
/// Use the token once. [onResult] runs once.
class XtlCheckView extends StatefulWidget {
  const XtlCheckView({super.key, required this.checkUrl, required this.sdkToken, required this.onResult, this.allowInsecureHttp = false});

  final String checkUrl;
  final String sdkToken;
  final void Function(XtlResult result) onResult;

  /// Development only: accept a plain http check address on any host (for example an emulator reaching your machine at 10.0.2.2).
  final bool allowInsecureHttp;

  @override
  State<XtlCheckView> createState() => _XtlCheckViewState();
}

class _XtlCheckViewState extends State<XtlCheckView> {
  late final Uri _check = parseCheckUrl(widget.checkUrl, allowInsecureHttp: widget.allowInsecureHttp);
  late final String _sessionId = sessionIdOf(_check);

  @override
  Widget build(BuildContext context) => XtlPlatformCheck(check: _check, sessionId: _sessionId, sdkToken: widget.sdkToken, onResult: widget.onResult);
}
