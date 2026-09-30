import 'package:encrypt/encrypt.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/services/page_probe.dart';

void main() {
  test('accepts a complete JSON object with whitespace', () {
    expect(decodeMobileResponse(' {"data":{"value":12}}\n'), {
      'data': {'value': 12},
    });
  });

  test('decrypts AES CBC PKCS7 response hex', () {
    final cipher = crypto.Encrypter(
      crypto.AES(
        crypto.Key.fromUtf8('1234123412ABCDEF'),
        mode: crypto.AESMode.cbc,
        padding: 'PKCS7',
      ),
    );
    final encrypted = cipher.encrypt(
      '{"data":{"resultData":{"planRemianFlowInfo":{}}}}',
      iv: crypto.IV.fromUtf8('ABCDEF1234123412'),
    );
    expect(decodeMobileResponse(encrypted.base16)?['data'], {
      'resultData': {'planRemianFlowInfo': <String, dynamic>{}},
    });
    expect(decodeMobileResponse(encrypted.base16.substring(1)), isNull);
  });

  test('rejects malformed, incomplete and non-object responses', () {
    for (final value in [
      '',
      ' ',
      '{"data":',
      '[]',
      'null',
      '42',
      '<html>登录</html>',
      'abcdef',
      '0' * 32,
    ]) {
      expect(decodeMobileResponse(value), isNull, reason: value);
    }
  });

  test('session restoration rejects absent and incomplete credentials', () {
    expect(broadnetSessionRestoreScript(null), '(() => false)();');
    expect(
      broadnetSessionRestoreScript({'phoneInfo': 'x'}),
      '(() => false)();',
    );
    final script = broadnetSessionRestoreScript({
      'phoneInfo': '";alert(1);//',
      'sessionId': 'session',
    });
    expect(script, contains(r'\";alert(1);//'));
    expect(script, contains("location.origin !== 'https://www.10099.com.cn'"));
  });
}
