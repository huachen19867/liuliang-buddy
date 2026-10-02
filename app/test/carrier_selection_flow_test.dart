import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/main.dart';
import 'package:liuliang_app/ui/carrier_selection_screen.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const featureChannel = MethodChannel(
    'com.pichillilorenzo/flutter_inappwebview_webviewfeature',
  );
  const widgetChannel = MethodChannel('cn.liuliang/widgets');
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  var supportsProfiles = true;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    supportsProfiles = true;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      featureChannel,
      (call) async =>
          call.method == 'isFeatureSupported' ? supportsProfiles : null,
    );
    messenger.setMockMethodCallHandler(
      widgetChannel,
      (call) async => call.method == 'consumeLaunchRefresh' ? false : null,
    );
    messenger.setMockMethodCallHandler(secureChannel, (_) async => null);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [featureChannel, widgetChannel, secureChannel]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  CarrierSelectionScreen screen(WidgetTester tester) => tester
      .widget<CarrierSelectionScreen>(find.byType(CarrierSelectionScreen));

  Future<void> choose(WidgetTester tester, Map<Carrier, int> counts) async {
    screen(tester).onSelectionChanged(counts.keys.toSet());
    await tester.pump();
    screen(tester).onAccountCountsChanged!(counts);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    // Capability is already checked. Avoid platform views and native widget
    // calls while testing account persistence rather than Android rendering.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final selection = screen(tester);
    selection.onContinue(selection.selectedCarriers);
    await tester.pumpAndSettle();
  }

  for (final count in [3, 4]) {
    testWidgets('首次保存同家$count张并在重启后保持稳定ID', (tester) async {
      await tester.pumpWidget(const FlowBuddyApp());
      await tester.pumpAndSettle();
      await choose(tester, {Carrier.mobile: count});
      expect(screen(tester).accountCounts[Carrier.mobile], count);
      await save(tester);
      final ids = [
        for (var slot = 1; slot <= count; slot++)
          CarrierAccount.idFor(Carrier.mobile, slot),
      ];
      expect(
        tester
            .widget<DashboardScreen>(find.byType(DashboardScreen))
            .accountEntries!
            .map((entry) => entry.account.id),
        ids,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const FlowBuddyApp());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DashboardScreen>(find.byType(DashboardScreen))
            .accountEntries!
            .map((entry) => entry.account.id),
        ids,
      );
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  for (final count in [2, 3]) {
    testWidgets('混合${count + 1}张保留各家独立数量', (tester) async {
      await tester.pumpWidget(const FlowBuddyApp());
      await tester.pumpAndSettle();
      await choose(tester, {Carrier.mobile: count, Carrier.unicom: 1});
      await save(tester);
      final dashboard = tester.widget<DashboardScreen>(
        find.byType(DashboardScreen),
      );
      expect(dashboard.accountEntries, hasLength(count + 1));
      expect(
        dashboard.accountEntries!.where(
          (entry) => entry.account.carrier == Carrier.mobile,
        ),
        hasLength(count),
      );
      expect(
        dashboard.accountEntries!.where(
          (entry) => entry.account.carrier == Carrier.unicom,
        ),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('不支持独立profile时拒绝同家四张并保留一张', (tester) async {
    supportsProfiles = false;
    await tester.pumpWidget(const FlowBuddyApp());
    await tester.pumpAndSettle();
    await choose(tester, {Carrier.mobile: 4});
    expect(find.text('这台手机暂不支持同运营商的额外号码'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(screen(tester).accountCounts[Carrier.mobile] ?? 1, 1);
    await save(tester);
    expect(
      tester
          .widget<DashboardScreen>(find.byType(DashboardScreen))
          .accountEntries,
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('管理数量减少保留旧备注和缓存，再加入复用相同账号', (tester) async {
    final selection = CarrierSelection.complete([Carrier.mobile]);
    final accounts = CarrierAccounts.fromSelection(selection)
        .withCount(Carrier.mobile, 4)
        .updateIdentity('mobile_4', note: '工作号码', phoneNumber: '13800138000');
    SharedPreferences.setMockInitialValues({
      'carrier_selection': selection.toStorageString(),
      CarrierAccounts.storageKey: accounts.toStorageString(),
      'snapshot_mobile_4': 'history-marker',
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(const FlowBuddyApp());
    await tester.pumpAndSettle();
    tester
        .widget<DashboardScreen>(find.byType(DashboardScreen))
        .onManageCarriers!();
    await tester.pumpAndSettle();
    screen(tester).onAccountCountsChanged!({Carrier.mobile: 2});
    await tester.pumpAndSettle();
    await save(tester);
    final prefs = await SharedPreferences.getInstance();
    final hidden = CarrierAccounts.restore(
      savedJson: prefs.getString(CarrierAccounts.storageKey),
      selection: selection,
    );
    expect(hidden.find('mobile_4')!.note, '工作号码');
    expect(hidden.find('mobile_4')!.enabled, isFalse);
    expect(prefs.getString('snapshot_mobile_4'), 'history-marker');
    tester
        .widget<DashboardScreen>(find.byType(DashboardScreen))
        .onManageCarriers!();
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    screen(tester).onAccountCountsChanged!({Carrier.mobile: 4});
    await tester.pumpAndSettle();
    await save(tester);
    final reopened = CarrierAccounts.restore(
      savedJson: prefs.getString(CarrierAccounts.storageKey),
      selection: selection,
    );
    expect(reopened.visibleCount(selection), 4);
    expect(reopened.find('mobile_4')!.note, '工作号码');
    expect(reopened.find('mobile_4')!.profileName, 'liuliang_mobile_4');
    expect(prefs.getString('snapshot_mobile_4'), 'history-marker');
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
