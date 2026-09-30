import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/ui/carrier_selection_screen.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';

const _previewBoundaryKey = ValueKey<String>('dashboard-preview');
const _broadnetPreviewBoundaryKey = ValueKey<String>(
  'broadnet-summary-preview',
);
const _gib = 1024 * 1024 * 1024;

void main() {
  setUpAll(_loadPreviewChineseFont);

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

    expect(find.text('请在安卓手机添加'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '添加桌面卡片'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
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
    expect(find.textContaining('3.0'), findsOneWidget);
    expect(find.textContaining('7.0'), findsOneWidget);
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
    expect(find.text('约 18.0 GB'), findsOneWidget);
    await tester.ensureVisible(find.text('约 18.0 GB'));
    await tester.tap(find.text('约 18.0 GB'));
    await tester.pumpAndSettle();
    expect(find.text('剩余流量（估算）'), findsOneWidget);
    expect(find.text('约 18.0 GB'), findsNWidgets(2));
    expect(find.textContaining('舍入差异'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('电信部分套餐无法估算时仍标记可计算明细且弹窗保留估算说明', (tester) async {
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
    expect(find.text('余额待确认'), findsOneWidget);
    expect(find.text('部分官网明细无法估算，暂不显示合计；请核对官方查询页'), findsOneWidget);
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
    expect(find.text('0 家已选择'), findsOneWidget);
    await _writeScreenshot(tester, 'carrier-selection-four-demo.png');

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
    expect(find.text('约 18.0 GB'), findsOneWidget);
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
      ),
    ],
  ),
];

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
  const materialIconsPath =
      r'D:\AI\tools\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf';
  final materialIconsFile = File(materialIconsPath);
  if (!await materialIconsFile.exists()) {
    throw StateError('Flutter Material Icons font was not found.');
  }
  final materialIconsBytes = await materialIconsFile.readAsBytes();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(materialIconsBytes)))).load();

  const paths = [r'C:\Windows\Fonts\msyh.ttc', r'C:\Windows\Fonts\simhei.ttf'];
  File? fontFile;
  for (final path in paths) {
    final candidate = File(path);
    if (await candidate.exists()) {
      fontFile = candidate;
      break;
    }
  }
  if (fontFile == null) {
    throw StateError('No system Chinese font found for the UI screenshot.');
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
