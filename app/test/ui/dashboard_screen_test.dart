import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';

const _previewBoundaryKey = ValueKey<String>('dashboard-preview');
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

      expect(find.text('两张卡，一眼看清'), findsOneWidget);
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

    await tester.ensureVisible(find.text('全部刷新'));
    await tester.tap(find.text('全部刷新'));
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

    expect(find.text('两张卡，一眼看清'), findsOneWidget);
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
}

Widget _host({
  required List<CarrierSnapshot> snapshots,
  required bool demo,
  required double textScale,
  _CallbackCalls? calls,
  VoidCallback? onAddWidget,
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

File _previewFile() {
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
    '${Platform.pathSeparator}ui-preview.png',
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
