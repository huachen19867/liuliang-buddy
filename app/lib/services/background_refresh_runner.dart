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
import '../data/traffic_classification.dart';
import '../data/models.dart';
import '../data/parsers.dart';
import 'carrier_web.dart';
import 'page_probe.dart';
import 'broadnet_session.dart';
import 'mobile_query_assembly.dart';
import 'unicom_official_query.dart';
import 'unicom_app_client.dart';
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
    final appMode =
        carrier == Carrier.unicom &&
        prefs.getString('unicom_query_method_${account.id}') == 'app';
    final appSessionRaw = appMode
        ? await _readUnicomAppSession(account.id)
        : null;
    if (!await _isTaskCurrent()) return null;
    UnicomAppQueryResult? appResult;
    _HeadlessResult result;
    if (appMode) {
      try {
        if (appSessionRaw == null) throw const FormatException();
        final session = UnicomAppSession.restore(appSessionRaw);
        if (account.phoneNumber != null &&
            account.phoneNumber != session.phoneNumber) {
          throw const FormatException();
        }
        appResult = await UnicomAppClient().query(
          session,
          isCurrent: _isTaskCurrent,
        );
        result = _HeadlessResult(appResult.snapshot);
      } catch (_) {
        result = const _HeadlessResult(
          CarrierSnapshot(
            carrier: Carrier.unicom,
            status: QueryStatus.authExpired,
            message: '联通 App 会话不可用，请打开应用重新连接',
          ),
        );
      }
    } else {
      result = await _queryInHeadlessWebView(account);
    }
    await prefs.reload();
    if (!await _isTaskCurrent()) return null;
    final latestAccounts = CarrierAccounts.restore(
      savedJson: prefs.getString(CarrierAccounts.storageKey),
      selection: selection,
    );
    final latestAccount = latestAccounts.find(account.id);
    if (latestAccount == null ||
        !latestAccount.enabled ||
        latestAccount.phoneNumber != account.phoneNumber) {
      continue;
    }
    if (carrier == Carrier.broadnet &&
        !sameBroadnetSession(
          await _readBroadnetSession(account),
          result.initialSession,
        )) {
      // A fresh foreground login must not be overwritten or paused by a
      // response sent using the previous official session.
      continue;
    }
    if (!await _isTaskCurrent()) return null;
    if (carrier == Carrier.unicom) {
      final stillApp =
          prefs.getString('unicom_query_method_${account.id}') == 'app';
      if (stillApp != appMode) continue;
      if (appMode) {
        final currentRaw = await _readUnicomAppSession(account.id);
        if (!await _isTaskCurrent()) return null;
        // A foreground import, logout or renewal supersedes this task's copy.
        if (currentRaw != appSessionRaw) continue;
        if (appResult != null &&
            jsonEncode(appResult.session.toJson()) != appSessionRaw) {
          try {
            await _secureStorage.write(
              key: UnicomAppSession.storageKey(account.id),
              value: jsonEncode(appResult.session.toJson()),
            );
          } catch (_) {
            // A failed renewal save must not block the following accounts.
            result = const _HeadlessResult(
              CarrierSnapshot(
                carrier: Carrier.unicom,
                status: QueryStatus.authExpired,
                message: '联通新会话暂未保存，请打开应用重新连接',
              ),
            );
          }
          if (!await _isTaskCurrent()) return null;
        }
      }
    }
    if (result.status == QueryStatus.success) {
      succeeded++;
      snapshots[account.id] = result.snapshot;
      await prefs.setBool('background_auth_required_${account.id}', false);
      if (carrier == Carrier.broadnet) {
        await _saveBroadnetSession(
          account,
          result.session,
          expected: result.initialSession,
        );
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
  // Only the foreground editor writes this key. An in-flight network response
  // must use the latest choices rather than the task's earlier cached copy.
  final classifications = TrafficClassificationOverrides.restore(
    prefs.getString(TrafficClassificationOverrides.storageKey),
  );
  for (final account in displayAccounts.accounts) {
    final snapshot = snapshots[account.id];
    if (snapshot != null) {
      snapshots[account.id] = classifications.apply(account.id, snapshot);
    }
  }
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

Future<String?> _readUnicomAppSession(String accountId) async {
  try {
    return await _secureStorage
        .read(key: UnicomAppSession.storageKey(accountId))
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    return null;
  }
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
  const _HeadlessResult(this.snapshot, {this.session, this.initialSession});
  final CarrierSnapshot snapshot;
  final Map<String, dynamic>? session;
  final Map<String, dynamic>? initialSession;
  QueryStatus get status => snapshot.status;
  String? get message => snapshot.message;
}

Future<_HeadlessResult> _queryInHeadlessWebView(CarrierAccount account) async {
  final carrier = account.carrier;
  final result = Completer<_HeadlessResult>();
  HeadlessInAppWebView? webView;
  Map<String, dynamic>? broadnetSession;
  Map<String, dynamic>? initialBroadnetSession;
  var acceptingResponses = true;
  final mobileQuery = MobileQueryAssembly();
  CarrierSnapshot? pendingMobileFlow;

  void complete(CarrierSnapshot snapshot) {
    if (acceptingResponses && !result.isCompleted) {
      result.complete(
        _HeadlessResult(
          snapshot,
          session: broadnetSession,
          initialSession: initialBroadnetSession,
        ),
      );
    }
  }

  try {
    final savedSession = carrier == Carrier.broadnet
        ? await _readBroadnetSession(account)
        : null;
    initialBroadnetSession = savedSession;
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
        if (carrier == Carrier.mobile)
          UserScript(
            source: mobileBalanceCaptureScript,
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
            final capturedPage = Uri.tryParse(
              payload['pageUrl'] as String? ?? '',
            );
            if (!acceptingResponses ||
                currentPage == null ||
                capturedPage == null ||
                !isCarrierResponsePageCurrent(
                  carrier,
                  capturedPage,
                  currentPage,
                ) ||
                isCarrierLoginPage(currentPage) ||
                !isCarrierNavigationAllowed(carrier, currentPage)) {
              return false;
            }
            if (carrier == Carrier.mobile &&
                payload['stage'] == 'mobileBalanceRendered') {
              final responseUrl = Uri.tryParse(payload['url'] as String? ?? '');
              final raw = payload['body'];
              if (isCarrierResponseAllowed(
                    carrier,
                    responseUrl,
                    capturedPage,
                    'mobileBalanceRendered',
                  ) &&
                  raw is String) {
                final decoded = decodeMobileResponse(raw);
                if (decoded != null) {
                  mobileQuery.acceptBalance(
                    parseMobileBalanceRendered(decoded),
                  );
                }
              }
              return true;
            }
            var parsed = _parseCapturedResponse(carrier, payload);
            if (parsed != null && carrier == Carrier.mobile) {
              if (!mobileQuery.claimFlow()) return false;
              if (parsed.status == QueryStatus.success) {
                pendingMobileFlow = parsed.copyWith(
                  balanceYuan: null,
                  message: '${parsed.message ?? '流量已更新'}；话费余额暂未取得',
                );
                try {
                  await created
                      .evaluateJavascript(source: mobileBalanceCaptureScript)
                      .timeout(const Duration(seconds: 1));
                } on Exception {
                  // Allowances remain useful if the balance is unavailable.
                }
                parsed = await mobileQuery.assemble(parsed);
                Uri? latestPage;
                try {
                  latestPage = Uri.tryParse(
                    (await created.getUrl())?.toString() ?? '',
                  );
                } on Exception {
                  return false;
                }
                if (!acceptingResponses ||
                    result.isCompleted ||
                    !await _isTaskCurrent() ||
                    latestPage == null ||
                    !isCarrierResponsePageCurrent(
                      carrier,
                      capturedPage,
                      latestPage,
                    )) {
                  return false;
                }
              }
            }
            if (parsed?.status == QueryStatus.success &&
                carrier == Carrier.broadnet) {
              try {
                final captured = await created
                    .evaluateJavascript(source: broadnetSessionCaptureScript)
                    .timeout(const Duration(seconds: 2));
                broadnetSession = normalizeBroadnetSession(captured);
              } on Exception {
                // An existing backup is retained if capture is unavailable.
              }
            }
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
        if (carrier == Carrier.unicom) {
          try {
            await created.evaluateJavascript(source: unicomOfficialQueryScript);
          } on Exception {
            // Existing bounded task timeout retains the prior snapshot.
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
        pendingMobileFlow ??
            CarrierSnapshot(
              carrier: carrier,
              status: QueryStatus.error,
              message: '后台未取得可识别结果，保留上次查询时间',
            ),
        initialSession: initialBroadnetSession,
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
      initialSession: initialBroadnetSession,
    );
  } finally {
    acceptingResponses = false;
    mobileQuery.cancel();
    try {
      await webView?.dispose().timeout(const Duration(seconds: 3));
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
    final raw = await _secureStorage
        .read(key: account.broadnetSessionKey)
        .timeout(const Duration(seconds: 3));
    if (raw == null) return null;
    return normalizeBroadnetSession(jsonDecode(raw));
  } catch (_) {
    return null;
  }
}

bool _validBroadnetSession(Map<String, dynamic> session) =>
    normalizeBroadnetSession(session) != null;

Future<void> _saveBroadnetSession(
  CarrierAccount account,
  Map<String, dynamic>? session, {
  required Map<String, dynamic>? expected,
}) async {
  if (session == null || !_validBroadnetSession(session)) return;
  try {
    final captured = captureBroadnetSession(
      session,
      capturedAt: DateTime.now(),
    );
    if (captured == null) return;
    if (!sameBroadnetSession(await _readBroadnetSession(account), expected) ||
        !await _isTaskCurrent()) {
      return;
    }
    await _secureStorage.write(
      key: account.broadnetSessionKey,
      value: jsonEncode(captured),
    );
  } catch (_) {
    // The balance remains useful; the next refresh may need foreground login.
  }
}
