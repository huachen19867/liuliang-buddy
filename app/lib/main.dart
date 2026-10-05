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
import 'data/traffic_classification.dart';
import 'ui/carrier_selection_screen.dart';
import 'data/parsers.dart';
import 'services/page_probe.dart';
import 'services/broadnet_session.dart';
import 'services/mobile_query_assembly.dart';
import 'services/unicom_official_query.dart';
import 'services/unicom_app_client.dart';
import 'services/carrier_web.dart';
import 'services/background_refresh.dart';
import 'ui/system_surfaces_settings.dart';
import 'services/background_refresh_runner.dart';
import 'services/telecom_page_probe.dart';
import 'services/response_policy.dart';
import 'services/refresh_throttle.dart';
import 'services/query_state.dart';
import 'services/widget_bridge.dart';
import 'services/ios_account_profiles.dart';
import 'ui/dashboard_screen.dart';
import 'ui/resort_theme.dart';
import 'ui/account_identity_dialog.dart';
import 'ui/carrier_browser_shell.dart';
import 'ui/unicom_app_session_screen.dart';

const demoMode = bool.fromEnvironment('DEMO');
const _notifications = MethodChannel('cn.liuliang/notifications');
const _secure = FlutterSecureStorage();
const _widgetBridge = WidgetBridge();

AccountWebViewSettings officialPageSettings(
  Carrier carrier, {
  String? profileName,
}) => AccountWebViewSettings(profileName: profileName)
  ..supportZoom = true
  ..builtInZoomControls = true
  ..enableViewportScale = true
  ..displayZoomControls = carrier == Carrier.unicom
  // The PC login form otherwise opens as a tiny full-page overview.
  // Keep the official DOM and let the user pan or pinch the native view.
  ..loadWithOverviewMode = carrier != Carrier.unicom
  ..initialScale = carrier == Carrier.unicom ? 100 : 0;

int accountLowTrafficNotificationId(CarrierAccount account) =>
    account.carrier.index * 4 + account.slot;

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
      scaffoldBackgroundColor: ResortPalette.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ResortPalette.mint,
        surface: ResortPalette.paper,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ResortPalette.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: ResortPalette.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ResortPalette.paper,
        showDragHandle: true,
      ),
    ),
    home: const FlowHome(),
  );
}

class FlowHome extends StatefulWidget {
  const FlowHome({super.key, this.unicomAppClient});
  final UnicomAppClient? unicomAppClient;
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
  final Map<String, MobileQueryAssembly> _mobileQueries = {};
  final RefreshThrottle _refreshThrottle = RefreshThrottle();
  final Map<String, bool> _warnedLow = {};
  final Set<String> _inFlight = {};
  final Set<String> _awaitingLoginReturn = {};
  final Set<String> _openingLogin = {};
  SharedPreferences? _prefs;
  CarrierSelection _selection = CarrierSelection.unconfigured();
  CarrierAccounts _accounts = CarrierAccounts.fromSelection(
    CarrierSelection.unconfigured(),
  );
  Set<Carrier> _draftSelection = {};
  final Map<Carrier, int> _draftAccountCounts = {};
  bool _restoring = true;
  bool _savingSelection = false;
  final Map<String, Map<String, dynamic>> _broadnetSessions = {};
  final Set<String> _unicomAppAccounts = {};
  final Map<String, Object> _appQueryTickets = {};
  TrafficClassificationOverrides _trafficClassifications =
      TrafficClassificationOverrides.restore(null);
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

  CarrierSnapshot _restoredSnapshot(
    CarrierSnapshot snapshot, {
    bool startup = false,
  }) =>
      snapshot.status == QueryStatus.loading ||
          (startup && snapshot.status == QueryStatus.success)
      ? snapshot.copyWith(status: QueryStatus.error, message: '上次查询记录，正在确认最新状态')
      : snapshot;

  void _putSnapshot(CarrierAccount account, CarrierSnapshot snapshot) {
    if (snapshot.carrier != account.carrier) return;
    final classified = _trafficClassifications.apply(account.id, snapshot);
    _accountSnapshots[account.id] = classified;
    if (account.isPrimary) _snapshots[account.carrier] = classified;
  }

  void _reapplyTrafficClassifications() {
    for (final account in _accounts.accounts) {
      final snapshot = _accountSnapshots[account.id];
      if (snapshot != null) _putSnapshot(account, snapshot);
    }
  }

  Future<bool> _classifyTrafficBucket(
    String id,
    TrafficBucket bucket,
    BucketKind? kind, {
    required CarrierAccount? expectedAccount,
  }) async {
    if (demoMode ||
        _clearing ||
        _profileClearPending ||
        _savingSelection ||
        kind == BucketKind.unknown) {
      return false;
    }
    final generation = _generation;
    var saved = false;
    try {
      await _store(() async {
        final account = _account(id);
        if (!_current(generation) ||
            account == null ||
            !account.enabled ||
            expectedAccount == null ||
            account.phoneNumber != expectedAccount.phoneNumber) {
          return;
        }
        final snapshot = _snapshot(account);
        if (!TrafficClassificationOverrides.canOverride(snapshot, bucket)) {
          return;
        }
        final next = _trafficClassifications.withOverride(
          id,
          snapshot,
          bucket,
          kind,
        );
        if (await _prefs?.setString(
              TrafficClassificationOverrides.storageKey,
              jsonEncode(next.toJson()),
            ) !=
            true) {
          return;
        }
        if (!_current(generation)) return;
        setState(() {
          _trafficClassifications = next;
          _warnedLow.remove(id);
          _reapplyTrafficClassifications();
        });
        saved = true;
      });
      if (saved && _current(generation)) await _publishWidget();
    } catch (_) {
      // The dialog keeps the choice available for a retry on a failed save.
      if (saved && mounted && _current(generation)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('分类已保存，卡片暂未同步，返回首页后会重试')));
      }
      return saved;
    }
    return saved;
  }

  void _settleInterruptedQueries() {
    for (final carrier in Carrier.values) {
      _snapshots[carrier] = settleInterruptedQuery(_snapshots[carrier]!);
    }
    _accountSnapshots.updateAll(
      (accountId, snapshot) => settleInterruptedQuery(snapshot),
    );
  }

  List<CarrierAccount> get _visibleAccounts =>
      _accounts.visibleAccounts(_selection);

  CarrierAccount? _account(String id) => _accounts.find(id);

  Future<bool> _canSetAccountCounts(Map<Carrier, int> counts) async {
    if (counts.values.any((count) => count < 1 || count > 4) ||
        counts.values.fold<int>(0, (sum, count) => sum + count) > 4) {
      _showInfo('最多照顾四张卡', '每家可选一到四张，合计最多四张。请先调整数量。');
      return false;
    }
    if (!counts.entries.any(
      (entry) =>
          entry.value > 1 && entry.value > _accounts.enabledCount(entry.key),
    )) {
      return true;
    }
    if (_profileClearPending) {
      _showInfo('额外号码暂时锁住了', '上次清除网页登录资料还未完成，请重试清除后再加入。');
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
        _showInfo('额外号码暂时无法加入', '无法确认独立网页登录资料已准备好，请稍后重试。');
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
    } on MissingPluginException {
      // Older plugin builds must not share the primary session.
    }
    if (mounted) {
      _showInfo('这台手机暂不支持同运营商的额外号码', '当前网页内核无法把多个号码的登录会话分开。暂时只能连接每家运营商的一张卡。');
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
    if (account != null) await _dismissOfficialKeyboard(account.id);
    if (!_current(generation) || _visibleAccountId != account?.id) return;
    setState(() => _visibleAccountId = null);
    if (account != null && controller != null) {
      try {
        final url = await controller.getUrl();
        final uri = url == null ? null : Uri.tryParse(url.toString());
        if (!_current(generation) || uri == null || isCarrierLoginPage(uri)) {
          return;
        }
        if (account.carrier == Carrier.telecom &&
            isCarrierResponseAllowed(
              Carrier.telecom,
              uri,
              uri,
              'telecomRendered',
            ) &&
            _awaitingLoginReturn.contains(account.id)) {
          await _resumeTelecomRenderedReturn(account, controller, generation);
        } else if (isCarrierResponsePageCurrent(account.carrier, uri, uri)) {
          _openingLogin.remove(account.id);
          _awaitingLoginReturn.remove(account.id);
          await _refreshAccount(account.id);
        }
      } on Exception {
        // Closing the official page remains available if it was disposed.
      }
    }
  }

  Future<void> _dismissOfficialKeyboard(String accountId) async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await _controllers[accountId]?.clearFocus();
    } on Exception {
      // The page may have closed while a native focus request was pending.
    }
    if (mounted) {
      try {
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      } on PlatformException {
        // The platform may already have dismissed the keyboard.
      }
    }
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
    _refreshThrottle.clear();
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
        _refreshAll(automatic: true);
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
        final candidate = normalizeBroadnetSession(jsonDecode(raw));
        if (candidate != null) {
          _broadnetSessions[account.id] = candidate;
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
      _trafficClassifications = TrafficClassificationOverrides.restore(
        prefs.getString(TrafficClassificationOverrides.storageKey),
      );
      _restoring = false;
      _thresholdGb = (prefs.getDouble('threshold_gb') ?? 5).clamp(1, 20);
      _backgroundRefresh = _ios
          ? BackgroundRefreshInterval.off
          : BackgroundRefreshInterval.fromMinutes(
              prefs.getInt('background_refresh_minutes'),
            );
      _reminders = prefs.getBool('reminders') ?? false;
      for (final account in restoredAccounts.accounts) {
        if (account.carrier == Carrier.unicom &&
            prefs.getString('unicom_query_method_${account.id}') == 'app') {
          _unicomAppAccounts.add(account.id);
        }
        final raw = prefs.getString(account.snapshotKey);
        if (raw != null) {
          try {
            final snapshot = CarrierSnapshot.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            );
            _putSnapshot(account, _restoredSnapshot(snapshot, startup: true));
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
    if (_current(generation)) {
      for (final account in _visibleAccounts.where(
        (a) => _unicomAppAccounts.contains(a.id) && _connected.contains(a.id),
      )) {
        unawaited(_refreshAccount(account.id, automatic: true));
      }
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
        _trafficClassifications = TrafficClassificationOverrides.restore(
          prefs.getString(TrafficClassificationOverrides.storageKey),
        );
        _reapplyTrafficClassifications();
        for (final account in _visibleAccounts) {
          if (_inFlight.contains(account.id)) continue;
          final raw = prefs.getString(account.snapshotKey);
          if (raw == null) continue;
          try {
            _putSnapshot(
              account,
              _restoredSnapshot(
                CarrierSnapshot.fromJson(
                  jsonDecode(raw) as Map<String, dynamic>,
                ),
              ),
            );
          } catch (_) {
            // Keep the in-memory result if a background record is malformed.
          }
        }
      });
    }
    _refreshAll(automatic: true);
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
    if (_account(accountId)?.carrier == Carrier.unicom &&
        _nativeMobile &&
        !demoMode &&
        !_profileClearPending &&
        !_clearing) {
      unawaited(_chooseUnicomConnection(accountId));
      return;
    }
    _connectOfficialAccount(accountId);
  }

  Future<void> _chooseUnicomConnection(String accountId) async {
    final account = _account(accountId);
    if (account == null || !account.enabled || _clearing) return;
    final generation = _generation;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('${account.displayName} · 连接方式'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'web'),
            child: const ListTile(
              leading: Icon(Icons.language_rounded),
              title: Text('官方网站验证'),
              subtitle: Text('通过官网短信登录查询'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'app'),
            child: const ListTile(
              leading: Icon(Icons.link_rounded),
              title: Text('联通 App 查询（试验）'),
              subtitle: Text('官网查询失败时，可手动导入自己的 App 会话'),
            ),
          ),
        ],
      ),
    );
    if (!_current(generation) || choice == null) return;
    if (choice == 'app') {
      await _configureUnicomApp(accountId);
      return;
    }
    _appQueryTickets.remove(accountId);
    _inFlight.remove(accountId);
    if (!_unicomAppAccounts.contains(accountId)) {
      _connectOfficialAccount(accountId);
      return;
    }
    try {
      await _store(() async {
        if (!_current(generation)) return;
        await _secure.delete(key: UnicomAppSession.storageKey(accountId));
        await _prefs?.remove('unicom_query_method_$accountId');
        await _prefs?.setBool('background_auth_required_$accountId', false);
      });
      if (!_current(generation)) return;
      setState(() => _unicomAppAccounts.remove(accountId));
      _connectOfficialAccount(accountId);
    } catch (_) {
      if (_current(generation)) _showInfo('连接方式暂未切换', '本机会话存储暂时不可用，请稍后重试。');
    }
  }

  Future<void> _configureUnicomApp(String accountId) async {
    final account = _account(accountId);
    if (account == null ||
        !account.enabled ||
        _clearing ||
        _profileClearPending) {
      return;
    }
    if (demoMode || !_nativeMobile) {
      _showInfo('这是界面预览', '请安装正式手机包后连接自己的联通会话。');
      return;
    }
    final generation = _generation;
    final candidate = await showUnicomAppSessionScreen(
      context,
      account: account,
      hasSession: _unicomAppAccounts.contains(accountId),
    );
    if (candidate == null || !_current(generation)) return;
    final current = _account(accountId);
    if (current == null || !current.enabled) return;
    if (current.phoneNumber != null &&
        current.phoneNumber != candidate.phoneNumber) {
      _showInfo('号码不一致', '导入号码与这张卡已备注的号码不同，请先确认或修改卡片号码。');
      return;
    }
    _timeouts[accountId]?.cancel();
    _openingLogin.remove(accountId);
    _awaitingLoginReturn.remove(accountId);
    _inFlight.remove(accountId);
    final controller = _controllers.remove(accountId);
    if (controller != null) {
      try {
        await controller.stopLoading();
      } catch (_) {
        /* Already disposed. */
      }
    }
    if (!_current(generation)) return;
    await _refreshUnicomAppAccount(current, candidate: candidate);
  }

  Future<void> _refreshUnicomAppAccount(
    CarrierAccount account, {
    UnicomAppSession? candidate,
  }) async {
    final generation = _generation;
    final id = account.id;
    final ticket = Object();
    _appQueryTickets[id] = ticket;
    _inFlight.add(id);
    _refreshThrottle.started(id, DateTime.now());
    bool current() =>
        _current(generation) &&
        identical(_appQueryTickets[id], ticket) &&
        _account(id)?.enabled == true &&
        _account(id)?.phoneNumber == account.phoneNumber &&
        _selection.allows(Carrier.unicom);
    final previous = _snapshot(account);
    setState(() {
      if (_visibleAccountId == id) _visibleAccountId = null;
      _putSnapshot(
        account,
        previous.copyWith(
          status: QueryStatus.loading,
          message: '正在通过联通 App 接口查询',
        ),
      );
    });
    unawaited(_publishWidget());
    try {
      final stored = candidate == null
          ? await _secure
                .read(key: UnicomAppSession.storageKey(id))
                .timeout(const Duration(seconds: 3))
          : null;
      if (!current()) return;
      final session =
          candidate ??
          (stored == null ? null : UnicomAppSession.restore(stored));
      if (session == null) {
        throw const FormatException('会话不存在');
      }
      if (account.phoneNumber != null &&
          account.phoneNumber != session.phoneNumber) {
        throw const FormatException('会话号码不匹配');
      }
      final result = await (widget.unicomAppClient ?? UnicomAppClient()).query(
        session,
        isCurrent: current,
      );
      if (!current()) return;
      final success = result.snapshot.status == QueryStatus.success;
      final accepted = success || !identical(result.session, session);
      final displayed = success
          ? result.snapshot
          : previous.copyWith(
              status: result.snapshot.status,
              message: result.snapshot.message,
            );
      await _store(() async {
        if (!current()) return;
        // A verified renewal can rotate the token even if a later query fails.
        // Preserve that session; an unauthenticated failed import never replaces it.
        if (accepted) {
          await _secure.write(
            key: UnicomAppSession.storageKey(id),
            value: jsonEncode(result.session.toJson()),
          );
        }
        if (!current()) return;
        if (accepted) {
          await _prefs?.setString('unicom_query_method_$id', 'app');
          await _prefs?.setBool(account.connectedKey, true);
        }
        if (!current()) return;
        await _prefs?.setString(
          account.snapshotKey,
          jsonEncode(displayed.toJson()),
        );
        await _prefs?.setBool(
          'background_auth_required_$id',
          result.snapshot.status == QueryStatus.authExpired,
        );
      });
      if (!current()) return;
      setState(() {
        if (accepted) {
          _unicomAppAccounts.add(id);
          _connected.add(id);
        }
        _putSnapshot(account, displayed);
      });
      await _publishWidget();
      if (current() && success) {
        await _syncBackgroundSchedule();
        if (current()) await _notifyLowTraffic(account, result.snapshot);
      }
    } catch (_) {
      if (current()) {
        setState(
          () => _putSnapshot(
            account,
            previous.copyWith(
              status: QueryStatus.error,
              message: '联通 App 会话暂不可用，请重新连接或使用官方网站验证',
            ),
          ),
        );
        await _publishWidget();
      }
    } finally {
      if (identical(_appQueryTickets[id], ticket)) {
        _appQueryTickets.remove(id);
        _inFlight.remove(id);
      }
    }
  }

  void _connectOfficialAccount(String accountId) {
    final account = _account(accountId);
    if (account == null || !account.enabled) return;
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
    final generation = _generation;
    _inFlight.remove(accountId);
    _awaitingLoginReturn.remove(accountId);
    _refreshThrottle.loginOrLoadFailed(accountId);
    setState(() {
      _visibleAccountId = accountId;
      _webMessage = null;
      _connected.add(accountId);
      _openingLogin.add(accountId);
      _putSnapshot(
        account,
        _snapshot(
          account,
        ).copyWith(status: QueryStatus.loading, message: '正在打开官方验证页'),
      );
    });
    _armOfficialTimeout(account, generation, openingLogin: true);
    unawaited(_publishWidget());
    final prefs = _prefs;
    if (prefs != null) {
      final saved = _store(() async {
        if (_current(generation)) {
          await prefs.setBool(account.connectedKey, true);
        }
      });
      unawaited(saved.then((_) => _syncBackgroundSchedule()));
    }
    final controller = _controllers[accountId];
    if (controller != null) {
      unawaited(_loadOfficialLogin(account, controller, generation));
    }
  }

  Future<void> _loadOfficialLogin(
    CarrierAccount account,
    InAppWebViewController controller,
    int generation,
  ) async {
    try {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(_loginUrl(account.carrier))),
      );
    } on Exception {
      if (!_current(generation)) return;
      _openingLogin.remove(account.id);
      _awaitingLoginReturn.remove(account.id);
      _timeouts[account.id]?.cancel();
      setState(
        () => _putSnapshot(
          account,
          _snapshot(
            account,
          ).copyWith(status: QueryStatus.error, message: '官方登录页暂时无法打开，请重试'),
        ),
      );
      unawaited(_publishWidget());
    }
  }

  void _armOfficialTimeout(
    CarrierAccount account,
    int generation, {
    bool openingLogin = false,
  }) {
    final accountId = account.id;
    _timeouts[accountId]?.cancel();
    _mobileQueries.remove(accountId)?.cancel();
    _timeouts[accountId] = Timer(const Duration(seconds: 35), () {
      if (!_current(generation)) return;
      final pending = openingLogin
          ? _openingLogin.remove(accountId)
          : _inFlight.remove(accountId);
      if (!pending) return;
      if (openingLogin) _awaitingLoginReturn.remove(accountId);
      final failed = _snapshot(account).copyWith(
        status: QueryStatus.error,
        message: openingLogin
            ? '官方验证页加载超时，请重新连接'
            : account.carrier == Carrier.unicom
            ? '联通官网未返回可识别的套餐数据，请打开官方查询页确认登录和套餐；查询已结束，可重新尝试'
            : '未取得可识别的套餐余量，请打开官方查询页确认',
      );
      setState(() {
        _putSnapshot(account, failed);
        if (_visibleAccountId == accountId) _webMessage = failed.message;
      });
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
  }

  Future<void> _resumeTelecomRenderedReturn(
    CarrierAccount account,
    InAppWebViewController controller,
    int generation,
  ) async {
    if (!_current(generation)) return;
    final id = account.id;
    _openingLogin.remove(id);
    _awaitingLoginReturn.remove(id);
    if (_inFlight.add(id)) {
      _refreshThrottle.started(id, DateTime.now());
      setState(
        () => _putSnapshot(
          account,
          _snapshot(
            account,
          ).copyWith(status: QueryStatus.loading, message: '正在读取官网本次打开的套餐页面'),
        ),
      );
      _armOfficialTimeout(account, generation);
      unawaited(_publishWidget());
    }
    try {
      await controller.evaluateJavascript(source: telecomRenderedCaptureScript);
    } on Exception {
      // The active 35-second deadline settles an unavailable rendered page.
    }
  }

  void _refreshAll({bool automatic = false}) {
    if (demoMode || _clearing) return;
    for (final account in _visibleAccounts.where(
      (a) => _connected.contains(a.id),
    )) {
      _refreshAccount(account.id, automatic: automatic);
    }
  }

  Future<void> _refresh(Carrier carrier, {bool automatic = false}) =>
      _refreshAccount(carrier.name, automatic: automatic);

  Future<void> _refreshAccount(
    String accountId, {
    bool automatic = false,
  }) async {
    final account = _account(accountId);
    if (account == null || !account.enabled) return;
    if (_profileClearPending) {
      if (!automatic) {
        _showInfo('查询暂时锁住了', '上次清除网页登录资料还未完成，请在设置里重试清除。');
      }
      return;
    }
    final carrier = account.carrier;
    if (_clearing || !_selection.allows(carrier)) return;
    if (automatic &&
        (_snapshot(account).status == QueryStatus.authExpired ||
            _prefs?.getBool('background_auth_required_$accountId') == true)) {
      return;
    }
    if (!_connected.contains(accountId)) {
      if (!automatic) _connectAccount(accountId);
      return;
    }
    if (_inFlight.contains(accountId) || _openingLogin.contains(accountId)) {
      return;
    }
    if (_refreshThrottle.blocks(accountId, DateTime.now())) return;
    if (carrier == Carrier.unicom && _unicomAppAccounts.contains(accountId)) {
      await _refreshUnicomAppAccount(account);
      return;
    }
    final controller = _controllers[accountId];
    if (controller == null) return;
    final generation = _generation;
    _inFlight.add(accountId);
    if (!_current(generation)) {
      _inFlight.remove(accountId);
      return;
    }
    _refreshThrottle.started(accountId, DateTime.now());
    setState(
      () => _putSnapshot(
        account,
        _snapshot(
          account,
        ).copyWith(status: QueryStatus.loading, message: '正在向运营商查询'),
      ),
    );
    unawaited(_publishWidget());
    _armOfficialTimeout(account, generation);
    try {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(_queryUrl(carrier))),
      );
    } catch (_) {
      _timeouts[accountId]?.cancel();
      _inFlight.remove(accountId);
      _refreshThrottle.loginOrLoadFailed(accountId);
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
    if (_unicomAppAccounts.contains(accountId) ||
        _appQueryTickets.containsKey(accountId)) {
      return;
    }
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
          page == null ||
          !isCarrierResponsePageCurrent(
            carrier,
            page,
            Uri.tryParse(currentUrl.toString()) ?? Uri(),
          )) {
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
    final mobileQuery = carrier == Carrier.mobile
        ? _mobileQueries.putIfAbsent(accountId, MobileQueryAssembly.new)
        : null;
    if (carrier == Carrier.mobile && stage == 'mobileBalanceRendered') {
      mobileQuery!.acceptBalance(parseMobileBalanceRendered(decoded));
      return;
    }
    if (mobileQuery != null && !mobileQuery.claimFlow()) return;
    final status = payload['status'] is int ? payload['status'] as int : null;
    final unicomSession = carrier == Carrier.unicom && stage == 'unicomSession';
    if (unicomSession && !isUnicomSessionExpired(decoded, status)) return;
    var snapshot = unicomSession
        ? const CarrierSnapshot(
            carrier: Carrier.unicom,
            status: QueryStatus.authExpired,
            message: '联通官网登录已失效，请重新连接号码',
          )
        : switch (carrier) {
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
    if (mobileQuery != null && snapshot.status == QueryStatus.success) {
      // A confirmed allowance response has met the original query deadline.
      // Only the short independent money wait remains.
      _timeouts[accountId]?.cancel();
      try {
        await controller
            .evaluateJavascript(source: mobileBalanceCaptureScript)
            .timeout(const Duration(seconds: 1));
      } on Exception {
        // Missing money must not discard a successful allowance response.
      }
      snapshot = await mobileQuery.assemble(snapshot);
      if (!_current(generation) ||
          !identical(_mobileQueries[accountId], mobileQuery)) {
        return;
      }
      try {
        final latestUrl = await controller.getUrl();
        if (latestUrl == null ||
            !isCarrierResponsePageCurrent(
              carrier,
              page,
              Uri.tryParse(latestUrl.toString()) ?? Uri(),
            )) {
          return;
        }
      } on Exception {
        return;
      }
    }
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
        (mobileQuery != null &&
            !identical(_mobileQueries[accountId], mobileQuery)) ||
        (!_inFlight.contains(accountId) &&
            !_awaitingLoginReturn.contains(accountId))) {
      return;
    }
    final hadPreviousQuery = _snapshot(account).queriedAt != null;
    _timeouts[accountId]?.cancel();
    _inFlight.remove(accountId);
    _awaitingLoginReturn.remove(accountId);
    _mobileQueries.remove(accountId)?.cancel();
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
      if (carrier == Carrier.broadnet) {
        await _saveVerifiedBroadnetSession(account, controller, generation);
      }
      if (!_current(generation)) return;
      if (!hadPreviousQuery) await _syncBackgroundSchedule();
      if (!_current(generation)) return;
      await _notifyLowTraffic(account, snapshot);
    }
  }

  Future<void> _notifyLowTraffic(
    CarrierAccount account,
    CarrierSnapshot snapshot,
  ) async {
    final classified = _trafficClassifications.apply(account.id, snapshot);
    final remaining = classified.generalRemainingBytes;
    final hasManualGeneral = classified.buckets.any(
      (bucket) => bucket.manualKind == BucketKind.general,
    );
    final low = remaining != null && remaining / 1073741824 <= _thresholdGb;
    if (low &&
        !(_warnedLow[account.id] ?? false) &&
        _reminders &&
        _nativeMobile) {
      try {
        await _notifications.invokeMethod('notify', {
          'id': accountLowTrafficNotificationId(account),
          'title': '${account.label}流量快见底了',
          'body':
              '通用流量剩余 ${(remaining / 1073741824).toStringAsFixed(2)} GB${hasManualGeneral ? '（含手动分类）' : ''}，数据以运营商查询为准。',
        });
      } on PlatformException {
        /* Dashboard retains the actual result. */
      }
    }
    _warnedLow[account.id] = low;
  }

  Future<void> _saveVerifiedBroadnetSession(
    CarrierAccount account,
    InAppWebViewController controller,
    int generation,
  ) async {
    if (!_current(generation)) return;
    try {
      final result = await controller
          .evaluateJavascript(source: broadnetSessionCaptureScript)
          .timeout(const Duration(seconds: 2));
      if (!_current(generation)) return;
      final session = captureBroadnetSession(
        result,
        capturedAt: DateTime.now(),
      );
      if (session == null) return;
      await _store(() async {
        if (_current(generation)) {
          await _secure.write(
            key: account.broadnetSessionKey,
            value: jsonEncode(session),
          );
        }
      });
      if (!_current(generation)) return;
      _broadnetSessions[account.id] = session;
      // Document-start scripts retain their original source. Replace the
      // backup after an official rotation rather than restoring old keys on
      // a later reload with empty sessionStorage.
      await controller.removeUserScriptsByGroupName(
        groupName: 'broadnetRestore',
      );
      if (!_current(generation)) return;
      await controller.addUserScript(
        userScript: UserScript(
          groupName: 'broadnetRestore',
          source: broadnetSessionRestoreScript(session),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      );
    } catch (_) {
      /* Official login remains usable for this WebView session. */
    }
  }

  Future<void> _openMobileAuthAgreement(Uri target) async {
    if (!isMobileNumberAuthAgreement(target)) return;
    try {
      await ChromeSafariBrowser().open(url: WebUri(target.toString()));
    } catch (_) {
      if (mounted) {
        _showInfo(
          '认证协议暂时无法打开',
          '请在系统浏览器查看中国移动认证协议：\nhttps://wap.cmpassport.com/resources/html/contract.html',
        );
      }
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
        child: CarrierBrowserShell(
          title: '${account.label}官方页面',
          message:
              _webMessage ??
              (carrier == Carrier.mobile
                  ? mobileLoginGuide
                  : carrier == Carrier.unicom
                  ? '在官网选择「随机密码登录」获取短信密码。表单可双指缩放、左右移动；登录后点击「查询流量」。'
                  : '在官网完成验证后点击上方「查询流量」。关闭此页可回到首页。'),
          onClose: () => unawaited(_closeOfficialPage()),
          onQuery: () => unawaited(_refreshAccount(accountId)),
          onReload: () {
            final controller = _controllers[accountId];
            if (controller != null) unawaited(controller.reload());
          },
          onDismissKeyboard: () =>
              unawaited(_dismissOfficialKeyboard(accountId)),
          keyboardVisible: MediaQuery.viewInsetsOf(context).bottom > 0,
          onHelp: carrier == Carrier.mobile
              ? () => _showInfo(
                  '移动网页登录帮助',
                  '输入完整手机号后，请在官网阅读并自行勾选协议，再点击「获取验证码」。如果按钮没有反应，可先收起键盘，查看官网是否显示协议或错误提示。\n\n$mobileLoginHelpMessage',
                )
              : carrier == Carrier.unicom
              ? () => _showInfo(
                  '联通网页登录帮助',
                  '在联通官网选择「随机密码登录」，自行输入手机号、按官网要求勾选协议并获取短信密码。登录框来自联通官网，可以双指放大或缩小、左右移动；Android 也可使用网页缩放按钮。\n\n完成官网登录后点击本页「查询流量」，等待官网套餐页面加载。若官网仍要求验证或报错，请按官网提示处理。',
                )
              : null,
          child: InAppWebView(
            key: ValueKey('${account.id}_$_generation'),
            // Every account is loaded only after its WebView profile is set.
            initialSettings: officialPageSettings(
              carrier,
              profileName: _ios ? account.profileName : null,
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
                    throw StateError('Persistent account store unavailable');
                  }
                } on Exception {
                  if (_current(generation)) {
                    _openingLogin.remove(accountId);
                    _timeouts[accountId]?.cancel();
                    setState(
                      () => _putSnapshot(
                        account,
                        _snapshot(account).copyWith(
                          status: QueryStatus.error,
                          message: '此 iPhone 暂无法打开额外号码的独立登录会话',
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
                      throw StateError('Profile ownership could not be saved');
                    }
                  });
                  if (!_current(generation)) return;
                  await (controller.platform
                          as android_webview.AndroidInAppWebViewController)
                      .setAccountProfile(account.profileName!);
                } catch (_) {
                  if (_current(generation)) {
                    _openingLogin.remove(accountId);
                    _timeouts[accountId]?.cancel();
                    setState(
                      () => _putSnapshot(
                        account,
                        _snapshot(account).copyWith(
                          status: QueryStatus.error,
                          message: '此手机的网页内核暂不支持同运营商的额外号码',
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
              if (_openingLogin.contains(accountId) ||
                  _snapshot(account).status == QueryStatus.notConnected) {
                await _loadOfficialLogin(account, controller, generation);
              } else {
                await _refreshAccount(accountId);
              }
            },
            shouldOverrideUrlLoading: (controller, action) async {
              final target = Uri.tryParse(action.request.url?.toString() ?? '');
              if (carrier == Carrier.mobile &&
                  action.isForMainFrame &&
                  target != null &&
                  isMobileNumberAuthAgreement(target)) {
                await _openMobileAuthAgreement(target);
                return NavigationActionPolicy.CANCEL;
              }
              return _allowedUrl(carrier, action.request.url)
                  ? NavigationActionPolicy.ALLOW
                  : NavigationActionPolicy.CANCEL;
            },
            onUpdateVisitedHistory: (controller, url, isReload) {
              if (!_current(generation) || url == null) return;
              final uri = Uri.tryParse(url.toString());
              if (uri != null && isCarrierLoginPage(uri)) {
                _timeouts[accountId]?.cancel();
                _openingLogin.remove(accountId);
                _inFlight.remove(accountId);
                _refreshThrottle.loginOrLoadFailed(accountId);
                _mobileQueries.remove(accountId)?.cancel();
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
              } else if (carrier == Carrier.telecom &&
                  uri != null &&
                  isCarrierResponseAllowed(
                    Carrier.telecom,
                    uri,
                    uri,
                    'telecomRendered',
                  ) &&
                  (_awaitingLoginReturn.contains(accountId) ||
                      _openingLogin.contains(accountId) ||
                      _inFlight.contains(accountId))) {
                // Telecom changes its SPA hash after login without always
                // emitting onLoadStop. This reads that new official route.
                unawaited(
                  _resumeTelecomRenderedReturn(account, controller, generation),
                );
              }
            },
            onLoadStop: (controller, url) async {
              if (!_current(generation)) return;
              if (url == null ||
                  Uri.tryParse(url.toString())?.scheme != 'https' ||
                  !_allowedUrl(carrier, url)) {
                return;
              }
              final finishedOpeningLogin = _openingLogin.remove(accountId);
              if (finishedOpeningLogin) _timeouts[accountId]?.cancel();
              if (isCarrierLoginPage(Uri.parse(url.toString()))) {
                _mobileQueries.remove(accountId)?.cancel();
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
                _refreshThrottle.loginOrLoadFailed(accountId);
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
              if (_current(generation) &&
                  !isCarrierLoginPage(Uri.parse(url.toString())) &&
                  (_awaitingLoginReturn.remove(accountId) ||
                      finishedOpeningLogin)) {
                unawaited(_refreshAccount(accountId));
                return;
              }
              if (_current(generation) &&
                  carrier == Carrier.unicom &&
                  _inFlight.contains(accountId)) {
                try {
                  await controller.evaluateJavascript(
                    source: unicomOfficialQueryScript,
                  );
                } on Exception {
                  // The existing timeout preserves the last verified data.
                }
              }
              if (_current(generation) &&
                  carrier == Carrier.telecom &&
                  _inFlight.contains(accountId)) {
                try {
                  await controller.evaluateJavascript(
                    source: telecomRenderedCaptureScript,
                  );
                } on Exception {
                  // The existing timeout preserves the last verified data.
                }
              }
            },
            onReceivedError: (controller, request, error) {
              if (request.isForMainFrame != true || !_current(generation)) {
                return;
              }
              _timeouts[accountId]?.cancel();
              _openingLogin.remove(accountId);
              _inFlight.remove(accountId);
              _refreshThrottle.loginOrLoadFailed(accountId);
              setState(() {
                _webMessage = '官方页面暂时无法打开，请检查网络后重试';
                _putSnapshot(
                  account,
                  _snapshot(
                    account,
                  ).copyWith(status: QueryStatus.error, message: _webMessage),
                );
              });
              unawaited(_publishWidget());
            },
          ),
        ),
      ),
    );
  }

  Future<void> _applySelection(
    Set<Carrier> carriers, {
    Map<Carrier, int> accountCounts = const {},
  }) async {
    if (_savingSelection || carriers.isEmpty || _clearing) return;
    final previousSelection = _selection;
    final previousAccounts = _accounts;
    final selection = CarrierSelection.complete(carriers);
    final counts = {
      for (final carrier in carriers) carrier: accountCounts[carrier] ?? 1,
    };
    if (counts.values.any((count) => count < 1 || count > 4) ||
        counts.values.fold<int>(0, (sum, count) => sum + count) > 4) {
      _showInfo('最多照顾四张卡', '每家可选一到四张，合计最多四张。请先调整数量。');
      return;
    }
    final nextAccounts = _accounts.withAccountCounts(selection, counts);
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
          final session = normalizeBroadnetSession(jsonDecode(secureRaw));
          if (session != null) {
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
      _settleInterruptedQueries();
      _selection = selection;
      _accounts = nextAccounts;
      _connected.addAll(connectedNew);
      _broadnetSessions.addAll(restoredSessions);
      for (final account in nextAccounts.accounts) {
        final restored = restoredNew[account.id];
        if (restored != null) {
          _putSnapshot(account, _restoredSnapshot(restored));
        }
      }
      _controllers.clear();
      _visibleAccountId = null;
      _refreshThrottle.clear();
      _appQueryTickets.clear();
      _unicomAppAccounts.addAll(
        nextAccounts.accounts
            .where(
              (a) =>
                  a.carrier == Carrier.unicom &&
                  _prefs?.getString('unicom_query_method_${a.id}') == 'app',
            )
            .map((a) => a.id),
      );
      for (final query in _mobileQueries.values) {
        query.cancel();
      }
      _mobileQueries.clear();
      _inFlight.clear();
      _awaitingLoginReturn.clear();
      _openingLogin.clear();
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
    var draftCounts = {
      for (final carrier in Carrier.values)
        carrier: _accounts.enabledCount(carrier) == 0
            ? 1
            : _accounts.enabledCount(carrier),
    };
    final result = await Navigator.of(context)
        .push<(Set<Carrier>, Map<Carrier, int>)>(
          MaterialPageRoute(
            builder: (context) => StatefulBuilder(
              builder: (context, update) => CarrierSelectionScreen(
                selectedCarriers: draft,
                accountCounts: draftCounts,
                onSelectionChanged: (value) => update(() => draft = value),
                onAccountCountsChanged: (counts) async {
                  if (await _canSetAccountCounts(counts) && context.mounted) {
                    update(() => draftCounts = {...draftCounts, ...counts});
                  }
                },
                onContinue: (value) =>
                    Navigator.pop(context, (value, draftCounts)),
                isInitialSetup: false,
                demo: demoMode,
              ),
            ),
          ),
        );
    if (result != null && mounted) {
      await _applySelection(result.$1, accountCounts: result.$2);
    }
  }

  Future<void> _editAccount(String id) async {
    if (_clearing || _savingSelection) return;
    final account = _account(id);
    if (account == null) return;
    final generation = _generation;
    final identity = await showDialog<(String, String)>(
      context: context,
      builder: (_) => AccountIdentityDialog(account: account),
    );
    if (identity == null || !_current(generation)) return;
    try {
      await _store(() async {
        if (!_current(generation) || _account(id) == null) return;
        final next = _accounts.updateIdentity(
          id,
          note: identity.$1,
          phoneNumber: identity.$2,
        );
        final phoneChanged = account.phoneNumber != next.find(id)?.phoneNumber;
        if (phoneChanged) {
          _mobileQueries.remove(id)?.cancel();
          _awaitingLoginReturn.remove(id);
          final classifications = _trafficClassifications.withoutAccount(id);
          if (await _prefs?.setString(
                TrafficClassificationOverrides.storageKey,
                jsonEncode(classifications.toJson()),
              ) !=
              true) {
            throw StateError('Classification reset failed');
          }
          if (!_current(generation)) return;
          setState(() {
            _trafficClassifications = classifications;
            _warnedLow.remove(id);
            _reapplyTrafficClassifications();
          });
        }
        if (await _prefs?.setString(
              CarrierAccounts.storageKey,
              next.toStorageString(),
            ) !=
            true) {
          throw StateError('Identity save failed');
        }
        if (_current(generation)) {
          setState(() {
            _accounts = next;
            if (phoneChanged) {
              _appQueryTickets.remove(id);
              _inFlight.remove(id);
              _refreshThrottle.loginOrLoadFailed(id);
              if (_unicomAppAccounts.contains(id)) {
                _putSnapshot(
                  account,
                  _snapshot(account).copyWith(
                    status: QueryStatus.authExpired,
                    message: '卡片号码已修改，请重新连接此号码的联通 App 会话',
                  ),
                );
              }
            }
          });
        }
      });
      if (_current(generation)) await _publishWidget();
    } catch (_) {
      if (_current(generation)) _showInfo('备注还没保存', '本机存储暂时无法写入，请稍后重试。');
    }
  }

  Future<void> _removeSecondAccount(String id) async {
    final account = _account(id);
    if (account == null || account.isPrimary || _clearing) return;
    final previous = _accounts;
    final oldControllers = _controllers.values.toList();
    setState(() {
      _generation++;
      _settleInterruptedQueries();
      _accounts = _accounts.removeSecond(id);
      _controllers.clear();
      _visibleAccountId = null;
      for (final query in _mobileQueries.values) {
        query.cancel();
      }
      _mobileQueries.clear();
      _inFlight.clear();
      _awaitingLoginReturn.clear();
      _openingLogin.clear();
      _refreshThrottle.clear();
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .9,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '照顾好你的流量',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_android) const SystemSurfacesSettings(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('管理运营商'),
                      subtitle: Text(
                        _selection.selectedCarriers
                            .map((c) => c.label)
                            .join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(_manageCarriers());
                      },
                    ),
                    for (final account in _visibleAccounts.where(
                      (a) => a.carrier == Carrier.unicom,
                    ))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${account.displayName} · 查询方式'),
                        subtitle: Text(
                          _unicomAppAccounts.contains(account.id)
                              ? '联通 App 查询 · 本机独立会话'
                              : '官方网站 · 可切换 App 查询试验',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
                          unawaited(_chooseUnicomConnection(account.id));
                        },
                      ),
                    for (final account in _visibleAccounts.where(
                      (a) => !a.isPrimary,
                    ))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('收起 ${account.label}'),
                        subtitle: const Text('保留本机查询记录和登录资料，之后可重新加入'),
                        trailing: const Icon(
                          Icons.remove_circle_outline_rounded,
                        ),
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
                            for (final value
                                in BackgroundRefreshInterval.values)
                              PopupMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
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
      _unicomAppAccounts.clear();
      _appQueryTickets.clear();
      for (final query in _mobileQueries.values) {
        query.cancel();
      }
      _mobileQueries.clear();
      _inFlight.clear();
      _awaitingLoginReturn.clear();
      _openingLogin.clear();
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
                      (carrier) => [2, 3, 4].any(
                        (slot) =>
                            (_prefs?.containsKey(
                                  'connected_${CarrierAccount.idFor(carrier, slot)}',
                                ) ??
                                false) ||
                            (_prefs?.containsKey(
                                  'snapshot_${CarrierAccount.idFor(carrier, slot)}',
                                ) ??
                                false),
                      ),
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
      for (final id in [
        for (var slot = 1; slot <= 4; slot++)
          CarrierAccount.idFor(carrier, slot),
      ]) {
        try {
          if (carrier == Carrier.broadnet) {
            await _secure.delete(
              key: id == carrier.name
                  ? 'broadnet_session'
                  : 'broadnet_session_$id',
            );
          }
          if (carrier == Carrier.unicom) {
            await _secure.delete(key: UnicomAppSession.storageKey(id));
            await _prefs?.remove('unicom_query_method_$id');
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
    try {
      if (await _prefs?.remove(TrafficClassificationOverrides.storageKey) !=
          true) {
        otherDataCleared = false;
      }
    } catch (_) {
      otherDataCleared = false;
    }
    try {
      final clearedAccounts = _accounts.withoutIdentities();
      if (await _prefs?.setString(
            CarrierAccounts.storageKey,
            clearedAccounts.toStorageString(),
          ) !=
          true) {
        otherDataCleared = false;
      } else {
        _accounts = clearedAccounts;
      }
    } catch (_) {
      otherDataCleared = false;
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
      _refreshThrottle.clear();
      _warnedLow.clear();
      _broadnetSessions.clear();
      _unicomAppAccounts.clear();
      _appQueryTickets.clear();
      _visibleAccountId = null;
      _accountSnapshots.clear();
      _trafficClassifications = TrafficClassificationOverrides.restore(null);
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
  Widget build(BuildContext context) {
    final classificationAccounts = _accounts;
    return PopScope(
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
                accountCounts: _draftAccountCounts,
                onSelectionChanged: (value) =>
                    setState(() => _draftSelection = value),
                onAccountCountsChanged: (counts) async {
                  if (await _canSetAccountCounts(counts) && mounted) {
                    setState(() => _draftAccountCounts.addAll(counts));
                  }
                },
                onContinue: (value) => unawaited(
                  _applySelection(value, accountCounts: _draftAccountCounts),
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
                onEditAccount: (id) => unawaited(_editAccount(id)),
                onClassifyBucket: demoMode
                    ? null
                    : (id, bucket, kind) => _classifyTrafficBucket(
                        id,
                        bucket,
                        kind,
                        expectedAccount: classificationAccounts.find(id),
                      ),
                onRefreshAll: _refreshAll,
                onSettings: _settings,
                onAddWidget: _addWidget,
                widgetSupported: _nativeMobile && !demoMode,
                onAbout: () => _showInfo(
                  kReleaseMode ? '流量小伙伴' : '流量小伙伴 · 开发版',
                  '可选择移动、联通、电信、广电，至少一家。数据来自官方查询，通用、定向和其他套餐流量分开展示。\n\n联通默认查询官网，也可在连接方式中选择 App 查询试验；该方式需要主动导入自己的会话，不能自动读取官方 App 或一键获取验证码。电信名称含“定向”的归入定向流量，其余归入其他流量；按官网已用量和总量的显示值估算，主位标「约」。真实号码和余额准确性仍需手机验证。\n\n会话保存在手机本地，广电备份与联通 App 会话使用系统安全存储；不上传第三方服务器，不读取短信或服务密码。Android 可选择桌面卡片后台刷新间隔，但系统可能延迟任务；iPhone 桌面卡片显示上次查询结果，打开 APP 后刷新。电信需要打开 APP 查询。',
                ),
                demo: demoMode,
              ),
            if (_nativeMobile && !demoMode)
              if (!_restoring && !_savingSelection)
                for (final account in _visibleAccounts.where(
                  (a) =>
                      _connected.contains(a.id) &&
                      !_profileClearPending &&
                      !_unicomAppAccounts.contains(a.id),
                ))
                  _webView(account),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_nativeMobile && !demoMode) _widgetBridge.onOpen(null);
    WidgetsBinding.instance.removeObserver(this);
    _foregroundTimer?.cancel();
    for (final query in _mobileQueries.values) {
      query.cancel();
    }
    _mobileQueries.clear();
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
