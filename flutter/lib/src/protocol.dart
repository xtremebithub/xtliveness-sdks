/// The rules shared by the widget and its tests. No Flutter imports, so they can be tested alone.
library;

import 'dart:convert';

/// What the hosted check reports. It never carries the verdict: your server learns that from the API or the webhook.
sealed class XtlResult {
  const XtlResult();
}

/// The person finished the check. Ask YOUR server for the verdict (GET /v1/sessions/{sessionId}); never decide from this.
class XtlCompleted extends XtlResult {
  const XtlCompleted(this.sessionId);
  final String sessionId;
}

class XtlCancelled extends XtlResult {
  const XtlCancelled();
}

/// [code] is one of: token_invalid, token_used, session_expired, session_not_open, engine_unavailable, timeout, missing_token,
/// camera_denied, load_failed, unsupported_platform, error.
class XtlError extends XtlResult {
  const XtlError(this.code);
  final String code;
}

final RegExp _checkPath = RegExp(r'^/check/[0-9a-fA-F-]{36}$');

/// Checks the address your server got from POST /v1/sessions and returns it parsed. Throws [ArgumentError] when it is not a check
/// address: https only. Plain http is accepted for localhost, and for any host only when [allowInsecureHttp] is set (development against a
/// service on your own network; never in a release).
Uri parseCheckUrl(String raw, {bool allowInsecureHttp = false}) {
  final Uri url;
  try {
    url = Uri.parse(raw);
  } on FormatException {
    throw ArgumentError.value(raw, 'checkUrl', 'is not a valid URL');
  }
  final local = url.host == 'localhost' || url.host == '127.0.0.1';
  if (!(url.scheme == 'https' || (url.scheme == 'http' && (local || allowInsecureHttp)))) {
    throw ArgumentError.value(raw, 'checkUrl', 'must be https');
  }
  if (!_checkPath.hasMatch(url.path)) {
    throw ArgumentError.value(raw, 'checkUrl', 'is not a check address');
  }
  return url;
}

/// The session id inside a check address.
String sessionIdOf(Uri checkUrl) => checkUrl.pathSegments.last.toLowerCase();

/// Where the WebView is sent. The one-time token rides in the fragment: it is never sent to a server or written to a log.
Uri loadUrl(Uri checkUrl, String sdkToken) {
  if (sdkToken.isEmpty) {
    throw ArgumentError.value(sdkToken, 'sdkToken', 'is required');
  }
  return Uri(
    scheme: checkUrl.scheme,
    host: checkUrl.host,
    port: checkUrl.hasPort ? checkUrl.port : null,
    path: checkUrl.path,
    fragment: 't=${Uri.encodeQueryComponent(sdkToken)}',
  );
}

/// Reads one message from the page's XtlBridge channel. Returns null for anything that is not a result for this session.
XtlResult? parseMessage(String raw, String expectedSessionId) {
  final Object? data;
  try {
    data = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (data is! Map || data['type'] != 'xtl:result') return null;
  if ('${data['sessionId']}'.toLowerCase() != expectedSessionId.toLowerCase()) return null;
  switch (data['status']) {
    case 'completed':
      return XtlCompleted('${data['sessionId']}');
    case 'cancelled':
      return const XtlCancelled();
    case 'error':
      final code = data['code'];
      return XtlError(code is String && code.isNotEmpty ? code : 'error');
    default:
      return null;
  }
}

/// A page may only stay on the check's own address.
bool sameOrigin(Uri a, Uri b) => a.scheme == b.scheme && a.host == b.host && a.port == b.port;
