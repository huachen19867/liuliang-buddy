import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/services/widget_bridge.dart';

void main() {
  final time = DateTime.utc(2026, 9, 30, 6, 30);
  const previewBytes = 29527900160; // One package: 27.5 GiB.
  const confirmedPackage = TrafficBucket(
    name: '官网套餐 A',
    kind: BucketKind.unknown,
    remainingBytes: previewBytes,
    rawUnit: 'GB',
  );
  const pendingPackage = TrafficBucket(
    name: '官网套餐 B',
    kind: BucketKind.unknown,
    rawRemaining: '待确认',
  );

  Map<String, Object?> accountPayload(CarrierSnapshot snapshot) {
    final selection = CarrierSelection.complete([snapshot.carrier]);
    return buildWidgetPayload(
      [snapshot],
      thresholdGb: 5,
      selection: selection,
      accounts: CarrierAccounts.fromSelection(selection),
      accountSnapshots: {snapshot.carrier.name: snapshot},
    );
  }

  test(
    'partial Telecom carries one package preview without any partial sum',
    () {
      final snapshot = CarrierSnapshot(
        carrier: Carrier.telecom,
        status: QueryStatus.success,
        queriedAt: time,
        phoneMasked: 'private phone hint',
        buckets: const [
          confirmedPackage,
          TrafficBucket(
            name: '另一条可读套餐',
            kind: BucketKind.unknown,
            remainingBytes: 10737418240,
            rawUnit: 'GB',
          ),
          pendingPackage,
        ],
      );
      final legacy = buildWidgetPayload([snapshot], thresholdGb: 5);
      final accounts = accountPayload(snapshot);
      final instance = (accounts['instances'] as List).single as Map;
      for (final row in [
        legacy['telecom'] as Map,
        accounts['telecom'] as Map,
        instance,
      ]) {
        expect(row['trafficReadableCount'], 2);
        expect(row['trafficPendingCount'], 1);
        expect(row['previewRemainingBytes'], previewBytes);
        expect(row['previewUnlimited'], isFalse);
        expect(row.keys, isNot(contains('phoneMasked')));
        expect(row.keys, isNot(contains('trafficPreview')));
      }
      expect((legacy['telecom'] as Map)['remainingBytes'], isNull);
      expect(instance['primaryValue'], isNull);
      expect(instance['otherRemainingBytes'], isNull);
      expect(instance['otherState'], 'unavailable');
      expect(instance['generalRemainingBytes'], isNull);
    },
  );

  test(
    'manual partial group stays unavailable beside a single package preview',
    () {
      final payload = accountPayload(
        CarrierSnapshot(
          carrier: Carrier.telecom,
          status: QueryStatus.success,
          queriedAt: time,
          buckets: [
            confirmedPackage.copyWith(manualKind: BucketKind.general),
            pendingPackage.copyWith(manualKind: BucketKind.general),
          ],
        ),
      );
      final row = (payload['instances'] as List).single as Map;
      expect(row['primaryValue'], isNull);
      expect(row['generalRemainingBytes'], isNull);
      expect(row['generalState'], 'unavailable');
      expect(row['previewRemainingBytes'], previewBytes);
    },
  );

  test(
    'missing units, invalid bytes, unnamed and conflicting rows stay pending',
    () {
      final payload = accountPayload(
        CarrierSnapshot(
          carrier: Carrier.telecom,
          status: QueryStatus.success,
          queriedAt: time,
          buckets: [
            const TrafficBucket(
              name: '仅有数字',
              kind: BucketKind.unknown,
              remainingBytes: 42,
            ),
            confirmedPackage.copyWith(rawUnit: '分钟'),
            confirmedPackage.copyWith(name: '   '),
            confirmedPackage.copyWith(remainingBytes: -1),
            confirmedPackage.copyWith(totalBytes: -1),
            confirmedPackage.copyWith(totalBytes: previewBytes - 1),
            confirmedPackage.copyWith(isUnlimited: true),
            pendingPackage,
          ],
        ),
      );
      final row = (payload['instances'] as List).single as Map;
      expect(row['trafficReadableCount'], 0);
      expect(row['trafficPendingCount'], 8);
      expect(row['previewRemainingBytes'], isNull);
      expect(row['previewUnlimited'], isFalse);
      expect(row['primaryValue'], isNull);
    },
  );

  test('zero remains a confirmed individual package amount', () {
    final payload = accountPayload(
      CarrierSnapshot(
        carrier: Carrier.telecom,
        status: QueryStatus.success,
        queriedAt: time,
        buckets: [confirmedPackage.copyWith(remainingBytes: 0), pendingPackage],
      ),
    );
    final row = (payload['instances'] as List).single as Map;
    expect(row['previewRemainingBytes'], 0);
    expect(row['trafficReadableCount'], 1);
    expect(row['trafficPendingCount'], 1);
    expect(row['primaryValue'], isNull);
  });

  test(
    'explicit unlimited preview is a single package with no numeric amount',
    () {
      final payload = accountPayload(
        CarrierSnapshot(
          carrier: Carrier.telecom,
          status: QueryStatus.success,
          queriedAt: time,
          buckets: const [
            TrafficBucket(
              name: '官网明确不限量',
              kind: BucketKind.unknown,
              isUnlimited: true,
            ),
            pendingPackage,
          ],
        ),
      );
      final row = (payload['instances'] as List).single as Map;
      expect(row['trafficReadableCount'], 1);
      expect(row['trafficPendingCount'], 1);
      expect(row['previewUnlimited'], isTrue);
      expect(row['previewRemainingBytes'], isNull);
      expect(row['primaryValue'], isNull);
    },
  );

  test(
    'partial preview cache preserves loading, error and expired query metadata',
    () {
      for (final status in [
        QueryStatus.loading,
        QueryStatus.error,
        QueryStatus.authExpired,
      ]) {
        final payload = accountPayload(
          CarrierSnapshot(
            carrier: Carrier.telecom,
            status: status,
            queriedAt: time,
            buckets: const [confirmedPackage, pendingPackage],
          ),
        );
        for (final row in [
          payload['telecom'] as Map,
          (payload['instances'] as List).single as Map,
        ]) {
          expect(row['status'], status.name);
          expect(row['queriedAt'], time.millisecondsSinceEpoch);
          expect(row['previewRemainingBytes'], previewBytes);
          expect(row['trafficReadableCount'], 1);
          expect(row['trafficPendingCount'], 1);
        }
      }
    },
  );

  test('untimed and disconnected rows cannot become partial previews', () {
    for (final snapshot in [
      const CarrierSnapshot(
        carrier: Carrier.telecom,
        status: QueryStatus.loading,
        buckets: [confirmedPackage, pendingPackage],
      ),
      CarrierSnapshot(
        carrier: Carrier.telecom,
        status: QueryStatus.notConnected,
        queriedAt: time,
        buckets: const [confirmedPackage, pendingPackage],
      ),
    ]) {
      final payload = accountPayload(snapshot);
      for (final row in [
        payload['telecom'] as Map,
        (payload['instances'] as List).single as Map,
      ]) {
        expect(row['trafficReadableCount'], 0);
        expect(row['trafficPendingCount'], 0);
        expect(row['previewRemainingBytes'], isNull);
        expect(row['previewUnlimited'], isFalse);
      }
    }
  });

  test(
    'complete headline or no pending package does not request a preview',
    () {
      for (final buckets in [
        [confirmedPackage],
        [pendingPackage],
        [
          confirmedPackage.copyWith(manualKind: BucketKind.general),
          pendingPackage,
        ],
      ]) {
        final payload = accountPayload(
          CarrierSnapshot(
            carrier: Carrier.telecom,
            status: QueryStatus.success,
            queriedAt: time,
            buckets: buckets,
          ),
        );
        final row = (payload['instances'] as List).single as Map;
        expect(row['previewRemainingBytes'], isNull);
        expect(row['previewUnlimited'], isFalse);
      }
    },
  );

  test('other carriers cannot use the Telecom partial preview fallback', () {
    for (final carrier in [Carrier.mobile, Carrier.broadnet, Carrier.unicom]) {
      final payload = accountPayload(
        CarrierSnapshot(
          carrier: carrier,
          status: QueryStatus.success,
          queriedAt: time,
          buckets: const [confirmedPackage, pendingPackage],
        ),
      );
      final row = (payload['instances'] as List).single as Map;
      expect(row['trafficReadableCount'], 0);
      expect(row['trafficPendingCount'], 0);
      expect(row['previewRemainingBytes'], isNull);
      expect(row['previewUnlimited'], isFalse);
    }
  });

  test(
    'partial widget counts stay bounded while retaining the first package',
    () {
      final payload = accountPayload(
        CarrierSnapshot(
          carrier: Carrier.telecom,
          status: QueryStatus.success,
          queriedAt: time,
          buckets: [
            for (var index = 0; index < 250; index++) confirmedPackage,
            for (var index = 0; index < 250; index++) pendingPackage,
          ],
        ),
      );
      final row = (payload['instances'] as List).single as Map;
      expect(row['trafficReadableCount'], 200);
      expect(row['trafficPendingCount'], 200);
      expect(row['previewRemainingBytes'], previewBytes);
      expect(row['primaryValue'], isNull);
    },
  );
  test(
    'hidden history never occupies a widget slot or displaces selected accounts',
    () {
      final selection = CarrierSelection.complete([
        Carrier.mobile,
        Carrier.unicom,
      ]);
      final accounts = CarrierAccounts.fromSelection(selection)
          .withCount(Carrier.mobile, 4)
          .withCount(Carrier.mobile, 1)
          .withCount(Carrier.unicom, 3);
      final snapshots = <String, CarrierSnapshot>{
        for (final account in accounts.accounts)
          account.id: CarrierSnapshot(
            carrier: account.carrier,
            status: QueryStatus.success,
            queriedAt: time,
            buckets: [
              TrafficBucket(
                name: '通用',
                kind: BucketKind.general,
                remainingBytes: account.carrier.index * 100 + account.slot,
              ),
            ],
          ),
      };
      final payload = buildWidgetPayload(
        snapshots.values,
        thresholdGb: 5,
        selection: selection,
        accounts: accounts,
        accountSnapshots: snapshots,
      );
      final instances = payload['instances'] as List<Map<String, Object?>>;
      expect(instances.map((row) => row['accountId']), [
        'mobile',
        'unicom',
        'unicom_2',
        'unicom_3',
      ]);
      expect(instances.map((row) => row['primaryValue']), [
        1,
        Carrier.unicom.index * 100 + 1,
        Carrier.unicom.index * 100 + 2,
        Carrier.unicom.index * 100 + 3,
      ]);
      final restored = accounts.withCount(Carrier.mobile, 4);
      final mobileOnly = buildWidgetPayload(
        [],
        thresholdGb: 5,
        selection: CarrierSelection.complete([Carrier.mobile]),
        accounts: restored,
        accountSnapshots: snapshots,
      );
      expect(
        (mobileOnly['instances'] as List).map(
          (row) => (row as Map)['accountId'],
        ),
        ['mobile', 'mobile_2', 'mobile_3', 'mobile_4'],
      );
    },
  );
  test('secondary-only background result cannot fill the primary account', () {
    final selection = CarrierSelection.complete([Carrier.mobile]);
    final accounts = CarrierAccounts.fromSelection(
      selection,
    ).addSecond(Carrier.mobile);
    final secondary = CarrierSnapshot(
      carrier: Carrier.mobile,
      status: QueryStatus.success,
      queriedAt: time,
      buckets: const [
        TrafficBucket(
          name: '通用流量',
          kind: BucketKind.general,
          remainingBytes: 200,
        ),
      ],
    );
    final payload = buildWidgetPayload(
      [secondary],
      thresholdGb: 5,
      selection: selection,
      accounts: accounts,
      accountSnapshots: {'mobile_2': secondary},
    );
    final instances = payload['instances'] as List;
    expect((instances[0] as Map)['status'], 'notConnected');
    expect((instances[0] as Map)['primaryValue'], isNull);
    expect((instances[1] as Map)['primaryValue'], 200);
    expect((payload['mobile'] as Map)['remainingBytes'], isNull);

    final mismatched = CarrierSnapshot(
      carrier: Carrier.unicom,
      status: QueryStatus.success,
      queriedAt: time,
    );
    final bad = buildWidgetPayload(
      [secondary],
      thresholdGb: 5,
      selection: selection,
      accounts: accounts,
      accountSnapshots: {'mobile': mismatched, 'mobile_2': secondary},
    );
    expect(((bad['instances'] as List)[0] as Map)['status'], 'notConnected');
  });
  test(
    'expired widget cache retains the original query time and explicit status',
    () {
      final payload = buildWidgetPayload([
        CarrierSnapshot(
          carrier: Carrier.mobile,
          status: QueryStatus.authExpired,
          queriedAt: time,
          phoneMasked: '138****1234',
          buckets: const [
            TrafficBucket(
              name: '通用流量',
              kind: BucketKind.general,
              remainingBytes: 0,
            ),
            TrafficBucket(
              name: '定向流量',
              kind: BucketKind.directed,
              remainingBytes: 1000000,
            ),
          ],
        ),
      ], thresholdGb: 5);
      final mobile = payload['mobile'] as Map<String, Object?>;
      expect(mobile['remainingBytes'], 0);
      expect(mobile['status'], 'authExpired');
      expect(mobile['queriedAt'], time.millisecondsSinceEpoch);
      expect(mobile.keys, isNot(contains('phoneMasked')));
      expect((payload['broadnet'] as Map)['remainingBytes'], isNull);
      expect((payload['broadnet'] as Map)['status'], 'notConnected');
      expect(
        payload['selectedCarriers'],
        Carrier.values.map((item) => item.name),
      );
    },
  );

  test('packages without verified units are never partially summed', () {
    const packages = [
      TrafficBucket(name: '套餐A', kind: BucketKind.unknown, remainingBytes: 42),
      TrafficBucket(name: '套餐B', kind: BucketKind.unknown, remainingBytes: 80),
    ];
    final payload = buildWidgetPayload([
      CarrierSnapshot(
        carrier: Carrier.broadnet,
        status: QueryStatus.success,
        queriedAt: time,
        buckets: packages,
      ),
    ], thresholdGb: 5);
    expect((payload['broadnet'] as Map)['remainingBytes'], isNull);
  });

  test('verified Broadnet package rows show a limited detail sum', () {
    final payload = buildWidgetPayload([
      CarrierSnapshot(
        carrier: Carrier.broadnet,
        status: QueryStatus.success,
        queriedAt: time,
        buckets: const [
          TrafficBucket(
            name: '套餐A',
            kind: BucketKind.unknown,
            remainingBytes: 42,
            rawUnit: 'KB',
          ),
          TrafficBucket(
            name: '套餐B',
            kind: BucketKind.unknown,
            remainingBytes: 80,
            rawUnit: 'KB',
          ),
        ],
      ),
    ], thresholdGb: 5);
    expect((payload['broadnet'] as Map)['remainingBytes'], 122);
    expect((payload['broadnet'] as Map)['label'], '套餐明细合计');
  });

  test('single selected carrier cannot leak hidden cached balance or time', () {
    final snapshots = [
      CarrierSnapshot(
        carrier: Carrier.mobile,
        status: QueryStatus.success,
        queriedAt: time,
        buckets: const [
          TrafficBucket(
            name: '通用流量',
            kind: BucketKind.general,
            remainingBytes: 42,
          ),
        ],
      ),
      CarrierSnapshot(
        carrier: Carrier.broadnet,
        status: QueryStatus.success,
        queriedAt: time,
        buckets: const [
          TrafficBucket(
            name: '旧广电套餐',
            kind: BucketKind.unknown,
            remainingBytes: 999999,
            rawUnit: 'KB',
          ),
        ],
      ),
    ];
    final payload = buildWidgetPayload(
      snapshots,
      thresholdGb: 5,
      selection: CarrierSelection.complete([Carrier.mobile]),
    );
    expect(payload['selectedCarriers'], ['mobile']);
    expect((payload['mobile'] as Map)['remainingBytes'], 42);
    final hidden = payload['broadnet'] as Map;
    expect(hidden['remainingBytes'], isNull);
    expect(hidden['queriedAt'], isNull);
    expect(hidden['status'], 'notConnected');
  });

  test('unfinished setup sends no selected card or cached balance', () {
    final payload = buildWidgetPayload(
      [
        CarrierSnapshot(
          carrier: Carrier.mobile,
          status: QueryStatus.success,
          queriedAt: time,
          buckets: const [
            TrafficBucket(
              name: '通用流量',
              kind: BucketKind.general,
              remainingBytes: 123,
            ),
          ],
        ),
      ],
      thresholdGb: 5,
      selection: CarrierSelection.unconfigured(),
    );
    expect(payload['selectedCarriers'], isEmpty);
    expect((payload['mobile'] as Map)['remainingBytes'], isNull);
    expect((payload['mobile'] as Map)['queriedAt'], isNull);
  });

  test('all four selected carriers have separate display fields', () {
    final selection = CarrierSelection.complete(Carrier.values);
    final snapshots = [
      for (final carrier in Carrier.values)
        CarrierSnapshot(
          carrier: carrier,
          status: QueryStatus.success,
          queriedAt: time,
          phoneMasked: 'private',
          buckets: const [
            TrafficBucket(
              name: '通用流量',
              kind: BucketKind.general,
              remainingBytes: 42,
            ),
          ],
        ),
    ];
    final payload = buildWidgetPayload(
      snapshots,
      thresholdGb: 5,
      selection: selection,
    );
    expect(
      payload['selectedCarriers'],
      Carrier.values.map((item) => item.name),
    );
    for (final carrier in Carrier.values) {
      final card = payload[carrier.name] as Map<String, Object?>;
      expect(card['status'], 'success');
      expect(card['remainingBytes'], 42);
      expect(card['queriedAt'], time.millisecondsSinceEpoch);
      expect(card.keys, isNot(contains('phoneMasked')));
    }
  });

  test('nonadjacent selection excludes other carriers from cache', () {
    final payload = buildWidgetPayload(
      [
        for (final carrier in Carrier.values)
          CarrierSnapshot(
            carrier: carrier,
            status: QueryStatus.success,
            queriedAt: time,
            buckets: const [
              TrafficBucket(
                name: '通用流量',
                kind: BucketKind.general,
                remainingBytes: 123,
              ),
            ],
          ),
      ],
      thresholdGb: 5,
      selection: CarrierSelection.complete([Carrier.broadnet, Carrier.telecom]),
    );
    expect(payload['selectedCarriers'], ['broadnet', 'telecom']);
    for (final carrier in [Carrier.mobile, Carrier.unicom]) {
      final card = payload[carrier.name] as Map<String, Object?>;
      expect(card['status'], 'notConnected');
      expect(card['remainingBytes'], isNull);
      expect(card['queriedAt'], isNull);
    }
  });

  test('schema 2 gives each selected account its own widget slot', () {
    final selection = CarrierSelection.complete([
      Carrier.mobile,
      Carrier.broadnet,
    ]);
    final accounts = CarrierAccounts.fromSelection(
      selection,
    ).addSecond(Carrier.mobile);
    final snapshots = {
      'mobile': CarrierSnapshot(
        carrier: Carrier.mobile,
        status: QueryStatus.success,
        queriedAt: time,
        phoneMasked: '138****0001',
        buckets: const [
          TrafficBucket(
            name: '通用流量',
            kind: BucketKind.general,
            remainingBytes: 100,
          ),
        ],
      ),
      'mobile_2': CarrierSnapshot(
        carrier: Carrier.mobile,
        status: QueryStatus.authExpired,
        queriedAt: time,
        phoneMasked: '138****0002',
        buckets: const [
          TrafficBucket(
            name: '通用流量',
            kind: BucketKind.general,
            remainingBytes: 200,
          ),
        ],
      ),
    };
    final payload = buildWidgetPayload(
      snapshots.values,
      thresholdGb: 5,
      selection: selection,
      accounts: accounts,
      accountSnapshots: snapshots,
    );
    final instances = payload['instances'] as List<Map<String, Object?>>;
    expect(payload['schema'], 2);
    expect(payload['selectedCarriers'], ['mobile', 'broadnet']);
    expect(instances.map((item) => item['accountId']), [
      'mobile',
      'mobile_2',
      'broadnet',
    ]);
    expect(instances.map((item) => item['accountLabel']), [
      '中国移动 1',
      '中国移动 2',
      '中国广电 1',
    ]);
    expect(instances[0]['primaryValue'], 100);
    expect(instances[1]['primaryValue'], 200);
    expect(instances[1]['status'], 'authExpired');
    expect(instances.every((item) => !item.containsKey('phoneMasked')), isTrue);
    expect(payload['mobile'], containsPair('remainingBytes', 100));
  });

  test(
    'unlimited headline requires successful timed query and yields no amount',
    () {
      final selection = CarrierSelection.complete([Carrier.mobile]);
      final accounts = CarrierAccounts.fromSelection(selection);
      final snapshot = CarrierSnapshot(
        carrier: Carrier.mobile,
        status: QueryStatus.success,
        queriedAt: time,
        buckets: const [
          TrafficBucket(
            name: '不限量套餐',
            kind: BucketKind.general,
            isUnlimited: true,
          ),
        ],
      );
      final payload = buildWidgetPayload(
        [snapshot],
        thresholdGb: 5,
        selection: selection,
        accounts: accounts,
        accountSnapshots: {'mobile': snapshot},
      );
      final instance = (payload['instances'] as List).single as Map;
      expect(instance['primaryValue'], isNull);
      expect(instance['primaryLabel'], '含不限量套餐');
      expect(instance['isUnlimited'], isTrue);

      final failedRefresh = CarrierSnapshot(
        carrier: Carrier.mobile,
        status: QueryStatus.error,
        queriedAt: time,
        message: 'network error',
        buckets: const [
          TrafficBucket(
            name: '不限量套餐',
            kind: BucketKind.general,
            isUnlimited: true,
          ),
        ],
      );
      final failedPayload = buildWidgetPayload(
        [failedRefresh],
        thresholdGb: 5,
        selection: selection,
        accounts: accounts,
        accountSnapshots: {'mobile': failedRefresh},
      );
      final failedInstance = (failedPayload['instances'] as List).single as Map;
      expect(failedInstance['status'], 'error');
      expect(failedInstance['queriedAt'], time.millisecondsSinceEpoch);
      expect(failedInstance['isUnlimited'], isTrue);
    },
  );

  test(
    'pin status bridge distinguishes actual installation from pending request',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(WidgetBridge.channel, (call) async {
        if (call.method == 'requestPin') {
          return {'status': 'request_pending_confirmation'};
        }
        if (call.method == 'installationStatus') {
          return {'status': 'already_added'};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(WidgetBridge.channel, null),
      );

      const bridge = WidgetBridge();
      final request = await bridge.requestPinDetailed();
      expect(request.status, WidgetPinStatus.requestPendingConfirmation);
      expect(request.isAlreadyAdded, isFalse);
      expect(await bridge.requestPin(), isTrue);
      expect(
        (await bridge.installationStatus()).status,
        WidgetPinStatus.alreadyAdded,
      );
    },
  );
}
