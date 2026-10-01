import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liuliang_app/main.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/ui/carrier_selection_screen.dart';
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

  testWidgets(
    'fresh install waits for an explicit choice and persists single carrier',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const FlowBuddyApp());
      await tester.pumpAndSettle();
      expect(find.byType(CarrierSelectionScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      var screen = tester.widget<CarrierSelectionScreen>(
        find.byType(CarrierSelectionScreen),
      );
      expect(screen.selectedCarriers, isEmpty);
      screen.onSelectionChanged({Carrier.mobile});
      await tester.pump();
      screen = tester.widget<CarrierSelectionScreen>(
        find.byType(CarrierSelectionScreen),
      );
      screen.onContinue(screen.selectedCarriers);
      await tester.pumpAndSettle();
      final dashboard = tester.widget<DashboardScreen>(
        find.byType(DashboardScreen),
      );
      expect(dashboard.snapshots.map((s) => s.carrier), [Carrier.mobile]);
      final prefs = await SharedPreferences.getInstance();
      final choice = CarrierSelection.restore(
        savedJson: prefs.getString('carrier_selection'),
        legacyPreferences: {},
      );
      expect(choice.selectedCarriers, {Carrier.mobile});
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const FlowBuddyApp());
      await tester.pumpAndSettle();
      expect(find.byType(CarrierSelectionScreen), findsNothing);
      expect(
        tester
            .widget<DashboardScreen>(find.byType(DashboardScreen))
            .snapshots
            .map((s) => s.carrier),
        [Carrier.mobile],
      );
      tester
          .widget<DashboardScreen>(find.byType(DashboardScreen))
          .onManageCarriers!();
      await tester.pumpAndSettle();
      final manage = tester.widget<CarrierSelectionScreen>(
        find.byType(CarrierSelectionScreen),
      );
      expect(manage.isInitialSetup, isFalse);
      manage.onContinue({Carrier.broadnet});
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DashboardScreen>(find.byType(DashboardScreen))
            .snapshots
            .map((s) => s.carrier),
        [Carrier.broadnet],
      );
      expect(
        CarrierSelection.restore(
          savedJson: prefs.getString('carrier_selection'),
          legacyPreferences: {},
        ).selectedCarriers,
        {Carrier.broadnet},
      );
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'legacy connected carrier is migrated without showing an unused card',
    (tester) async {
      SharedPreferences.setMockInitialValues({'connected_broadnet': true});
      await tester.pumpWidget(const FlowBuddyApp());
      await tester.pumpAndSettle();
      expect(find.byType(CarrierSelectionScreen), findsNothing);
      expect(
        tester
            .widget<DashboardScreen>(find.byType(DashboardScreen))
            .snapshots
            .map((s) => s.carrier),
        [Carrier.broadnet],
      );
      expect(
        (await SharedPreferences.getInstance()).getString('carrier_selection'),
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('corrupt saved choice cannot reactivate legacy connected cards', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'carrier_selection': '{broken',
      'connected_mobile': true,
    });
    await tester.pumpWidget(const FlowBuddyApp());
    await tester.pumpAndSettle();
    expect(find.byType(CarrierSelectionScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  for (final supportsProfiles in [true, false]) {
    testWidgets(
      supportsProfiles
          ? 'same carrier second account is saved only with isolated WebView support'
          : 'unsupported WebView refuses second account without fake duplicate card',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        SharedPreferences.setMockInitialValues({});
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          const MethodChannel(
            'com.pichillilorenzo/flutter_inappwebview_webviewfeature',
          ),
          (call) async =>
              call.method == 'isFeatureSupported' ? supportsProfiles : null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('cn.liuliang/background_refresh_schedule'),
          (_) async => null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('cn.liuliang/widgets'),
          (call) async => call.method == 'consumeLaunchRefresh' ? false : null,
        );
        await tester.pumpWidget(const FlowBuddyApp());
        await tester.pumpAndSettle();
        var screen = tester.widget<CarrierSelectionScreen>(
          find.byType(CarrierSelectionScreen),
        );
        screen.onSelectionChanged({Carrier.mobile});
        await tester.pump();
        screen = tester.widget<CarrierSelectionScreen>(
          find.byType(CarrierSelectionScreen),
        );
        screen.onAddSecondAccount!(Carrier.mobile);
        await tester.pumpAndSettle();
        if (!supportsProfiles) {
          expect(find.text('这台手机暂不支持第二张同运营商卡'), findsOneWidget);
          await tester.tap(find.text('知道了'));
          await tester.pumpAndSettle();
        }
        screen = tester.widget<CarrierSelectionScreen>(
          find.byType(CarrierSelectionScreen),
        );
        // Profile capability was checked above; keep this unit test focused on
        // persisted account selection rather than native widget channels.
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        screen.onContinue(screen.selectedCarriers);
        await tester.pumpAndSettle();
        final dashboard = tester.widget<DashboardScreen>(
          find.byType(DashboardScreen),
        );
        expect(dashboard.accountEntries?.length, supportsProfiles ? 2 : 1);
        final prefs = await SharedPreferences.getInstance();
        final accounts = CarrierAccounts.restore(
          savedJson: prefs.getString(CarrierAccounts.storageKey),
          selection: CarrierSelection.complete([Carrier.mobile]),
        );
        expect(accounts.find('mobile_2') != null, supportsProfiles);
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets(
    'interrupted clear stays pending even after profile deletion succeeds',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({
        'account_profiles_cleanup_pending': true,
        'carrier_selection': CarrierSelection.complete([
          Carrier.mobile,
        ]).toStorageString(),
        'connected_mobile': true,
      });
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(
          'com.pichillilorenzo/flutter_inappwebview_webviewfeature',
        ),
        (call) async => call.method == 'deleteAccountProfiles' ? true : null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('cn.liuliang/background_refresh_schedule'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('cn.liuliang/widgets'),
        (call) async => call.method == 'consumeLaunchRefresh' ? false : null,
      );
      await tester.pumpWidget(const FlowBuddyApp());
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'account_profiles_cleanup_pending',
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
