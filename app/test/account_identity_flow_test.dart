import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/main.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  testWidgets('editing account identity validates, persists and restores', (
    tester,
  ) async {
    final selection = CarrierSelection.complete([Carrier.mobile]);
    SharedPreferences.setMockInitialValues({
      'carrier_selection': selection.toStorageString(),
    });
    await tester.pumpWidget(const FlowBuddyApp());
    await tester.pumpAndSettle();
    tester.widget<DashboardScreen>(find.byType(DashboardScreen)).onEditAccount!(
      'mobile',
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '主卡');
    await tester.enterText(fields.at(1), 'invalid');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入 7–15 位数字，可在开头加 +'), findsOneWidget);
    await tester.enterText(fields.at(1), '13812345678');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final dashboard = tester.widget<DashboardScreen>(
      find.byType(DashboardScreen),
    );
    expect(dashboard.accountEntries!.single.account.displayName, '主卡');
    expect(dashboard.accountEntries!.single.account.phoneHint, '138****5678');
    final prefs = await SharedPreferences.getInstance();
    final restored = CarrierAccounts.restore(
      savedJson: prefs.getString(CarrierAccounts.storageKey),
      selection: selection,
    );
    expect(restored.find('mobile')!.phoneNumber, '13812345678');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const FlowBuddyApp());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DashboardScreen>(find.byType(DashboardScreen))
          .accountEntries!
          .single
          .account
          .displayName,
      '主卡',
    );
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
