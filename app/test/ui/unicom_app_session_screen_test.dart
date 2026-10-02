import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/services/unicom_app_client.dart';
import 'package:liuliang_app/ui/resort_theme.dart';
import 'package:liuliang_app/ui/unicom_app_session_screen.dart';

const _previewBoundaryKey = ValueKey<String>('unicom-app-session-preview');

void main() {
  setUpAll(_loadPreviewFonts);

  testWidgets('生成联通 App 会话导入页预览截图', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);

    final typography = Typography.material2021(
      platform: TargetPlatform.android,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'PreviewChinese',
          scaffoldBackgroundColor: ResortPalette.canvas,
          textTheme: typography.black.apply(fontFamily: 'PreviewChinese'),
          primaryTextTheme: typography.white.apply(
            fontFamily: 'PreviewChinese',
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: ResortPalette.mint,
            surface: ResortPalette.paper,
          ),
        ),
        home: RepaintBoundary(
          key: _previewBoundaryKey,
          child: UnicomAppSessionScreen(
            account: _account(phoneNumber: '13800138000'),
            hasSession: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('unicom-app-session')),
      'session=preview',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('unicom-app-cookie-owner')),
      findsOneWidget,
    );
    expect(find.textContaining('不是一键登录'), findsOneWidget);
    expect(find.textContaining('Cookie 归属勾选仅代表'), findsNothing);
    expect(tester.takeException(), isNull);
    await _writePreviewScreenshot(tester);
  });

  testWidgets('高级入口说明不是一键登录并可返回官网连接方式', (tester) async {
    UnicomAppSession? result;
    await _openScreen(
      tester,
      account: _account(phoneNumber: '13800138000'),
      hasSession: true,
      onResult: (value) => result = value,
    );

    expect(find.text('联通 App 会话（高级）'), findsOneWidget);
    expect(find.textContaining('不是一键登录'), findsOneWidget);
    expect(find.textContaining('本机已保存此号码的会话'), findsOneWidget);
    expect(find.textContaining('没有会话资料时'), findsOneWidget);
    expect(find.text('验证并连接'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('unicom-app-phone')))
          .controller
          ?.text,
      '13800138000',
    );

    final cancel = find.byKey(const ValueKey('unicom-app-cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('导入 Cookie 要逐号确认、手机号必须是 11 位并返回会话对象', (tester) async {
    UnicomAppSession? result;
    await _openScreen(
      tester,
      account: _account(),
      onResult: (value) => result = value,
    );

    await _enter(tester, const ValueKey('unicom-app-phone'), '13800138000');
    await _enter(tester, const ValueKey('unicom-app-session'), 'session=test');
    expect(
      find.byKey(const ValueKey('unicom-app-cookie-owner')),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('unicom-app-submit')));
    await tester.tap(find.byKey(const ValueKey('unicom-app-submit')));
    await tester.pumpAndSettle();
    expect(find.text('请先确认 Cookie 与上方号码对应。'), findsOneWidget);
    expect(result, isNull);

    await tester.ensureVisible(
      find.byKey(const ValueKey('unicom-app-cookie-owner')),
    );
    await tester.tap(find.byKey(const ValueKey('unicom-app-cookie-owner')));
    await tester.pumpAndSettle();
    await _enter(tester, const ValueKey('unicom-app-phone'), '1380013800');
    await tester.ensureVisible(find.byKey(const ValueKey('unicom-app-submit')));
    await tester.tap(find.byKey(const ValueKey('unicom-app-submit')));
    await tester.pumpAndSettle();
    expect(find.text('请输入 11 位大陆手机号'), findsOneWidget);
    expect(result, isNull);

    await _enter(tester, const ValueKey('unicom-app-phone'), '13800138000');
    await tester.ensureVisible(
      find.byKey(const ValueKey('unicom-app-cookie-owner')),
    );
    await tester.tap(find.byKey(const ValueKey('unicom-app-cookie-owner')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('unicom-app-submit')));
    await tester.tap(find.byKey(const ValueKey('unicom-app-submit')));
    await tester.pumpAndSettle();

    expect(result, isA<UnicomAppSession>());
    expect(result!.phoneNumber, '13800138000');
    expect(result!.hasCookie, isTrue);
    expect(find.text('session=test'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('格式错误时显示安全文案，不回显输入内容', (tester) async {
    const secretLookingText = 'PRIVATE_SESSION_MARKER';
    await _openScreen(tester, account: _account());

    await _enter(tester, const ValueKey('unicom-app-phone'), '13800138000');
    await _enter(
      tester,
      const ValueKey('unicom-app-session'),
      '{"cookie":"$secretLookingText"',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('unicom-app-cookie-owner')),
    );
    await tester.tap(find.byKey(const ValueKey('unicom-app-cookie-owner')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('unicom-app-submit')));
    await tester.tap(find.byKey(const ValueKey('unicom-app-submit')));
    await tester.pumpAndSettle();

    expect(find.text('会话资料格式或号码无法确认，请检查后重试。'), findsOneWidget);
    final input = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('unicom-app-session')),
        matching: find.byType(EditableText),
      ),
    );
    final error = tester.widget<Text>(
      find.byKey(const ValueKey('unicom-app-session-error')),
    );
    expect(input.obscureText, isTrue);
    expect(error.data, isNot(contains(secretLookingText)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('token-only JSON 不要求 Cookie 确认', (tester) async {
    UnicomAppSession? result;
    await _openScreen(
      tester,
      account: _account(),
      onResult: (value) => result = value,
    );

    await _enter(tester, const ValueKey('unicom-app-phone'), '13800138000');
    await _enter(
      tester,
      const ValueKey('unicom-app-session'),
      '{"token_online":"opaque-token","appId":"client","version":"1"}',
    );
    expect(find.byKey(const ValueKey('unicom-app-cookie-owner')), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('unicom-app-submit')));
    await tester.tap(find.byKey(const ValueKey('unicom-app-submit')));
    await tester.pumpAndSettle();

    expect(result, isA<UnicomAppSession>());
    expect(result!.hasCookie, isFalse);
    expect(result!.phoneNumber, '13800138000');
    expect(tester.takeException(), isNull);
  });

  testWidgets('400x850、大字并有 300px 键盘遮挡时仍可滚动提交', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 850);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await _openScreen(tester, account: _account(), textScale: 1.3);
    final phone = find.byKey(const ValueKey('unicom-app-phone'));
    final session = find.byKey(const ValueKey('unicom-app-session'));
    final submit = find.byKey(const ValueKey('unicom-app-submit'));
    await tester.ensureVisible(phone);
    await tester.ensureVisible(session);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('请输入 11 位大陆手机号'), findsOneWidget);
    expect(find.text('请输入会话资料'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _writePreviewScreenshot(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewBoundaryKey),
  );
  final current = Directory.current;
  final appDirectory =
      File('${current.path}${Platform.pathSeparator}pubspec.yaml').existsSync()
      ? current
      : Directory('${current.path}${Platform.pathSeparator}app');
  final repoRoot =
      appDirectory.path.toLowerCase().endsWith('${Platform.pathSeparator}app')
      ? appDirectory.parent
      : current;
  final output = File(
    '${repoRoot.path}${Platform.pathSeparator}artifacts'
    '${Platform.pathSeparator}unicom-app-session-preview.png',
  );
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
  File? iconsFile;
  for (final root in sdkRoots) {
    final candidate = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (await candidate.exists()) {
      iconsFile = candidate;
      break;
    }
  }
  if (iconsFile == null) {
    throw StateError('Flutter Material Icons font was not found.');
  }
  final iconsBytes = await iconsFile.readAsBytes();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(iconsBytes)))).load();

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
  ];
  File? chineseFont;
  for (final path in fontPaths) {
    final candidate = File(path);
    if (await candidate.exists()) {
      chineseFont = candidate;
      break;
    }
  }
  if (chineseFont == null) {
    throw StateError(
      'Set LIULIANG_PREVIEW_CHINESE_FONT to a Chinese font for UI screenshots.',
    );
  }
  final fontBytes = await chineseFont.readAsBytes();
  await (FontLoader(
    'PreviewChinese',
  )..addFont(Future.value(ByteData.sublistView(fontBytes)))).load();
}

CarrierAccount _account({String? phoneNumber}) => CarrierAccount(
  id: 'unicom',
  carrier: Carrier.unicom,
  label: '中国联通 1',
  phoneNumber: phoneNumber,
);

Widget _host({
  required CarrierAccount account,
  bool hasSession = false,
  ValueChanged<UnicomAppSession?>? onResult,
  double textScale = 1,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final result = await showUnicomAppSessionScreen(
              context,
              account: account,
              hasSession: hasSession,
            );
            onResult?.call(result);
          },
          child: const Text('打开高级会话页'),
        ),
      ),
    ),
  ),
);

Future<void> _openScreen(
  WidgetTester tester, {
  required CarrierAccount account,
  bool hasSession = false,
  ValueChanged<UnicomAppSession?>? onResult,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    _host(
      account: account,
      hasSession: hasSession,
      onResult: onResult,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('打开高级会话页'));
  await tester.pumpAndSettle();
}

Future<void> _enter(
  WidgetTester tester,
  ValueKey<String> key,
  String value,
) async {
  final field = find.byKey(key);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}
