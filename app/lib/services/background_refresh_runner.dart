import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_inappwebview_android/flutter_inappwebview_android.dart'
    as android_webview;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/carrier_selection.dart';
import '../data/carrier_accounts.dart';
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
  // A separate FlutterEngine still starts a root isolate. Its Android engine
  // registers plugins; DartPluginRegistrant.ensureInitialized is for spawned isolates.
  _backgroundChannel.setMethodCallHandler((call) async {
    if (call.method != 'start') return false;
    try {
      final report = await _runScheduledRefresh();
      await _backgroundChannel.invokeMethod<void>(
        'completed',
        report ?? {'outcome': 'cancelled'},
      );
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
  if (prefs.getBool('account_profiles_cleanup_pending') == true) {
    return {'outcome': 'cleanup_required'};
  }
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

  final accounts = CarrierAccounts.restore(
    savedJson: prefs.getString(CarrierAccounts.storageKey),
    selection: selection,
  );
  final visibleAccounts = accounts.visibleAccounts(selection);
  final snapshots = <String, CarrierSnapshot>{};
  for (final account in visibleAccounts) {
    final raw = prefs.getString(account.snapshotKey);
    if (raw == null) continue;
    try {
      final snapshot = CarrierSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (snapshot.carrier == account.carrier) snapshots[account.id] = snapshot;
    } catch (_) {
      // A malformed saved record is not a background refresh authorization.
    }
  }

  final connected = <CarrierAccount>[
    for (final account in visibleAccounts)
      if (prefs.getBool(account.connectedKey) ?? false) account,
  ];
  var attempted = 0;
  var succeeded = 0;
  for (final account in connected) {
    final carrier = account.carrier;
    // Telecom currently needs account-page sessionStorage and an already
    // rendered billing DOM. Keep its data on the normal foreground path.
    if (carrier == Carrier.telecom ||
        snapshots[account.id]?.queriedAt == null ||
        (prefs.getBool('background_auth_required_${account.id}') ?? false)) {
      continue;
    }
    if (!await _isTaskCurrent()) return null;

    final previous = snapshots[account.id]!;
    attempted++;
    final result = await _queryInHeadlessWebView(account);
    await prefs.reload();
    if (!await _isTaskCurrent()) return null;
    if (result.status == QueryStatus.success) {
      succeeded++;
      snapshots[account.id] = result.snapshot;
      await prefs.setBool('background_auth_required_${account.id}', false);
      if (carrier == Carrier.broadnet) {
        await _saveBroadnetSession(account, result.session);
      }
    } else {
      snapshots[account.id] = previous.copyWith(
        status: result.status,
        message: result.message,
      );
      if (result.status == QueryStatus.authExpired) {
        await prefs.setBool('background_auth_required_${account.id}', true);
      }
    }
    if (!await _isTaskCurrent()) return null;
    await prefs.setString(
      account.snapshotKey,
      jsonEncode(snapshots[account.id]!.toJson()),
    );
    await prefs.reload();
  }

  if (!await _isTaskCurrent()) return null;
  // A local identity edit may happen while the official page is querying.
  // Publish the current display identity, not the earlier task's copy.
  await prefs.reload();
  final displayAccounts = CarrierAccounts.restore(
    savedJson: prefs.getString(CarrierAccounts.storageKey),
    selection: selection,
  );
  final current = <CarrierSnapshot>[
    for (final account in visibleAccounts)
      if (snapshots[account.id] != null) snapshots[account.id]!,
  ];
  return {
    'outcome': attempted == 0
        ? 'no_eligible_accounts'
        : succeeded == attempted
        ? 'success'
        : succeeded > 0
        ? 'partial'
        : 'no_result',
    'widgetPayload': buildWidgetPayload(
      current,
      thresholdGb: (prefs.getDouble('threshold_gb') ?? 5).clamp(1, 20),
      selection: selection,
      accounts: displayAccounts,
      accountSnapshots: snapshots,
    ),
  };
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

Future<_HeadlessResult> _queryInHeadlessWebView(CarrierAccount account) async {
  final carrier = account.carrier;
  final result = Completer<_HeadlessResult>();
  HeadlessInAppWebView? webView;
  Map<String, dynamic>? broadnetSession;
  var acceptingResponses = true;

  void complete(CarrierSnapshot snapshot) {
    if (acceptingResponses && !result.isCompleted) {
      result.complete(_HeadlessResult(snapshot, session: broadnetSession));
    }
  }

  try {
    final savedSession = carrier == Carrier.broadnet
        ? await _readBroadnetSession(account)
        : null;
    webView = HeadlessInAppWebView(
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
      onWebViewCreated: (created) async {
        if (!acceptingResponses || !await _isTaskCurrent()) return;
        created.addJavaScriptHandler(
          handlerName: 'trafficResponse',
          callback: (args) async {
            if (!acceptingResponses ||
                result.isCompleted ||
                !await _isTaskCurrent()) {
              return false;
            }
            if (args.isEmpty || args.first is! Map) return false;
            final payload = Map<String, dynamic>.from(args.first as Map);
            final currentUrl = await created.getUrl();
            final currentPage = Uri.tryParse(currentUrl?.toString() ?? '');
            if (!acceptingResponses ||
                currentPage == null ||
                currentPage !=
                    Uri.tryParse(payload['pageUrl'] as String? ?? '') ||
                isCarrierLoginPage(currentPage) ||
                !isCarrierNavigationAllowed(carrier, currentPage)) {
              return false;
            }
            final parsed = _parseCapturedResponse(carrier, payload);
            if (parsed != null) complete(parsed);
            return true;
          },
        );
        try {
          if (account.profileName != null) {
            if (!await android_webview
                .AndroidInAppWebViewController.supportsAccountProfiles()) {
              throw StateError('WebView account profiles unavailable');
            }
            await (created.platform
                    as android_webview.AndroidInAppWebViewController)
                .setAccountProfile(account.profileName!);
          }
          if (!acceptingResponses || !await _isTaskCurrent()) return;
          await created.loadUrl(
            urlRequest: URLRequest(url: WebUri(carrierQueryUrl(carrier))),
          );
        } catch (_) {
          complete(
            CarrierSnapshot(
              carrier: carrier,
              status: QueryStatus.error,
              message: '后台账号会话暂不可用，请打开 APP 查询',
            ),
          );
        }
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
        if (!acceptingResponses || url == null) return;
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
    await webView.run().timeout(const Duration(seconds: 15));
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
    acceptingResponses = false;
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
  if (carrier == Carrier.unicom && stage == 'unicomSession') {
    return isUnicomSessionExpired(decoded, status)
        ? const CarrierSnapshot(
            carrier: Carrier.unicom,
            status: QueryStatus.authExpired,
            message: '联通官网登录已失效，请重新连接号码',
          )
        : null;
  }
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

Future<Map<String, dynamic>?> _readBroadnetSession(
  CarrierAccount account,
) async {
  try {
    final raw = await _secureStorage.read(key: account.broadnetSessionKey);
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

Future<void> _saveBroadnetSession(
  CarrierAccount account,
  Map<String, dynamic>? session,
) async {
  if (session == null || !_validBroadnetSession(session)) return;
  try {
    session['savedAt'] = DateTime.now().toIso8601String();
    await _secureStorage.write(
      key: account.broadnetSessionKey,
      value: jsonEncode(session),
    );
  } catch (_) {
    // The balance remains useful; the next refresh may need foreground login.
  }
}
