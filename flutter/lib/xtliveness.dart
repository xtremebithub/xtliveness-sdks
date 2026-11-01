/// Face liveness check for Flutter apps.
///
/// ```dart
/// final result = await XtlLiveness.open(context, checkUrl: session.checkUrl, sdkToken: session.sdkToken);
/// if (result is XtlCompleted) { /* ask YOUR server for the verdict */ }
/// ```
library;

import 'package:flutter/material.dart';

import 'src/check_view.dart';
import 'src/protocol.dart';

export 'src/check_view.dart' show XtlCheckView, xtlSupportedPlatform;
export 'src/protocol.dart' show XtlResult, XtlCompleted, XtlCancelled, XtlError;

class XtlLiveness {
  XtlLiveness._();

  /// Opens the check full screen and returns when the person is done. Closing the screen with Back counts as cancelled.
  /// Completed only means the check ran: the verdict comes from your server (GET /v1/sessions/{id}) or your webhook.
  static Future<XtlResult> open(BuildContext context, {required String checkUrl, required String sdkToken, bool allowInsecureHttp = false}) async {
    parseCheckUrl(checkUrl, allowInsecureHttp: allowInsecureHttp);   // fail early, before any screen opens
    if (!xtlSupportedPlatform) return const XtlError('unsupported_platform');   // desktop apps (Windows, macOS, Linux)
    final result = await Navigator.of(context).push<XtlResult>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: const Text('Face check'), leading: CloseButton(onPressed: () => Navigator.of(ctx).pop(const XtlCancelled()))),
        body: SafeArea(child: XtlCheckView(checkUrl: checkUrl, sdkToken: sdkToken, allowInsecureHttp: allowInsecureHttp, onResult: (r) => Navigator.of(ctx).pop(r))),
      ),
    ));
    return result ?? const XtlCancelled();
  }
}
