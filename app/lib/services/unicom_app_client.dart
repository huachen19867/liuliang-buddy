import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../data/models.dart';
import '../data/unicom_app_parser.dart';

/// App sessions are deliberately separate from official E5 WebView cookies.
class UnicomAppSession {
  UnicomAppSession._({
    required this.phoneNumber,
    required this.cookie,
    required this.confirmedCookieOwner,
    this.tokenOnline,
    this.appId,
    this.version,
    this.deviceCode,
    this.deviceModel,
  });

  final String phoneNumber;
  final String cookie;
  final bool confirmedCookieOwner;
  final String? tokenOnline;
  final String? appId;
  final String? version;
  final String? deviceCode;
  final String? deviceModel;
  bool get hasCookie => cookie.isNotEmpty;
  bool get canRenew => tokenOnline != null && appId != null && version != null;
  String get phoneMasked =>
      '${phoneNumber.substring(0, 3)}****${phoneNumber.substring(7)}';

  static UnicomAppSession import(
    String input, {
    required String phoneNumber,
    required bool confirmedCookieOwner,
  }) {
    final phone = phoneNumber.trim();
    if (!RegExp(r'^1[3-9][0-9]{9}$').hasMatch(phone)) {
      throw const FormatException('请输入 11 位联通手机号');
    }
    if (input.length > 65536) {
      throw const FormatException('会话内容过长，请只导入这个号码的会话');
    }
    Map<String, dynamic> data;
    final source = input.trim();
    if (source.startsWith('{')) {
      try {
        final value = jsonDecode(source);
        if (value is! Map<String, dynamic>) throw const FormatException();
        data = value;
      } catch (_) {
        throw const FormatException('会话 JSON 格式不正确');
      }
    } else {
      data = {'cookie': source};
    }
    if (data['phoneNumber'] != null && data['phoneNumber'] != phone) {
      throw const FormatException('会话中的号码与填写的号码不一致');
    }
    String? field(String name, int max) {
      final value = data[name];
      if (value == null || value == '') return null;
      if (value is! String ||
          value.length > max ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
        throw const FormatException('会话字段格式不正确');
      }
      return value.trim().isEmpty ? null : value.trim();
    }

    final rawCookie = field('cookie', 32768) ?? field('Cookie', 32768) ?? '';
    final cookie = _normalizeCookie(rawCookie);
    final token = field('token_online', 16384);
    final appId = field('appId', 2048);
    final version = field('version', 128);
    if (cookie.isEmpty && token == null) {
      throw const FormatException('请输入联通 App 会话');
    }
    if (cookie.isNotEmpty && !confirmedCookieOwner) {
      throw const FormatException('请确认会话来自填写号码的联通 App');
    }
    if (token != null && (appId == null || version == null)) {
      throw const FormatException('token 会话需要同一次登录的 appId 和 version');
    }
    _checkCookiePhone(cookie, phone);
    return UnicomAppSession._(
      phoneNumber: phone,
      cookie: cookie,
      confirmedCookieOwner: confirmedCookieOwner,
      tokenOnline: token,
      appId: appId,
      version: version,
      deviceCode: field('deviceCode', 256),
      deviceModel: field('deviceModel', 128),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'phoneNumber': phoneNumber,
    'cookie': cookie,
    'confirmedCookieOwner': confirmedCookieOwner,
    'token_online': tokenOnline,
    'appId': appId,
    'version': version,
    'deviceCode': deviceCode,
    'deviceModel': deviceModel,
  };

  static UnicomAppSession restore(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['schemaVersion'] != 1 ||
        value['phoneNumber'] is! String) {
      throw const FormatException('联通 App 会话记录无效');
    }
    return import(
      raw,
      phoneNumber: value['phoneNumber'] as String,
      confirmedCookieOwner: value['confirmedCookieOwner'] == true,
    );
  }

  static String storageKey(String accountId) {
    if (!RegExp(r'^unicom(?:_[234])?$').hasMatch(accountId)) {
      throw ArgumentError('Not a Unicom account');
    }
    return 'unicom_app_session_$accountId';
  }

  @override
  String toString() => 'UnicomAppSession($phoneMasked, credentials: redacted)';
}

String _normalizeCookie(String raw) {
  if (raw.isEmpty) return '';
  final value = raw.startsWith('Cookie:') ? raw.substring(7).trim() : raw;
  final parts = value
      .split(';')
      .map((part) => part.trim())
      .where((p) => p.isNotEmpty);
  final values = <String, String>{};
  for (final part in parts) {
    final at = part.indexOf('=');
    if (at < 1 ||
        !RegExp(
          r'^[!#$%&\x27*+.^_`|~0-9a-zA-Z-]+$',
        ).hasMatch(part.substring(0, at)) ||
        RegExp(r'[\x00-\x20\x7f]').hasMatch(part.substring(at + 1))) {
      throw const FormatException('请输入完整 Cookie，不是请求网址或抓包全文');
    }
    final key = part.substring(0, at);
    if (values.containsKey(key)) {
      throw const FormatException('会话包含重复 Cookie，请只保留一个号码的会话');
    }
    values[key] = part.substring(at + 1);
  }
  if (values.isEmpty) throw const FormatException('Cookie 格式不正确');
  return values.entries.map((e) => '${e.key}=${e.value}').join('; ');
}

void _checkCookiePhone(String cookie, String phone) {
  for (final part in cookie.split(';')) {
    final at = part.indexOf('=');
    if (at < 1) continue;
    final name = part.substring(0, at).trim();
    if (name != 'c_mobile' && name != 'u_account') continue;
    final value = part.substring(at + 1);
    if (RegExp(r'^1[3-9][0-9]{9}$').hasMatch(value) && value != phone) {
      throw const FormatException('Cookie 中的号码与填写的号码不一致');
    }
  }
}

class UnicomAppRequest {
  const UnicomAppRequest(this.url, this.session, {this.form = const {}});
  final Uri url;
  final UnicomAppSession session;
  final Map<String, String> form;
  @override
  String toString() => 'UnicomAppRequest(${url.path}, credentials: redacted)';
}

class UnicomAppResponse {
  const UnicomAppResponse(this.status, this.body, {this.cookies = const []});
  final int status;
  final String body;
  final List<String> cookies;
}

typedef UnicomAppTransport =
    Future<UnicomAppResponse> Function(UnicomAppRequest);

class UnicomAppQueryResult {
  const UnicomAppQueryResult(this.snapshot, this.session);
  final CarrierSnapshot snapshot;
  final UnicomAppSession session;
}

/// Exact first-party endpoints only. Never forward a credential on redirects.
class UnicomAppClient {
  UnicomAppClient({UnicomAppTransport? transport})
    : _transport = transport ?? _post;
  final UnicomAppTransport _transport;
  static final packageUrl = Uri.parse(
    'https://m.client.10010.com/servicequerybusiness/operationservice/queryOcsPackageFlowLeftContentRevisedInJune',
  );
  static final balanceUrl = Uri.parse(
    'https://m.client.10010.com/servicequerybusiness/balancenew/accountBalancenew.htm',
  );
  static final onlineUrl = Uri.parse(
    'https://m.client.10010.com/mobileService/onLine.htm',
  );

  Future<UnicomAppQueryResult> query(
    UnicomAppSession original, {
    FutureOr<bool> Function()? isCurrent,
  }) async {
    var session = original;
    try {
      var renewed = false;
      if (!session.hasCookie) {
        session = await _renew(session, isCurrent: isCurrent);
        renewed = true;
      }
      var response = await _send(packageUrl, session, isCurrent: isCurrent);
      var snapshot = _parsePackage(response, session);
      if (snapshot.status == QueryStatus.authExpired &&
          session.canRenew &&
          !renewed) {
        session = await _renew(session, isCurrent: isCurrent);
        response = await _send(packageUrl, session, isCurrent: isCurrent);
        snapshot = _parsePackage(response, session);
      }
      if (snapshot.status != QueryStatus.success) {
        return UnicomAppQueryResult(snapshot, session);
      }
      // Balance is independent: a failed bill query never discards valid flow.
      try {
        final fee = await _send(balanceUrl, session, isCurrent: isCurrent);
        final balance = parseUnicomAppBalance(
          _json(fee),
          httpStatus: fee.status,
        );
        snapshot = snapshot.copyWith(
          balanceYuan: balance,
          message: balance == null ? '流量已更新，话费余额暂未取得' : snapshot.message,
        );
      } on _AppFailure {
        rethrow;
      } catch (_) {
        snapshot = snapshot.copyWith(message: '流量已更新，话费余额暂未取得');
      }
      return UnicomAppQueryResult(snapshot, session);
    } on _AppFailure catch (failure) {
      return UnicomAppQueryResult(
        CarrierSnapshot(
          carrier: Carrier.unicom,
          status: failure.status,
          message: failure.message,
        ),
        session,
      );
    } catch (_) {
      return UnicomAppQueryResult(
        const CarrierSnapshot(
          carrier: Carrier.unicom,
          status: QueryStatus.error,
          message: '联通 App 查询暂时失败，请检查网络后重试',
        ),
        session,
      );
    }
  }

  CarrierSnapshot _parsePackage(
    UnicomAppResponse response,
    UnicomAppSession session,
  ) {
    if (response.status == 401 || response.status == 403) {
      return const CarrierSnapshot(
        carrier: Carrier.unicom,
        status: QueryStatus.authExpired,
        message: '联通 App 会话已失效，请重新连接',
      );
    }
    final body = response.body.trim();
    if (body == '999998' || body == '999999') {
      return const CarrierSnapshot(
        carrier: Carrier.unicom,
        status: QueryStatus.authExpired,
        message: '联通 App 会话已失效，请重新连接',
      );
    }
    return parseUnicomAppPackage(
      _json(response),
      queriedAt: DateTime.now(),
      phoneMasked: session.phoneMasked,
      httpStatus: response.status,
    );
  }

  Future<UnicomAppSession> _renew(
    UnicomAppSession session, {
    FutureOr<bool> Function()? isCurrent,
  }) async {
    if (!session.canRenew) {
      throw const _AppFailure(QueryStatus.authExpired, '联通 App 会话已失效，请重新连接');
    }
    final response = await _send(
      onlineUrl,
      session,
      isCurrent: isCurrent,
      form: {
        'token_online': session.tokenOnline!,
        'appId': session.appId!,
        'version': session.version!,
        if (session.deviceCode != null) 'deviceCode': session.deviceCode!,
        if (session.deviceModel != null) 'deviceModel': session.deviceModel!,
      },
    );
    if (response.status != 200) {
      throw const _AppFailure(QueryStatus.error, '联通暂时无法确认 App 会话，请稍后重试');
    }
    final data = _json(response);
    if (data['code']?.toString() != '0') {
      // Do not expose upstream messages which may contain account/token data.
      throw const _AppFailure(
        QueryStatus.authExpired,
        '联通拒绝了 App 会话，请在官方 App 验证后重新连接',
      );
    }
    final phone = data['desmobile'];
    if (phone is! String || phone != session.phoneNumber) {
      throw const _AppFailure(
        QueryStatus.authExpired,
        '联通未确认这个完整号码，已停止连接以避免串卡',
      );
    }
    if (_mergeCookies('', response.cookies).isEmpty) {
      throw const _AppFailure(QueryStatus.authExpired, '联通没有返回新的 App 会话，请重新连接');
    }
    final cookie = _mergeCookies(session.cookie, response.cookies);
    if (cookie.isEmpty) {
      throw const _AppFailure(
        QueryStatus.authExpired,
        '联通没有返回可用的 App 会话，请重新连接',
      );
    }
    final token = data['token_online'];
    return UnicomAppSession.import(
      jsonEncode({
        ...session.toJson(),
        'cookie': cookie,
        'token_online': token is String && token.isNotEmpty
            ? token
            : session.tokenOnline,
      }),
      phoneNumber: session.phoneNumber,
      confirmedCookieOwner: true,
    );
  }

  Future<UnicomAppResponse> _send(
    Uri url,
    UnicomAppSession session, {
    Map<String, String> form = const {},
    FutureOr<bool> Function()? isCurrent,
  }) async {
    if (isCurrent != null && !await isCurrent()) {
      throw const _AppFailure(QueryStatus.error, '本次联通查询已取消');
    }
    final response = await _transport(
      UnicomAppRequest(url, session, form: form),
    ).timeout(const Duration(seconds: 15));
    if (response.body.length > 2000000) throw const FormatException();
    return response;
  }

  static Map<String, dynamic> _json(UnicomAppResponse response) {
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic>) throw const FormatException();
    return value;
  }

  static Future<UnicomAppResponse> _post(UnicomAppRequest input) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await (() async {
        final request = await client.postUrl(input.url);
        request.followRedirects = false;
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/x-www-form-urlencoded',
        );
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'unicom{version:${input.session.version ?? 'android@11.0900'}}',
        );
        if (input.session.hasCookie && input.url != onlineUrl) {
          request.headers.set(HttpHeaders.cookieHeader, input.session.cookie);
        }
        request.write(
          input.form.entries
              .map(
                (e) =>
                    '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
              )
              .join('&'),
        );
        final response = await request.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > 2000000) {
            throw const FormatException();
          }
          bytes.addAll(chunk);
        }
        return UnicomAppResponse(
          response.statusCode,
          utf8.decode(bytes),
          cookies: response.headers[HttpHeaders.setCookieHeader] ?? const [],
        );
      })().timeout(const Duration(seconds: 14));
    } finally {
      client.close(force: true);
    }
  }
}

String _mergeCookies(String existing, List<String> updates) {
  final cookies = <String, String>{};
  for (final item in existing.split(';')) {
    final at = item.indexOf('=');
    if (at > 0) cookies[item.substring(0, at).trim()] = item.substring(at + 1);
  }
  for (final header in updates) {
    final parsed = Cookie.fromSetCookieValue(header);
    if (parsed.domain != null &&
        ![
          'm.client.10010.com',
          '.m.client.10010.com',
          'client.10010.com',
          '.client.10010.com',
          '10010.com',
          '.10010.com',
        ].contains(parsed.domain!.toLowerCase())) {
      continue;
    }
    if ((parsed.maxAge != null && parsed.maxAge! <= 0) ||
        (parsed.expires != null && parsed.expires!.isBefore(DateTime.now()))) {
      cookies.remove(parsed.name);
    } else {
      cookies[parsed.name] = parsed.value;
    }
  }
  return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
}

class _AppFailure implements Exception {
  const _AppFailure(this.status, this.message);
  final QueryStatus status;
  final String message;
}
