import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/main.dart';
import 'package:liuliang_app/ui/carrier_selection_screen.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS setup, cached dashboard and manual widget entry', (
    tester,
  ) async {
    // Keep this smoke run free of real account state and official page logins.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FlowBuddyApp());
    await tester.pumpAndSettle();

    expect(find.byType(CarrierSelectionScreen), findsOneWidget);
    expect(find.text('先选好你的运营商'), findsOneWidget);
    expect(await binding.takeScreenshot('ios-selection'), isNotEmpty);

    await tester.tap(find.byKey(const ValueKey('carrier-option-mobile')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('carrier-selection-continue')),
    );
    await tester.tap(find.byKey(const ValueKey('carrier-selection-continue')));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    final dashboard = tester.widget<DashboardScreen>(
      find.byType(DashboardScreen),
    );
    expect(dashboard.accountEntries, hasLength(1));
    expect(
      dashboard.accountEntries!.single.snapshot?.status,
      QueryStatus.notConnected,
    );
    expect(await binding.takeScreenshot('ios-dashboard'), isNotEmpty);

    await tester.ensureVisible(find.text('添加桌面卡片'));
    await tester.tap(find.text('添加桌面卡片'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请长按 iPhone 主屏幕空白处'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('提醒设置'));
    await tester.tap(find.text('提醒设置'));
    await tester.pumpAndSettle();
    expect(find.text('桌面卡片后台刷新'), findsNothing);
    expect(find.textContaining('iOS 暂无定时后台官网查询'), findsOneWidget);
  });
}
