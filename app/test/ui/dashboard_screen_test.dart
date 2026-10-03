import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/ui/carrier_selection_screen.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';
import 'package:liuliang_app/ui/resort_theme.dart';
import 'package:liuliang_app/ui/system_surfaces_settings.dart';
import 'package:liuliang_app/services/system_surfaces.dart';

const _previewBoundaryKey = ValueKey<String>('dashboard-preview');
const _broadnetPreviewBoundaryKey = ValueKey<String>(
  'broadnet-summary-preview',
);
const _gib = 1024 * 1024 * 1024;

void main() {
  setUpAll(_loadPreviewChineseFont);

  testWidgets('生成通知栏与快捷设置组件DEMO截图', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemSurfaces.channel,
      (_) async => {
        'notificationEnabled': true,
        'tileEnabled': true,
        'notificationsAllowed': true,
        'tileAddSupported': true,
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemSurfaces.channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'PreviewChinese',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF75A795)),
        ),
        home: RepaintBoundary(
          key: _previewBoundaryKey,
          child: Scaffold(
            backgroundColor: const Color(0xFFFFFBF5),
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '照顾好你的流量',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'DEMO · 设置组件示例，非系统通知栏截图',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 24),
                      SystemSurfacesSettings(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _writeScreenshot(tester, 'android-system-surfaces-settings-demo.png');
  });

  testWidgets('通话短信逐项展示未知真零超额与原查询时间', (tester) async {
    _configureViewport(tester, const Size(320, 1200));
    await tester.pumpWidget(
      _host(
        snapshots: [_serviceDemo(QueryStatus.authExpired)],
        demo: false,
        textScale: 1.4,
        selectedCarriers: const {Carrier.mobile},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('剩余 120 分钟'), findsOneWidget);
    expect(find.text('剩余 0 条'), findsOneWidget);
    expect(find.text('剩余待确认'), findsOneWidget);
    expect(find.text('超出 2 条'), findsOneWidget);
    expect(find.textContaining('显示上次查询'), findsNothing);
    expect(find.textContaining('以下为上次查询'), findsOneWidget);
    expect(find.textContaining('10:20'), findsOneWidget);
    expect(find.text('仅限本地拨打'), findsOneWidget);
    expect(find.text('剩余 150 分钟'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('四卡通话短信未知状态在窄屏无溢出', (tester) async {
    _configureViewport(tester, const Size(320, 1800));
    await tester.pumpWidget(
      _host(
        snapshots: const [],
        demo: false,
        textScale: 1.4,
        selectedCarriers: Carrier.values.toSet(),
      ),
    );
    await tester.pumpAndSettle();
    for (final carrier in Carrier.values) {
      final details = find.byKey(ValueKey('account-details-${carrier.name}'));
      await tester.ensureVisible(details);
      await tester.tap(
        find.descendant(of: details, matching: find.text('套餐与通话明细')),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('等待连接'), findsNWidgets(8));
    expect(find.text('剩余 0 条'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('仅通话短信缓存保留时间且估算不限量不混淆', (tester) async {
    _configureViewport(tester, const Size(390, 1200));
    await tester.pumpWidget(
      _host(
        snapshots: [
          CarrierSnapshot(
            carrier: Carrier.telecom,
            status: QueryStatus.error,
            queriedAt: DateTime(2026, 10, 1, 10, 20),
            allowances: const [
              ServiceAllowance(
                kind: AllowanceKind.voice,
                label: '国内语音',
                remaining: 18.5,
                isEstimated: true,
              ),
              ServiceAllowance(
                kind: AllowanceKind.voice,
                label: '指定亲情号',
                isUnlimited: true,
              ),
              ServiceAllowance(
                kind: AllowanceKind.sms,
                label: '短信资源',
                rawUnit: '次',
                remaining: 19,
                total: 20,
                isEstimated: true,
              ),
            ],
          ),
        ],
        demo: false,
        textScale: 1,
        selectedCarriers: const {Carrier.telecom},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('约剩余 18.5 分钟'), findsOneWidget);
    expect(find.text('不限量'), findsOneWidget);
    expect(find.text('约剩余 19 次'), findsOneWidget);
    expect(find.text('共 20 次'), findsOneWidget);
    expect(find.textContaining('显示上次查询'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('生成流量通话短信实际组件DEMO截图', (tester) async {
    _configureViewport(tester, const Size(390, 1520));
    await tester.pumpWidget(
      _host(
        snapshots: [_serviceDemo(QueryStatus.success)],
        demo: true,
        textScale: 1,
        selectedCarriers: const {Carrier.mobile},
        previewBoundaryKey: _previewBoundaryKey,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _writeScreenshot(tester, 'dashboard-voice-sms-demo.png');
  });

  testWidgets('未连接与演示数据在小屏和常见屏幕宽度无布局异常', (tester) async {
    _configureViewport(tester, const Size(320, 640));
    for (final size in const [Size(320, 640), Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        _host(snapshots: const [], demo: false, textScale: 1.4),
      );
      await tester.pumpAndSettle();

      expect(find.text('所选运营商，一眼看清'), findsOneWidget);
      expect(find.text('连接后查看'), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _host(snapshots: _demoSnapshots(), demo: true, textScale: 1.4),
      );
      await tester.pumpAndSettle();

      expect(find.text('界面演示 · 非真实流量'), findsOneWidget);
      expect(find.text('移动卡'), findsOneWidget);
      expect(find.text('广电卡'), findsOneWidget);
      expect(find.text('SIM 1'), findsNothing);
      expect(find.text('SIM 2'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('卡片按钮调用对应回调', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    final calls = _CallbackCalls();
    await tester.pumpWidget(
      _host(
        snapshots: const [],
        demo: false,
        textScale: 1.0,
        calls: calls,
        onAddWidget: () => calls.widgetAdditions++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('连接号码').first);
    await tester.tap(find.text('连接号码').first);
    await tester.pump();
    expect(calls.connected, [Carrier.mobile]);

    await tester.ensureVisible(find.text('连接号码').last);
    await tester.tap(find.text('连接号码').last);
    await tester.pump();
    expect(calls.connected, [Carrier.mobile, Carrier.broadnet]);

    await tester.ensureVisible(find.text('刷新所选'));
    await tester.tap(find.text('刷新所选'));
    await tester.pump();
    expect(calls.refreshAll, 1);

    await tester.ensureVisible(find.text('刷新').first);
    await tester.tap(find.text('刷新').first);
    await tester.pump();
    expect(calls.refreshed, [Carrier.mobile]);

    await tester.ensureVisible(find.text('提醒设置'));
    await tester.tap(find.text('提醒设置'));
    await tester.pump();
    await tester.ensureVisible(find.text('关于与说明'));
    await tester.tap(find.text('关于与说明'));
    await tester.pump();
    await tester.ensureVisible(find.text('添加桌面卡片'));
    await tester.tap(find.text('添加桌面卡片'));
    await tester.pump();
    expect(calls.settings, 1);
    expect(calls.about, 1);
    expect(calls.widgetAdditions, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('温泉主题卡片显示账号身份、分类余量并支持编辑与角色短句', (tester) async {
    _configureViewport(tester, const Size(320, 1280));
    final account = CarrierAccount(
      id: 'mobile',
      carrier: Carrier.mobile,
      label: '中国移动 1',
      note: '家庭上网卡',
      phoneNumber: '13812345678',
    );
    final snapshot = CarrierSnapshot(
      carrier: Carrier.mobile,
      status: QueryStatus.success,
      queriedAt: DateTime(2026, 10, 1, 10, 20),
      phoneMasked: '13812345678',
      balanceYuan: 26.5,
      buckets: const [
        TrafficBucket(
          name: '通用流量',
          kind: BucketKind.general,
          remainingBytes: 5 * _gib,
          totalBytes: 20 * _gib,
          rawUnit: 'GB',
        ),
        TrafficBucket(
          name: '视频专属流量',
          kind: BucketKind.directed,
          remainingBytes: 2 * _gib,
          rawUnit: 'GB',
        ),
        TrafficBucket(
          name: '活动流量',
          kind: BucketKind.unknown,
          remainingBytes: _gib,
          rawUnit: 'GB',
        ),
      ],
      allowances: [
        ServiceAllowance(
          kind: AllowanceKind.voice,
          label: '国内通话',
          remaining: 90,
        ),
        ServiceAllowance(kind: AllowanceKind.sms, label: '国内短信', remaining: 12),
      ],
    );
    final edited = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.4),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: DashboardScreen(
          snapshots: [snapshot],
          selectedCarriers: const {Carrier.mobile},
          accountEntries: [DashboardAccountEntry(account, snapshot)],
          thresholdGb: 2,
          onConnect: (_) {},
          onRefresh: (_) {},
          onRefreshAll: () {},
          onSettings: () {},
          onAbout: () {},
          onEditAccount: edited.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account-card-mobile')),
        matching: find.text('家庭上网卡'),
      ),
      findsOneWidget,
    );
    expect(find.text('138****5678'), findsOneWidget);
    expect(find.text('13812345678'), findsNothing);
    expect(find.text('¥26.50'), findsOneWidget);
    expect(find.text('话费余额'), findsOneWidget);
    expect(find.text('定向流量'), findsOneWidget);
    expect(find.text('用途未知'), findsOneWidget);
    expect(find.text('国内通话'), findsOneWidget);
    expect(find.text('国内短信'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ResortMiniScene)).height,
      lessThanOrEqualTo(120),
    );

    await tester.tap(find.byTooltip('编辑备注与号码'));
    await tester.pump();
    expect(edited, ['mobile']);
    await tester.tap(find.byType(ResortMascotSticker).first);
    await tester.pumpAndSettle();
    expect(find.text('查询一下，今天也安心出发。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('不支持桌面卡片的平台显示安卓说明并禁用入口', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      _host(
        snapshots: const [],
        demo: true,
        textScale: 1.0,
        widgetSupported: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('请在安卓手机或 iPhone 添加'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '添加桌面卡片'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同运营商两张卡分开展示且明确不限量', (tester) async {
    _configureViewport(tester, const Size(390, 1220));
    final accounts = CarrierAccounts.fromSelection(
      CarrierSelection.complete([Carrier.mobile]),
    ).addSecond(Carrier.mobile).accounts;
    final first = CarrierSnapshot(
      carrier: Carrier.mobile,
      status: QueryStatus.success,
      queriedAt: DateTime(2026, 10, 1, 10),
      buckets: const [
        TrafficBucket(
          name: '通用流量',
          kind: BucketKind.general,
          remainingBytes: 5 * _gib,
        ),
      ],
    );
    final second = CarrierSnapshot(
      carrier: Carrier.mobile,
      status: QueryStatus.success,
      queriedAt: DateTime(2026, 10, 1, 10),
      message: '达量后可能限速，具体以官网规则为准',
      buckets: const [
        TrafficBucket(
          name: '畅享套餐',
          kind: BucketKind.general,
          isUnlimited: true,
        ),
      ],
    );
    final connected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'PreviewChinese'),
        builder: (context, child) =>
            RepaintBoundary(key: _previewBoundaryKey, child: child!),
        home: DashboardScreen(
          snapshots: [first],
          selectedCarriers: const {Carrier.mobile},
          demo: true,
          accountEntries: [
            DashboardAccountEntry(accounts[0], first),
            DashboardAccountEntry(accounts[1], second),
          ],
          thresholdGb: 2,
          onConnect: (_) {},
          onRefresh: (_) {},
          onConnectAccount: connected.add,
          onRefreshAccount: (_) {},
          onRefreshAll: () {},
          onSettings: () {},
          onAbout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('中国移动 1'), findsWidgets);
    expect(find.text('中国移动 2'), findsWidgets);
    expect(find.text('含不限量套餐'), findsOneWidget);
    expect(find.text('中国移动 2'), findsNWidgets(3));
    expect(find.text('不限量'), findsWidgets);
    expect(find.textContaining('达量后可能限速'), findsOneWidget);
    await _writeScreenshot(tester, 'dashboard-two-mobile-unlimited-demo.png');
    await tester.ensureVisible(find.text('连接号码').last);
    await tester.tap(find.text('连接号码').last);
    expect(connected, ['mobile_2']);
  });

  testWidgets('四个同家账号紧凑展示并保存真实渲染演示截图', (tester) async {
    _configureViewport(tester, const Size(390, 2200));
    final selection = CarrierSelection.complete([Carrier.mobile]);
    final accounts = CarrierAccounts.fromSelection(
      selection,
    ).withCount(Carrier.mobile, 4);
    final entries = [
      for (var index = 0; index < accounts.accounts.length; index++)
        DashboardAccountEntry(
          accounts.accounts[index],
          _snapshot(
            Carrier.mobile,
            QueryStatus.success,
            remainingGiB: 5.0 + index * 3,
            totalGiB: 30,
          ),
        ),
    ];
    final refreshed = <String>[];
    await tester.pumpWidget(
      _host(
        snapshots: [entries.first.snapshot!],
        selectedCarriers: const {Carrier.mobile},
        accountEntries: entries,
        onRefreshAccount: refreshed.add,
        demo: true,
        textScale: 1,
        previewBoundaryKey: _previewBoundaryKey,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('界面演示 · 非真实流量'), findsOneWidget);
    expect(find.text('4 个号码 · 可分别查询'), findsOneWidget);
    for (final account in accounts.accounts) {
      expect(
        find.byKey(ValueKey('account-card-${account.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('account-details-${account.id}')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
    await _writeScreenshot(tester, 'dashboard-four-accounts-demo.png');
    final fourth = find.byKey(const ValueKey('account-card-mobile_4'));
    final refresh = find.descendant(
      of: fourth,
      matching: find.widgetWithText(OutlinedButton, '刷新'),
    );
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    expect(refreshed, ['mobile_4']);
    final details = find.byKey(const ValueKey('account-details-mobile_4'));
    await tester.ensureVisible(details);
    await tester.tap(
      find.descendant(of: details, matching: find.text('套餐与通话明细')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: details, matching: find.text('通话余量')),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('三四个同家账号在320像素大字屏可逐卡操作', (tester) async {
    _configureViewport(tester, const Size(320, 640));
    for (final count in [3, 4]) {
      final accounts = CarrierAccounts.fromSelection(
        CarrierSelection.complete([Carrier.mobile]),
      ).withCount(Carrier.mobile, count);
      final connected = <String>[];
      await tester.pumpWidget(
        _host(
          snapshots: const [],
          selectedCarriers: const {Carrier.mobile},
          accountEntries: [
            for (final account in accounts.accounts)
              DashboardAccountEntry(account, null),
          ],
          onConnectAccount: connected.add,
          demo: true,
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      for (final account in accounts.accounts) {
        final card = find.byKey(ValueKey('account-card-${account.id}'));
        final button = find.descendant(
          of: card,
          matching: find.widgetWithText(FilledButton, '连接号码'),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        expect(tester.takeException(), isNull);
      }
      expect(
        connected,
        accounts.accounts.map((account) => account.id).toList(),
      );
      expect(find.text('$count 个号码 · 可分别查询'), findsOneWidget);
    }
  });

  testWidgets('缓存与 error 状态可查看旧值但不会进入汇总', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    final snapshots = [
      _snapshot(
        Carrier.mobile,
        QueryStatus.error,
        remainingGiB: 3,
        totalGiB: 20,
        message: '本次查询失败',
      ),
      _snapshot(
        Carrier.broadnet,
        QueryStatus.authExpired,
        remainingGiB: 7,
        totalGiB: 15,
      ),
    ];
    await tester.pumpWidget(
      _host(snapshots: snapshots, demo: false, textScale: 1.4),
    );
    await tester.pumpAndSettle();

    expect(find.text('所选运营商，一眼看清'), findsOneWidget);
    expect(find.text('通用流量总览'), findsNothing);
    expect(find.textContaining('显示上次查询'), findsOneWidget);
    expect(find.textContaining('登录已过期 · 以下为上次查询'), findsOneWidget);
    expect(find.text('3.0'), findsOneWidget);
    expect(find.text('7.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载状态在小屏无布局异常', (tester) async {
    _configureViewport(tester, const Size(320, 640));
    await tester.pumpWidget(
      _host(
        snapshots: [
          const CarrierSnapshot(
            carrier: Carrier.mobile,
            status: QueryStatus.loading,
          ),
          const CarrierSnapshot(
            carrier: Carrier.broadnet,
            status: QueryStatus.notConnected,
          ),
        ],
        demo: false,
        textScale: 1.4,
      ),
    );
    await tester.pump();

    expect(find.text('查询中'), findsOneWidget);
    expect(find.text('未连接'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单家运营商只显示所选卡片并按该卡数据汇总', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      _host(
        snapshots: _demoSnapshots(),
        selectedCarriers: const {Carrier.mobile},
        demo: true,
        textScale: 1.0,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('中国移动'), findsWidgets);
    expect(find.text('中国广电'), findsNothing);
    expect(find.text('通用流量总览'), findsOneWidget);
    expect(find.text('12.4'), findsNWidgets(2));
    expect(find.textContaining('中国移动的通用流量剩余'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单家广电可显示套餐汇总且不套用通用提醒', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      _host(
        snapshots: [
          _broadnetPackageSnapshot([30, 113]),
        ],
        selectedCarriers: const {Carrier.broadnet},
        demo: true,
        textScale: 1.0,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('中国移动'), findsNothing);
    expect(find.text('中国广电'), findsWidgets);
    expect(find.text('套餐明细合计'), findsNWidgets(2));
    expect(find.text('143'), findsNWidgets(2));
    expect(find.text('适用范围以各套餐规则为准'), findsOneWidget);
    expect(find.textContaining('提醒线'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('联通单条已确认单位的unknown余额显示为套餐余量，不参与通用汇总', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      _host(
        snapshots: [_unicomDemoSnapshot()],
        selectedCarriers: const {Carrier.unicom},
        demo: true,
        textScale: 1.0,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('中国联通'), findsWidgets);
    expect(find.text('套餐余量'), findsOneWidget);
    expect(find.text('18.0'), findsOneWidget);
    expect(find.text('通用流量总览'), findsNothing);
    expect(find.textContaining('提醒线'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('电信套餐显示官网舍入估算并明确不计入通用流量', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      _host(
        snapshots: [_telecomDemoSnapshot()],
        selectedCarriers: const {Carrier.telecom},
        demo: true,
        textScale: 1.0,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('中国电信'), findsWidgets);
    expect(find.text('套餐估算余量'), findsNWidgets(2));
    expect(find.text('18.0'), findsNWidgets(2));
    expect(find.text('约'), findsNWidgets(2));
    expect(find.textContaining('舍入'), findsNWidgets(2));
    expect(find.text('通用流量总览'), findsNothing);
    expect(find.textContaining('提醒线'), findsNothing);
    expect(find.text('约 18.0 GB'), findsNWidgets(2));
    await tester.ensureVisible(find.text('约 18.0 GB').last);
    await tester.tap(find.text('约 18.0 GB').last);
    await tester.pumpAndSettle();
    expect(find.text('剩余流量（估算）'), findsOneWidget);
    expect(find.text('约 18.0 GB'), findsNWidgets(3));
    expect(find.textContaining('舍入差异'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('电信其他类别显示已读部分估算与待确认项且详情保留说明', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      _host(
        snapshots: [_telecomPartialDemoSnapshot()],
        selectedCarriers: const {Carrier.telecom},
        demo: true,
        textScale: 1.0,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('套餐估算余量'), findsNothing);
    expect(find.text('部分同步'), findsOneWidget);
    expect(find.text('已同步'), findsNothing);
    expect(find.text('已读取 1 项 · 1 项待确认'), findsOneWidget);
    expect(find.text('余额待确认'), findsNothing);
    expect(find.text('通话余量'), findsNothing);
    expect(find.text('短信余量'), findsNothing);
    expect(find.text('部分套餐余量待确认，详见明细'), findsNothing);
    expect(find.text('已读约18.0GB\n1项待确认'), findsOneWidget);
    expect(find.textContaining('其他流量已读部分约 18.0 GB，另有 1 项待确认'), findsOneWidget);
    expect(find.text('套餐用途待确认，可点明细设置'), findsNothing);
    expect(find.textContaining('用途待确认'), findsNothing);
    expect(find.text('其他流量只显示已确认子项的估算；未计入项待确认，完整套餐合计待确认。'), findsOneWidget);
    expect(find.text('约 18.0 GB'), findsOneWidget);
    expect(find.text('剩余额无法确认（单位待确认）'), findsOneWidget);

    await tester.ensureVisible(find.text('约 18.0 GB'));
    await tester.tap(find.text('约 18.0 GB'));
    await tester.pumpAndSettle();
    expect(find.text('剩余流量（估算）'), findsOneWidget);
    expect(find.text('约 18.0 GB'), findsNWidgets(2));
    expect(find.textContaining('舍入差异'), findsOneWidget);
    expect(find.textContaining('不展示估算余额'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('电信定向与其他流量分组可分别估算，分类弹窗使用其他流量名称并生成预览', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    final snapshot = CarrierSnapshot(
      carrier: Carrier.telecom,
      status: QueryStatus.success,
      queriedAt: DateTime(2026, 10, 2, 15),
      message: '部分官网明细无法估算，暂不显示合计；请核对官方查询页',
      buckets: const [
        TrafficBucket(
          name: '定向视频流量',
          kind: BucketKind.directed,
          remainingBytes: 2 * _gib,
          totalBytes: 8 * _gib,
          rawUnit: 'GB',
        ),
        TrafficBucket(
          name: '定向视频流量',
          kind: BucketKind.directed,
          remainingBytes: 3 * _gib,
          totalBytes: 8 * _gib,
          rawUnit: 'GB',
        ),
        TrafficBucket(
          name: '国内上网流量含12GB',
          kind: BucketKind.unknown,
          remainingBytes: 4 * _gib,
          totalBytes: 12 * _gib,
          rawUnit: 'GB',
        ),
        TrafficBucket(
          name: '需核对的补充套餐',
          kind: BucketKind.general,
          manualKind: BucketKind.general,
          rawRemaining: '待确认',
        ),
      ],
    );
    await tester.pumpWidget(
      _host(
        snapshots: [snapshot],
        selectedCarriers: const {Carrier.telecom},
        demo: true,
        textScale: 1,
        previewBoundaryKey: _previewBoundaryKey,
        onClassifyBucket: (_, _, _) async => true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('其他流量'), findsOneWidget);
    expect(find.text('定向流量'), findsOneWidget);
    expect(find.text('约 5.0 GB'), findsOneWidget);
    expect(find.text('约 4.0 GB'), findsAtLeastNWidgets(1));
    expect(find.text('待确认'), findsWidgets);
    expect(find.textContaining('用途未知'), findsNothing);
    expect(find.textContaining('用途待确认'), findsNothing);
    expect(find.text('余额待确认'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('国内上网流量含12GB'));
    await tester.tap(find.text('国内上网流量含12GB'));
    await tester.pumpAndSettle();
    expect(find.text('流量分类'), findsOneWidget);
    expect(find.text('当前：其他流量'), findsOneWidget);
    expect(find.text('当前：用途未知'), findsNothing);
    expect(find.text('用途分类'), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(390, 1100);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 2000),
    );
    await tester.pumpAndSettle();
    expect(find.text('界面演示 · 非真实流量'), findsOneWidget);
    await _writeScreenshot(
      tester,
      'telecom-directed-other-partial-preview.png',
    );
  });

  testWidgets('电信仅有通话有效时不冒称流量部分同步', (tester) async {
    _configureViewport(tester, const Size(320, 640));
    await tester.pumpWidget(
      _host(
        snapshots: [
          CarrierSnapshot(
            carrier: Carrier.telecom,
            status: QueryStatus.success,
            queriedAt: DateTime(2026, 10, 2, 15),
            buckets: const [
              TrafficBucket(name: '待确认套餐', kind: BucketKind.unknown),
            ],
            allowances: const [
              ServiceAllowance(
                kind: AllowanceKind.voice,
                label: '通话',
                remaining: 100,
              ),
            ],
          ),
        ],
        selectedCarriers: const {Carrier.telecom},
        demo: false,
        textScale: 1.4,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('部分同步'), findsNothing);
    expect(find.textContaining('已读取 0 项'), findsNothing);
    expect(find.text('余额待确认'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未备注号码只保留账号标记，已知号码继续脱敏显示', (tester) async {
    _configureViewport(tester, const Size(320, 640));
    await tester.pumpWidget(
      _host(
        snapshots: [
          const CarrierSnapshot(
            carrier: Carrier.telecom,
            status: QueryStatus.notConnected,
          ),
        ],
        selectedCarriers: const {Carrier.telecom},
        demo: false,
        textScale: 1.4,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('号码未备注'), findsNothing);
    expect(find.text('中国电信'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _host(
        snapshots: [_telecomPartialDemoSnapshot()],
        selectedCarriers: const {Carrier.telecom},
        demo: false,
        textScale: 1.4,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('189****7612'), findsOneWidget);
    expect(find.text('已读取 1 项 · 1 项待确认'), findsOneWidget);
    expect(find.text('已读约18.0GB\n1项待确认'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('套餐每页最多五组，翻页后仍能分类并可收起', (tester) async {
    _configureViewport(tester, const Size(320, 640));
    final snapshot = CarrierSnapshot(
      carrier: Carrier.telecom,
      status: QueryStatus.success,
      queriedAt: DateTime(2026, 10, 2, 15),
      buckets: [
        for (var index = 1; index <= 12; index++)
          TrafficBucket(
            name: '分页套餐 $index',
            kind: BucketKind.unknown,
            remainingBytes: index == 12 ? null : index * _gib,
            totalBytes: 20 * _gib,
            rawUnit: index == 12 ? null : 'B',
          ),
      ],
    );
    String? savedName;
    await tester.pumpWidget(
      _host(
        snapshots: [snapshot],
        selectedCarriers: const {Carrier.telecom},
        demo: false,
        textScale: 1.4,
        onClassifyBucket: (_, bucket, _) async {
          savedName = bucket.name;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('分页套餐 3'), findsOneWidget);
    expect(find.text('分页套餐 4'), findsNothing);
    await tester.ensureVisible(find.text('查看全部 12 项'));
    await tester.tap(find.text('查看全部 12 项'));
    await tester.pumpAndSettle();
    expect(find.text('分页套餐 5'), findsOneWidget);
    expect(find.text('分页套餐 6'), findsNothing);
    expect(find.text('第 1 / 3 页'), findsOneWidget);

    await tester.ensureVisible(find.text('下一页'));
    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();
    expect(find.text('分页套餐 1'), findsNothing);
    expect(find.text('分页套餐 6'), findsOneWidget);
    expect(find.text('分页套餐 10'), findsOneWidget);
    expect(find.text('分页套餐 11'), findsNothing);
    await tester.ensureVisible(find.text('分页套餐 6'));
    await tester.tap(find.text('分页套餐 6'));
    await tester.pumpAndSettle();
    expect(find.text('流量分类'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('bucket-classification-general')),
    );
    await tester.tap(
      find.byKey(const ValueKey('bucket-classification-general')),
    );
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(savedName, '分页套餐 6');

    await tester.ensureVisible(find.text('下一页'));
    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();
    expect(find.text('分页套餐 11'), findsOneWidget);
    expect(find.text('分页套餐 12'), findsOneWidget);
    expect(find.text('分页套餐 10'), findsNothing);
    expect(find.text('第 3 / 3 页'), findsOneWidget);
    await tester.ensureVisible(find.text('上一页'));
    await tester.tap(find.text('上一页'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 / 3 页'), findsOneWidget);
    await tester.ensureVisible(find.text('收起套餐明细'));
    await tester.tap(find.text('收起套餐明细'));
    await tester.pumpAndSettle();
    expect(find.text('分页套餐 3'), findsOneWidget);
    expect(find.text('分页套餐 4'), findsNothing);
    expect(find.text('上一页'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同名不同余量只折叠展示，组弹窗保留每项及详情', (tester) async {
    _configureViewport(tester, const Size(320, 640));
    const longName = '国内基础流量同名赠送套餐完整名称及适用地区说明请逐项核对';
    final snapshot = CarrierSnapshot(
      carrier: Carrier.telecom,
      status: QueryStatus.success,
      queriedAt: DateTime(2026, 10, 2, 15),
      buckets: [
        for (var index = 1; index <= 8; index++)
          TrafficBucket(
            name: index == 2 ? ' $longName ' : longName,
            kind: BucketKind.unknown,
            remainingBytes: index * _gib,
            totalBytes: 10 * _gib,
            rawUnit: 'B',
          ),
        const TrafficBucket(
          name: '$longName（省内）',
          kind: BucketKind.unknown,
          rawRemaining: '待确认',
        ),
      ],
    );
    await tester.pumpWidget(
      _host(
        snapshots: [snapshot],
        selectedCarriers: const {Carrier.telecom},
        demo: false,
        textScale: 1.4,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('合并约 36.0 GB'), findsOneWidget);
    expect(find.text('共 8 项'), findsNothing);
    expect(find.text('已读取 8 项 · 1 项待确认'), findsOneWidget);
    expect(find.text('$longName（省内）'), findsOneWidget);
    expect(find.text('查看全部 9 项'), findsNothing);
    expect(find.text('约 1.0 GB'), findsNothing);
    await tester.ensureVisible(find.text('合并约 36.0 GB'));
    await tester.tap(find.text('合并约 36.0 GB'));
    await tester.pumpAndSettle();
    expect(find.textContaining('合并估算：约 36.0 GB'), findsOneWidget);
    expect(find.textContaining('来自 8 个同名子项'), findsOneWidget);
    expect(find.text('共 8 项'), findsNothing);
    expect(find.text('约 1.0 GB'), findsOneWidget);
    await tester.tap(find.text('约 1.0 GB'));
    await tester.pumpAndSettle();
    expect(find.text('剩余流量（估算）'), findsOneWidget);
    expect(find.text('约 1.0 GB'), findsNWidgets(2));
    await tester.ensureVisible(find.text('知道了'));
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    final dialogList = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(ListView),
    );
    await tester.scrollUntilVisible(
      find.text('第 8 项'),
      150,
      scrollable: find.descendant(
        of: dialogList,
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('约 8.0 GB'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('合并约 36.0 GB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('生成电信多项部分同步分组真实组件预览', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    final snapshot = CarrierSnapshot(
      carrier: Carrier.telecom,
      status: QueryStatus.success,
      queriedAt: DateTime(2026, 10, 2, 15),
      message: '部分官网明细无法估算，暂不显示合计；请核对官方查询页',
      buckets: [
        for (var index = 0; index < 24; index++)
          TrafficBucket(
            name: index < 8
                ? '基础套餐流量'
                : index < 16
                ? '长期赠送流量包'
                : index < 23
                ? '专属应用流量'
                : '待确认套餐',
            kind: BucketKind.unknown,
            remainingBytes: index == 23 ? null : (index + 1) * _gib,
            totalBytes: 30 * _gib,
            rawUnit: index == 23 ? null : 'B',
          ),
      ],
    );
    await tester.pumpWidget(
      _host(
        snapshots: [snapshot],
        selectedCarriers: const {Carrier.telecom},
        demo: true,
        textScale: 1,
        previewBoundaryKey: _previewBoundaryKey,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('界面演示 · 非真实流量'), findsOneWidget);
    expect(find.text('已读取 23 项 · 1 项待确认'), findsOneWidget);
    expect(find.text('已读约276GB\n1项待确认'), findsOneWidget);
    expect(find.text('合并约 36.0 GB'), findsOneWidget);
    expect(find.text('合并约 100 GB'), findsOneWidget);
    expect(find.text('合并约 140 GB'), findsOneWidget);
    expect(find.text('查看全部 4 项'), findsOneWidget);
    expect(find.text('查看全部 24 项'), findsNothing);
    expect(find.textContaining('共 8 项'), findsNothing);
    expect(find.textContaining('共 7 项'), findsNothing);
    expect(find.text('已同步'), findsNothing);
    expect(find.text('号码未备注'), findsNothing);
    expect(tester.takeException(), isNull);
    await _writeScreenshot(tester, 'telecom-partial-preview.png');
  });

  testWidgets('四家组合在窄屏可滚动显示全部选中运营商', (tester) async {
    _configureViewport(tester, const Size(320, 640));
    await tester.pumpWidget(
      _host(
        snapshots: const [],
        selectedCarriers: Carrier.values.toSet(),
        demo: true,
        textScale: 1.4,
      ),
    );
    await tester.pumpAndSettle();

    for (final carrier in Carrier.values) {
      expect(find.text(carrier.label), findsWidgets);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('可以从首页进入运营商管理选择页', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    var manageCalls = 0;
    await tester.pumpWidget(
      _host(
        snapshots: const [],
        selectedCarriers: const {Carrier.mobile},
        demo: false,
        textScale: 1.0,
        onManageCarriers: () => manageCalls++,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('运营商设置'));
    await tester.tap(find.text('运营商设置'));
    await tester.pump();

    expect(manageCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('广电 unknown 套餐大字主位合计，明细可展开并查看完整名称', (tester) async {
    _configureViewport(tester, const Size(320, 640));
    final packages = _broadnetPackageSnapshot([30, 113, 20, 4, 2]);
    for (final size in const [Size(320, 640), Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        _host(
          snapshots: [
            const CarrierSnapshot(
              carrier: Carrier.mobile,
              status: QueryStatus.notConnected,
            ),
            packages,
          ],
          demo: true,
          textScale: 1.4,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('套餐明细合计'), findsOneWidget);
      expect(find.text('169'), findsOneWidget);
      expect(find.textContaining('适用范围以各套餐规则为准'), findsOneWidget);
      expect(find.text('查看全部 5 项'), findsOneWidget);
      expect(find.text('所选运营商，一眼看清'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.ensureVisible(find.text('查看全部 5 项'));
    await tester.tap(find.text('查看全部 5 项'));
    await tester.pumpAndSettle();
    const longName = '视频专属流量套餐明细第五项完整名称';
    expect(find.text(longName), findsOneWidget);

    await tester.ensureVisible(find.text(longName));
    await tester.tap(find.text(longName));
    await tester.pumpAndSettle();
    expect(find.text(longName), findsNWidgets(2));
    expect(find.text('剩余流量'), findsOneWidget);
    expect(find.text('套餐总量'), findsOneWidget);
    expect(find.text('4.0 GB'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('生成含演示提示的完整中文预览截图', (tester) async {
    _configureViewport(tester, const Size(390, 1360));
    await tester.pumpWidget(
      _host(
        snapshots: _demoSnapshots(),
        demo: true,
        textScale: 1.15,
        onAddWidget: () {},
        previewBoundaryKey: _previewBoundaryKey,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('界面演示 · 非真实流量'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_previewBoundaryKey),
    );
    final output = _previewFile();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await output.parent.create(recursive: true);
      await output.writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
    expect(output.existsSync(), isTrue);
    expect(output.lengthSync(), greaterThan(10_000));
  });

  testWidgets('生成广电套餐明细合计演示截图', (tester) async {
    _configureViewport(tester, const Size(390, 1360));
    await tester.pumpWidget(
      _host(
        snapshots: [
          const CarrierSnapshot(
            carrier: Carrier.mobile,
            status: QueryStatus.notConnected,
          ),
          _broadnetPackageSnapshot([30, 113]),
        ],
        demo: true,
        textScale: 1.15,
        onAddWidget: () {},
        previewBoundaryKey: _broadnetPreviewBoundaryKey,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('界面演示 · 非真实流量'), findsOneWidget);
    expect(find.text('套餐明细合计'), findsOneWidget);
    expect(find.text('143'), findsOneWidget);
    expect(find.textContaining('适用范围以各套餐规则为准'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_broadnetPreviewBoundaryKey),
    );
    final output = _previewFile('broadnet-summary-preview.png');
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await output.parent.create(recursive: true);
      await output.writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
    expect(output.existsSync(), isTrue);
    expect(output.lengthSync(), greaterThan(10_000));
  });

  testWidgets('导出首次选择、单家、多家和设置页的真实组件DEMO截图', (tester) async {
    _configureViewport(tester, const Size(390, 1360));

    final unicom = Carrier.values.byName('unicom');
    final telecom = Carrier.values.byName('telecom');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      _selectionHost(selected: const {}, isInitialSetup: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('界面演示 · 非真实流量'), findsOneWidget);
    expect(find.text('先选好你的运营商'), findsOneWidget);
    for (final carrier in Carrier.values) {
      expect(find.text(carrier.label), findsOneWidget);
    }
    expect(find.text('余额查询接入中'), findsNothing);
    expect(find.text('0 / 4 张已选择'), findsOneWidget);
    await _writeScreenshot(tester, 'carrier-selection-four-demo.png');

    tester.view.physicalSize = const Size(390, 1060);
    await tester.pumpWidget(
      _selectionHost(
        selected: {Carrier.mobile},
        isInitialSetup: true,
        accountCounts: const {Carrier.mobile: 4},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4 / 4 张已选择'), findsOneWidget);
    await _writeScreenshot(tester, 'carrier-count-four-demo.png');

    tester.view.physicalSize = const Size(390, 1360);
    await tester.pumpWidget(
      _host(
        snapshots: [
          _unicomDemoSnapshot(),
          _broadnetPackageSnapshot([30, 113]),
        ],
        selectedCarriers: {unicom, Carrier.broadnet},
        demo: true,
        textScale: 1.0,
        onAddWidget: () {},
        onManageCarriers: () {},
        previewBoundaryKey: _previewBoundaryKey,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('界面演示 · 非真实流量'), findsOneWidget);
    expect(find.text('中国移动'), findsNothing);
    expect(find.text('中国联通'), findsWidgets);
    expect(find.text('中国广电'), findsWidgets);
    expect(find.text('通用流量总览'), findsNothing);
    await _writeScreenshot(tester, 'dashboard-unicom-broadnet-demo.png');

    tester.view.physicalSize = const Size(390, 1100);
    await tester.pumpWidget(
      _host(
        snapshots: [_telecomDemoSnapshot()],
        selectedCarriers: {telecom},
        demo: true,
        textScale: 1.0,
        onAddWidget: () {},
        onManageCarriers: () {},
        previewBoundaryKey: _previewBoundaryKey,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('界面演示 · 非真实流量'), findsOneWidget);
    expect(find.text('中国电信'), findsWidgets);
    expect(find.text('套餐估算余量'), findsNWidgets(2));
    expect(find.text('约'), findsNWidgets(2));
    expect(find.textContaining('舍入'), findsNWidgets(2));
    expect(find.text('约 18.0 GB'), findsNWidgets(2));
    await _writeScreenshot(tester, 'dashboard-telecom-demo.png');

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _selectionHost(selected: {unicom, telecom}, isInitialSetup: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('界面演示 · 非真实流量'), findsOneWidget);
    expect(find.text('管理运营商'), findsOneWidget);
    expect(find.textContaining('余额查询接入中'), findsNothing);
    await _writeScreenshot(tester, 'carrier-settings-four-demo.png');
    expect(tester.takeException(), isNull);
  });
}

Widget _selectionHost({
  required Set<Carrier> selected,
  required bool isInitialSetup,
  Map<Carrier, int> accountCounts = const {},
}) {
  final typography = Typography.material2021(platform: TargetPlatform.android);
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'PreviewChinese',
      textTheme: typography.black.apply(fontFamily: 'PreviewChinese'),
      primaryTextTheme: typography.white.apply(fontFamily: 'PreviewChinese'),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4E83D9)),
    ),
    builder: (context, child) => RepaintBoundary(
      key: _previewBoundaryKey,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.0)),
        child: child!,
      ),
    ),
    home: CarrierSelectionScreen(
      selectedCarriers: selected,
      accountCounts: accountCounts,
      onAccountCountsChanged: (_) {},
      isInitialSetup: isInitialSetup,
      demo: true,
      onSelectionChanged: (_) {},
      onContinue: (_) {},
    ),
  );
}

Future<void> _writeScreenshot(WidgetTester tester, String fileName) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewBoundaryKey),
  );
  final output = _previewFile(fileName);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await output.parent.create(recursive: true);
    await output.writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
  expect(output.existsSync(), isTrue);
  expect(output.lengthSync(), greaterThan(10_000));
}

Widget _host({
  required List<CarrierSnapshot> snapshots,
  required bool demo,
  required double textScale,
  Set<Carrier> selectedCarriers = const {Carrier.mobile, Carrier.broadnet},
  _CallbackCalls? calls,
  VoidCallback? onAddWidget,
  VoidCallback? onManageCarriers,
  bool widgetSupported = true,
  Key? previewBoundaryKey,
  List<DashboardAccountEntry>? accountEntries,
  ValueChanged<String>? onConnectAccount,
  ValueChanged<String>? onRefreshAccount,
  BucketClassificationCallback? onClassifyBucket,
}) {
  final callbacks = calls ?? _CallbackCalls();
  final typography = Typography.material2021(platform: TargetPlatform.android);
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'PreviewChinese',
      textTheme: typography.black.apply(fontFamily: 'PreviewChinese'),
      primaryTextTheme: typography.white.apply(fontFamily: 'PreviewChinese'),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4E83D9)),
    ),
    builder: (context, child) {
      final scaledChild = MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
      if (previewBoundaryKey == null) return scaledChild;
      return RepaintBoundary(key: previewBoundaryKey, child: scaledChild);
    },
    home: DashboardScreen(
      snapshots: snapshots,
      thresholdGb: 2,
      demo: demo,
      onConnect: callbacks.connected.add,
      onRefresh: callbacks.refreshed.add,
      onRefreshAll: () => callbacks.refreshAll++,
      onSettings: () => callbacks.settings++,
      onAbout: () => callbacks.about++,
      selectedCarriers: selectedCarriers,
      accountEntries: accountEntries,
      onConnectAccount: onConnectAccount,
      onRefreshAccount: onRefreshAccount,
      onClassifyBucket: onClassifyBucket,
      onManageCarriers: onManageCarriers,
      onAddWidget: onAddWidget,
      widgetSupported: widgetSupported,
    ),
  );
}

List<CarrierSnapshot> _demoSnapshots() => [
  _snapshot(
    Carrier.mobile,
    QueryStatus.success,
    remainingGiB: 12.4,
    totalGiB: 30,
    phoneMasked: '138****2468',
  ),
  CarrierSnapshot(
    carrier: Carrier.broadnet,
    status: QueryStatus.success,
    queriedAt: DateTime(2026, 9, 30, 10, 20),
    phoneMasked: '192****6812',
    buckets: [
      const TrafficBucket(
        name: '通用流量',
        kind: BucketKind.general,
        remainingBytes: 5 * _gib,
        totalBytes: 15 * _gib,
      ),
      const TrafficBucket(
        name: '视频定向流量',
        kind: BucketKind.directed,
        rawRemaining: '2.5',
        rawUnit: 'GB',
      ),
    ],
  ),
];

CarrierSnapshot _serviceDemo(QueryStatus status) => CarrierSnapshot(
  carrier: Carrier.mobile,
  status: status,
  queriedAt: DateTime(2026, 10, 1, 10, 20),
  phoneMasked: '138****2468',
  buckets: const [
    TrafficBucket(
      name: '通用流量',
      kind: BucketKind.general,
      remainingBytes: 12 * _gib,
      totalBytes: 30 * _gib,
    ),
  ],
  allowances: const [
    ServiceAllowance(
      kind: AllowanceKind.voice,
      label: '国内通话',
      remaining: 120,
      total: 300,
    ),
    ServiceAllowance(
      kind: AllowanceKind.voice,
      label: '本地赠送通话',
      remaining: 30,
      scope: '仅限本地拨打',
    ),
    ServiceAllowance(
      kind: AllowanceKind.sms,
      label: '国内短信',
      remaining: 0,
      total: 100,
    ),
    ServiceAllowance(kind: AllowanceKind.sms, label: '短、彩信共享包'),
    ServiceAllowance(kind: AllowanceKind.sms, label: '已超出套餐短信', overage: 2),
  ],
);

CarrierSnapshot _unicomDemoSnapshot() => CarrierSnapshot(
  carrier: Carrier.unicom,
  status: QueryStatus.success,
  queriedAt: DateTime(2026, 9, 30, 10, 20),
  phoneMasked: '186****4321',
  buckets: const [
    TrafficBucket(
      name: '官网套餐余量',
      kind: BucketKind.unknown,
      remainingBytes: 18 * _gib,
      totalBytes: 26 * _gib,
      rawUnit: 'MB',
      rawRemaining: '18432',
    ),
  ],
);

CarrierSnapshot _telecomDemoSnapshot() => CarrierSnapshot(
  carrier: Carrier.telecom,
  status: QueryStatus.success,
  queriedAt: DateTime(2026, 9, 30, 10, 20),
  phoneMasked: '189****7612',
  buckets: const [
    TrafficBucket(
      name: '国内流量套餐',
      kind: BucketKind.unknown,
      remainingBytes: 18 * _gib,
      totalBytes: 26 * _gib,
      rawUnit: 'MB',
      rawRemaining: '18432.00',
    ),
  ],
);

CarrierSnapshot _telecomPartialDemoSnapshot() => CarrierSnapshot(
  carrier: Carrier.telecom,
  status: QueryStatus.success,
  queriedAt: DateTime(2026, 9, 30, 10, 20),
  phoneMasked: '189****7612',
  message: '部分官网明细无法估算，暂不显示合计；请核对官方查询页',
  buckets: const [
    TrafficBucket(
      name: '国内流量套餐',
      kind: BucketKind.unknown,
      remainingBytes: 18 * _gib,
      totalBytes: 26 * _gib,
      rawUnit: 'B',
      rawRemaining: '19327352832',
    ),
    TrafficBucket(
      name: '另一项套餐',
      kind: BucketKind.unknown,
      rawRemaining: '剩余额无法确认',
    ),
  ],
);

CarrierSnapshot _snapshot(
  Carrier carrier,
  QueryStatus status, {
  double? remainingGiB,
  double? totalGiB,
  String? phoneMasked,
  String? message,
}) {
  return CarrierSnapshot(
    carrier: carrier,
    status: status,
    queriedAt: DateTime(2026, 9, 30, 10, 20),
    phoneMasked: phoneMasked,
    message: message,
    buckets: remainingGiB == null
        ? const []
        : [
            TrafficBucket(
              name: '通用流量',
              kind: BucketKind.general,
              rawUnit: 'GB',
              remainingBytes: (remainingGiB * _gib).round(),
              totalBytes: totalGiB == null ? null : (totalGiB * _gib).round(),
            ),
          ],
  );
}

void _configureViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _loadPreviewChineseFont() async {
  final sdkRoots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final String root) root,
    r'D:\AI\tools\flutter',
  ];
  var parent = File(Platform.resolvedExecutable).parent;
  while (parent.parent.path != parent.path) {
    sdkRoots.add(parent.path);
    parent = parent.parent;
  }
  File? materialIconsFile;
  for (final root in sdkRoots) {
    final candidate = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (await candidate.exists()) {
      materialIconsFile = candidate;
      break;
    }
  }
  if (materialIconsFile == null) {
    throw StateError('Flutter Material Icons font was not found.');
  }
  final materialIconsBytes = await materialIconsFile.readAsBytes();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(materialIconsBytes)))).load();

  final paths = [
    if (Platform.environment['LIULIANG_PREVIEW_CHINESE_FONT']
        case final String path)
      path,
    r'C:\Windows\Fonts\msyh.ttc',
    r'C:\Windows\Fonts\simhei.ttf',
    '/System/Library/Fonts/PingFang.ttc',
    '/System/Library/Fonts/STHeiti Medium.ttc',
    '/System/Library/Fonts/STHeiti Light.ttc',
    '/System/Library/Fonts/Supplemental/Songti.ttc',
  ];
  File? fontFile;
  for (final path in paths) {
    final candidate = File(path);
    if (await candidate.exists()) {
      fontFile = candidate;
      break;
    }
  }
  if (fontFile == null) {
    throw StateError(
      'Set LIULIANG_PREVIEW_CHINESE_FONT to a Chinese font for UI screenshots.',
    );
  }

  final bytes = await fontFile.readAsBytes();
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  await (FontLoader('PreviewChinese')..addFont(Future.value(data))).load();
}

CarrierSnapshot _broadnetPackageSnapshot(List<int> remainingGiB) {
  const names = [
    '语音娱乐流量套餐明细第一项',
    '节假日流量套餐明细第二项',
    '视频专属流量套餐明细第三项',
    '家庭共享流量套餐明细第四项',
    '视频专属流量套餐明细第五项完整名称',
  ];
  return CarrierSnapshot(
    carrier: Carrier.broadnet,
    status: QueryStatus.success,
    queriedAt: DateTime(2026, 9, 30, 10, 20),
    buckets: [
      for (var index = 0; index < remainingGiB.length; index++)
        TrafficBucket(
          name: names[index],
          kind: BucketKind.unknown,
          remainingBytes: remainingGiB[index] * _gib,
          totalBytes: remainingGiB[index] * 2 * _gib,
          rawUnit: 'KB',
          rawRemaining: '${remainingGiB[index]}',
        ),
    ],
  );
}

File _previewFile([String fileName = 'ui-preview.png']) {
  final current = Directory.current;
  final currentPubspec = File(
    '${current.path}${Platform.pathSeparator}pubspec.yaml',
  );
  final appDirectory = currentPubspec.existsSync()
      ? current
      : Directory('${current.path}${Platform.pathSeparator}app');
  final repoRoot =
      appDirectory.path.toLowerCase().endsWith('${Platform.pathSeparator}app')
      ? appDirectory.parent
      : current;
  return File(
    '${repoRoot.path}${Platform.pathSeparator}artifacts'
    '${Platform.pathSeparator}$fileName',
  );
}

class _CallbackCalls {
  final connected = <Carrier>[];
  final refreshed = <Carrier>[];
  int refreshAll = 0;
  int settings = 0;
  int about = 0;
  int widgetAdditions = 0;
}
