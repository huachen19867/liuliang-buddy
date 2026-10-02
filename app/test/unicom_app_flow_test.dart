import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/main.dart';
import 'package:liuliang_app/services/unicom_app_client.dart';
import 'package:liuliang_app/ui/account_identity_dialog.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _phones = ['18600000001', '18600000002'];
final _oldAt = DateTime(2026, 10, 2, 8);

UnicomAppResponse _package(int mb) => UnicomAppResponse(
  200,
  jsonEncode({
    'code': '0000',
    'resources': [
      {
        'type': 'flow',
        'details': [
          {
            'feePolicyName': '国内通用流量',
            'unit': 'MB',
            'total': '4096',
            'use': '${4096 - mb}',
            'remain': '$mb',
          },
        ],
      },
    ],
  }),
);

DashboardScreen _dashboard(WidgetTester tester) =>
    tester.widget<DashboardScreen>(find.byType(DashboardScreen));

void main() {
  late Map<String, String> secureValues;
  late List<Map<Object?, Object?>> widgetUpdates;
  const channels = [
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    MethodChannel('cn.liuliang/widgets'),
    MethodChannel('cn.liuliang/background_refresh_schedule'),
    MethodChannel('cn.liuliang/notifications'),
  ];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    secureValues = {};
    widgetUpdates = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channels[0], (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return secureValues[key];
        case 'write':
          secureValues[key!] = args['value'] as String;
          return null;
        case 'delete':
          secureValues.remove(key);
          return null;
        case 'deleteAll':
          secureValues.clear();
          return null;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(channels[1], (call) async {
      if (call.method == 'updateSnapshot') {
        widgetUpdates.add(Map<Object?, Object?>.from(call.arguments as Map));
      }
      return null;
    });
    messenger.setMockMethodCallHandler(channels[2], (_) async => null);
    messenger.setMockMethodCallHandler(channels[3], (_) async => null);
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
    WidgetTester tester,
    UnicomAppClient client, {
    int count = 1,
    bool settle = true,
  }) async {
    final selection = CarrierSelection.complete([Carrier.unicom]);
    var accounts = CarrierAccounts.fromSelection(
      selection,
    ).withCount(Carrier.unicom, count);
    for (var index = 0; index < count; index++) {
      final id = CarrierAccount.idFor(Carrier.unicom, index + 1);
      accounts = accounts.updateIdentity(
        id,
        note: '测试卡 ${index + 1}',
        phoneNumber: _phones[index],
      );
      secureValues[UnicomAppSession.storageKey(id)] = jsonEncode(
        UnicomAppSession.import(
          'test_session=card${index + 1}',
          phoneNumber: _phones[index],
          confirmedCookieOwner: true,
        ).toJson(),
      );
    }
    final initial = <String, Object>{
      'carrier_selection': selection.toStorageString(),
      CarrierAccounts.storageKey: accounts.toStorageString(),
    };
    for (final account in accounts.accounts) {
      initial[account.connectedKey] = true;
      initial['unicom_query_method_${account.id}'] = 'app';
      initial[account.snapshotKey] = jsonEncode(
        CarrierSnapshot(
          carrier: Carrier.unicom,
          status: QueryStatus.success,
          queriedAt: _oldAt,
          balanceYuan: 12.30,
          buckets: const [
            TrafficBucket(
              name: '旧通用流量',
              kind: BucketKind.general,
              remainingBytes: 64 * 1024 * 1024,
              totalBytes: 4096 * 1024 * 1024,
            ),
          ],
        ).toJson(),
      );
    }
    SharedPreferences.setMockInitialValues(initial);
    await tester.pumpWidget(
      MaterialApp(home: FlowHome(unicomAppClient: client)),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(InAppWebView), findsNothing);
  }

  testWidgets('双联通 App 会话分别查询并把各自余量发布到桌面', (tester) async {
    final requests = <UnicomAppRequest>[];
    final client = UnicomAppClient(
      transport: (request) async {
        requests.add(request);
        final first = request.session.phoneNumber == _phones.first;
        if (request.url == UnicomAppClient.packageUrl) {
          return _package(first ? 512 : 1024);
        }
        return UnicomAppResponse(
          200,
          jsonEncode({
            'code': '0000',
            'curntbalancecust': first ? '10.00' : '20.00',
          }),
        );
      },
    );
    await mount(tester, client, count: 2);
    // App sessions refresh on launch without needing a hidden E5 WebView.
    expect(requests, hasLength(4));
    _dashboard(tester).onRefreshAll();
    await tester.pumpAndSettle();
    expect(requests, hasLength(4)); // A rapid second tap is throttled.
    final entries = _dashboard(tester).accountEntries!;
    expect(
      entries.map((e) => e.snapshot!.status),
      everyElement(QueryStatus.success),
    );
    expect(entries.map((e) => e.snapshot!.buckets.single.remainingBytes), [
      512 * 1024 * 1024,
      1024 * 1024 * 1024,
    ]);
    expect(entries.map((e) => e.snapshot!.balanceYuan), [10, 20]);
    final packageRequests = requests.where(
      (r) => r.url == UnicomAppClient.packageUrl,
    );
    expect(
      packageRequests.map((r) => r.session.phoneNumber),
      unorderedEquals(_phones),
    );
    expect(
      packageRequests.map((r) => r.session.cookie),
      unorderedEquals(['test_session=card1', 'test_session=card2']),
    );
    final instances = widgetUpdates.last['instances'] as List;
    expect(instances.map((e) => (e as Map)['accountId']), [
      'unicom',
      'unicom_2',
    ]);
    expect(instances.map((e) => (e as Map)['generalRemainingBytes']), [
      512 * 1024 * 1024,
      1024 * 1024 * 1024,
    ]);
    expect(jsonEncode(widgetUpdates), isNot(contains('test_session')));
    expect(jsonEncode(widgetUpdates), isNot(contains(_phones.first)));
    expect(find.byType(InAppWebView), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('App 认证失效保留旧余量余额及时间并记下后台登录门禁', (tester) async {
    final client = UnicomAppClient(
      transport: (_) async => const UnicomAppResponse(200, '999999'),
    );
    await mount(tester, client);
    final originalSession = secureValues['unicom_app_session_unicom'];
    _dashboard(tester).onRefreshAccount!('unicom');
    await tester.pumpAndSettle();
    final snapshot = _dashboard(tester).accountEntries!.single.snapshot!;
    expect(snapshot.status, QueryStatus.authExpired);
    expect(snapshot.queriedAt, _oldAt);
    expect(snapshot.balanceYuan, 12.30);
    expect(snapshot.buckets.single.remainingBytes, 64 * 1024 * 1024);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('background_auth_required_unicom'), isTrue);
    final saved = CarrierSnapshot.fromJson(
      jsonDecode(prefs.getString('snapshot_unicom')!) as Map<String, dynamic>,
    );
    expect(saved.status, QueryStatus.authExpired);
    expect(saved.queriedAt, _oldAt);
    expect(secureValues['unicom_app_session_unicom'], originalSession);
    expect(find.byType(InAppWebView), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('编辑号码后在途 App 响应不能覆盖新号码卡片或持久记录', (tester) async {
    final pending = Completer<UnicomAppResponse>();
    final requests = <UnicomAppRequest>[];
    final client = UnicomAppClient(
      transport: (request) {
        requests.add(request);
        if (request.url == UnicomAppClient.packageUrl) return pending.future;
        return Future.value(
          const UnicomAppResponse(
            200,
            '{"code":"0000","curntbalancecust":"99.00"}',
          ),
        );
      },
    );
    await mount(tester, client, settle: false);
    _dashboard(tester).onRefreshAccount!('unicom');
    // Advance microtasks without waiting for the intentionally pending request.
    await tester.pump();
    await tester.pump();
    expect(requests, hasLength(1));
    _dashboard(tester).onEditAccount!('unicom');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final dialog = find.byType(AccountIdentityDialog);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextFormField)).at(1),
      _phones[1],
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('保存')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    final savedBeforeResponse = prefs.getString('snapshot_unicom');
    final secureBeforeResponse = Map<String, String>.from(secureValues);
    pending.complete(_package(3072));
    await tester.pumpAndSettle();
    final entry = _dashboard(tester).accountEntries!.single;
    expect(entry.account.phoneNumber, _phones[1]);
    expect(entry.snapshot!.status, isNot(QueryStatus.loading));
    expect(
      entry.snapshot!.buckets.any(
        (b) => b.remainingBytes == 3072 * 1024 * 1024,
      ),
      isFalse,
    );
    expect(entry.snapshot!.balanceYuan, isNot(99));
    expect(prefs.getString('snapshot_unicom'), savedBeforeResponse);
    expect(secureValues, secureBeforeResponse);
    expect(find.byType(InAppWebView), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
