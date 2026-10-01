import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/services/system_surfaces.dart';
import 'package:liuliang_app/ui/system_surfaces_settings.dart';

void main() {
  const notifications = MethodChannel('cn.liuliang/notifications');
  var state = <String, Object?>{};
  var permitted = true;
  var tileResult = 'canceled';
  final calls = <String>[];

  setUp(() {
    state = {
      'notificationEnabled': false,
      'tileEnabled': false,
      'notificationsAllowed': true,
      'tileAddSupported': true,
    };
    permitted = true;
    tileResult = 'canceled';
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (_) async => permitted);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemSurfaces.channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'setNotificationEnabled':
              state['notificationEnabled'] = call.arguments;
            case 'setTileEnabled':
              state['tileEnabled'] = call.arguments;
            case 'requestAddTile':
              return tileResult;
          }
          return state;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemSurfaces.channel, null);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SystemSurfacesSettings()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('拒绝通知权限不会保存开启', (tester) async {
    permitted = false;
    await open(tester);
    await tester.tap(find.text('通知栏余额'));
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('setNotificationEnabled')));
    expect(find.text('未获通知权限，通知栏余额没有开启'), findsOneWidget);
    expect(state['notificationEnabled'], false);
  });

  testWidgets('频道关闭时回退开关并说明系统限制', (tester) async {
    state['notificationsAllowed'] = false;
    await open(tester);
    await tester.tap(find.text('通知栏余额'));
    await tester.pumpAndSettle();
    expect(state['notificationEnabled'], false);
    expect(find.textContaining('余额通知频道已关闭'), findsOneWidget);
  });

  testWidgets('开关即时保存且重开读取原生状态', (tester) async {
    await open(tester);
    await tester.tap(find.text('通知栏余额'));
    await tester.pumpAndSettle();
    expect(state['notificationEnabled'], true);
    await tester.pumpWidget(const SizedBox.shrink());
    await open(tester);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      true,
    );
    await tester.tap(find.text('通知栏余额'));
    await tester.pumpAndSettle();
    expect(state['notificationEnabled'], false);
  });

  testWidgets('添加取消不当成功且可以重试', (tester) async {
    await open(tester);
    await tester.tap(find.text('快捷设置入口'));
    await tester.pumpAndSettle();
    expect(state['tileEnabled'], true);
    expect(find.textContaining('已取消系统添加'), findsOneWidget);
    tileResult = 'added';
    await tester.tap(find.text('添加到系统快捷设置'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已添加快捷开关'), findsOneWidget);
    expect(calls.where((call) => call == 'requestAddTile').length, 2);
  });

  testWidgets('旧版启用后说明手动拖入不请求系统弹窗', (tester) async {
    state['tileAddSupported'] = false;
    await open(tester);
    await tester.tap(find.text('快捷设置入口'));
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('requestAddTile')));
    expect(find.textContaining('请下拉快捷设置'), findsOneWidget);
  });

  testWidgets('请求权限时重复点击及关闭页面安全', (tester) async {
    final response = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (_) => response.future);
    await open(tester);
    await tester.tap(find.text('通知栏余额'));
    await tester.pump();
    expect(
      tester
          .widget<SwitchListTile>(find.byType(SwitchListTile).first)
          .onChanged,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(true);
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('setNotificationEnabled')));
    expect(tester.takeException(), isNull);
  });
}
