import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/models.dart';
import 'data/carrier_selection.dart';
import 'ui/carrier_selection_screen.dart';
import 'data/parsers.dart';
import 'services/page_probe.dart';
import 'services/carrier_web.dart';
import 'services/telecom_page_probe.dart';
import 'services/response_policy.dart';
import 'services/widget_bridge.dart';
import 'ui/dashboard_screen.dart';

const demoMode = bool.fromEnvironment('DEMO');
const _notifications = MethodChannel('cn.liuliang/notifications');
const _secure = FlutterSecureStorage();
const _widgetBridge = WidgetBridge();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlowBuddyApp());
}

class FlowBuddyApp extends StatelessWidget {
  const FlowBuddyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '流量小伙伴',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFFFAF2),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7EA6DB)),
    ),
    home: const FlowHome(),
  );
}

class FlowHome extends StatefulWidget {
  const FlowHome({super.key});
  @override
  State<FlowHome> createState() => _FlowHomeState();
}

class _FlowHomeState extends State<FlowHome> with WidgetsBindingObserver {
  final Map<Carrier, CarrierSnapshot> _snapshots = {
    for (final carrier in Carrier.values)
      carrier: CarrierSnapshot(
        carrier: carrier,
        status: QueryStatus.notConnected,
      ),
  };
  final Map<Carrier, InAppWebViewController> _controllers = {};
  final Set<Carrier> _connected = {};
  final Map<Carrier, Timer> _timeouts = {};
  final Map<Carrier, DateTime> _lastRequests = {};
  final Map<Carrier, bool> _warnedLow = {};
  SharedPreferences? _prefs;
  CarrierSelection _selection = CarrierSelection.unconfigured();
  Set<Carrier> _draftSelection = {};
  bool _restoring = true;
  bool _savingSelection = false;
  Map<String, dynamic>? _broadnetSession;
  Carrier? _visibleCarrier;
  double _thresholdGb = 5;
  bool _reminders = false;
  int _generation = 0;
  String? _webMessage;
  Timer? _foregroundTimer;
  bool _clearing = false;
  Future<void> _storageTasks = Future<void>.value();

  bool _current(int generation) =>
      mounted && !_clearing && generation == _generation;

  Future<void> _store(Future<void> Function() operation) {
    final task = _storageTasks.then((_) => operation());
    _storageTasks = task.catchError((Object _) {});
    return task;
  }

  Future<void> _closeOfficialPage() async {
    final generation = _generation;
    final controller = _controllers[Carrier.broadnet];
    if (_visibleCarrier == Carrier.broadnet && controller != null) {
      await _saveSession(controller, generation);
    }
    if (_current(generation)) setState(() => _visibleCarrier = null);
  }

  Future<void> _publishWidget() async {
    if (!_android || demoMode || _clearing) return;
    final generation = _generation;
    await _store(() async {
      if (_current(generation)) {
        await _widgetBridge.update(
          _snapshots.values,
          _thresholdGb,
          selection: _selection,
        );
      }
    });
  }

  Future<void> _openFromWidget() async {
    if (!mounted || _clearing) return;
    setState(() => _visibleCarrier = null);
    _lastRequests.clear();
    _refreshAll();
  }

  Future<void> _addWidget() async {
    if (!_android || demoMode) return;
    await _publishWidget();
    if (!mounted || _clearing) return;
    try {
      final requested = await _widgetBridge.requestPin();
      if (!requested && mounted) {
        _showInfo(
          '从桌面添加卡片',
          '请长按桌面空白处，进入「小组件」或「窗口小工具」，找到「流量小伙伴」并拖到桌面。\n\n卡片显示上次查询的余额与时间，轻点会打开 APP 更新。',
        );
      }
    } on PlatformException {
      if (mounted) {
        _showInfo('从桌面添加卡片', '请长按手机桌面，在小组件中找到「流量小伙伴」。不同桌面的入口名称可能略有不同。');
      }
    }
  }

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_android && !demoMode) _widgetBridge.onOpen(_openFromWidget);
    if (demoMode) {
      _selection = CarrierSelection.complete(Carrier.values);
      _restoring = false;
      for (final carrier in Carrier.values) {
        _snapshots[carrier] = CarrierSnapshot(
          carrier: carrier,
          status: QueryStatus.success,
          queriedAt: DateTime.now(),
          phoneMasked: switch (carrier) {
            Carrier.mobile => '138****2088',
            Carrier.broadnet => '192****6099',
            Carrier.unicom => '186****3056',
            Carrier.telecom => '189****4066',
          },
          message: carrier == Carrier.telecom
              ? '根据官网已用/总量显示值估算，有舍入误差（此处为演示）'
              : null,
          buckets: [
            TrafficBucket(
              name: carrier == Carrier.unicom
                  ? '官网套餐余量'
                  : carrier == Carrier.telecom
                  ? '国内流量（演示）'
                  : '通用流量',
              kind: carrier == Carrier.unicom || carrier == Carrier.telecom
                  ? BucketKind.unknown
                  : BucketKind.general,
              rawUnit: 'GB',
              remainingBytes:
                  ((carrier == Carrier.mobile ? 23.6 : 4.8) * 1073741824)
                      .round(),
              totalBytes: (carrier == Carrier.mobile ? 50 : 30) * 1073741824,
            ),
            if (carrier == Carrier.mobile)
              const TrafficBucket(
                name: '视频定向流量',
                kind: BucketKind.directed,
                remainingBytes: 10 * 1073741824,
                totalBytes: 20 * 1073741824,
              ),
          ],
        );
      }
    } else {
      unawaited(_restore());
    }
    _foregroundTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          _visibleCarrier == null) {
        _refreshAll();
      }
    });
  }

  Future<void> _restore() async {
    final generation = _generation;
    final prefs = await SharedPreferences.getInstance();
    if (!_current(generation)) return;
    _prefs = prefs;
    Map<String, dynamic>? session;
    try {
      final raw = await _secure
          .read(key: 'broadnet_session')
          .timeout(const Duration(seconds: 3));
      if (raw != null) {
        final candidate = jsonDecode(raw) as Map<String, dynamic>;
        final savedAt = DateTime.tryParse(
          candidate['savedAt'] as String? ?? '',
        );
        final age = savedAt == null ? null : DateTime.now().difference(savedAt);
        if (age != null && !age.isNegative && age < const Duration(days: 7)) {
          session = candidate;
        } else {
          await _secure.delete(key: 'broadnet_session');
        }
      }
    } catch (_) {
      /* A corrupt session requires official login again. */
    }
    if (!_current(generation)) return;
    setState(() {
      _prefs = prefs;
      _selection = CarrierSelection.restore(
        savedJson: prefs.get('carrier_selection') == null
            ? null
            : prefs.get('carrier_selection') is String
            ? prefs.get('carrier_selection') as String
            : 'invalid',
        legacyPreferences: {
          for (final key in prefs.getKeys()) key: prefs.get(key),
        },
      );
      _restoring = false;
      _broadnetSession = session;
      _thresholdGb = (prefs.getDouble('threshold_gb') ?? 5).clamp(1, 20);
      _reminders = prefs.getBool('reminders') ?? false;
      for (final carrier in Carrier.values) {
        final raw = prefs.getString('snapshot_${carrier.name}');
        if (raw != null) {
          try {
            final snapshot = CarrierSnapshot.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            );
            _snapshots[carrier] = snapshot.copyWith(
              status: QueryStatus.error,
              message: '上次查询记录，正在确认最新状态',
            );
          } catch (_) {
            /* Retain the explicit unconnected state. */
          }
        }
        if (prefs.getBool('connected_${carrier.name}') ?? false) {
          _connected.add(carrier);
        }
      }
    });
    await _store(() async {
      if (_current(generation)) {
        await prefs.setString(
          'carrier_selection',
          _selection.toStorageString(),
        );
      }
    });
    await _publishWidget();
    if (_android && !demoMode && _current(generation)) {
      if (await _widgetBridge.consumeLaunchRefresh()) await _openFromWidget();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visibleCarrier == null) {
      _refreshAll();
    }
  }

  String _queryUrl(Carrier carrier) => carrierQueryUrl(carrier);
  String _loginUrl(Carrier carrier) => carrierLoginUrl(carrier);

  bool _allowedUrl(Carrier carrier, WebUri? url) {
    if (url == null) return false;
    final uri = Uri.tryParse(url.toString());
    return uri != null && isCarrierNavigationAllowed(carrier, uri);
  }

  void _connect(Carrier carrier) {
    if (_clearing || !_selection.allows(carrier)) return;
    if (demoMode || !_android) {
      _showInfo('这是界面预览', '请安装安卓测试包后连接号码。演示流量不是您的实际余额。');
      return;
    }
    setState(() {
      _visibleCarrier = carrier;
      _webMessage = null;
      _connected.add(carrier);
    });
    final prefs = _prefs;
    if (prefs != null) {
      final generation = _generation;
      unawaited(
        _store(() async {
          if (_current(generation)) {
            await prefs.setBool('connected_${carrier.name}', true);
          }
        }),
      );
    }
    final controller = _controllers[carrier];
    if (controller != null) {
      unawaited(
        controller.loadUrl(
          urlRequest: URLRequest(url: WebUri(_loginUrl(carrier))),
        ),
      );
    }
  }

  void _refreshAll() {
    if (demoMode || _clearing) return;
    for (final carrier in _selection.queryableCarriers(_connected)) {
      _refresh(carrier, automatic: true);
    }
  }

  Future<void> _refresh(Carrier carrier, {bool automatic = false}) async {
    if (_clearing || !_selection.allows(carrier)) return;
    if (!_connected.contains(carrier)) {
      if (!automatic) _connect(carrier);
      return;
    }
    final last = _lastRequests[carrier];
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 30)) {
      return;
    }
    final controller = _controllers[carrier];
    if (controller == null) return;
    final generation = _generation;
    if (carrier == Carrier.broadnet) await _saveSession(controller, generation);
    if (!_current(generation)) return;
    _lastRequests[carrier] = DateTime.now();
    setState(
      () => _snapshots[carrier] = _snapshots[carrier]!.copyWith(
        status: QueryStatus.loading,
        message: '正在向运营商查询',
      ),
    );
    unawaited(_publishWidget());
    _timeouts[carrier]?.cancel();
    _timeouts[carrier] = Timer(const Duration(seconds: 35), () {
      if (!mounted || _snapshots[carrier]!.status != QueryStatus.loading) {
        return;
      }
      setState(
        () => _snapshots[carrier] = _snapshots[carrier]!.copyWith(
          status: QueryStatus.error,
          message: '未取得可识别的流量结果，请打开官方查询页确认',
        ),
      );
      unawaited(_publishWidget());
    });
    unawaited(
      controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(_queryUrl(carrier))),
      ),
    );
  }

  Future<void> _receive(
    Carrier carrier,
    List<dynamic> args,
    int generation,
  ) async {
    if (!_current(generation) || !_selection.allows(carrier)) return;
    if (args.isEmpty || args.first is! Map) return;
    final payload = Map<String, dynamic>.from(args.first as Map);
    final url = Uri.tryParse(payload['url'] as String? ?? '');
    final page = Uri.tryParse(payload['pageUrl'] as String? ?? '');
    final stage = payload['stage'] is String
        ? payload['stage'] as String
        : null;
    if (!isCarrierResponseAllowed(carrier, url, page, stage)) return;
    if (carrier == Carrier.unicom || carrier == Carrier.telecom) {
      // A queued event from a Home page must not revive a logged-out SPA.
      final controller = _controllers[carrier];
      if (controller == null) return;
      try {
        final currentUrl = await controller.getUrl();
        if (!_current(generation) ||
            !_selection.allows(carrier) ||
            currentUrl == null ||
            Uri.tryParse(currentUrl.toString()) != page) {
          return;
        }
      } on Exception {
        return;
      }
    }
    final raw = payload['body'];
    if (raw is! String || raw.length > 2000000) return;
    final Map<String, dynamic>? decoded;
    if (carrier == Carrier.mobile) {
      decoded = decodeMobileResponse(raw);
    } else {
      try {
        final value = jsonDecode(raw);
        decoded = value is Map ? Map<String, dynamic>.from(value) : null;
      } catch (_) {
        return;
      }
    }
    if (decoded == null) return;
    final status = payload['status'] is int ? payload['status'] as int : null;
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
      Carrier.telecom => parseTelecomRendered(
        decoded,
        queriedAt: DateTime.now(),
      ),
    };
    if (carrier == Carrier.broadnet &&
        !shouldApplyBroadnetResponse(
          stage: payload['stage'] is String ? payload['stage'] as String : null,
          parsedStatus: snapshot.status,
          currentStatus: _snapshots[carrier]!.status,
          httpStatus: status,
        )) {
      // Prefer the site's decoded event, but accept an independently verified
      // plaintext raw success if that event was not observed.
      return;
    }
    if (!mounted) return;
    _timeouts[carrier]?.cancel();
    setState(
      () => _snapshots[carrier] = snapshot.status == QueryStatus.success
          ? snapshot
          : _snapshots[carrier]!.copyWith(
              status: snapshot.status,
              message: snapshot.message,
            ),
    );
    await _publishWidget();
    if (!_current(generation)) return;
    if (snapshot.status == QueryStatus.success) {
      await _store(() async {
        if (_current(generation)) {
          await _prefs?.setString(
            'snapshot_${carrier.name}',
            jsonEncode(snapshot.toJson()),
          );
        }
      });
      if (!_current(generation)) return;
      final remaining = snapshot.generalRemainingBytes;
      final low = remaining != null && remaining / 1073741824 <= _thresholdGb;
      if (low && !(_warnedLow[carrier] ?? false) && _reminders && _android) {
        try {
          await _notifications.invokeMethod('notify', {
            'id': carrier.index + 1,
            'title': '${carrier.label}流量快见底了',
            'body':
                '通用流量剩余 ${(remaining / 1073741824).toStringAsFixed(2)} GB，数据以运营商查询为准。',
          });
        } on PlatformException {
          /* Dashboard retains the actual result. */
        }
      }
      _warnedLow[carrier] = low;
    }
  }

  Future<void> _saveSession(
    InAppWebViewController controller,
    int generation,
  ) async {
    if (!_current(generation)) return;
    try {
      final result = await controller.evaluateJavascript(
        source: broadnetSessionCaptureScript,
      );
      if (!_current(generation) || result is! Map) return;
      final session = Map<String, dynamic>.from(result);
      if (session['phoneInfo'] is! String ||
          session['sessionId'] is! String ||
          (session['phoneInfo'] as String).isEmpty ||
          (session['sessionId'] as String).isEmpty) {
        return;
      }
      if (_broadnetSession?['sessionId'] == session['sessionId']) return;
      session['savedAt'] = DateTime.now().toIso8601String();
      await _store(() async {
        if (_current(generation)) {
          await _secure.write(
            key: 'broadnet_session',
            value: jsonEncode(session),
          );
        }
      });
      if (_current(generation)) _broadnetSession = session;
    } catch (_) {
      /* Official login remains usable for this WebView session. */
    }
  }

  Widget _webView(Carrier carrier) {
    final generation = _generation;
    return Positioned.fill(
      key: ValueKey('view_${carrier.name}_$generation'),
      child: Offstage(
        offstage: _visibleCarrier != carrier,
        child: Column(
          children: [
            Material(
              color: const Color(0xFFFFFAF2),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _closeOfficialPage,
                          icon: const Icon(Icons.close),
                        ),
                        Expanded(
                          child: Text(
                            '${carrier.label}官方页面',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _refresh(carrier),
                          child: const Text('查询流量'),
                        ),
                        IconButton(
                          onPressed: () => _controllers[carrier]?.reload(),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        _webMessage ?? '在官网完成验证后点击「查询流量」。关闭此页可回到首页。',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF736F69),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: InAppWebView(
                key: ValueKey('${carrier.name}_$_generation'),
                initialUrlRequest: URLRequest(
                  url: WebUri(
                    _snapshots[carrier]!.status == QueryStatus.notConnected
                        ? _loginUrl(carrier)
                        : _queryUrl(carrier),
                  ),
                ),
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
                  if (carrier == Carrier.telecom)
                    UserScript(
                      source: telecomRenderedCaptureScript,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  if (carrier == Carrier.broadnet)
                    UserScript(
                      groupName: 'broadnetRestore',
                      source: broadnetSessionRestoreScript(_broadnetSession),
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                ]),
                onWebViewCreated: (controller) {
                  if (!_current(generation)) return;
                  _controllers[carrier] = controller;
                  controller.addJavaScriptHandler(
                    handlerName: 'trafficResponse',
                    callback: (args) => _receive(carrier, args, generation),
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_current(generation) &&
                        _snapshots[carrier]!.status !=
                            QueryStatus.notConnected) {
                      _refresh(carrier);
                    }
                  });
                },
                shouldOverrideUrlLoading: (controller, action) async =>
                    _allowedUrl(carrier, action.request.url)
                    ? NavigationActionPolicy.ALLOW
                    : NavigationActionPolicy.CANCEL,
                onUpdateVisitedHistory: (controller, url, isReload) {
                  if (!_current(generation) || url == null) return;
                  final uri = Uri.tryParse(url.toString());
                  if (uri != null && isCarrierLoginPage(uri)) {
                    _timeouts[carrier]?.cancel();
                    setState(
                      () => _snapshots[carrier] = _snapshots[carrier]!.copyWith(
                        status: QueryStatus.authExpired,
                        message: '请在官方页面验证号码，完成后查询流量',
                      ),
                    );
                    unawaited(_publishWidget());
                  }
                },
                onLoadStop: (controller, url) async {
                  if (!_current(generation)) return;
                  if (url != null &&
                      isCarrierLoginPage(Uri.parse(url.toString()))) {
                    if (carrier == Carrier.broadnet) {
                      _broadnetSession = null;
                      await controller.removeUserScriptsByGroupName(
                        groupName: 'broadnetRestore',
                      );
                      await _store(() async {
                        if (_current(generation)) {
                          await _secure.delete(key: 'broadnet_session');
                        }
                      });
                    }
                    if (!_current(generation)) return;
                    _timeouts[carrier]?.cancel();
                    setState(
                      () => _snapshots[carrier] = _snapshots[carrier]!.copyWith(
                        status: QueryStatus.authExpired,
                        message: '请在官方页面验证号码，完成后查询流量',
                      ),
                    );
                    unawaited(_publishWidget());
                  } else if (carrier == Carrier.broadnet &&
                      url?.host == 'www.10099.com.cn') {
                    await _saveSession(controller, generation);
                  }
                },
                onReceivedError: (controller, request, error) {
                  if (request.isForMainFrame != true || !_current(generation)) {
                    return;
                  }
                  _timeouts[carrier]?.cancel();
                  setState(() {
                    _webMessage = '官方页面暂时无法打开，请检查网络后重试';
                    _snapshots[carrier] = _snapshots[carrier]!.copyWith(
                      status: QueryStatus.error,
                      message: _webMessage,
                    );
                  });
                  unawaited(_publishWidget());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applySelection(Set<Carrier> carriers) async {
    if (_savingSelection || carriers.isEmpty || _clearing) return;
    final previousSelection = _selection;
    final selection = CarrierSelection.complete(carriers);
    final oldControllers = _controllers.values.toList();
    setState(() {
      _savingSelection = true;
      _generation++;
      _selection = selection;
      _controllers.clear();
      _visibleCarrier = null;
      _lastRequests.clear();
      _warnedLow.clear();
    });
    final generation = _generation;
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    for (final controller in oldControllers) {
      try {
        await controller.stopLoading();
      } on Exception {
        /* Already disposed. */
      }
    }
    try {
      await _store(() async {
        if (_current(generation)) {
          if (_android && !demoMode) {
            await _widgetBridge.clear();
          }
          final saved = await _prefs?.setString(
            'carrier_selection',
            selection.toStorageString(),
          );
          if (saved == false) throw StateError('Selection save failed');
          if (_android && !demoMode) {
            try {
              await _notifications.invokeMethod('cancelAll');
            } on PlatformException {
              /* Display and query selection stay valid. */
            }
          }
        }
      });
      if (_current(generation)) {
        setState(() => _savingSelection = false);
        await _publishWidget();
      }
    } catch (_) {
      if (_current(generation)) {
        setState(() {
          _selection = previousSelection;
          _savingSelection = false;
        });
        await _publishWidget();
        _showInfo('设置暂未完整保存', '请重新选择运营商并保存。');
      }
    }
  }

  Future<void> _manageCarriers() async {
    var draft = _selection.selectedCarriers.toSet();
    final result = await Navigator.of(context).push<Set<Carrier>>(
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, update) => CarrierSelectionScreen(
            selectedCarriers: draft,
            onSelectionChanged: (value) => update(() => draft = value),
            onContinue: (value) => Navigator.pop(context, value),
            isInitialSetup: false,
            demo: demoMode,
          ),
        ),
      ),
    );
    if (result != null && mounted) await _applySelection(result);
  }

  Future<void> _settings() async {
    double threshold = _thresholdGb;
    bool reminders = _reminders;
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '照顾好你的流量',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('管理运营商'),
                  subtitle: Text(
                    _selection.selectedCarriers.map((c) => c.label).join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_manageCarriers());
                  },
                ),
                Text('通用流量低于 ${threshold.toStringAsFixed(0)} GB 时提醒'),
                Slider(
                  value: threshold,
                  min: 1,
                  max: 20,
                  divisions: 19,
                  onChanged: (value) => update(() => threshold = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('低流量通知'),
                  value: reminders,
                  onChanged: (value) => update(() => reminders = value),
                ),
                const Text(
                  '打开 APP 和回到前台时查询；在前台每 5 分钟尝试更新。关闭 APP 后不持续查询。运营商账单可能延迟。',
                  style: TextStyle(fontSize: 13, color: Color(0xFF736F69)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('保存设置'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _clearData();
                  },
                  child: const Text('清除号码连接与本地数据'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (save != true || !mounted) return;
    var permitted = reminders;
    if (reminders && _android) {
      try {
        permitted =
            await _notifications.invokeMethod<bool>('requestPermission') ??
            false;
      } on PlatformException {
        permitted = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _thresholdGb = threshold;
      _reminders = permitted;
      _warnedLow.clear();
    });
    await _prefs?.setDouble('threshold_gb', threshold);
    await _prefs?.setBool('reminders', permitted);
    await _publishWidget();
  }

  Future<void> _clearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除本地连接？'),
        content: const Text('将删除此 APP 中的查询记录和登录会话，之后需要重新验证号码。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final oldControllers = _controllers.values.toList();
    setState(() {
      _clearing = true;
      _generation++;
      _connected.clear();
      _controllers.clear();
      _visibleCarrier = null;
      _broadnetSession = null;
    });
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    await Future.wait(
      oldControllers.map((controller) async {
        try {
          await controller.stopLoading();
        } on Exception {
          /* View is already disposed. */
        }
      }),
    );
    await WidgetsBinding.instance.endOfFrame;
    await _storageTasks;
    if (_android) {
      await CookieManager.instance().deleteAllCookies();
      await WebStorageManager.instance().deleteAllData();
      await _widgetBridge.clear();
      try {
        await _notifications.invokeMethod('cancelAll');
      } on PlatformException {
        /* No active notifications. */
      }
    }
    await _secure.delete(key: 'broadnet_session');
    for (final carrier in Carrier.values) {
      await _prefs?.remove('snapshot_${carrier.name}');
      await _prefs?.remove('connected_${carrier.name}');
    }
    if (!mounted) return;
    setState(() {
      _clearing = false;
      _connected.clear();
      _controllers.clear();
      _lastRequests.clear();
      _warnedLow.clear();
      _broadnetSession = null;
      _visibleCarrier = null;
      for (final carrier in Carrier.values) {
        _snapshots[carrier] = CarrierSnapshot(
          carrier: carrier,
          status: QueryStatus.notConnected,
        );
      }
    });
    await _publishWidget();
  }

  void _showInfo(String title, String content) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _visibleCarrier == null,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_closeOfficialPage());
    },
    child: Scaffold(
      body: Stack(
        children: [
          if (_restoring || _savingSelection)
            const Center(child: CircularProgressIndicator())
          else if (!_selection.setupCompleted)
            CarrierSelectionScreen(
              selectedCarriers: _draftSelection,
              onSelectionChanged: (value) =>
                  setState(() => _draftSelection = value),
              onContinue: (value) => unawaited(_applySelection(value)),
              demo: demoMode,
            )
          else
            DashboardScreen(
              snapshots: _selection.visibleSnapshots(_snapshots.values),
              selectedCarriers: _selection.selectedCarriers,
              onManageCarriers: _manageCarriers,
              thresholdGb: _thresholdGb,
              onConnect: _connect,
              onRefresh: _refresh,
              onRefreshAll: _refreshAll,
              onSettings: _settings,
              onAddWidget: _addWidget,
              widgetSupported: _android && !demoMode,
              onAbout: () => _showInfo(
                '流量小伙伴 · 测试版',
                '可选择移动、联通、电信、广电，至少一家。数据来自您登录官方网页后的查询结果，通用、定向和用途未知的流量分开展示。\n\n联通展示官网套餐余量；电信按官网已用量和总量的舍入显示值估算，主位标「约」，均不当作已确认通用额度或触发提醒。真实号码登录和余额准确性仍需手机验证，无法识别时请在官方查询页查看。\n\n会话保存在手机本地，广电会话备份使用系统安全存储；不上传第三方服务器，不读取短信或服务密码。桌面卡片显示上次查询的余额和时间，点击打开 APP 更新；APP 关闭后不会持续查询。',
              ),
              demo: demoMode,
            ),
          if (_android && !demoMode)
            if (!_restoring && !_savingSelection)
              for (final carrier in _selection.queryableCarriers(_connected))
                _webView(carrier),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    if (_android && !demoMode) _widgetBridge.onOpen(null);
    WidgetsBinding.instance.removeObserver(this);
    _foregroundTimer?.cancel();
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
