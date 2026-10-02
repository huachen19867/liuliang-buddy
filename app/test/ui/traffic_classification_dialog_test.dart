import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';

const _previewKey = ValueKey<String>('traffic-classification-preview');
const _gib = 1024 * 1024 * 1024;

void main() {
  setUpAll(_loadPreviewFonts);

  testWidgets('保存时将账号、套餐与 null 自动分类传给主应用', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    final bucket = _unknownBucket(manualKind: BucketKind.directed);
    final snapshot = _snapshot([bucket]);
    String? savedAccount;
    TrafficBucket? savedBucket;
    BucketKind? savedKind = BucketKind.general;

    await tester.pumpWidget(
      _host(
        snapshot: snapshot,
        onClassifyBucket: (accountId, value, kind) async {
          savedAccount = accountId;
          savedBucket = value;
          savedKind = kind;
          return true;
        },
      ),
    );
    await _openBucket(tester, bucket.name);
    await tester.tap(
      find.byKey(const ValueKey('bucket-classification-automatic')),
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedAccount, 'broadnet_2');
    expect(identical(savedBucket, bucket), isTrue);
    expect(savedKind, isNull);
    expect(find.text('用途分类'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('取消不触发保存', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    var saves = 0;
    final bucket = _unknownBucket();
    await tester.pumpWidget(
      _host(
        snapshot: _snapshot([bucket]),
        onClassifyBucket: (_, _, _) async {
          saves++;
          return true;
        },
      ),
    );
    await _openBucket(tester, bucket.name);
    await tester.tap(
      find.byKey(const ValueKey('bucket-classification-general')),
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(saves, 0);
    expect(find.text('用途分类'), findsNothing);
  });

  testWidgets('保存失败留在弹窗并可重试', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    var saves = 0;
    final bucket = _unknownBucket();
    await tester.pumpWidget(
      _host(
        snapshot: _snapshot([bucket]),
        onClassifyBucket: (_, _, _) async => ++saves > 1,
      ),
    );
    await _openBucket(tester, bucket.name);
    await tester.tap(
      find.byKey(const ValueKey('bucket-classification-directed')),
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('保存失败，请重试。'), findsOneWidget);
    expect(find.text('用途分类'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saves, 2);
    expect(find.text('用途分类'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('通用套餐仍在明细中，可再次打开并改回自动识别', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    final bucket = TrafficBucket(
      name: '原通用流量',
      kind: BucketKind.general,
      remainingBytes: 2 * _gib,
      totalBytes: 8 * _gib,
      rawUnit: 'GB',
      manualKind: BucketKind.general,
    );
    BucketKind? savedKind = BucketKind.directed;
    await tester.pumpWidget(
      _host(
        snapshot: _snapshot([bucket]),
        onClassifyBucket: (_, _, kind) async {
          savedKind = kind;
          return true;
        },
      ),
    );
    await _openBucket(tester, bucket.name);
    expect(find.text('手动分类'), findsOneWidget);
    expect(find.text('通用流量'), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('bucket-classification-automatic')),
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedKind, isNull);
    expect(find.text(bucket.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同名套餐给出不能区分的说明', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    final duplicate = _unknownBucket(name: '同名套餐');
    await tester.pumpWidget(
      _host(
        snapshot: _snapshot([duplicate, duplicate.copyWith()]),
        onClassifyBucket: (_, _, _) async => true,
      ),
    );
    await _openBucket(tester, '同名套餐', first: true);
    expect(find.text('共 2 项'), findsOneWidget);
    final groupedBalance = find
        .descendant(of: find.byType(AlertDialog), matching: find.text('1.0 GB'))
        .first;
    await tester.ensureVisible(groupedBalance);
    await tester.tap(groupedBalance);
    await tester.pumpAndSettle();

    expect(find.text('存在同名套餐，暂时无法准确区分'), findsOneWidget);
    expect(find.text('保存'), findsNothing);
    expect(
      find.byKey(const ValueKey('bucket-classification-general')),
      findsNothing,
    );
  });

  testWidgets('无保存回调时保留原只读明细', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    final bucket = _unknownBucket();
    await tester.pumpWidget(_host(snapshot: _snapshot([bucket])));
    await _openBucket(tester, bucket.name);

    expect(find.text('套餐总量'), findsOneWidget);
    expect(find.text('知道了'), findsOneWidget);
    expect(find.text('用途分类'), findsNothing);
    expect(find.text('保存'), findsNothing);
  });

  testWidgets('小屏大字下分类弹窗仍可滚动操作', (tester) async {
    _configureViewport(tester, const Size(280, 560));
    final bucket = _unknownBucket();
    BucketKind? savedKind;
    await tester.pumpWidget(
      _host(
        snapshot: _snapshot([bucket]),
        textScale: 1.4,
        onClassifyBucket: (_, _, kind) async {
          savedKind = kind;
          return true;
        },
      ),
    );
    await _openBucket(tester, bucket.name);
    await tester.ensureVisible(
      find.byKey(const ValueKey('bucket-classification-directed')),
    );
    await tester.tap(
      find.byKey(const ValueKey('bucket-classification-directed')),
    );
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedKind, BucketKind.directed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('生成套餐手动分类弹窗预览截图', (tester) async {
    _configureViewport(tester, const Size(390, 844));
    final bucket = _unknownBucket();
    await tester.pumpWidget(
      _host(
        snapshot: _snapshot([bucket]),
        onClassifyBucket: (_, _, _) async => true,
        preview: true,
      ),
    );
    await _openBucket(tester, bucket.name);
    await tester.pumpAndSettle();

    expect(find.text('自动识别'), findsOneWidget);
    expect(find.text('通用流量'), findsWidgets);
    expect(find.text('定向流量'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _writeScreenshot(tester);
  });
}

Widget _host({
  required CarrierSnapshot snapshot,
  BucketClassificationCallback? onClassifyBucket,
  double textScale = 1,
  bool preview = false,
}) {
  const account = CarrierAccount(
    id: 'broadnet_2',
    carrier: Carrier.broadnet,
    label: '中国广电 2',
    note: '旅行备用卡',
  );
  final typography = Typography.material2021(platform: TargetPlatform.android);
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'PreviewChinese',
      textTheme: typography.black.apply(fontFamily: 'PreviewChinese'),
      primaryTextTheme: typography.white.apply(fontFamily: 'PreviewChinese'),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF75A795)),
    ),
    builder: (context, child) {
      final scaled = MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
      return preview
          ? RepaintBoundary(key: _previewKey, child: scaled)
          : scaled;
    },
    home: DashboardScreen(
      snapshots: [snapshot],
      selectedCarriers: const {Carrier.broadnet},
      accountEntries: [DashboardAccountEntry(account, snapshot)],
      thresholdGb: 2,
      onConnect: (_) {},
      onRefresh: (_) {},
      onRefreshAll: () {},
      onSettings: () {},
      onAbout: () {},
      onClassifyBucket: onClassifyBucket,
      demo: preview,
    ),
  );
}

CarrierSnapshot _snapshot(List<TrafficBucket> buckets) => CarrierSnapshot(
  carrier: Carrier.broadnet,
  status: QueryStatus.success,
  queriedAt: DateTime(2026, 10, 2, 13),
  buckets: buckets,
);

TrafficBucket _unknownBucket({
  String name = '视频专属流量',
  BucketKind? manualKind,
}) => TrafficBucket(
  name: name,
  kind: BucketKind.unknown,
  remainingBytes: _gib,
  totalBytes: 5 * _gib,
  rawUnit: 'GB',
  manualKind: manualKind,
);

Future<void> _openBucket(
  WidgetTester tester,
  String name, {
  bool first = false,
}) async {
  final row = find.text(name);
  await tester.ensureVisible(row.first);
  await tester.tap(first ? row.first : row);
  await tester.pumpAndSettle();
}

void _configureViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _writeScreenshot(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = _previewFile();
      await output.parent.create(recursive: true);
      await output.writeAsBytes(png!.buffer.asUint8List());
      expect(output.lengthSync(), greaterThan(10_000));
    } finally {
      image.dispose();
    }
  });
}

File _previewFile() {
  final current = Directory.current;
  final appDirectory =
      File('${current.path}${Platform.pathSeparator}pubspec.yaml').existsSync()
      ? current
      : Directory('${current.path}${Platform.pathSeparator}app');
  final repoRoot =
      appDirectory.path.toLowerCase().endsWith('${Platform.pathSeparator}app')
      ? appDirectory.parent
      : current;
  return File(
    '${repoRoot.path}${Platform.pathSeparator}artifacts'
    '${Platform.pathSeparator}traffic-classification-preview.png',
  );
}

Future<void> _loadPreviewFonts() async {
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

  final fontPaths = [
    if (Platform.environment['LIULIANG_PREVIEW_CHINESE_FONT']
        case final String path)
      path,
    r'C:\Windows\Fonts\msyh.ttc',
    r'C:\Windows\Fonts\simhei.ttf',
    '/System/Library/Fonts/PingFang.ttc',
    '/System/Library/Fonts/STHeiti Medium.ttc',
    '/System/Library/Fonts/STHeiti Light.ttc',
    '/System/Library/Fonts/Supplemental/Songti.ttc',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc',
  ];
  File? fontFile;
  for (final path in fontPaths) {
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
