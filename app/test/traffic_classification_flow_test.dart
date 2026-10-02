import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/traffic_classification.dart';
import 'package:liuliang_app/main.dart';
import 'package:liuliang_app/services/unicom_app_client.dart';
import 'package:liuliang_app/ui/account_identity_dialog.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gib = 1073741824;
final _at = DateTime(2026, 10, 2, 9);
const _bucket = TrafficBucket(
  name: '随心流量包',
  kind: BucketKind.unknown,
  remainingBytes: _gib,
  totalBytes: 2 * _gib,
  rawUnit: 'MB',
);

DashboardScreen _dashboard(WidgetTester tester) =>
    tester.widget<DashboardScreen>(find.byType(DashboardScreen));

void main() {
  late List<Map<Object?, Object?>> updates;
  late Map<String, String> secure;
  const channels = [
    MethodChannel('cn.liuliang/widgets'),
    MethodChannel('cn.liuliang/background_refresh_schedule'),
    MethodChannel('cn.liuliang/notifications'),
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
  ];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    updates = [];
    secure = {};
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channels[0], (call) async {
      if (call.method == 'updateSnapshot') {
        updates.add(Map<Object?, Object?>.from(call.arguments as Map));
      }
      return null;
    });
    messenger.setMockMethodCallHandler(channels[1], (_) async => null);
    messenger.setMockMethodCallHandler(channels[2], (_) async => null);
    messenger.setMockMethodCallHandler(channels[3], (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String?;
      if (call.method == 'read') return secure[key];
      if (call.method == 'write') secure[key!] = args['value'] as String;
      if (call.method == 'delete') secure.remove(key);
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  Future<void> mount(
    WidgetTester tester, {
    UnicomAppClient? client,
    bool pending = false,
  }) async {
    final selection = CarrierSelection.complete([Carrier.unicom]);
    final accounts = CarrierAccounts.fromSelection(selection)
        .withCount(Carrier.unicom, 2)
        .updateIdentity('unicom', note: '', phoneNumber: '18600000001')
        .updateIdentity('unicom_2', note: '', phoneNumber: '18600000002');
    final initial = <String, Object>{
      'carrier_selection': selection.toStorageString(),
      CarrierAccounts.storageKey: accounts.toStorageString(),
    };
    for (final account in accounts.accounts) {
      initial[account.snapshotKey] = jsonEncode(
        CarrierSnapshot(
          carrier: Carrier.unicom,
          status: QueryStatus.success,
          queriedAt: _at,
          buckets: const [_bucket],
        ).toJson(),
      );
    }
    if (client != null) {
      initial['connected_unicom'] = true;
      initial['unicom_query_method_unicom'] = 'app';
      secure[UnicomAppSession.storageKey('unicom')] = jsonEncode(
        UnicomAppSession.import(
          'sample_session=test',
          phoneNumber: '18600000001',
          confirmedCookieOwner: true,
        ).toJson(),
      );
    }
    SharedPreferences.setMockInitialValues(initial);
    await tester.pumpWidget(
      MaterialApp(home: FlowHome(unicomAppClient: client)),
    );
    if (pending) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> finish(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('电信旧缓存启动即按名称重分类并同步现有桌面', (tester) async {
    final selection = CarrierSelection.complete([Carrier.telecom]);
    final accounts = CarrierAccounts.fromSelection(selection);
    final account = accounts.accounts.single;
    final snapshot = CarrierSnapshot(
      carrier: Carrier.telecom,
      status: QueryStatus.success,
      queriedAt: _at,
      buckets: const [
        TrafficBucket(
          name: '国内上网含10GB',
          kind: BucketKind.general,
          remainingBytes: 2 * _gib,
          totalBytes: 10 * _gib,
          rawUnit: 'B',
        ),
        TrafficBucket(
          name: '定向国内上网流量',
          kind: BucketKind.unknown,
          remainingBytes: 3 * _gib,
          totalBytes: 10 * _gib,
          rawUnit: 'B',
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'carrier_selection': selection.toStorageString(),
      CarrierAccounts.storageKey: accounts.toStorageString(),
      account.snapshotKey: jsonEncode(snapshot.toJson()),
    });
    await tester.pumpWidget(MaterialApp(home: FlowHome()));
    await tester.pumpAndSettle();
    final restored = _dashboard(tester).accountEntries!.single.snapshot!;
    expect(restored.buckets[0].effectiveKind, BucketKind.unknown);
    expect(restored.buckets[1].effectiveKind, BucketKind.directed);
    expect(restored.queriedAt, _at);
    expect(restored.generalRemainingBytes, isNull);
    final row = (updates.last['instances'] as List).single as Map;
    expect(row['otherRemainingBytes'], 2 * _gib);
    expect(row['directedRemainingBytes'], 3 * _gib);
    expect(row['generalRemainingBytes'], isNull);
    expect(row['queriedAt'], _at.millisecondsSinceEpoch);
    await finish(tester);
  });

  testWidgets('应用内分类立即同步组件，仅影响当前账号，重启保留且可恢复自动', (tester) async {
    await mount(tester);
    final before = _dashboard(tester);
    expect(
      await before.onClassifyBucket!('unicom', _bucket, BucketKind.general),
      isTrue,
    );
    await tester.pumpAndSettle();
    final entries = _dashboard(tester).accountEntries!;
    expect(entries.first.snapshot!.buckets.single.kind, BucketKind.unknown);
    expect(
      entries.first.snapshot!.buckets.single.manualKind,
      BucketKind.general,
    );
    expect(entries.last.snapshot!.buckets.single.manualKind, isNull);
    expect(entries.first.snapshot!.queriedAt, _at);
    final instances = updates.last['instances'] as List;
    expect((instances.first as Map)['generalRemainingBytes'], _gib);
    expect((instances.last as Map)['generalRemainingBytes'], isNull);
    final prefs = await SharedPreferences.getInstance();
    final storedSnapshot = prefs.getString('snapshot_unicom');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(home: FlowHome()));
    await tester.pumpAndSettle();
    expect(
      _dashboard(
        tester,
      ).accountEntries!.first.snapshot!.buckets.single.manualKind,
      BucketKind.general,
    );
    expect(
      await _dashboard(tester).onClassifyBucket!('unicom', _bucket, null),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(
      _dashboard(
        tester,
      ).accountEntries!.first.snapshot!.buckets.single.manualKind,
      isNull,
    );
    expect(prefs.getString('snapshot_unicom'), storedSnapshot);
    expect(
      ((updates.last['instances'] as List).first
          as Map)['generalRemainingBytes'],
      isNull,
    );
    await finish(tester);
  });

  testWidgets('正在查询时修改分类，新响应仍按最新选择同步卡片', (tester) async {
    final response = Completer<UnicomAppResponse>();
    final client = UnicomAppClient(
      transport: (request) => request.url == UnicomAppClient.packageUrl
          ? response.future
          : Future.value(
              const UnicomAppResponse(
                200,
                '{"code":"0000","curntbalancecust":"10.00"}',
              ),
            ),
    );
    await mount(tester, client: client, pending: true);
    expect(
      await _dashboard(tester).onClassifyBucket!(
        'unicom',
        _bucket,
        BucketKind.directed,
      ),
      isTrue,
    );
    response.complete(
      UnicomAppResponse(
        200,
        jsonEncode({
          'code': '0000',
          'resources': [
            {
              'type': 'flow',
              'details': [
                {
                  'feePolicyName': _bucket.name,
                  'unit': 'MB',
                  'total': '2048',
                  'remain': '512',
                },
              ],
            },
          ],
        }),
      ),
    );
    await tester.pumpAndSettle();
    final snapshot = _dashboard(tester).accountEntries!.first.snapshot!;
    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.buckets.single.effectiveKind, BucketKind.directed);
    expect(snapshot.buckets.single.remainingBytes, _gib ~/ 2);
    final instance = (updates.last['instances'] as List).first as Map;
    expect(instance['directedRemainingBytes'], _gib ~/ 2);
    expect(instance['generalRemainingBytes'], isNull);
    await finish(tester);
  });

  testWidgets('改备注保留分类，换号码清除分类并拒绝旧弹窗保存', (tester) async {
    await mount(tester);
    await _dashboard(tester).onClassifyBucket!(
      'unicom',
      _bucket,
      BucketKind.general,
    );
    await tester.pumpAndSettle();
    Future<void> edit({String? note, String? phone}) async {
      _dashboard(tester).onEditAccount!('unicom');
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AccountIdentityDialog),
        matching: find.byType(TextFormField),
      );
      if (note != null) await tester.enterText(fields.at(0), note);
      if (phone != null) await tester.enterText(fields.at(1), phone);
      await tester.tap(
        find.descendant(
          of: find.byType(AccountIdentityDialog),
          matching: find.text('保存'),
        ),
      );
      await tester.pumpAndSettle();
    }

    await edit(note: '上网卡');
    expect(
      _dashboard(
        tester,
      ).accountEntries!.first.snapshot!.buckets.single.manualKind,
      BucketKind.general,
    );
    final staleSave = _dashboard(tester).onClassifyBucket!;
    await edit(phone: '18600000003');
    expect(
      _dashboard(
        tester,
      ).accountEntries!.first.snapshot!.buckets.single.manualKind,
      isNull,
    );
    expect(await staleSave('unicom', _bucket, BucketKind.directed), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(
      TrafficClassificationOverrides.restore(
            prefs.getString(TrafficClassificationOverrides.storageKey),
          )
          .apply('unicom', _dashboard(tester).accountEntries!.first.snapshot!)
          .buckets
          .single
          .manualKind,
      isNull,
    );
    await finish(tester);
  });
}
