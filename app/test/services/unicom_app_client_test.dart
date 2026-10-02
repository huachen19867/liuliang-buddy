import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/services/unicom_app_client.dart';

const _phone = '13800138000';
const _otherPhone = '13900139000';
const _oldToken = 'synthetic-old-token';
const _newToken = 'synthetic-new-token';

// All requests go to a scripted fake. These fixtures contain no real session.
class _FakeTransport {
  _FakeTransport(this.responses);

  final List<Object> responses;
  final requests = <UnicomAppRequest>[];

  Future<UnicomAppResponse> call(UnicomAppRequest request) async {
    requests.add(request);
    if (responses.isEmpty) throw StateError('Unexpected extra request');
    final next = responses.removeAt(0);
    if (next is UnicomAppResponse) return next;
    throw next;
  }
}

UnicomAppSession _session({
  String cookie = 'sid=synthetic-old-cookie',
  bool withToken = false,
}) => UnicomAppSession.import(
  jsonEncode({
    'phoneNumber': _phone,
    'cookie': cookie,
    if (withToken) ...{
      'token_online': _oldToken,
      'appId': 'synthetic-app-id',
      'version': 'android@11.0900',
      'deviceCode': 'synthetic-owned-device',
      'deviceModel': 'synthetic-model',
    },
  }),
  phoneNumber: _phone,
  confirmedCookieOwner: true,
);

UnicomAppResponse _package() => UnicomAppResponse(
  200,
  jsonEncode({
    'code': '0000',
    'resources': [
      {
        'type': 'flow',
        'details': [
          {'feePolicyName': '国内通用流量', 'total': 1024, 'use': 256, 'remain': 768},
        ],
      },
    ],
  }),
);

UnicomAppResponse _balance() =>
    const UnicomAppResponse(200, '{"code":"0000","curntbalancecust":"-5.25"}');

UnicomAppResponse _online({
  Object? phone = _phone,
  List<String> cookies = const [
    'sid=synthetic-new-cookie; Domain=.10010.com; Path=/; Secure; HttpOnly',
  ],
  Object code = '0',
}) => UnicomAppResponse(
  200,
  jsonEncode({'code': code, 'desmobile': phone, 'token_online': _newToken}),
  cookies: cookies,
);

void main() {
  test(
    'cancelled account does not send a later fee or renewal request',
    () async {
      var allowed = true;
      final sent = <Uri>[];
      final client = UnicomAppClient(
        transport: (request) async {
          sent.add(request.url);
          allowed = false;
          return const UnicomAppResponse(
            200,
            '{"code":"0000","resources":[{"type":"flow","details":[{"feePolicyName":"通用流量","remain":"10","total":"20"}]}]}',
          );
        },
      );
      final result = await client.query(_session(), isCurrent: () => allowed);
      expect(sent, [UnicomAppClient.packageUrl]);
      expect(result.snapshot.status, QueryStatus.error);
      expect(result.snapshot.message, contains('取消'));
      final blocked = await client.query(
        _session(withToken: true),
        isCurrent: () async => false,
      );
      expect(blocked.snapshot.status, QueryStatus.error);
      expect(sent, hasLength(1));
    },
  );
  test(
    'cookie query orders package then balance and preserves session',
    () async {
      final original = _session();
      final fake = _FakeTransport([_package(), _balance()]);
      final result = await UnicomAppClient(
        transport: fake.call,
      ).query(original);
      expect(fake.requests.map((r) => r.url), [
        UnicomAppClient.packageUrl,
        UnicomAppClient.balanceUrl,
      ]);
      expect(
        fake.requests.every((r) => identical(r.session, original)),
        isTrue,
      );
      expect(fake.requests.every((r) => r.form.isEmpty), isTrue);
      expect(result.snapshot.status, QueryStatus.success);
      expect(result.snapshot.generalRemainingBytes, 768 * 1024 * 1024);
      expect(result.snapshot.balanceYuan, -5.25);
      expect(result.snapshot.phoneMasked, '138****8000');
      expect(result.session, same(original));
    },
  );

  test(
    'ordinary business and gateway errors never renew or query fees',
    () async {
      for (final response in [
        const UnicomAppResponse(200, '{"code":"ECS000047","dsc":"号码类型不支持"}'),
        const UnicomAppResponse(502, '{"code":"UPSTREAM_ERROR"}'),
        const UnicomAppResponse(200, '<html>Gateway unavailable</html>'),
        const UnicomAppResponse(200, '{"code":"0000","resources":[]}'),
      ]) {
        final fake = _FakeTransport([response]);
        final result = await UnicomAppClient(
          transport: fake.call,
        ).query(_session(withToken: true));
        expect(result.snapshot.status, QueryStatus.error);
        expect(fake.requests.map((r) => r.url), [UnicomAppClient.packageUrl]);
      }
    },
  );

  test(
    'token-only query renews first and sends only supplied parameters',
    () async {
      final original = _session(cookie: '', withToken: true);
      final fake = _FakeTransport([_online(), _package(), _balance()]);
      final result = await UnicomAppClient(
        transport: fake.call,
      ).query(original);
      expect(fake.requests.map((r) => r.url), [
        UnicomAppClient.onlineUrl,
        UnicomAppClient.packageUrl,
        UnicomAppClient.balanceUrl,
      ]);
      expect(fake.requests.first.form, {
        'token_online': _oldToken,
        'appId': 'synthetic-app-id',
        'version': 'android@11.0900',
        'deviceCode': 'synthetic-owned-device',
        'deviceModel': 'synthetic-model',
      });
      expect(result.snapshot.status, QueryStatus.success);
      expect(result.session.tokenOnline, _newToken);
      expect(result.session.cookie, 'sid=synthetic-new-cookie');
      expect(result.session.confirmedCookieOwner, isTrue);
      expect(fake.requests[1].session, same(result.session));
      expect(original.tokenOnline, _oldToken);
      expect(original.hasCookie, isFalse);
    },
  );

  test(
    'renewal requires matching full desmobile before any package request',
    () async {
      for (final phone in [null, _otherPhone, '138****8000', 13800138000]) {
        final fake = _FakeTransport([_online(phone: phone)]);
        final result = await UnicomAppClient(
          transport: fake.call,
        ).query(_session(cookie: '', withToken: true));
        expect(result.snapshot.status, QueryStatus.authExpired);
        expect(fake.requests.map((r) => r.url), [UnicomAppClient.onlineUrl]);
        expect(result.session.tokenOnline, _oldToken);
        expect(result.session.hasCookie, isFalse);
        expect(result.snapshot.message, isNot(contains(_otherPhone)));
      }
    },
  );

  test(
    'renewal rejects non-success code and hides upstream credential text',
    () async {
      final fake = _FakeTransport([
        UnicomAppResponse(
          200,
          jsonEncode({
            'code': '3',
            'dsc': 'token=$_oldToken phone=$_phone',
            'desmobile': _phone,
          }),
        ),
      ]);
      final result = await UnicomAppClient(
        transport: fake.call,
      ).query(_session(cookie: '', withToken: true));
      expect(result.snapshot.status, QueryStatus.authExpired);
      expect(fake.requests, hasLength(1));
      expect(result.snapshot.message, isNot(contains(_oldToken)));
      expect(result.snapshot.message, isNot(contains(_phone)));
    },
  );

  test('token-only renewal requires usable first-party Set-Cookie', () async {
    for (final cookies in <List<String>>[
      [],
      ['sid=foreign-session; Domain=example.com; Path=/'],
      ['sid=deleted; Max-Age=0; Domain=.10010.com; Path=/'],
    ]) {
      final fake = _FakeTransport([_online(cookies: cookies)]);
      final result = await UnicomAppClient(
        transport: fake.call,
      ).query(_session(cookie: '', withToken: true));
      expect(result.snapshot.status, QueryStatus.authExpired);
      expect(fake.requests, hasLength(1));
      expect(result.session.tokenOnline, _oldToken);
    }
  });

  test(
    'expired existing cookie cannot renew without fresh Set-Cookie',
    () async {
      final original = _session(withToken: true);
      final fake = _FakeTransport([
        const UnicomAppResponse(200, '999999'),
        _online(cookies: []),
      ]);
      final result = await UnicomAppClient(
        transport: fake.call,
      ).query(original);
      expect(result.snapshot.status, QueryStatus.authExpired);
      expect(fake.requests.map((r) => r.url), [
        UnicomAppClient.packageUrl,
        UnicomAppClient.onlineUrl,
      ]);
      expect(result.session, same(original));
      expect(result.session.tokenOnline, _oldToken);
    },
  );

  test(
    'negative Max-Age deletes a returned cookie and cannot establish renewal',
    () async {
      for (final cookie in ['', 'sid=synthetic-old-cookie']) {
        final fake = _FakeTransport([
          if (cookie.isNotEmpty) const UnicomAppResponse(200, '999999'),
          _online(
            cookies: [
              'sid=synthetic-new-cookie; Max-Age=-1; Domain=.10010.com; Path=/',
            ],
          ),
        ]);
        final result = await UnicomAppClient(
          transport: fake.call,
        ).query(_session(cookie: cookie, withToken: true));
        expect(result.snapshot.status, QueryStatus.authExpired);
        expect(fake.requests.last.url, UnicomAppClient.onlineUrl);
        expect(fake.requests, hasLength(cookie.isEmpty ? 1 : 2));
        expect(result.session.tokenOnline, _oldToken);
      }
    },
  );

  test(
    'explicit cookie expiry renews once, rotates token and replaces cookies',
    () async {
      for (final expired in [
        const UnicomAppResponse(200, '999999'),
        const UnicomAppResponse(200, '999998'),
        const UnicomAppResponse(401, 'Unauthorized'),
        const UnicomAppResponse(200, '{"code":"AUTH_FAILED"}'),
      ]) {
        final fake = _FakeTransport([
          expired,
          _online(
            cookies: [
              'sid=synthetic-new-cookie; Domain=.10010.com; Path=/',
              'extra=fresh; Domain=m.client.10010.com; Path=/',
            ],
          ),
          _package(),
          _balance(),
        ]);
        final result = await UnicomAppClient(
          transport: fake.call,
        ).query(_session(withToken: true));
        expect(fake.requests.map((r) => r.url), [
          UnicomAppClient.packageUrl,
          UnicomAppClient.onlineUrl,
          UnicomAppClient.packageUrl,
          UnicomAppClient.balanceUrl,
        ]);
        expect(result.snapshot.status, QueryStatus.success);
        expect(result.session.tokenOnline, _newToken);
        expect(result.session.cookie, 'sid=synthetic-new-cookie; extra=fresh');
        expect(fake.requests[2].session.tokenOnline, _newToken);
      }
    },
  );

  test(
    'repeated expiry after renewal stops without cycling or querying balance',
    () async {
      for (final cookie in ['sid=synthetic-old-cookie', '']) {
        final fake = _FakeTransport([
          if (cookie.isNotEmpty) const UnicomAppResponse(200, '999999'),
          _online(),
          const UnicomAppResponse(200, '999998'),
        ]);
        final result = await UnicomAppClient(
          transport: fake.call,
        ).query(_session(cookie: cookie, withToken: true));
        expect(result.snapshot.status, QueryStatus.authExpired);
        expect(
          fake.requests.where((r) => r.url == UnicomAppClient.onlineUrl),
          hasLength(1),
        );
        expect(
          fake.requests.where((r) => r.url == UnicomAppClient.balanceUrl),
          isEmpty,
        );
        expect(fake.responses, isEmpty);
      }
    },
  );

  test(
    'expired cookie without renewal credentials needs reconnect only',
    () async {
      final fake = _FakeTransport([const UnicomAppResponse(200, '999999')]);
      final result = await UnicomAppClient(
        transport: fake.call,
      ).query(_session());
      expect(result.snapshot.status, QueryStatus.authExpired);
      expect(fake.requests.map((r) => r.url), [UnicomAppClient.packageUrl]);
    },
  );

  test(
    'every fee failure preserves successful flow without more login',
    () async {
      for (final failure in <Object>[
        const UnicomAppResponse(200, '{"code":"999999"}'),
        const UnicomAppResponse(500, '{"code":"0000","curntbalancecust":"10"}'),
        const UnicomAppResponse(200, '{"code":"0000","realfeecustnew":"10"}'),
        const UnicomAppResponse(200, '<html>unavailable</html>'),
        StateError('synthetic network failure'),
      ]) {
        final fake = _FakeTransport([_package(), failure]);
        final result = await UnicomAppClient(
          transport: fake.call,
        ).query(_session(withToken: true));
        expect(result.snapshot.status, QueryStatus.success);
        expect(result.snapshot.generalRemainingBytes, 768 * 1024 * 1024);
        expect(result.snapshot.balanceYuan, isNull);
        expect(fake.requests.map((r) => r.url), [
          UnicomAppClient.packageUrl,
          UnicomAppClient.balanceUrl,
        ]);
        expect(result.snapshot.message, contains('话费'));
      }
    },
  );

  test(
    'renewed Set-Cookie containing another account stops before packages',
    () async {
      for (final cookieName in ['c_mobile', 'u_account']) {
        final fake = _FakeTransport([
          _online(
            cookies: [
              'sid=synthetic-new-cookie; Domain=.10010.com; Path=/',
              '$cookieName=$_otherPhone; Domain=.10010.com; Path=/',
            ],
          ),
        ]);
        final result = await UnicomAppClient(
          transport: fake.call,
        ).query(_session(cookie: '', withToken: true));
        expect(result.snapshot.status, QueryStatus.error);
        expect(fake.requests.map((r) => r.url), [UnicomAppClient.onlineUrl]);
        expect(result.session.hasCookie, isFalse);
      }
    },
  );

  test(
    'Cookie import requires confirmed owner and checks exposed phone keys',
    () {
      expect(
        () => UnicomAppSession.import(
          'sid=synthetic-cookie',
          phoneNumber: _phone,
          confirmedCookieOwner: false,
        ),
        throwsFormatException,
      );
      for (final key in ['c_mobile', 'u_account']) {
        expect(
          () => UnicomAppSession.import(
            'sid=synthetic-cookie; $key=$_otherPhone',
            phoneNumber: _phone,
            confirmedCookieOwner: true,
          ),
          throwsFormatException,
        );
      }
      final session = UnicomAppSession.import(
        'Cookie: sid=synthetic-cookie; c_mobile=$_phone;',
        phoneNumber: _phone,
        confirmedCookieOwner: true,
      );
      expect(session.cookie, 'sid=synthetic-cookie; c_mobile=$_phone');
    },
  );

  test(
    'JSON account mismatch and partial token credentials cannot be imported',
    () {
      for (final data in <Map<String, Object?>>[
        {'phoneNumber': _otherPhone, 'cookie': 'sid=synthetic-cookie'},
        {'token_online': _oldToken},
        {'token_online': _oldToken, 'appId': 'synthetic-app-id'},
        {'token_online': _oldToken, 'version': 'android@11.0900'},
        {'cookie': ''},
        {'cookie': true},
      ]) {
        expect(
          () => UnicomAppSession.import(
            jsonEncode(data),
            phoneNumber: _phone,
            confirmedCookieOwner: true,
          ),
          throwsFormatException,
        );
      }
      final tokenOnly = UnicomAppSession.import(
        jsonEncode({
          'token_online': _oldToken,
          'appId': 'synthetic-app-id',
          'version': 'android@11.0900',
        }),
        phoneNumber: _phone,
        confirmedCookieOwner: false,
      );
      expect(tokenOnly.hasCookie, isFalse);
      expect(tokenOnly.canRenew, isTrue);
    },
  );

  test(
    'credentials reject controls, ambiguous cookies and oversized imports',
    () {
      for (final input in [
        'sid=a\r\nInjected: header=x',
        'sid=a; sid=b',
        'https://m.client.10010.com/?sid=a',
        'sid=a b',
        jsonEncode({
          'token_online': 'a\u0000b',
          'appId': 'synthetic-app-id',
          'version': 'android@11.0900',
        }),
        jsonEncode({'cookie': 'sid=a', 'version': 'a\u007fb'}),
        List.filled(65537, 'a').join(),
      ]) {
        expect(
          () => UnicomAppSession.import(
            input,
            phoneNumber: _phone,
            confirmedCookieOwner: true,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'session and request debug strings redact phone, cookie, token and form',
    () {
      final session = _session(withToken: true);
      final request = UnicomAppRequest(
        UnicomAppClient.onlineUrl,
        session,
        form: {'token_online': _oldToken, 'appId': 'synthetic-app-id'},
      );
      for (final output in [session.toString(), request.toString()]) {
        expect(output, contains('redacted'));
        for (final secret in [
          _phone,
          _oldToken,
          'synthetic-old-cookie',
          'synthetic-app-id',
        ]) {
          expect(output, isNot(contains(secret)));
        }
      }
      expect(session.toString(), contains('138****8000'));
    },
  );

  test(
    'secure storage keys separate four Unicom accounts and reject others',
    () {
      const accounts = ['unicom', 'unicom_2', 'unicom_3', 'unicom_4'];
      final keys = accounts.map(UnicomAppSession.storageKey).toSet();
      expect(keys, hasLength(4));
      for (final account in [
        'mobile',
        'telecom',
        'unicom_1',
        'unicom_5',
        '../unicom',
      ]) {
        expect(() => UnicomAppSession.storageKey(account), throwsArgumentError);
      }
    },
  );

  test('restore retains account and credentials and rechecks owner', () {
    final original = _session(withToken: true);
    final restored = UnicomAppSession.restore(jsonEncode(original.toJson()));
    expect(restored.toJson(), original.toJson());
    expect(restored.phoneMasked, original.phoneMasked);
    for (final data in <Map<String, Object?>>[
      {...original.toJson(), 'schemaVersion': 2},
      {...original.toJson(), 'confirmedCookieOwner': false},
      {...original.toJson(), 'cookie': 'sid=a; c_mobile=$_otherPhone'},
    ]) {
      expect(
        () => UnicomAppSession.restore(jsonEncode(data)),
        throwsFormatException,
      );
    }
  });

  test(
    'oversized package response fails without login or fee requests',
    () async {
      final fake = _FakeTransport([
        UnicomAppResponse(200, List.filled(2000001, 'a').join()),
      ]);
      final result = await UnicomAppClient(
        transport: fake.call,
      ).query(_session(withToken: true));
      expect(result.snapshot.status, QueryStatus.error);
      expect(fake.requests, hasLength(1));
    },
  );
}
