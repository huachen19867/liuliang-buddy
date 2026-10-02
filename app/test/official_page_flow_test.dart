import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/main.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('十六个合法账号的低量通知ID互不覆盖', () {
    final ids = <int>{};
    for (final carrier in Carrier.values) {
      final accounts = CarrierAccounts.fromSelection(
        CarrierSelection.complete([carrier]),
      ).withCount(carrier, 4);
      for (final account in accounts.accounts) {
        expect(ids.add(accountLowTrafficNotificationId(account)), isTrue);
      }
    }
    expect(ids, hasLength(16));
  });

  test('联通使用原生100%初始显示并允许缩放，保留独立Profile', () {
    final settings = officialPageSettings(
      Carrier.unicom,
      profileName: 'liuliang_unicom_4',
    );
    expect(settings.supportZoom, isTrue);
    expect(settings.builtInZoomControls, isTrue);
    expect(settings.displayZoomControls, isTrue);
    expect(settings.enableViewportScale, isTrue);
    expect(settings.loadWithOverviewMode, isFalse);
    expect(settings.initialScale, 100);
    expect(settings.toMap()['liuliangAccountProfile'], 'liuliang_unicom_4');
    expect(settings.userAgent, anyOf(isNull, isEmpty));
  });

  testWidgets('连接页没有加载回调时35秒内退出连接中并保留旧余额时间', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const widgets = MethodChannel('cn.liuliang/widgets');
    const secure = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(widgets, (_) async => null);
    messenger.setMockMethodCallHandler(secure, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(widgets, null);
      messenger.setMockMethodCallHandler(secure, null);
    });
    final selection = CarrierSelection.complete([Carrier.unicom]);
    final at = DateTime(2026, 10, 2, 8);
    final old = CarrierSnapshot(
      carrier: Carrier.unicom,
      status: QueryStatus.success,
      queriedAt: at,
      balanceYuan: 12.30,
    );
    SharedPreferences.setMockInitialValues({
      'carrier_selection': selection.toStorageString(),
      'snapshot_unicom': jsonEncode(old.toJson()),
    });
    await tester.pumpWidget(const FlowBuddyApp());
    await tester.pumpAndSettle();
    final dashboard = tester.widget<DashboardScreen>(
      find.byType(DashboardScreen),
    );
    // Exercise the real connection state and deadline, with no platform view
    // load callback. Platform rendering itself is outside this unit test.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    dashboard.onConnectAccount!('unicom');
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pump();
    expect(
      tester
          .widget<DashboardScreen>(find.byType(DashboardScreen))
          .accountEntries!
          .single
          .snapshot!
          .status,
      QueryStatus.loading,
    );
    await tester.pump(const Duration(seconds: 36));
    await tester.pumpAndSettle();
    final settled = tester
        .widget<DashboardScreen>(find.byType(DashboardScreen))
        .accountEntries!
        .single
        .snapshot!;
    expect(settled.status, QueryStatus.error);
    expect(settled.message, contains('加载超时'));
    expect(settled.queriedAt, at);
    expect(settled.balanceYuan, 12.30);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
