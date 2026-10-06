import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/main.dart';
import 'package:liuliang_app/services/page_probe.dart';
import 'package:liuliang_app/services/query_health.dart';
import 'package:liuliang_app/services/system_surfaces.dart';
import 'package:liuliang_app/services/widget_bridge.dart';
import 'package:liuliang_app/ui/carrier_browser_shell.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';
import 'package:liuliang_app/ui/query_health_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The app and navigation are real. Only the native WebView/plugin methods are
// replaced, so reconnect must reach FlowHome's actual official load path.
class _HealthWebViewPlatform extends InAppWebViewPlatform {
  final controller = _HealthController();

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => _HealthWebViewWidget(params, controller);
}

class _HealthWebViewWidget extends PlatformInAppWebViewWidget {
  _HealthWebViewWidget(super.params, this.controller) : super.implementation();

  final _HealthController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.created) {
      controller.created = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        params.onWebViewCreated?.call(controllerFromPlatform(controller));
      });
    }
    return const SizedBox.expand();
  }

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}

class _HealthController extends PlatformInAppWebViewController {
  _HealthController()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(
          id: 'health-fixture',
        ),
      );

  bool created = false;
  final loadedUrls = <String>[];
  final userScriptGroups = <String?>[];
  final handlers = <String, JavaScriptHandlerCallback>{};

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    loadedUrls.add(urlRequest.url.toString());
  }

  @override
  Future<void> addUserScript({required UserScript userScript}) async {
    userScriptGroups.add(userScript.groupName);
  }

  @override
  Future<void> removeUserScriptsByGroupName({
    required String groupName,
  }) async {}

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {
    handlers[handlerName] = callback;
  }

  @override
  void dispose({bool isKeepAlive = false}) {}
}

void main() {
  late _HealthWebViewPlatform platform;
  late InAppWebViewPlatform? previousPlatform;
  late List<String> notificationCalls;
  late bool versionFails;
  const phone = '13800000000';
  const privateNote = '私人备注13800000000';
  const privateToken = 'SYNTHETIC_SECRET_TOKEN';
  const rawServerMessage =
      'HTTP 403 https://private.invalid/raw?token=SYNTHETIC_SECRET_TOKEN phone=13800000000';
  final oldTime = DateTime.utc(2026, 10, 2, 8);
  final oldSnapshot = CarrierSnapshot(
    carrier: Carrier.mobile,
    status: QueryStatus.authExpired,
    queriedAt: oldTime,
    phoneMasked: phone,
    balanceYuan: 9.87,
    message: rawServerMessage,
  );
  const notifications = MethodChannel('cn.liuliang/notifications');
  const background = MethodChannel('cn.liuliang/background_refresh_schedule');
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const channels = [
    notifications,
    background,
    secure,
    WidgetBridge.channel,
    SystemSurfaces.channel,
  ];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    previousPlatform = InAppWebViewPlatform.instance;
    platform = _HealthWebViewPlatform();
    InAppWebViewPlatform.instance = platform;
    notificationCalls = [];
    versionFails = false;
    final selection = CarrierSelection.complete([Carrier.mobile]);
    final accounts = CarrierAccounts.fromSelection(
      selection,
    ).updateIdentity('mobile', note: privateNote, phoneNumber: phone);
    SharedPreferences.setMockInitialValues({
      'carrier_selection': selection.toStorageString(),
      CarrierAccounts.storageKey: accounts.toStorageString(),
      'connected_mobile': false,
      'snapshot_mobile': jsonEncode(oldSnapshot.toJson()),
      'background_refresh_minutes': 60,
      'background_auth_required_mobile': true,
      'reminders': false,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notifications, (call) async {
      notificationCalls.add(call.method);
      if (call.method == 'getAppVersion') {
        if (versionFails) throw PlatformException(code: 'version-unavailable');
        return {'name': '9.8.7', 'code': '432'};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(background, (call) async {
      if (call.method == 'status') {
        return {
          'lastOutcome': rawServerMessage,
          'lastFinishedAt': oldTime.millisecondsSinceEpoch,
        };
      }
      return null;
    });
    messenger.setMockMethodCallHandler(secure, (_) async => null);
    messenger.setMockMethodCallHandler(WidgetBridge.channel, (call) async {
      if (call.method == 'consumeLaunchRefresh') return false;
      return null;
    });
    messenger.setMockMethodCallHandler(
      SystemSurfaces.channel,
      (_) async => {
        'notificationEnabled': false,
        'tileEnabled': false,
        'notificationsAllowed': true,
        'tileAddSupported': true,
      },
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    InAppWebViewPlatform.instance =
        previousPlatform ?? _HealthWebViewPlatform();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  Future<QueryHealthScreen> openReport(WidgetTester tester) async {
    await tester.pumpWidget(const FlowBuddyApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('提醒设置'));
    await tester.tap(find.text('提醒设置'));
    await tester.pumpAndSettle();
    expect(find.text('照顾好你的流量'), findsOneWidget);
    await tester.ensureVisible(find.text('连接与刷新检查'));
    await tester.tap(find.text('连接与刷新检查'));
    await tester.pumpAndSettle();
    expect(find.text('查询状态'), findsOneWidget);
    return tester.widget<QueryHealthScreen>(find.byType(QueryHealthScreen));
  }

  testWidgets('设置进入真实诊断报告读取安装版本且重新登录打开官方页面', (tester) async {
    final screen = await openReport(tester);
    expect(
      notificationCalls.where((call) => call == 'getAppVersion'),
      hasLength(1),
    );
    expect(screen.report.version, '9.8.7+432');
    expect(find.text('9.8.7+432'), findsOneWidget);
    expect(screen.report.refreshInterval, '每 1 小时');
    final account = screen.report.accounts.single;
    expect(account.accountId, 'mobile');
    expect(account.label, '中国移动 1');
    expect(account.kind, QueryHealthKind.loginExpired);
    expect(account.action, QueryHealthAction.reconnect);
    expect(account.lastValidDataAt, oldTime);
    expect(screen.report.backgroundSummary, '尚无后台查询记录');

    final reportValues = [
      screen.report.version,
      screen.report.refreshInterval,
      screen.report.backgroundSummary,
      account.accountId,
      account.label,
      account.detail,
      account.backgroundNote,
    ].join('\n');
    final visibleTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(QueryHealthScreen),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
        .join('\n');
    for (final privateValue in [
      phone,
      privateNote,
      privateToken,
      rawServerMessage,
    ]) {
      expect(reportValues, isNot(contains(privateValue)));
      expect(visibleTexts, isNot(contains(privateValue)));
    }
    expect(platform.controller.loadedUrls, isEmpty);

    await tester.ensureVisible(find.text('重新登录'));
    await tester.tap(find.text('重新登录'));
    // Start the pop animation in its first frame, then advance its clock.
    // Pumping only zero-time continuation frames leaves the old route alive.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }
    expect(find.byType(QueryHealthScreen), findsNothing);
    expect(find.byType(CarrierBrowserShell), findsOneWidget);
    expect(platform.controller.loadedUrls, [mobileLoginUrl]);
    expect(platform.controller.userScriptGroups, contains('queryEpoch'));
    expect(platform.controller.handlers, contains('trafficResponse'));
    final dashboard = tester.widget<DashboardScreen>(
      find.byType(DashboardScreen),
    );
    expect(
      dashboard.accountEntries!.single.snapshot!.status,
      QueryStatus.loading,
    );
    expect(dashboard.accountEntries!.single.snapshot!.queriedAt, oldTime);
    expect(
      (await SharedPreferences.getInstance()).getBool('connected_mobile'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('安装版本方法失败时诊断入口不冒用源码版本', (tester) async {
    versionFails = true;
    final screen = await openReport(tester);
    expect(
      notificationCalls.where((call) => call == 'getAppVersion'),
      hasLength(1),
    );
    expect(screen.report.version, '版本信息暂不可用');
    expect(find.text('版本信息暂不可用'), findsOneWidget);
    expect(screen.report.accounts.single.kind, QueryHealthKind.loginExpired);
    expect(platform.controller.loadedUrls, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
}
