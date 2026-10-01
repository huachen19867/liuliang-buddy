import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/carrier_selection.dart';
import '../data/models.dart';
import '../data/parsers.dart';
import 'carrier_web.dart';
import 'page_probe.dart';
import 'response_policy.dart';
import 'widget_bridge.dart';

const _backgroundChannel = MethodChannel('cn.liuliang/background_refresh');
const _secureStorage = FlutterSecureStorage();

@pragma('vm:entry-point')
Future<void> runBackgroundRefreshEntrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  _backgroundChannel.setMethodCallHandler((call) async {
    if (call.method != 'start') return false;
    try {
      final payload = await _runScheduledRefresh();
      await _backgroundChannel.invokeMethod<void>('completed', {
        'widgetPayload': ?payload,
      });
    } catch (_) {
      await _backgroundChannel.invokeMethod<void>('failed');
    }
    return true;
  });
  await _backgroundChannel.invokeMethod<void>('ready');
}

Future<Map<String, Object?>?> _runScheduledRefresh() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  if (!await _isTaskCurrent()) return null;
  final minutes = prefs.getInt('background_refresh_minutes') ?? 0;
  if (minutes == 0) return null;
  final selection = CarrierSelection.restore(
    savedJson: prefs.getString('carrier_selection'),
    legacyPreferences: {
      for (final carrier in Carrier.values)
        'connected_${carrier.name}':
            prefs.getBool('connected_${carrier.name}') ?? false,
    },
  );
  if (!selection.setupCompleted) return null;

  final snapshots = <Carrier, CarrierSnapshot>{};
  for (final carrier in Carrier.values) {
    if (!selection.allows(carrier)) continue;
    final raw = prefs.getString('snapshot_${carrier.name}');
    if (raw == null) continue;
    try {
      snapshots[carrier] = CarrierSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // A malformed saved record is not a background refresh authorization.
    }
  }

  final connected = <Carrier>[
    for (final carrier in Carrier.values)
      if (selection.allows(carrier) &&
          (prefs.getBool('connected_${carrier.name}') ?? false))
        carrier,
  ];
  for (final carrier in connected) {
    // Telecom currently needs account-page sessionStorage and an already
    // rendered billing DOM. Keep its data on the normal foreground path.
    if (carrier == Carrier.telecom ||
        snapshots[carrier]?.queriedAt == null ||
        snapshots[carrier]!.buckets.isEmpty ||
        (prefs.getBool('background_auth_required_${carrier.name}') ?? false)) {
      continue;
    }
    if (!await _isTaskCurrent()) return null;

    final previous = snapshots[carrier]!;
    final result = await _queryInHeadlessWebView(carrier);
    await prefs.reload();
    if (!await _isTaskCurrent()) return null;
    if (result.status == QueryStatus.success) {
      snapshots[carrier] = result.snapshot;
      await prefs.setBool('background_auth_required_${carrier.name}', false);
      if (carrier == Carrier.broadnet) {
        await _saveBroadnetSession(result.session);
      }
    } else {
      snapshots[carrier] = previous.copyWith(
        status: result.status,
        message: result.message,
      );
      if (result.status == QueryStatus.authExpired) {
        await prefs.setBool('background_auth_required_${carrier.name}', true);
      }
    }
    await prefs.setString(
      'snapshot_${carrier.name}',
      jsonEncode(snapshots[carrier]!.toJson()),
    );
    await prefs.reload();
  }

  if (!await _isTaskCurrent()) return null;
  final current = <CarrierSnapshot>[
    for (final carrier in selection.selectedCarriers)
      if (snapshots[carrier] != null) snapshots[carrier]!,
  ];
  return buildWidgetPayload(
    current,
    thresholdGb: (prefs.getDouble('threshold_gb') ?? 5).clamp(1, 20),
    selection: selection,
  );
}

Future<bool> _isTaskCurrent() async {
  try {
    return await _backgroundChannel.invokeMethod<bool>('isTaskCurrent') ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

class _HeadlessResult {
  const _HeadlessResult(this.snapshot, {this.session});
  final CarrierSnapshot snapshot;
  final Map<String, dynamic>? session;
  QueryStatus get status => snapshot.status;
  String? get message => snapshot.message;
}

Future<_HeadlessResult> _queryInHeadlessWebView(Carrier carrier) async {
  final result = Completer<_HeadlessResult>();
  HeadlessInAppWebView? webView;
  Map<String, dynamic>? broadnetSession;

  void complete(CarrierSnapshot snapshot) {
    if (!result.isCompleted) {
      result.complete(_HeadlessResult(snapshot, session: broadnetSession));
    }
  }

  try {
    final savedSession = carrier == Carrier.broadnet
        ? await _readBroadnetSession()
        : null;
    webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(carrierQueryUrl(carrier))),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
        thirdPartyCookiesEnabled: false,
        allowFileAccess: false,
        allowContentAccess: false,
      ),
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: responseCaptureScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
        if (carrier == Carrier.broadnet)
          UserScript(
            groupName: 'broadnetRestore',
            source: broadnetSessionRestoreScript(savedSession),
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
      ]),
      onWebViewCreated: (created) {
        created.addJavaScriptHandler(
          handlerName: 'trafficResponse',
          callback: (args) async {
            if (args.isEmpty || args.first is! Map) return false;
            final payload = Map<String, dynamic>.from(args.first as Map);
            final parsed = _parseCapturedResponse(carrier, payload);
            if (parsed != null) complete(parsed);
            return true;
          },
        );
      },
      shouldOverrideUrlLoading: (created, action) async {
        final uri = Uri.tryParse(action.request.url?.toString() ?? '');
        return uri != null && isCarrierNavigationAllowed(carrier, uri)
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onUpdateVisitedHistory: (created, url, isReload) {
        if (url == null) return;
        final uri = Uri.tryParse(url.toString());
        if (uri != null && isCarrierLoginPage(uri)) {
          complete(
            CarrierSnapshot(
              carrier: carrier,
              status: QueryStatus.authExpired,
              message: '${carrier.label}登录已失效，请打开 APP 重新验证',
            ),
          );
        }
      },
      onLoadStop: (created, url) async {
        if (url == null) return;
        final uri = Uri.tryParse(url.toString());
        if (uri == null) return;
        if (isCarrierLoginPage(uri)) {
          complete(
            CarrierSnapshot(
              carrier: carrier,
              status: QueryStatus.authExpired,
              message: '${carrier.label}登录已失效，请打开 APP 重新验证',
            ),
          );
          return;
        }
        if (carrier == Carrier.broadnet && uri.host == 'www.10099.com.cn') {
          try {
            final captured = await created.evaluateJavascript(
              source: broadnetSessionCaptureScript,
            );
            if (captured is Map) {
              final candidate = Map<String, dynamic>.from(captured);
              if (_validBroadnetSession(candidate)) {
                broadnetSession = candidate;
              }
            }
          } catch (_) {
            // A query response may still be usable when session backup fails.
          }
        }
      },
      onReceivedError: (created, request, error) {
        if (request.isForMainFrame != true) return;
        complete(
          CarrierSnapshot(
            carrier: carrier,
            status: QueryStatus.error,
            message: '后台暂时无法连接，保留上次查询时间',
          ),
        );
      },
    );
    await webView.run();
    final completed = await result.future.timeout(
      const Duration(seconds: 40),
      onTimeout: () => _HeadlessResult(
        CarrierSnapshot(
          carrier: carrier,
          status: QueryStatus.error,
          message: '后台未取得可识别结果，保留上次查询时间',
        ),
      ),
    );
    return completed;
  } catch (_) {
    return _HeadlessResult(
      CarrierSnapshot(
        carrier: carrier,
        status: QueryStatus.error,
        message: '后台网页查询暂不可用，保留上次查询时间',
      ),
    );
  } finally {
    try {
      await webView?.dispose();
    } catch (_) {
      // A disposed engine can already have released this headless view.
    }
  }
}

CarrierSnapshot? _parseCapturedResponse(
  Carrier carrier,
  Map<String, dynamic> payload,
) {
  final url = Uri.tryParse(payload['url'] as String? ?? '');
  final page = Uri.tryParse(payload['pageUrl'] as String? ?? '');
  final stage = payload['stage'] is String ? payload['stage'] as String : null;
  if (!isCarrierResponseAllowed(carrier, url, page, stage)) return null;
  final raw = payload['body'];
  if (raw is! String || raw.length > 2000000) return null;
  final status = payload['status'] is int ? payload['status'] as int : null;
  final Map<String, dynamic>? decoded;
  if (carrier == Carrier.mobile) {
    decoded = decodeMobileResponse(raw);
  } else {
    try {
      final value = jsonDecode(raw);
      decoded = value is Map ? Map<String, dynamic>.from(value) : null;
    } catch (_) {
      return null;
    }
  }
  if (decoded == null) return null;
  final snapshot = switch (carrier) {
    Carrier.mobile => parseMobile(
      decoded,
      queriedAt: DateTime.now(),
      httpStatus: status,
    ),
    Carrier.broadnet => parseBroadnetH5(
      decoded,
      queriedAt: DateTime.now(),
      httpStatus: status,
    ),
    Carrier.unicom => parseUnicomWeb(
      decoded,
      queriedAt: DateTime.now(),
      httpStatus: status,
    ),
    Carrier.telecom => null,
  };
  if (snapshot == null) return null;
  if (carrier == Carrier.broadnet &&
      !shouldApplyBroadnetResponse(
        stage: stage,
        parsedStatus: snapshot.status,
        currentStatus: QueryStatus.error,
        httpStatus: status,
      )) {
    return null;
  }
  return snapshot;
}

Future<Map<String, dynamic>?> _readBroadnetSession() async {
  try {
    final raw = await _secureStorage.read(key: 'broadnet_session');
    if (raw == null) return null;
    final candidate = jsonDecode(raw);
    if (candidate is! Map) return null;
    final session = Map<String, dynamic>.from(candidate);
    final savedAt = DateTime.tryParse(session['savedAt'] as String? ?? '');
    final age = savedAt == null ? null : DateTime.now().difference(savedAt);
    if (age == null || age.isNegative || age >= const Duration(days: 7)) {
      return null;
    }
    return _validBroadnetSession(session) ? session : null;
  } catch (_) {
    return null;
  }
}

bool _validBroadnetSession(Map<String, dynamic> session) =>
    session['phoneInfo'] is String &&
    session['sessionId'] is String &&
    (session['phoneInfo'] as String).isNotEmpty &&
    (session['sessionId'] as String).isNotEmpty &&
    (session['phoneInfo'] as String).length <= 20000 &&
    (session['sessionId'] as String).length <= 20000;

Future<void> _saveBroadnetSession(Map<String, dynamic>? session) async {
  if (session == null || !_validBroadnetSession(session)) return;
  try {
    session['savedAt'] = DateTime.now().toIso8601String();
    await _secureStorage.write(
      key: 'broadnet_session',
      value: jsonEncode(session),
    );
  } catch (_) {
    // The balance remains useful; the next refresh may need foreground login.
  }
}
