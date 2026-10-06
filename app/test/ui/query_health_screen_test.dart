import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/services/query_health.dart';
import 'package:liuliang_app/ui/query_health_screen.dart';
import '../support/preview_fonts.dart';

void main() {
  setUpAll(loadPreviewFonts);
  final loginExpired = QueryAccountHealth(
    accountId: 'mobile-1',
    label: '移动 · 账号 1',
    carrier: Carrier.mobile,
    kind: QueryHealthKind.loginExpired,
    detail: '官网会话已失效，请重新登录后查询。',
    action: QueryHealthAction.reconnect,
    lastValidDataAt: DateTime(2026, 10, 5, 8, 30),
    lastAttemptAt: DateTime(2026, 10, 6, 9, 45),
  );

  final accessError = QueryAccountHealth(
    accountId: 'unicom-1',
    label: '联通 · 账号 1',
    carrier: Carrier.unicom,
    kind: QueryHealthKind.accessError,
    detail: '暂时无法访问官网，原有数据时间仍然保留。',
    action: QueryHealthAction.retry,
    lastValidDataAt: DateTime(2026, 10, 4, 17, 10),
  );

  final unreadFields = QueryAccountHealth(
    accountId: 'telecom-1',
    label: '电信 · 账号 1',
    carrier: Carrier.telecom,
    kind: QueryHealthKind.unreadFields,
    detail: '官网有返回，但有套餐字段尚未识别。',
    action: QueryHealthAction.inspectFields,
    lastValidDataAt: DateTime(2026, 10, 6, 9, 20),
  );

  final backgroundPaused = QueryAccountHealth(
    accountId: 'broadnet-1',
    label: '广电 · 账号 1',
    carrier: Carrier.broadnet,
    kind: QueryHealthKind.backgroundPaused,
    detail: '该账号暂不参与后台自动查询。',
    action: QueryHealthAction.backgroundSettings,
    lastValidDataAt: DateTime(2026, 10, 6, 8, 0),
    backgroundNote: '后台最近结果：部分账号未取得新数据。',
  );

  final report = QueryHealthReport(
    version: '1.10.10',
    refreshInterval: '每 1 小时',
    backgroundSummary: '后台查询未取得新数据',
    backgroundFinishedAt: DateTime(2026, 10, 6, 9, 40),
    accounts: [loginExpired, accessError, unreadFields, backgroundPaused],
  );

  Widget host({
    required QueryHealthReport report,
    required Future<void> Function(String, QueryHealthAction) onAction,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'PreviewChinese',
        textTheme: Typography.material2021().black.apply(
          fontFamily: 'PreviewChinese',
        ),
        primaryTextTheme: Typography.material2021().white.apply(
          fontFamily: 'PreviewChinese',
        ),
      ),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: size, textScaler: TextScaler.linear(textScale)),
          child: QueryHealthScreen(report: report, onAction: onAction),
        ),
      ),
    );
  }

  testWidgets('查询检查页面实际渲染演示截图', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: host(
          report: QueryHealthReport(
            version: '1.11.0+28 · 界面演示',
            refreshInterval: report.refreshInterval,
            backgroundSummary: report.backgroundSummary,
            accounts: report.accounts,
          ),
          onAction: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final context = tester.element(find.byType(QueryHealthScreen));
      for (final carrier in ['mobile', 'unicom', 'telecom', 'broadnet']) {
        await precacheImage(
          AssetImage('assets/carriers/$carrier.png'),
          context,
        );
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 2);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final output = File('../artifacts/query-health-preview.png');
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  });

  testWidgets('每种明确故障显示各自原因、旧数据时间和恢复操作', (tester) async {
    await tester.pumpWidget(host(report: report, onAction: (_, _) async {}));
    await tester.pumpAndSettle();

    expect(find.text('登录已过期'), findsOneWidget);
    expect(find.text('访问错误'), findsOneWidget);
    expect(find.text('部分字段未读'), findsOneWidget);
    expect(find.text('后台刷新已暂停'), findsOneWidget);
    expect(find.text('重新登录'), findsOneWidget);
    expect(find.text('重新查询'), findsOneWidget);
    expect(find.text('查看套餐明细'), findsOneWidget);
    expect(find.text('后台刷新设置'), findsOneWidget);
    expect(find.text('上次有效数据'), findsNWidgets(4));
    expect(find.text('2026-10-05 08:30'), findsOneWidget);
    expect(find.text('最近尝试'), findsOneWidget);
    expect(find.text('2026-10-06 09:45'), findsOneWidget);
    expect(find.text('1.10.10'), findsOneWidget);
    expect(find.text('每 1 小时'), findsOneWidget);
    expect(find.text('后台查询未取得新数据'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('每个操作只调用根提供的对应账号动作', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      host(
        report: report,
        onAction: (accountId, action) async {
          calls.add('$accountId:${action.name}');
        },
      ),
    );
    await tester.pumpAndSettle();

    for (final action in const [
      ('重新登录', 'mobile-1:reconnect'),
      ('重新查询', 'unicom-1:retry'),
      ('查看套餐明细', 'telecom-1:inspectFields'),
      ('后台刷新设置', 'broadnet-1:backgroundSettings'),
    ]) {
      await tester.ensureVisible(find.text(action.$1));
      await tester.tap(find.text(action.$1));
      await tester.pumpAndSettle();
    }

    expect(calls, [
      'mobile-1:reconnect',
      'unicom-1:retry',
      'telecom-1:inspectFields',
      'broadnet-1:backgroundSettings',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('小屏大字和四家多卡状态可滚动且无溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final accounts = [
      ...report.accounts,
      QueryAccountHealth(
        accountId: 'mobile-2',
        label: '移动 · 账号 2',
        carrier: Carrier.mobile,
        kind: QueryHealthKind.healthy,
        detail: '最近一次查询成功。',
        action: QueryHealthAction.none,
        lastValidDataAt: DateTime(2026, 10, 6, 9, 55),
      ),
      QueryAccountHealth(
        accountId: 'telecom-2',
        label: '电信 · 账号 2',
        carrier: Carrier.telecom,
        kind: QueryHealthKind.checking,
        detail: '正在确认官网是否返回新数据。',
        action: QueryHealthAction.none,
        lastValidDataAt: DateTime(2026, 10, 6, 9, 15),
      ),
      QueryAccountHealth(
        accountId: 'broadnet-2',
        label: '广电 · 账号 2',
        carrier: Carrier.broadnet,
        kind: QueryHealthKind.notConnected,
        detail: '这个账号尚未完成官网连接。',
        action: QueryHealthAction.reconnect,
      ),
    ];
    final manyAccounts = QueryHealthReport(
      version: report.version,
      refreshInterval: report.refreshInterval,
      backgroundSummary: report.backgroundSummary,
      backgroundFinishedAt: report.backgroundFinishedAt,
      accounts: accounts,
    );

    await tester.pumpWidget(
      host(
        report: manyAccounts,
        onAction: (_, _) async {},
        size: const Size(320, 640),
        textScale: 1.4,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已正常读取'), findsOneWidget);
    expect(find.text('检查中'), findsOneWidget);
    expect(find.text('尚未连接'), findsOneWidget);
    expect(find.text('7 个账号'), findsOneWidget);
    expect(find.text('1.10.10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('正常和检查中的账号不显示重复或无效按钮', (tester) async {
    final reportWithoutActions = QueryHealthReport(
      version: '1.10.10',
      refreshInterval: '关闭',
      backgroundSummary: '后台查询已关闭',
      accounts: [
        QueryAccountHealth(
          accountId: 'mobile-1',
          label: '移动 · 账号 1',
          carrier: Carrier.mobile,
          kind: QueryHealthKind.healthy,
          detail: '最近一次查询成功。',
          action: QueryHealthAction.none,
          lastValidDataAt: DateTime(2026, 10, 6, 9, 55),
        ),
        QueryAccountHealth(
          accountId: 'unicom-1',
          label: '联通 · 账号 1',
          carrier: Carrier.unicom,
          kind: QueryHealthKind.checking,
          detail: '正在等待官网响应。',
          action: QueryHealthAction.none,
          lastValidDataAt: DateTime(2026, 10, 6, 9, 15),
        ),
      ],
    );
    await tester.pumpWidget(
      host(report: reportWithoutActions, onAction: (_, _) async {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('已正常读取'), findsOneWidget);
    expect(find.text('检查中'), findsOneWidget);
    expect(find.text('重新查询'), findsNothing);
    expect(find.text('重新登录'), findsNothing);
    expect(find.text('查看套餐明细'), findsNothing);
    expect(find.text('后台刷新设置'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无历史成功时间时直说尚无记录', (tester) async {
    const noHistory = QueryHealthReport(
      version: '1.10.10',
      refreshInterval: '关闭',
      backgroundSummary: '尚无后台查询记录',
      accounts: [
        QueryAccountHealth(
          accountId: 'mobile-1',
          label: '移动 · 账号 1',
          carrier: Carrier.mobile,
          kind: QueryHealthKind.notConnected,
          detail: '还没有连接官网。',
          action: QueryHealthAction.reconnect,
        ),
      ],
    );
    await tester.pumpWidget(host(report: noHistory, onAction: (_, _) async {}));
    await tester.pumpAndSettle();

    expect(find.text('有效数据'), findsOneWidget);
    expect(find.text('尚无成功记录'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
