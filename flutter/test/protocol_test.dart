import 'package:flutter_test/flutter_test.dart';
import 'package:xtliveness/src/protocol.dart';

const id = '123e4567-e89b-12d3-a456-426614174000';

void main() {
  group('parseCheckUrl', () {
    test('accepts an https check address', () {
      expect(parseCheckUrl('https://check.example.com/check/$id').path, '/check/$id');
    });
    test('accepts http only on localhost', () {
      expect(parseCheckUrl('http://localhost:8200/check/$id').port, 8200);
      expect(() => parseCheckUrl('http://check.example.com/check/$id'), throwsArgumentError);
      expect(parseCheckUrl('http://10.0.2.2:8200/check/$id', allowInsecureHttp: true).host, '10.0.2.2');
    });
    test('refuses other paths and schemes', () {
      expect(() => parseCheckUrl('https://x.example/other'), throwsArgumentError);
      expect(() => parseCheckUrl('javascript:alert(1)'), throwsArgumentError);
      expect(() => parseCheckUrl('https://x.example/check/short'), throwsArgumentError);
    });
  });

  test('loadUrl puts the token in the fragment, not the query', () {
    final u = loadUrl(parseCheckUrl('https://c.example.com/check/$id'), 'ab+c/=');
    expect(u.query, '');
    expect(u.fragment.startsWith('t='), isTrue);
    expect(u.path, '/check/$id');
    expect(() => loadUrl(u, ''), throwsArgumentError);
  });

  group('parseMessage', () {
    String msg(String status, [String extra = '']) => '{"type":"xtl:result","sessionId":"${id.toUpperCase()}","status":"$status"$extra}';
    test('completed, cancelled and error', () {
      expect(parseMessage(msg('completed'), id), isA<XtlCompleted>());
      expect(parseMessage(msg('cancelled'), id), isA<XtlCancelled>());
      final e = parseMessage(msg('error', ',"code":"timeout"'), id) as XtlError;
      expect(e.code, 'timeout');
      expect((parseMessage(msg('error'), id) as XtlError).code, 'error');
    });
    test('ignores other sessions, other types and junk', () {
      expect(parseMessage(msg('completed'), '123e4567-e89b-12d3-a456-426614174999'), isNull);
      expect(parseMessage('{"type":"other","status":"completed"}', id), isNull);
      expect(parseMessage('not json', id), isNull);
      expect(parseMessage('[1,2]', id), isNull);
      expect(parseMessage(msg('weird'), id), isNull);
    });
  });

  test('sameOrigin compares scheme, host and port', () {
    final a = Uri.parse('https://c.example.com/check/x');
    expect(sameOrigin(a, Uri.parse('https://c.example.com/anything')), isTrue);
    expect(sameOrigin(a, Uri.parse('https://evil.example.com/')), isFalse);
    expect(sameOrigin(a, Uri.parse('http://c.example.com/')), isFalse);
  });
}
