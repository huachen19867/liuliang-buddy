import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/ui/carrier_browser_shell.dart';

void main() {
  const formKey = ValueKey('official-form');
  const message = '请在官网自行勾选协议并获取验证码。完成验证后点击上方「查询流量」。';
  var formTaps = 0;
  var keyboardDismissals = 0;
  var queries = 0;
  var helpRequests = 0;

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(320, 568),
    double keyboardHeight = 0,
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: CarrierBrowserShell(
              title: '中国移动 · 一个很长的自定义号码备注官方页面',
              message: message,
              keyboardVisible: MediaQuery.viewInsetsOf(context).bottom > 0,
              onClose: () {},
              onQuery: () => queries++,
              onReload: () {},
              onHelp: () => helpRequests++,
              onDismissKeyboard: () => keyboardDismissals++,
              child: SizedBox.expand(
                key: formKey,
                child: Center(
                  child: TextButton(
                    onPressed: () => formTaps++,
                    child: const Text('官网获取验证码'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() {
    formTaps = 0;
    keyboardDismissals = 0;
    queries = 0;
    helpRequests = 0;
  });

  testWidgets('窄屏大字保持官网点击和查询入口可用', (tester) async {
    await open(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('查询流量'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('official-query-flow'))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('官网获取验证码'));
    await tester.tap(find.byTooltip('查询流量'));
    expect(formTaps, 1);
    expect(queries, 1);
    expect(find.byTooltip('收起键盘'), findsNothing);
  });

  testWidgets('键盘出现时压缩说明并保留手动收起和官网点击', (tester) async {
    await open(tester, keyboardHeight: 250, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text(message), findsNothing);
    expect(find.text('查询流量'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('official-query-flow'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.getSize(find.byKey(formKey)).height, greaterThan(200));
    await tester.tap(find.byTooltip('收起键盘'));
    await tester.tap(find.text('官网获取验证码'));
    await tester.tap(find.byTooltip('登录遇到问题？'));
    expect(keyboardDismissals, 1);
    expect(formTaps, 1);
    expect(helpRequests, 1);
  });

  testWidgets('窄高横屏为官网保留空间不溢出', (tester) async {
    await open(tester, size: const Size(568, 200), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text(message), findsNothing);
    expect(tester.getSize(find.byKey(formKey)).height, greaterThan(100));
    await tester.tap(find.text('官网获取验证码'));
    expect(formTaps, 1);
    await tester.tap(find.text('查询流量'));
    expect(queries, 1);
  });

  testWidgets('官网表单避让系统底部导航区域', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byKey(formKey)).bottom, lessThanOrEqualTo(544));
    await tester.tap(find.text('官网获取验证码'));
    expect(formTaps, 1);
  });
}
