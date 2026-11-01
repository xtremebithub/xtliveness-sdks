// The connection every tab shares: where the service is, which API key to use, the photos picked, and the one place that calls the API.
// In a real app this part lives on YOUR server. The demo does it from the phone only so you can try everything from one place.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// A problem the person can fix (a missing photo, say), shown instead of a call.
class ApiProblem implements Exception {
  ApiProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What the service answered, or why there was no answer.
class ApiResult {
  ApiResult({required this.status, this.body, this.raw = '', this.note, this.request});

  /// A result made on the phone (no call was made or it could not be read).
  ApiResult.local(String message)
      : status = 0,
        body = {'success': false, 'message': message, 'errors': <Object?>[]},
        raw = message,
        note = null,
        request = null;

  final int status;
  final Map<String, dynamic>? body;
  final String raw;
  final String? note;     // for example "The person cancelled."
  final String? request;  // "POST /v1/identity/validate", shown above the reply

  bool get ok => status >= 200 && status < 300 && body != null && body!['success'] != false;
  Object? get data => body?['data'];
  Map<String, dynamic> get map => data is Map<String, dynamic> ? data as Map<String, dynamic> : <String, dynamic>{};
  String get message => (body?['message'] ?? '').toString();

  /// The first error the service gave, in its own words.
  String get problem {
    final errors = body?['errors'];
    if (errors is List && errors.isNotEmpty && errors.first is Map) {
      final e = errors.first as Map;
      return (e['message'] ?? e['code'] ?? 'The request failed.').toString();
    }
    if (message.isNotEmpty) return message;
    return status == 0 ? 'No answer from the service.' : 'The service answered $status.';
  }

  String get pretty => body == null ? raw : const JsonEncoder.withIndent('  ').convert(body);

  ApiResult withNote(String? n, String? req) => ApiResult(status: status, body: body, raw: raw, note: n ?? note, request: req ?? request);
}

class Conn extends ChangeNotifier {
  Conn() {
    base.addListener(notifyListeners);
    key.addListener(notifyListeners);
  }

  // Override at build time:  flutter run --dart-define=XTL_BASE=https://... --dart-define=XTL_KEY=xtl_test_...
  final base = TextEditingController(text: const String.fromEnvironment('XTL_BASE', defaultValue: 'https://liveness.xtremebithub.com'));
  final key = TextEditingController(text: const String.fromEnvironment('XTL_KEY'));

  Uint8List? selfie, reference;
  String selfieName = '', referenceName = '';

  bool get isTest => key.text.trim().startsWith('xtl_test_');
  bool get isLive => key.text.trim().startsWith('xtl_live_');
  bool get hasKey => isTest || isLive;
  bool get insecure => base.text.trim().startsWith('http://');

  Uri uri(String path) => Uri.parse('${base.text.trim().replaceAll(RegExp(r'/+$'), '')}$path');
  Map<String, String> get headers => {'Authorization': 'Bearer ${key.text.trim()}', 'Content-Type': 'application/json'};

  void setSelfie(Uint8List bytes, String name) {
    selfie = bytes;
    selfieName = name;
    notifyListeners();
  }

  void setReference(Uint8List bytes, String name) {
    reference = bytes;
    referenceName = name;
    notifyListeners();
  }

  void clearSelfie() {
    selfie = null;
    selfieName = '';
    notifyListeners();
  }

  void clearReference() {
    reference = null;
    referenceName = '';
    notifyListeners();
  }

  /// The photo to send: the one picked, else (test key only) a built-in sample such as test:face-a.
  String image(Uint8List? picked, String sample, {String what = 'a photo'}) {
    if (picked != null) return base64Encode(picked);
    if (isLive) throw ApiProblem('A live key needs real photos: choose $what first.');
    return sample;
  }

  /// One call to the service. Never throws for a bad status: the caller shows what the service said.
  /// extraHeaders: for example Idempotency-Key.
  Future<ApiResult> send(String method, String path, [Map<String, Object?>? body, Map<String, String>? extraHeaders]) async {
    final req = http.Request(method, uri(path))..headers.addAll(headers);
    if (extraHeaders != null) req.headers.addAll(extraHeaders);
    if (body != null) req.body = jsonEncode(body);
    final String label = '$method $path';
    try {
      final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 60)));
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return ApiResult(status: res.statusCode, body: decoded, raw: res.body, request: label);
      } on FormatException {
        // not JSON: fall through to the raw text
      }
      return ApiResult(status: res.statusCode, raw: res.body.length > 600 ? res.body.substring(0, 600) : res.body, request: label);
    } catch (e) {
      return ApiResult.local('Could not reach the service. Check the address and your connection.\n($e)').withNote(null, label);
    }
  }
}
