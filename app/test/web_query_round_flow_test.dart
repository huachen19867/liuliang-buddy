import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/main.dart';
import 'package:liuliang_app/services/page_probe.dart';
import 'package:liuliang_app/services/widget_bridge.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fake only the plugin boundary: FlowHome owns the real rounds, callbacks,
// timers, parsing, account snapshots, widget publishing and preferences.
class _FakeWebViewPlatform extends InAppWebViewPlatform {
  final controller = _FakeController();
  PlatformInAppWebViewWidgetCreationParams? viewParams;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    viewParams = params;
    return _FakeWebViewWidget(params, controller);
  }

  void visit(String url) {
    controller.currentUrl = WebUri(url);
    viewParams!.onUpdateVisitedHistory?.call(
      InAppWebViewController.fromPlatform(platform: controller),
      WebUri(url),
      false,
    );
  }
}

class _FakeWebViewWidget extends PlatformInAppWebViewWidget {
  _FakeWebViewWidget(super.params, this.controller) : super.implementation();

  final _FakeController controller;

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

class _FakeController extends PlatformInAppWebViewController {
  _FakeController()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 'fixture'),
      );

  final urlReads = Queue<Future<WebUri?> Function()>();
  final loads = Queue<Future<void> Function()>();
  final handlers = <String, JavaScriptHandlerCallback>{};
  final installedEpochs = <String>[];
  final loadedUrls = <String>[];
  bool failRestoreRemoval = false;
  Future<void>? stopResult;
  bool created = false;
  int getUrlCalls = 0;
  WebUri currentUrl = WebUri(mobileQueryUrl);

  String get epoch => installedEpochs.last;

  Future<dynamic> emit(Map<String, Object?> payload) async =>
      handlers['trafficResponse']!([payload]);

  @override
  Future<WebUri?> getUrl() {
    getUrlCalls++;
    return urlReads.isEmpty
        ? Future<WebUri?>.value(currentUrl)
        : urlReads.removeFirst()();
  }

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) {
    loadedUrls.add(urlRequest.url.toString());
    currentUrl = urlRequest.url!;
    return loads.isEmpty ? Future<void>.value() : loads.removeFirst()();
  }

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {
    handlers[handlerName] = callback;
  }

  @override
  Future<void> addUserScript({required UserScript userScript}) async {
    if (userScript.groupName == 'queryEpoch') {
      final value = RegExp(r'=\s*("[^"]+")\s*;').firstMatch(userScript.source);
      expectSync(value, isNotNull);
      installedEpochs.add(jsonDecode(value!.group(1)!) as String);
    }
  }

  @override
  Future<void> removeUserScriptsByGroupName({required String groupName}) async {
    if (groupName == 'broadnetRestore' && failRestoreRemoval) {
      throw PlatformException(code: 'restore-removal-failed');
    }
  }

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async => null;

  @override
  void dispose({bool isKeepAlive = false}) {}

  @override
  Future<void> stopLoading() async =>
      await (stopResult ?? Future<void>.value());
}

DashboardScreen _dashboard(WidgetTester tester) =>
    tester.widget<DashboardScreen>(find.byType(DashboardScreen));

CarrierSnapshot _snapshot(WidgetTester tester) =>
    _dashboard(tester).accountEntries!.single.snapshot!;

Future<void> _drain(WidgetTester tester) async {
  // Loading animations intentionally keep scheduling frames. Flush async
  // continuations without pumpAndSettle advancing query deadlines.
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

Map<String, Object?> _flow(String epoch, int remainingMb) => {
  'url': 'https://wx.10086.cn/website/serviceMargin/getNewMarginInfo',
  'pageUrl': mobileQueryUrl,
  'stage': 'raw',
  'queryEpoch': epoch,
  'status': 200,
  'body': jsonEncode({
    'data': {
      'resultData': {
        'planRemianFlowInfo': {
          'planRemian': {
            'remainNum': '$remainingMb',
            'sumNum': '100',
            'unit': '03',
          },
        },
      },
    },
  }),
};

Map<String, Object?> _balance(String epoch) => {
  'url': mobileQueryUrl,
  'pageUrl': mobileQueryUrl,
  'stage': 'mobileBalanceRendered',
  'queryEpoch': epoch,
  'status': 200,
  'body': jsonEncode({'source': 'officialRendered', 'balanceText': '12.34元'}),
};

void main() {
  late _FakeWebViewPlatform platform;
  late InAppWebViewPlatform? previousPlatform;
  final oldTime = DateTime.utc(2026, 10, 2, 8);
  final oldSnapshot = CarrierSnapshot(
    carrier: Carrier.mobile,
    status: QueryStatus.success,
    queriedAt: oldTime,
    balanceYuan: 9.87,
    buckets: const [
      TrafficBucket(
        name: '通用流量',
        kind: BucketKind.general,
        remainingBytes: 7 * 1024 * 1024,
        totalBytes: 100 * 1024 * 1024,
        rawUnit: '03',
      ),
    ],
  );
  const channels = [
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    WidgetBridge.channel,
    MethodChannel('cn.liuliang/background_refresh_schedule'),
    MethodChannel('cn.liuliang/notifications'),
    MethodChannel('cn.liuliang/system_surfaces'),
    MethodChannel('com.pichillilorenzo/flutter_inappwebview_webviewfeature'),
  ];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    previousPlatform = InAppWebViewPlatform.instance;
    platform = _FakeWebViewPlatform();
    InAppWebViewPlatform.instance = platform;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'carrier_selection': CarrierSelection.complete([
        Carrier.mobile,
      ]).toStorageString(),
      'connected_mobile': true,
      'snapshot_mobile': jsonEncode(oldSnapshot.toJson()),
      'background_refresh_minutes': 0,
      'reminders': false,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'consumeLaunchRefresh') return false;
        if (call.method == 'deleteAccountProfiles') return true;
        return null;
      });
    }
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    // The public setter rejects null; a fresh unsupported implementation is
    // equivalent to the original absent platform for this isolated test file.
    InAppWebViewPlatform.instance = previousPlatform ?? _FakeWebViewPlatform();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  Future<void> mount(WidgetTester tester) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(const FlowBuddyApp());
    await _drain(tester);
    expect(platform.controller.handlers, contains('trafficResponse'));
    expect(platform.controller.installedEpochs, hasLength(1));
    expect(_snapshot(tester).status, QueryStatus.loading);
  }

  Future<void> succeed(WidgetTester tester, int remainingMb) async {
    final controller = platform.controller;
    final money = controller.emit(_balance(controller.epoch));
    await _drain(tester);
    await money;
    final flow = controller.emit(_flow(controller.epoch, remainingMb));
    await _drain(tester);
    await flow;
    await _drain(tester);
    expect(_snapshot(tester).status, QueryStatus.success);
    expect(_snapshot(tester).generalRemainingBytes, remainingMb * 1024 * 1024);
    expect(_snapshot(tester).balanceYuan, 12.34);
  }

  testWidgets('旧 getUrl 在新轮开始后完成不会覆盖新轮或原记录', (tester) async {
    await mount(tester);
    final controller = platform.controller;
    final oldEpoch = controller.epoch;
    final oldUrl = Completer<WebUri?>();
    controller.urlReads.add(() => oldUrl.future);
    final oldReceive = controller.emit(_flow(oldEpoch, 99));
    await _drain(tester);
    expect(controller.getUrlCalls, 1);

    platform.visit(mobileLoginUrl);
    await _drain(tester);
    expect(_snapshot(tester).status, QueryStatus.authExpired);
    _dashboard(tester).onRefreshAccount!('mobile');
    await _drain(tester);
    final newEpoch = controller.epoch;
    expect(
      newEpoch,
      isNot(oldEpoch),
      reason:
          "state=${_snapshot(tester).status} message=${_snapshot(tester).message} loads=${controller.loadedUrls.length}",
    );
    expect(_snapshot(tester).status, QueryStatus.loading);

    oldUrl.complete(WebUri(mobileQueryUrl));
    await _drain(tester);
    await oldReceive;
    expect(_snapshot(tester).status, QueryStatus.loading);
    expect(_snapshot(tester).queriedAt, oldTime);
    expect(_snapshot(tester).buckets.single.remainingBytes, 7 * 1024 * 1024);
    expect(_snapshot(tester).balanceYuan, 9.87);
    final prefs = await SharedPreferences.getInstance();
    expect(
      CarrierSnapshot.fromJson(
        jsonDecode(prefs.getString('snapshot_mobile')!) as Map<String, dynamic>,
      ).queriedAt,
      oldTime,
    );

    await succeed(tester, 2);
    expect(controller.epoch, newEpoch);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('旧 loadUrl 迟到异常不能结束正在进行的新轮', (tester) async {
    final oldLoad = Completer<void>();
    platform.controller.loads.add(() => oldLoad.future);
    await mount(tester);
    final controller = platform.controller;
    final oldEpoch = controller.epoch;
    expect(controller.loadedUrls, hasLength(1));

    platform.visit(mobileLoginUrl);
    await _drain(tester);
    _dashboard(tester).onRefreshAccount!('mobile');
    await _drain(tester);
    final newEpoch = controller.epoch;
    expect(
      newEpoch,
      isNot(oldEpoch),
      reason:
          "state=${_snapshot(tester).status} message=${_snapshot(tester).message} loads=${controller.loadedUrls.length}",
    );
    expect(controller.loadedUrls, hasLength(2));

    oldLoad.completeError(PlatformException(code: 'late-old-load'));
    await _drain(tester);
    expect(_snapshot(tester).status, QueryStatus.loading);
    expect(_snapshot(tester).queriedAt, oldTime);
    await succeed(tester, 3);
    expect(controller.epoch, newEpoch);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('移动已有流量后第二次 getUrl 失败会结束 loading 且立即可重试', (tester) async {
    await mount(tester);
    final controller = platform.controller;
    final failedEpoch = controller.epoch;
    controller.urlReads.add(() async => WebUri(mobileQueryUrl));
    controller.urlReads.add(
      () => Future<WebUri?>.error(PlatformException(code: 'second-url-failed')),
    );
    final receiving = controller.emit(_flow(failedEpoch, 40));
    await _drain(tester);
    expect(controller.getUrlCalls, 1);
    await tester.pump(const Duration(seconds: 6));
    await _drain(tester);
    await receiving;
    expect(controller.getUrlCalls, 2);
    expect(_snapshot(tester).status, QueryStatus.error);
    expect(_snapshot(tester).message, contains('校验未完成'));
    expect(_snapshot(tester).queriedAt, oldTime);
    expect(_snapshot(tester).balanceYuan, 9.87);
    expect(_snapshot(tester).buckets.single.remainingBytes, 7 * 1024 * 1024);

    _dashboard(tester).onRefreshAccount!('mobile');
    await _drain(tester);
    expect(_snapshot(tester).status, QueryStatus.loading);
    expect(controller.loadedUrls, hasLength(2));
    expect(controller.epoch, isNot(failedEpoch));
    await succeed(tester, 4);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('无轮次的网页错误不终止新查询，但本轮仍按期限退出', (tester) async {
    await mount(tester);
    final controller = platform.controller;
    platform.viewParams!.onReceivedError!(
      InAppWebViewController.fromPlatform(platform: controller),
      WebResourceRequest(url: WebUri(mobileQueryUrl), isForMainFrame: true),
      WebResourceError(
        type: WebResourceErrorType.HOST_LOOKUP,
        description: 'old',
      ),
    );
    await _drain(tester);
    expect(_snapshot(tester).status, QueryStatus.loading);
    await tester.pump(const Duration(seconds: 36));
    await _drain(tester);
    expect(_snapshot(tester).status, QueryStatus.error);
    expect(_snapshot(tester).queriedAt, oldTime);
    _dashboard(tester).onRefreshAccount!('mobile');
    await _drain(tester);
    await succeed(tester, 4);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  for (final scriptFails in [false, true]) {
    testWidgets('广电登录页${scriptFails ? '脚本失败' : '删除超时'}仍退出查询且可重试', (
      tester,
    ) async {
      final previousStorage = FlutterSecureStoragePlatform.instance;
      FlutterSecureStoragePlatform.instance =
          MethodChannelFlutterSecureStorage();
      addTearDown(
        () => FlutterSecureStoragePlatform.instance = previousStorage,
      );
      final neverDelete = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channels.first, (call) async {
            if (call.method == 'delete') return neverDelete.future;
            return null;
          });
      final oldBroadnet = oldSnapshot.copyWith(carrier: Carrier.broadnet);
      SharedPreferences.setMockInitialValues({
        'carrier_selection': CarrierSelection.complete([
          Carrier.broadnet,
        ]).toStorageString(),
        'connected_broadnet': true,
        'snapshot_broadnet': jsonEncode(oldBroadnet.toJson()),
        'background_refresh_minutes': 0,
        'reminders': false,
      });
      await mount(tester);
      final controller = platform.controller;
      controller.failRestoreRemoval = scriptFails;
      controller.currentUrl = WebUri(broadnetLoginUrl);
      platform.viewParams!.onLoadStop!(
        InAppWebViewController.fromPlatform(platform: controller),
        WebUri(broadnetLoginUrl),
      );
      await _drain(tester);
      expect(_snapshot(tester).status, QueryStatus.authExpired);
      expect(_snapshot(tester).queriedAt, oldTime);
      await tester.pump(const Duration(seconds: 4));
      await _drain(tester);
      expect(tester.takeException(), isNull);
      _dashboard(tester).onRefreshAccount!('broadnet');
      await _drain(tester);
      expect(_snapshot(tester).status, QueryStatus.loading);
      expect(controller.loadedUrls, hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      neverDelete.complete();
    });
  }

  testWidgets('清理停止网页超时会保留门禁并返回可重试提示', (tester) async {
    await mount(tester);
    final neverStop = Completer<void>();
    platform.controller.stopResult = neverStop.future;
    _dashboard(tester).onSettings();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('清除号码连接与本地数据'));
    await tester.tap(find.text('清除号码连接与本地数据'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('清除').last);
    await _drain(tester);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'account_profiles_cleanup_pending',
      ),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 3));
    for (var i = 0; i < 12; i++) {
      await _drain(tester);
    }
    expect(find.text('部分网页登录资料还没清除'), findsOneWidget);
    expect(_snapshot(tester).status, QueryStatus.notConnected);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    neverStop.complete();
  });
}
