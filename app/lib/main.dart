import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_inappwebview_android/flutter_inappwebview_android.dart'
    as android_webview;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/models.dart';
import 'data/carrier_selection.dart';
import 'data/carrier_accounts.dart';
import 'ui/carrier_selection_screen.dart';
import 'data/parsers.dart';
import 'services/page_probe.dart';
import 'services/carrier_web.dart';
import 'services/background_refresh.dart';
import 'services/background_refresh_runner.dart';
import 'services/telecom_page_probe.dart';
import 'services/response_policy.dart';
import 'services/widget_bridge.dart';
import 'services/ios_account_profiles.dart';
import 'ui/dashboard_screen.dart';

const demoMode = bool.fromEnvironment('DEMO');
const _notifications = MethodChannel('cn.liuliang/notifications');
const _secure = FlutterSecureStorage();
const _widgetBridge = WidgetBridge();

@pragma('vm:entry-point')
Future<void> backgroundRefreshEntrypoint() => runBackgroundRefreshEntrypoint();

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
  final Map<String, CarrierSnapshot> _accountSnapshots = {};
  final Map<String, InAppWebViewController> _controllers = {};
  final Set<String> _connected = {};
  final Map<String, Timer> _timeouts = {};
  final Map<String, DateTime> _lastRequests = {};
  final Map<String, bool> _warnedLow = {};
  final Set<String> _inFlight = {};
  final Set<String> _awaitingLoginReturn = {};
  SharedPreferences? _prefs;
  CarrierSelection _selection = CarrierSelection.unconfigured();
  CarrierAccounts _accounts = CarrierAccounts.fromSelection(
    CarrierSelection.unconfigured(),
  );
  Set<Carrier> _draftSelection = {};
  final Set<Carrier> _draftSecond = {};
  bool _restoring = true;
  bool _savingSelection = false;
  final Map<String, Map<String, dynamic>> _broadnetSessions = {};
  String? _visibleAccountId;
  double _thresholdGb = 5;
  BackgroundRefreshInterval _backgroundRefresh = BackgroundRefreshInterval.off;
  bool _reminders = false;
  int _generation = 0;
  String? _webMessage;
  Timer? _foregroundTimer;
  bool _clearing = false;
  bool _profileClearPending = false;
  bool _widgetPinPending = false;
  Future<void> _storageTasks = Future<void>.value();

  bool _current(int generation) =>
      mounted && !_clearing && generation == _generation;

  CarrierSnapshot _snapshot(CarrierAccount account) =>
      _accountSnapshots[account.id] ??
      (account.isPrimary
          ? _snapshots[account.carrier]!
          : CarrierSnapshot(
              carrier: account.carrier,
              status: QueryStatus.notConnected,
            ));

  void _putSnapshot(CarrierAccount account, CarrierSnapshot snapshot) {
    if (snapshot.carrier != account.carrier) return;
    _accountSnapshots[account.id] = snapshot;
    if (account.isPrimary) _snapshots[account.carrier] = snapshot;
  }

  List<CarrierAccount> get _visibleAccounts =>
      _accounts.visibleAccounts(_selection);

  CarrierAccount? _account(String id) => _accounts.find(id);

  Future<bool> _canAddSecond(
    Carrier carrier,
    Set<Carrier> pending,
    Set<Carrier> selected,
  ) async {
    if (_profileClearPending) {
      _showInfo('第二张卡暂时锁住了', '上次清除网页登录资料还未完成，请重试清除后再加入。');
      return false;
    }
    if (_accounts.find('${carrier.name}_2') != null ||
        pending.contains(carrier)) {
      return false;
    }
    final effectiveSelected = {...selected, carrier};
    final existing = _accounts.accounts
        .where((a) => effectiveSelected.contains(a.carrier))
        .length;
    final newPrimaries = effectiveSelected
        .where((c) => _accounts.find(c.name) == null)
        .length;
    final newSeconds = {...pending, carrier}
        .where(
          (c) =>
              effectiveSelected.contains(c) &&
              _accounts.find('${c.name}_2') == null,
        )
        .length;
    if (existing + newPrimaries + newSeconds > 4) {
      _showInfo('最多照顾四张卡', '请先整理已有卡片，再加入新的号码。');
      return false;
    }
    if (demoMode) return true;
    if (_ios) {
      try {
        if (await IOSAccountProfiles.supported() &&
            mounted &&
            await _prefs?.setBool('account_profiles_may_exist', true) == true) {
          return true;
        }
      } on PlatformException {
        // A missing or older plugin must not share the primary account store.
      } on MissingPluginException {
        // A missing or older plugin must not share the primary account store.
      }
      if (mounted) {
        _showInfo('第二张卡暂时无法加入', '无法确认独立网页登录资料已准备好，请稍后重试。');
      }
      return false;
    }
    if (!_android) return false;
    try {
      if (await android_webview
          .AndroidInAppWebViewController.supportsAccountProfiles()) {
        return mounted;
      }
    } on PlatformException {
      // Installed WebView does not expose isolated profiles.
    }
    if (mounted) {
      _showInfo(
        '这台手机暂不支持第二张同运营商卡',
        '当前网页内核无法把两个号码的登录会话分开。为了避免把同一份余额显示两次，暂时只能连接这家运营商的一张卡。',
      );
    }
    return false;
  }

  Future<void> _store(Future<void> Function() operation) {
    final task = _storageTasks.then((_) => operation());
    _storageTasks = task.catchError((Object _) {});
    return task;
  }

  Future<void> _closeOfficialPage() async {
    final generation = _generation;
    final account = _visibleAccountId == null
        ? null
        : _account(_visibleAccountId!);
    final controller = account == null ? null : _controllers[account.id];
    if (account?.carrier == Carrier.broadnet && controller != null) {
      await _saveSession(account!, controller, generation);
    }
    if (_current(generation)) setState(() => _visibleAccountId = null);
  }

  Future<void> _publishWidget() async {
    if (!_nativeMobile || demoMode || _clearing) return;
    final generation = _generation;
    await _store(() async {
      if (_current(generation)) {
        await _widgetBridge.update(
          _snapshots.values,
          _thresholdGb,
          selection: _selection,
          accounts: _accounts,
          accountSnapshots: _accountSnapshots,
        );
      }
    });
  }

  Future<void> _openFromWidget() async {
    if (!mounted || _clearing) return;
    setState(() => _visibleAccountId = null);
    _lastRequests.clear();
    _refreshAll();
  }

  Future<void> _addWidget() async {
    if (!_nativeMobile || demoMode) return;
    await _publishWidget();
    if (!mounted || _clearing) return;
    if (_ios) {
      _showInfo(
        '添加桌面卡片',
        '请长按 iPhone 主屏幕空白处，点左上角「编辑」→「添加小组件」，搜索「流量小伙伴」，选择卡片后点「添加小组件」。卡片显示最近一次打开 APP 查询到的数据。',
      );
      return;
    }
    try {
      final result = await _widgetBridge.requestPinDetailed();
      if (!mounted) return;
      const manual = '也可以长按桌面空白处 →「小组件」或「窗口小工具」→ 找到「流量小伙伴」→ 拖到桌面。';
      switch (result.status) {
        case WidgetPinStatus.alreadyAdded:
          _showInfo('桌面卡片已经在啦', '系统检测到这张卡片已添加到桌面。');
        case WidgetPinStatus.requestPendingConfirmation:
          _widgetPinPending = true;
          _showInfo('请确认桌面弹窗', '已向桌面发出添加请求，请在系统弹窗中确认；这一步还不代表添加成功。\n\n$manual');
        case WidgetPinStatus.unsupported:
        case WidgetPinStatus.notAdded:
          _showInfo('请手动添加桌面卡片', '这次系统没有弹出确认窗口。\n\n$manual');
      }
    } on PlatformException {
      if (mounted) {
        _showInfo(
          '请手动添加桌面卡片',
          '系统没有弹出确认窗口。请长按桌面空白处，在「小组件」或「窗口小工具」中找到「流量小伙伴」，拖到桌面。',
        );
      }
    }
  }

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _nativeMobile => _android || _ios;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_nativeMobile && !demoMode) _widgetBridge.onOpen(_openFromWidget);
    if (demoMode) {
      _selection = CarrierSelection.complete(Carrier.values);
      _accounts = CarrierAccounts.fromSelection(_selection);
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
        _accountSnapshots[carrier.name] = _snapshots[carrier]!;
      }
    } else {
      unawaited(_restore());
    }
    _foregroundTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          _visibleAccountId == null) {
        _refreshAll();
      }
    });
  }

  Future<void> _restore() async {
    final generation = _generation;
    final prefs = await SharedPreferences.getInstance();
    if (!_current(generation)) return;
    _prefs = prefs;
    if (prefs.getBool('account_profiles_cleanup_pending') == true) {
      try {
        if (_android) {
          await android_webview
              .AndroidInAppWebViewController.deleteAccountProfiles();
        } else if (_ios) {
          await IOSAccountProfiles.clearAll();
        }
      } on Exception {
        // Keep the durable pending flag and disable every account.
      }
    }
    _profileClearPending =
        prefs.getBool('account_profiles_cleanup_pending') == true;
    final restoredSelection = CarrierSelection.restore(
      savedJson: prefs.get('carrier_selection') == null
          ? null
          : prefs.get('carrier_selection') is String
          ? prefs.get('carrier_selection') as String
          : 'invalid',
      legacyPreferences: {
        for (final key in prefs.getKeys()) key: prefs.get(key),
      },
    );
    final restoredAccounts = CarrierAccounts.restore(
      savedJson: prefs.getString(CarrierAccounts.storageKey),
      selection: restoredSelection,
    );
    if (_ios &&
        restoredAccounts.accounts.any((account) => !account.isPrimary)) {
      try {
        if (await prefs.setBool('account_profiles_may_exist', true) != true) {
          _profileClearPending = true;
        }
      } catch (_) {
        _profileClearPending = true;
      }
    }
    for (final account in restoredAccounts.accounts.where(
      (a) => a.carrier == Carrier.broadnet,
    )) {
      try {
        final raw = await _secure
            .read(key: account.broadnetSessionKey)
            .timeout(const Duration(seconds: 3));
        if (raw == null) continue;
        final candidate = jsonDecode(raw) as Map<String, dynamic>;
        final savedAt = DateTime.tryParse(
          candidate['savedAt'] as String? ?? '',
        );
        final age = savedAt == null ? null : DateTime.now().difference(savedAt);
        if (age != null && !age.isNegative && age < const Duration(days: 7)) {
          _broadnetSessions[account.id] = candidate;
        } else {
          await _secure.delete(key: account.broadnetSessionKey);
        }
      } catch (_) {
        // A corrupt session requires official login again.
      }
    }
    if (!_current(generation)) return;
    setState(() {
      _prefs = prefs;
      _selection = restoredSelection;
      _accounts = restoredAccounts;
      _restoring = false;
      _thresholdGb = (prefs.getDouble('threshold_gb') ?? 5).clamp(1, 20);
      _backgroundRefresh = _ios
          ? BackgroundRefreshInterval.off
          : BackgroundRefreshInterval.fromMinutes(
              prefs.getInt('background_refresh_minutes'),
            );
      _reminders = prefs.getBool('reminders') ?? false;
      for (final account in restoredAccounts.accounts) {
        final raw = prefs.getString(account.snapshotKey);
        if (raw != null) {
          try {
            final snapshot = CarrierSnapshot.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            );
            _putSnapshot(
              account,
              snapshot.status == QueryStatus.success
                  ? snapshot.copyWith(
                      status: QueryStatus.error,
                      message: '上次查询记录，正在确认最新状态',
                    )
                  : snapshot,
            );
          } catch (_) {
            /* Retain the explicit unconnected state. */
          }
        }
        if (prefs.getBool(account.connectedKey) ?? false) {
          _connected.add(account.id);
        }
      }
    });
    await _store(() async {
      if (_current(generation)) {
        await prefs.setString(
          'carrier_selection',
          _selection.toStorageString(),
        );
        await prefs.setString(
          CarrierAccounts.storageKey,
          _accounts.toStorageString(),
        );
      }
    });
    await _syncBackgroundSchedule();
    await _publishWidget();
    if (_nativeMobile && !demoMode && _current(generation)) {
      if (await _widgetBridge.consumeLaunchRefresh()) await _openFromWidget();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_widgetPinPending) unawaited(_checkWidgetInstallation());
      if (_visibleAccountId == null) {
        unawaited(_reloadBackgroundSnapshotsAndRefresh());
      }
    }
  }

  Future<void> _checkWidgetInstallation() async {
    try {
      final result = await _widgetBridge.installationStatus();
      if (!mounted) return;
      if (!result.isAlreadyAdded) {
        if (result.status == WidgetPinStatus.notAdded ||
            result.status == WidgetPinStatus.unsupported) {
          _widgetPinPending = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('还没检测到桌面卡片，可长按桌面从小组件里手动添加')),
          );
        }
        return;
      }
      _widgetPinPending = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('桌面卡片已经添加好啦')));
    } on PlatformException {
      // Launcher state can be checked on the next foreground entry.
    }
  }

  Future<void> _reloadBackgroundSnapshotsAndRefresh() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.reload();
      if (!mounted || _clearing) return;
      setState(() {
        for (final account in _visibleAccounts) {
          final raw = prefs.getString(account.snapshotKey);
          if (raw == null) continue;
          try {
            _putSnapshot(
              account,
              CarrierSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>),
            );
          } catch (_) {
            // Keep the in-memory result if a background record is malformed.
          }
        }
      });
    }
    _refreshAll();
  }

  Future<bool> _syncBackgroundSchedule() async {
    if (!_nativeMobile || demoMode) return true;
    if (_ios) {
      try {
        await BackgroundRefreshScheduler.configure(
          BackgroundRefreshInterval.off,
        );
        return true;
      } on Exception {
        return false;
      }
    }
    final hasBackgroundCarrier = _visibleAccounts.any(
      (account) =>
          account.carrier != Carrier.telecom &&
          _connected.contains(account.id) &&
          _snapshot(account).queriedAt != null,
    );
    final interval = hasBackgroundCarrier
        ? _backgroundRefresh
        : BackgroundRefreshInterval.off;
    try {
      await BackgroundRefreshScheduler.configure(interval);
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  String _queryUrl(Carrier carrier) => carrierQueryUrl(carrier);
  String _loginUrl(Carrier carrier) => carrierLoginUrl(carrier);

  bool _allowedUrl(Carrier carrier, WebUri? url) {
    if (url == null) return false;
    final uri = Uri.tryParse(url.toString());
    return uri != null && isCarrierNavigationAllowed(carrier, uri);
  }

  void _connect(Carrier carrier) => _connectAccount(carrier.name);

  void _connectAccount(String accountId) {
    final account = _account(accountId);
    if (account == null) return;
    if (_profileClearPending) {
      _showInfo('查询暂时锁住了', '上次清除网页登录资料还未完成，请在设置里重试清除。');
      return;
    }
    if (_visibleAccountId == accountId) return;
    final carrier = account.carrier;
    if (_clearing || !_selection.allows(carrier)) return;
    if (demoMode || !_nativeMobile) {
      _showInfo('这是界面预览', '请安装手机测试包后连接号码。演示流量不是您的实际余额。');
      return;
    }
    setState(() {
      _visibleAccountId = accountId;
      _webMessage = null;
      _connected.add(accountId);
    });
    final prefs = _prefs;
    if (prefs != null) {
      final generation = _generation;
      final saved = _store(() async {
        if (_current(generation)) {
          await prefs.setBool(account.connectedKey, true);
        }
      });
      unawaited(saved.then((_) => _syncBackgroundSchedule()));
    }
    final controller = _controllers[accountId];
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
    for (final account in _visibleAccounts.where(
      (a) => _connected.contains(a.id),
    )) {
      _refreshAccount(account.id, automatic: true);
    }
  }

  Future<void> _refresh(Carrier carrier, {bool automatic = false}) =>
      _refreshAccount(carrier.name, automatic: automatic);

  Future<void> _refreshAccount(
    String accountId, {
    bool automatic = false,
  }) async {
    final account = _account(accountId);
    if (account == null) return;
    if (_profileClearPending) {
      if (!automatic) {
        _showInfo('查询暂时锁住了', '上次清除网页登录资料还未完成，请在设置里重试清除。');
      }
      return;
    }
    final carrier = account.carrier;
    if (_clearing || !_selection.allows(carrier)) return;
    if (!_connected.contains(accountId)) {
      if (!automatic) _connectAccount(accountId);
      return;
    }
    if (_inFlight.contains(accountId)) return;
    final last = _lastRequests[accountId];
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 30)) {
      return;
    }
    final controller = _controllers[accountId];
    if (controller == null) return;
    final generation = _generation;
    _inFlight.add(accountId);
    if (carrier == Carrier.broadnet) {
      await _saveSession(account, controller, generation);
    }
    if (!_current(generation)) {
      _inFlight.remove(accountId);
      return;
    }
    _lastRequests[accountId] = DateTime.now();
    setState(
      () => _putSnapshot(
        account,
        _snapshot(
          account,
        ).copyWith(status: QueryStatus.loading, message: '正在向运营商查询'),
      ),
    );
    unawaited(_publishWidget());
    _timeouts[accountId]?.cancel();
    _timeouts[accountId] = Timer(const Duration(seconds: 35), () {
      if (!_current(generation) ||
          _snapshot(account).status != QueryStatus.loading) {
        return;
      }
      _inFlight.remove(accountId);
      final failed = _snapshot(
        account,
      ).copyWith(status: QueryStatus.error, message: '未取得可识别的流量结果，请打开官方查询页确认');
      setState(() => _putSnapshot(account, failed));
      unawaited(
        _store(() async {
          if (_current(generation)) {
            await _prefs?.setString(
              account.snapshotKey,
              jsonEncode(failed.toJson()),
            );
          }
        }),
      );
      unawaited(_publishWidget());
    });
    try {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(_queryUrl(carrier))),
      );
    } catch (_) {
      _timeouts[accountId]?.cancel();
      _inFlight.remove(accountId);
      if (_current(generation)) {
        setState(
          () => _putSnapshot(
            account,
            _snapshot(
              account,
            ).copyWith(status: QueryStatus.error, message: '官方查询页暂时无法打开'),
          ),
        );
        unawaited(_publishWidget());
      }
    }
  }

  Future<void> _receive(
    CarrierAccount account,
    List<dynamic> args,
    int generation,
  ) async {
    final carrier = account.carrier;
    final accountId = account.id;
    if (!_current(generation) || !_selection.allows(carrier)) return;
    if (args.isEmpty || args.first is! Map) return;
    final payload = Map<String, dynamic>.from(args.first as Map);
    final url = Uri.tryParse(payload['url'] as String? ?? '');
    final page = Uri.tryParse(payload['pageUrl'] as String? ?? '');
    final stage = payload['stage'] is String
        ? payload['stage'] as String
        : null;
    if (!isCarrierResponseAllowed(carrier, url, page, stage)) return;
    if (!_inFlight.contains(accountId) &&
        !_awaitingLoginReturn.contains(accountId)) {
      return;
    }
    // A delayed response must not revive a page that already returned to login.
    final controller = _controllers[accountId];
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
          currentStatus: _snapshot(account).status,
          httpStatus: status,
        )) {
      // Prefer the site's decoded event, but accept an independently verified
      // plaintext raw success if that event was not observed.
      return;
    }
    if (!_current(generation) ||
        (!_inFlight.contains(accountId) &&
            !_awaitingLoginReturn.contains(accountId))) {
      return;
    }
    final hadPreviousQuery = _snapshot(account).queriedAt != null;
    _timeouts[accountId]?.cancel();
    _inFlight.remove(accountId);
    _awaitingLoginReturn.remove(accountId);
    final displayed = snapshot.status == QueryStatus.success
        ? snapshot
        : _snapshot(
            account,
          ).copyWith(status: snapshot.status, message: snapshot.message);
    setState(() => _putSnapshot(account, displayed));
    await _publishWidget();
    if (!_current(generation)) return;
    await _store(() async {
      if (_current(generation)) {
        await _prefs?.setString(
          account.snapshotKey,
          jsonEncode(displayed.toJson()),
        );
        if (snapshot.status == QueryStatus.authExpired) {
          await _prefs?.setBool('background_auth_required_${account.id}', true);
        } else if (snapshot.status == QueryStatus.success) {
          await _prefs?.setBool(
            'background_auth_required_${account.id}',
            false,
          );
        }
      }
    });
    if (!_current(generation)) return;
    if (snapshot.status == QueryStatus.success) {
      if (!hadPreviousQuery) await _syncBackgroundSchedule();
      if (!_current(generation)) return;
      final remaining = snapshot.generalRemainingBytes;
      final low = remaining != null && remaining / 1073741824 <= _thresholdGb;
      if (low &&
          !(_warnedLow[accountId] ?? false) &&
          _reminders &&
          _nativeMobile) {
        try {
          await _notifications.invokeMethod('notify', {
            'id': carrier.index * 2 + (account.isPrimary ? 1 : 2),
            'title': '${account.label}流量快见底了',
            'body':
                '通用流量剩余 ${(remaining / 1073741824).toStringAsFixed(2)} GB，数据以运营商查询为准。',
          });
        } on PlatformException {
          /* Dashboard retains the actual result. */
        }
      }
      _warnedLow[accountId] = low;
    }
  }

  Future<void> _saveSession(
    CarrierAccount account,
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
      if (_broadnetSessions[account.id]?['sessionId'] == session['sessionId']) {
        return;
      }
      session['savedAt'] = DateTime.now().toIso8601String();
      await _store(() async {
        if (_current(generation)) {
          await _secure.write(
            key: account.broadnetSessionKey,
            value: jsonEncode(session),
          );
        }
      });
      if (_current(generation)) _broadnetSessions[account.id] = session;
    } catch (_) {
      /* Official login remains usable for this WebView session. */
    }
  }

  Widget _webView(CarrierAccount account) {
    final carrier = account.carrier;
    final accountId = account.id;
    final generation = _generation;
    return Positioned.fill(
      key: ValueKey('view_${account.id}_$generation'),
      child: Offstage(
        offstage: _visibleAccountId != accountId,
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
                            '${account.label}官方页面',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _refreshAccount(accountId),
                          child: const Text('查询流量'),
                        ),
                        IconButton(
                          onPressed: () => _controllers[accountId]?.reload(),
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
                key: ValueKey('${account.id}_$_generation'),
                // Every account is loaded only after its WebView profile is set.
                initialSettings: AccountWebViewSettings(
                  profileName: _ios ? account.profileName : null,
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
                      source: broadnetSessionRestoreScript(
                        _broadnetSessions[accountId],
                      ),
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                ]),
                onWebViewCreated: (controller) async {
                  if (!_current(generation)) return;
                  if (_ios && account.profileName != null) {
                    try {
                      if (!await IOSAccountProfiles.supported()) {
                        throw StateError(
                          'Persistent account store unavailable',
                        );
                      }
                    } on Exception {
                      if (_current(generation)) {
                        setState(
                          () => _putSnapshot(
                            account,
                            _snapshot(account).copyWith(
                              status: QueryStatus.error,
                              message: '此 iPhone 暂无法打开第二张卡的独立登录会话',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                  }
                  if (_android && account.profileName != null) {
                    try {
                      await _store(() async {
                        if (!_current(generation)) return;
                        if (await _prefs?.setBool(
                              'account_profiles_may_exist',
                              true,
                            ) !=
                            true) {
                          throw StateError(
                            'Profile ownership could not be saved',
                          );
                        }
                      });
                      if (!_current(generation)) return;
                      await (controller.platform
                              as android_webview.AndroidInAppWebViewController)
                          .setAccountProfile(account.profileName!);
                    } catch (_) {
                      if (_current(generation)) {
                        setState(
                          () => _putSnapshot(
                            account,
                            _snapshot(account).copyWith(
                              status: QueryStatus.error,
                              message: '此手机的网页内核暂不支持第二张同运营商卡',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                  }
                  if (!_current(generation)) return;
                  _controllers[accountId] = controller;
                  controller.addJavaScriptHandler(
                    handlerName: 'trafficResponse',
                    callback: (args) => _receive(account, args, generation),
                  );
                  if (_snapshot(account).status == QueryStatus.notConnected) {
                    try {
                      await controller.loadUrl(
                        urlRequest: URLRequest(url: WebUri(_loginUrl(carrier))),
                      );
                    } on Exception {
                      if (_current(generation)) {
                        setState(
                          () => _putSnapshot(
                            account,
                            _snapshot(account).copyWith(
                              status: QueryStatus.error,
                              message: '官方登录页暂时无法打开',
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    await _refreshAccount(accountId);
                  }
                },
                shouldOverrideUrlLoading: (controller, action) async =>
                    _allowedUrl(carrier, action.request.url)
                    ? NavigationActionPolicy.ALLOW
                    : NavigationActionPolicy.CANCEL,
                onUpdateVisitedHistory: (controller, url, isReload) {
                  if (!_current(generation) || url == null) return;
                  final uri = Uri.tryParse(url.toString());
                  if (uri != null && isCarrierLoginPage(uri)) {
                    _timeouts[accountId]?.cancel();
                    _inFlight.remove(accountId);
                    _awaitingLoginReturn.add(accountId);
                    setState(
                      () => _putSnapshot(
                        account,
                        _snapshot(account).copyWith(
                          status: QueryStatus.authExpired,
                          message: '请在官方页面验证号码，完成后查询流量',
                        ),
                      ),
                    );
                    unawaited(_publishWidget());
                  }
                },
                onLoadStop: (controller, url) async {
                  if (!_current(generation)) return;
                  if (url != null &&
                      isCarrierLoginPage(Uri.parse(url.toString()))) {
                    _awaitingLoginReturn.add(accountId);
                    if (carrier == Carrier.broadnet) {
                      _broadnetSessions.remove(accountId);
                      await controller.removeUserScriptsByGroupName(
                        groupName: 'broadnetRestore',
                      );
                      await _store(() async {
                        if (_current(generation)) {
                          await _secure.delete(key: account.broadnetSessionKey);
                        }
                      });
                    }
                    if (!_current(generation)) return;
                    _timeouts[accountId]?.cancel();
                    _inFlight.remove(accountId);
                    setState(
                      () => _putSnapshot(
                        account,
                        _snapshot(account).copyWith(
                          status: QueryStatus.authExpired,
                          message: '请在官方页面验证号码，完成后查询流量',
                        ),
                      ),
                    );
                    unawaited(_publishWidget());
                  } else if (carrier == Carrier.broadnet &&
                      url?.host == 'www.10099.com.cn') {
                    await _saveSession(account, controller, generation);
                  }
                  if (_current(generation) &&
                      url != null &&
                      !isCarrierLoginPage(Uri.parse(url.toString())) &&
                      _awaitingLoginReturn.remove(accountId)) {
                    unawaited(_refreshAccount(accountId));
                  }
                },
                onReceivedError: (controller, request, error) {
                  if (request.isForMainFrame != true || !_current(generation)) {
                    return;
                  }
                  _timeouts[accountId]?.cancel();
                  _inFlight.remove(accountId);
                  setState(() {
                    _webMessage = '官方页面暂时无法打开，请检查网络后重试';
                    _putSnapshot(
                      account,
                      _snapshot(account).copyWith(
                        status: QueryStatus.error,
                        message: _webMessage,
                      ),
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

  Future<void> _applySelection(
    Set<Carrier> carriers, {
    Set<Carrier> secondAccounts = const {},
  }) async {
    if (_savingSelection || carriers.isEmpty || _clearing) return;
    final previousSelection = _selection;
    final previousAccounts = _accounts;
    final selection = CarrierSelection.complete(carriers);
    var nextAccounts = _accounts.ensureSelection(selection);
    final pendingCount = secondAccounts
        .where(
          (carrier) =>
              carriers.contains(carrier) &&
              nextAccounts.find('${carrier.name}_2') == null,
        )
        .length;
    if (nextAccounts.visibleCount(selection) + pendingCount > 4) {
      _showInfo('最多照顾四张卡', '当前保存的号码加上新选择会超过四张，请先取消第二张卡后再保存。');
      return;
    }
    for (final carrier in secondAccounts.where(carriers.contains)) {
      nextAccounts = nextAccounts.addSecond(carrier);
    }
    final restoredNew = <String, CarrierSnapshot>{};
    final restoredSessions = <String, Map<String, dynamic>>{};
    final connectedNew = <String>{};
    for (final account in nextAccounts.accounts) {
      if (previousAccounts.find(account.id) != null) continue;
      if (_prefs?.getBool(account.connectedKey) == true) {
        connectedNew.add(account.id);
      }
      final raw = _prefs?.getString(account.snapshotKey);
      if (raw != null) {
        try {
          restoredNew[account.id] = CarrierSnapshot.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
        } catch (_) {
          // Keep this card unconnected if an old snapshot is corrupt.
        }
      }
      if (account.carrier == Carrier.broadnet) {
        try {
          final secureRaw = await _secure.read(key: account.broadnetSessionKey);
          if (secureRaw == null) continue;
          final session = jsonDecode(secureRaw) as Map<String, dynamic>;
          final savedAt = DateTime.tryParse(
            session['savedAt'] as String? ?? '',
          );
          final age = savedAt == null
              ? null
              : DateTime.now().difference(savedAt);
          if (age != null && !age.isNegative && age < const Duration(days: 7)) {
            restoredSessions[account.id] = session;
          }
        } catch (_) {
          // A corrupt backup requires official login again.
        }
      }
    }
    final oldControllers = _controllers.values.toList();
    setState(() {
      _savingSelection = true;
      _generation++;
      _selection = selection;
      _accounts = nextAccounts;
      _connected.addAll(connectedNew);
      _broadnetSessions.addAll(restoredSessions);
      for (final account in nextAccounts.accounts) {
        final restored = restoredNew[account.id];
        if (restored != null) _putSnapshot(account, restored);
      }
      _controllers.clear();
      _visibleAccountId = null;
      _lastRequests.clear();
      _inFlight.clear();
      _awaitingLoginReturn.clear();
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
          if (_nativeMobile && !demoMode) {
            await _widgetBridge.clear();
          }
          final saved = await _prefs?.setString(
            'carrier_selection',
            selection.toStorageString(),
          );
          if (saved == false) throw StateError('Selection save failed');
          await _prefs?.setString(
            CarrierAccounts.storageKey,
            _accounts.toStorageString(),
          );
          if (_nativeMobile && !demoMode) {
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
        await _syncBackgroundSchedule();
        await _publishWidget();
      }
    } catch (_) {
      if (_current(generation)) {
        setState(() {
          _selection = previousSelection;
          _accounts = previousAccounts;
          _savingSelection = false;
        });
        await _syncBackgroundSchedule();
        await _publishWidget();
        _showInfo('设置暂未完整保存', '请重新选择运营商并保存。');
      }
    }
  }

  Future<void> _manageCarriers() async {
    var draft = _selection.selectedCarriers.toSet();
    final draftSecond = <Carrier>{};
    final result = await Navigator.of(context)
        .push<(Set<Carrier>, Set<Carrier>)>(
          MaterialPageRoute(
            builder: (context) => StatefulBuilder(
              builder: (context, update) => CarrierSelectionScreen(
                selectedCarriers: draft,
                accountCounts: {
                  for (final carrier in Carrier.values)
                    carrier:
                        _accounts.accounts
                            .where((a) => a.carrier == carrier)
                            .length +
                        (draftSecond.contains(carrier) ? 1 : 0),
                },
                onSelectionChanged: (value) => update(() => draft = value),
                onAddSecondAccount: (carrier) async {
                  if (await _canAddSecond(carrier, draftSecond, draft)) {
                    update(() {
                      draft.add(carrier);
                      draftSecond.add(carrier);
                    });
                  }
                },
                onContinue: (value) =>
                    Navigator.pop(context, (value, draftSecond)),
                isInitialSetup: false,
                demo: demoMode,
              ),
            ),
          ),
        );
    if (result != null && mounted) {
      await _applySelection(result.$1, secondAccounts: result.$2);
    }
  }

  Future<void> _removeSecondAccount(String id) async {
    final account = _account(id);
    if (account == null || account.isPrimary || _clearing) return;
    final previous = _accounts;
    final oldControllers = _controllers.values.toList();
    setState(() {
      _generation++;
      _accounts = _accounts.removeSecond(id);
      _controllers.clear();
      _visibleAccountId = null;
      _inFlight.clear();
      _awaitingLoginReturn.clear();
      _lastRequests.clear();
    });
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    for (final controller in oldControllers) {
      try {
        await controller.stopLoading();
      } on Exception {
        // The view may already be disposed.
      }
    }
    try {
      await _prefs?.setString(
        CarrierAccounts.storageKey,
        _accounts.toStorageString(),
      );
      await _syncBackgroundSchedule();
      await _publishWidget();
    } catch (_) {
      if (mounted) {
        setState(() => _accounts = previous);
        _showInfo('卡片暂未保存', '请稍后再试。');
      }
    }
  }

  Future<void> _settings() async {
    double threshold = _thresholdGb;
    bool reminders = _reminders;
    var backgroundRefresh = _backgroundRefresh;
    final statusFuture = _android
        ? BackgroundRefreshScheduler.status().catchError(
            (Object _) => const BackgroundRefreshStatus(outcome: 'never'),
          )
        : Future.value(const BackgroundRefreshStatus(outcome: 'never'));
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
                for (final account in _visibleAccounts.where(
                  (a) => !a.isPrimary,
                ))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('收起 ${account.label}'),
                    subtitle: const Text('保留本机查询记录和登录资料，之后可重新加入'),
                    trailing: const Icon(Icons.remove_circle_outline_rounded),
                    onTap: () {
                      Navigator.pop(context);
                      unawaited(_removeSecondAccount(account.id));
                    },
                  ),
                if (_android)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('桌面卡片后台刷新'),
                    subtitle: Text(backgroundRefresh.label),
                    trailing: PopupMenuButton<BackgroundRefreshInterval>(
                      tooltip: '选择后台刷新间隔',
                      onSelected: (value) =>
                          update(() => backgroundRefresh = value),
                      itemBuilder: (context) => [
                        for (final value in BackgroundRefreshInterval.values)
                          PopupMenuItem(value: value, child: Text(value.label)),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('更改'),
                            SizedBox(width: 4),
                            Icon(Icons.expand_more_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_ios)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'iPhone 桌面卡片显示上次查询结果；打开 APP 后会刷新。iOS 暂无定时后台官网查询。',
                    ),
                  ),
                if (_android)
                  FutureBuilder<BackgroundRefreshStatus>(
                    future: statusFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final status = snapshot.data!;
                      final at = status.finishedAt ?? status.startedAt;
                      final local = at?.toLocal();
                      final time = local == null
                          ? ''
                          : ' · ${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${status.label}$time',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF777D87),
                          ),
                        ),
                      );
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
                  '后台刷新由 Android 尽力调度，省电模式、网络和运营商响应可能让任务延后。移动、联通、广电可尝试后台网页查询；电信需要打开 APP 查看。前台仍会在打开或返回时查询，并每 5 分钟尝试更新。',
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
    if (reminders && _nativeMobile) {
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
      _backgroundRefresh = _ios
          ? BackgroundRefreshInterval.off
          : backgroundRefresh;
      _warnedLow.clear();
    });
    await _prefs?.setDouble('threshold_gb', threshold);
    await _prefs?.setBool('reminders', permitted);
    await _prefs?.setInt(
      'background_refresh_minutes',
      _ios ? 0 : backgroundRefresh.minutes,
    );
    final scheduled = await _syncBackgroundSchedule();
    if (!scheduled &&
        _android &&
        backgroundRefresh != BackgroundRefreshInterval.off) {
      setState(() => _backgroundRefresh = BackgroundRefreshInterval.off);
      await _prefs?.setInt('background_refresh_minutes', 0);
      if (mounted) {
        _showInfo('后台刷新暂未启用', '系统没有接受后台任务设置。打开 APP 后仍会按原方式查询。');
      }
    }
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
    try {
      final prefs = _prefs;
      if (prefs == null) throw StateError('Preferences unavailable');
      await _store(() async {
        final saved = await prefs.setBool(
          'account_profiles_cleanup_pending',
          true,
        );
        if (!saved) throw StateError('Pending profile cleanup was not saved');
      });
    } catch (_) {
      _showInfo('暂时无法清除', '无法保存网页会话清理状态，请稍后重试。');
      return;
    }
    _profileClearPending = true;
    final oldControllers = _controllers.values.toList();
    setState(() {
      _clearing = true;
      _generation++;
      _connected.clear();
      _controllers.clear();
      _visibleAccountId = null;
      _broadnetSessions.clear();
      _inFlight.clear();
      _awaitingLoginReturn.clear();
    });
    if (_nativeMobile && !demoMode) {
      try {
        await BackgroundRefreshScheduler.configure(
          BackgroundRefreshInterval.off,
        );
      } on PlatformException {
        // Continue clearing local credentials even if WorkManager is unavailable.
      } on MissingPluginException {
        // Older installs may not expose the scheduler channel.
      }
    }
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
    var profilesCleared = !_nativeMobile || demoMode;
    var otherDataCleared = true;
    if (_nativeMobile) {
      try {
        await CookieManager.instance().deleteAllCookies();
        await WebStorageManager.instance().deleteAllData();
      } catch (_) {
        otherDataCleared = false;
      }
      try {
        if (_android) {
          profilesCleared =
              await android_webview
                  .AndroidInAppWebViewController.deleteAccountProfiles(
                profilesMayExist:
                    (_prefs?.getBool('account_profiles_may_exist') ?? false) ||
                    _accounts.accounts.any((account) => !account.isPrimary) ||
                    Carrier.values.any(
                      (carrier) =>
                          (_prefs?.containsKey('connected_${carrier.name}_2') ??
                              false) ||
                          (_prefs?.containsKey('snapshot_${carrier.name}_2') ??
                              false),
                    ),
              );
        } else if (_ios) {
          await IOSAccountProfiles.clearAll();
          profilesCleared = true;
        }
      } catch (_) {
        profilesCleared = false;
      }
      try {
        await _widgetBridge.clear();
      } catch (_) {
        otherDataCleared = false;
      }
      try {
        await _notifications.invokeMethod('cancelAll');
      } on PlatformException {
        /* No active notifications. */
      }
    }
    for (final carrier in Carrier.values) {
      for (final id in [carrier.name, '${carrier.name}_2']) {
        try {
          if (carrier == Carrier.broadnet) {
            await _secure.delete(
              key: id == carrier.name
                  ? 'broadnet_session'
                  : 'broadnet_session_$id',
            );
          }
          for (final key in [
            'snapshot_$id',
            'connected_$id',
            'background_auth_required_$id',
          ]) {
            if (await _prefs?.remove(key) != true) otherDataCleared = false;
          }
        } catch (_) {
          otherDataCleared = false;
        }
      }
    }
    final fullyCleared = profilesCleared && otherDataCleared;
    if (fullyCleared) {
      try {
        if (await _prefs?.setBool('account_profiles_may_exist', false) !=
            true) {
          throw StateError('Profile cleanup could not be saved');
        }
        final saved = await _prefs?.setBool(
          'account_profiles_cleanup_pending',
          false,
        );
        _profileClearPending = saved != true;
      } catch (_) {
        _profileClearPending = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _clearing = false;
      _connected.clear();
      _controllers.clear();
      _lastRequests.clear();
      _warnedLow.clear();
      _broadnetSessions.clear();
      _visibleAccountId = null;
      _accountSnapshots.clear();
      for (final carrier in Carrier.values) {
        _snapshots[carrier] = CarrierSnapshot(
          carrier: carrier,
          status: QueryStatus.notConnected,
        );
      }
    });
    await _publishWidget();
    if (_profileClearPending && mounted) {
      _showInfo('部分网页登录资料还没清除', '本机仍可能留有旧登录资料。请稍后在设置中再次清除；完成前所有号码查询已暂停。');
    }
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
    canPop: _visibleAccountId == null,
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
              accountCounts: {
                for (final carrier in Carrier.values)
                  carrier:
                      (_draftSelection.contains(carrier) ? 1 : 0) +
                      (_draftSecond.contains(carrier) ? 1 : 0),
              },
              onSelectionChanged: (value) =>
                  setState(() => _draftSelection = value),
              onAddSecondAccount: (carrier) async {
                if (await _canAddSecond(
                      carrier,
                      _draftSecond,
                      _draftSelection,
                    ) &&
                    mounted) {
                  setState(() {
                    _draftSelection.add(carrier);
                    _draftSecond.add(carrier);
                  });
                }
              },
              onContinue: (value) => unawaited(
                _applySelection(value, secondAccounts: _draftSecond),
              ),
              demo: demoMode,
            )
          else
            DashboardScreen(
              snapshots: _selection.visibleSnapshots(_snapshots.values),
              cleanupPending: _profileClearPending,
              accountEntries: [
                for (final account in _visibleAccounts)
                  DashboardAccountEntry(account, _snapshot(account)),
              ],
              selectedCarriers: _selection.selectedCarriers,
              onManageCarriers: _manageCarriers,
              thresholdGb: _thresholdGb,
              onConnect: _connect,
              onRefresh: _refresh,
              onConnectAccount: _connectAccount,
              onRefreshAccount: (id) => unawaited(_refreshAccount(id)),
              onRefreshAll: _refreshAll,
              onSettings: _settings,
              onAddWidget: _addWidget,
              widgetSupported: _nativeMobile && !demoMode,
              onAbout: () => _showInfo(
                '流量小伙伴 · 测试版',
                '可选择移动、联通、电信、广电，至少一家。数据来自您登录官方网页后的查询结果，通用、定向和用途未知的流量分开展示。\n\n联通展示官网套餐余量；电信按官网已用量和总量的舍入显示值估算，主位标「约」，均不当作已确认通用额度或触发提醒。真实号码登录和余额准确性仍需手机验证，无法识别时请在官方查询页查看。\n\n会话保存在手机本地，广电会话备份使用系统安全存储；不上传第三方服务器，不读取短信或服务密码。Android 可选择桌面卡片后台刷新间隔，但系统可能延迟任务；iPhone 桌面卡片显示上次查询结果，打开 APP 后刷新。电信需要打开 APP 查询。',
              ),
              demo: demoMode,
            ),
          if (_nativeMobile && !demoMode)
            if (!_restoring && !_savingSelection)
              for (final account in _visibleAccounts.where(
                (a) => _connected.contains(a.id) && !_profileClearPending,
              ))
                _webView(account),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    if (_nativeMobile && !demoMode) _widgetBridge.onOpen(null);
    WidgetsBinding.instance.removeObserver(this);
    _foregroundTimer?.cancel();
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
