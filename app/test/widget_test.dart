import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liuliang_app/main.dart';
import 'package:liuliang_app/services/widget_bridge.dart';

void main() {
  testWidgets('首次打开不显示虚构余额，可保存提醒阈值', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      WidgetBridge.channel,
      (call) async => call.method == 'consumeLaunchRefresh' ? false : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        WidgetBridge.channel,
        null,
      ),
    );
    await tester.pumpWidget(const FlowBuddyApp());
    await tester.pumpAndSettle();
    expect(find.text('中国移动'), findsWidgets);
    expect(find.text('中国广电'), findsWidgets);
    expect(find.textContaining('23.6'), findsNothing);
    await tester.ensureVisible(find.text('提醒设置'));
    await tester.tap(find.text('提醒设置'));
    await tester.pumpAndSettle();
    expect(find.text('照顾好你的流量'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('threshold_gb'), 5);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
