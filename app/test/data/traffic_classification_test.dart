import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/traffic_classification.dart';
import 'package:liuliang_app/data/traffic_summary.dart';
import 'package:liuliang_app/services/widget_bridge.dart';

void main() {
  final time = DateTime.utc(2026, 10, 2, 6);
  TrafficBucket row(
    String name, {
    BucketKind kind = BucketKind.unknown,
    int? remaining = 1024,
    String? unit = 'MB',
    bool unlimited = false,
    BucketKind? manualKind,
  }) => TrafficBucket(
    name: name,
    kind: kind,
    manualKind: manualKind,
    remainingBytes: remaining,
    totalBytes: 4096,
    rawUnit: unit,
    rawRemaining: '$remaining',
    isUnlimited: unlimited,
  );
  CarrierSnapshot sample(
    List<TrafficBucket> rows, {
    Carrier carrier = Carrier.unicom,
  }) => CarrierSnapshot(
    carrier: carrier,
    status: QueryStatus.success,
    queriedAt: time,
    phoneMasked: '130****5678',
    balanceYuan: -2.5,
    message: '现有查询说明',
    buckets: rows,
    allowances: const [
      ServiceAllowance(kind: AllowanceKind.voice, label: '语音', remaining: 10),
    ],
  );
  TrafficClassificationOverrides empty() =>
      TrafficClassificationOverrides.restore(null);

  test('old Telecom cache reclassifies names without changing query facts', () {
    final original = sample([
      row('国内上网流量', kind: BucketKind.general),
      row('国内上网含5GB', kind: BucketKind.directed, remaining: 0),
      row('视频专属流量', kind: BucketKind.directed, remaining: null),
      row('国内上网定向流量'),
      row('通用流量', kind: BucketKind.general, unlimited: true),
    ], carrier: Carrier.telecom);
    final restored = CarrierSnapshot.fromJson(original.toJson());
    final adjusted = empty().apply('telecom', restored);
    expect(adjusted.buckets.map((bucket) => bucket.kind), [
      BucketKind.unknown,
      BucketKind.unknown,
      BucketKind.unknown,
      BucketKind.directed,
      BucketKind.unknown,
    ]);
    for (var index = 0; index < restored.buckets.length; index++) {
      expect(adjusted.buckets[index].toJson(), {
        ...restored.buckets[index].toJson(),
        'kind': adjusted.buckets[index].kind.name,
      });
    }
    expect(adjusted.toJson(), {
      ...restored.toJson(),
      'buckets': adjusted.buckets.map((bucket) => bucket.toJson()).toList(),
    });
    expect(adjusted.queriedAt, time);
    expect(adjusted.balanceYuan, -2.5);
    expect(adjusted.generalRemainingBytes, isNull);
    expect(restored.buckets.first.kind, BucketKind.general);
    expect(empty().apply('telecom', adjusted).toJson(), adjusted.toJson());
  });

  test('saved Telecom manual classification wins after cache restoration', () {
    final original = sample([
      row('定向流量'),
      row('国内上网含5GB', kind: BucketKind.general),
    ], carrier: Carrier.telecom);
    var overrides = empty().withOverride(
      'telecom_2',
      original,
      original.buckets.first,
      BucketKind.general,
    );
    overrides = overrides.withOverride(
      'telecom_2',
      original,
      original.buckets.last,
      BucketKind.directed,
    );
    final cached = CarrierSnapshot.fromJson(
      overrides.apply('telecom_2', original).toJson(),
    );
    final restarted = TrafficClassificationOverrides.restore(
      jsonEncode(overrides.toJson()),
    );
    final adjusted = restarted.apply('telecom_2', cached);
    expect(adjusted.buckets.first.kind, BucketKind.directed);
    expect(adjusted.buckets.first.effectiveKind, BucketKind.general);
    expect(adjusted.buckets.last.kind, BucketKind.unknown);
    expect(adjusted.buckets.last.effectiveKind, BucketKind.directed);
    expect(adjusted.generalRemainingBytes, 1024);
    expect(
      restarted.apply('telecom', cached).buckets.first.effectiveKind,
      BucketKind.directed,
    );
    final reset = restarted.withOverride(
      'telecom_2',
      adjusted,
      adjusted.buckets.first,
      null,
    );
    expect(
      reset.apply('telecom_2', adjusted).buckets.first.effectiveKind,
      BucketKind.directed,
    );
    expect(reset.apply('telecom_2', adjusted).buckets.first.manualKind, isNull);
  });

  test(
    'Telecom duplicates keep rows and automatic purpose but no manual rule',
    () {
      final original = sample([row('定向流量')], carrier: Carrier.telecom);
      final overrides = empty().withOverride(
        'telecom',
        original,
        original.buckets.single,
        BucketKind.general,
      );
      final duplicate = sample([
        row('定向流量', remaining: 10, manualKind: BucketKind.general),
        row(' 定向流量 ', remaining: 20, manualKind: BucketKind.directed),
        row('国内上网流量', kind: BucketKind.general, remaining: 30),
        row('国内上网流量', kind: BucketKind.directed, remaining: null),
      ], carrier: Carrier.telecom);
      final adjusted = overrides.apply('telecom', duplicate);
      expect(adjusted.buckets, hasLength(4));
      expect(adjusted.buckets.map((bucket) => bucket.remainingBytes), [
        10,
        20,
        30,
        null,
      ]);
      expect(adjusted.buckets.map((bucket) => bucket.kind), [
        BucketKind.directed,
        BucketKind.directed,
        BucketKind.unknown,
        BucketKind.unknown,
      ]);
      expect(
        adjusted.buckets.every((bucket) => bucket.manualKind == null),
        isTrue,
      );
      expect(
        overrides.apply('telecom', original).buckets.single.effectiveKind,
        BucketKind.general,
      );
    },
  );

  test('background cache publishing uses latest Telecom manual choices', () {
    final selection = CarrierSelection.complete([Carrier.telecom]);
    final accounts = CarrierAccounts.fromSelection(selection);
    final original = sample([
      row('国内上网流量', kind: BucketKind.general, remaining: 10),
      row('定向流量', remaining: 20),
    ], carrier: Carrier.telecom);
    final stored = CarrierSnapshot.fromJson(original.toJson());
    final latest = empty().withOverride(
      'telecom',
      stored,
      stored.buckets.first,
      BucketKind.directed,
    );
    final adjusted = TrafficClassificationOverrides.restore(
      jsonEncode(latest.toJson()),
    ).apply('telecom', stored);
    final payload = buildWidgetPayload(
      [adjusted],
      thresholdGb: 5,
      accounts: accounts,
      selection: selection,
      accountSnapshots: {'telecom': adjusted},
    );
    final instance = (payload['instances'] as List).single as Map;
    expect(instance['generalRemainingBytes'], isNull);
    expect(instance['directedRemainingBytes'], 30);
    expect(instance['otherState'], 'unavailable');
    expect(instance['queriedAt'], time.millisecondsSinceEpoch);
    expect(instance['balanceYuan'], -2.5);
    expect(adjusted.buckets.first.kind, BucketKind.unknown);
    expect(adjusted.buckets.first.manualKind, BucketKind.directed);
  });

  test('other carriers retain their official purpose classifications', () {
    for (final carrier in [Carrier.mobile, Carrier.broadnet, Carrier.unicom]) {
      final original = sample([
        row('国内上网流量', kind: BucketKind.general),
        row('视频专属流量', kind: BucketKind.directed),
        row('定向流量'),
      ], carrier: carrier);
      expect(empty().apply(carrier.name, original).toJson(), original.toJson());
    }
  });

  test('manual correction keeps automatic kind and all query facts', () {
    final original = sample([row('国内包')]);
    final overrides = empty().withOverride(
      'unicom',
      original,
      original.buckets.single,
      BucketKind.general,
    );
    final adjusted = overrides.apply('unicom', original);
    final bucket = adjusted.buckets.single;
    expect(bucket.kind, BucketKind.unknown);
    expect(bucket.manualKind, BucketKind.general);
    expect(bucket.effectiveKind, BucketKind.general);
    expect(bucket.remainingBytes, original.buckets.single.remainingBytes);
    expect(bucket.totalBytes, original.buckets.single.totalBytes);
    expect(bucket.rawRemaining, original.buckets.single.rawRemaining);
    expect(bucket.rawUnit, original.buckets.single.rawUnit);
    expect(adjusted.queriedAt, time);
    expect(adjusted.balanceYuan, -2.5);
    expect(adjusted.status, original.status);
    expect(adjusted.phoneMasked, original.phoneMasked);
    expect(adjusted.message, original.message);
    expect(adjusted.allowances, original.allowances);
    expect(original.buckets.single.manualKind, isNull);
    expect(empty().apply('unicom', original).generalRemainingBytes, isNull);
    expect(adjusted.generalRemainingBytes, 1024);
  });

  test('same carrier accounts and carrier IDs never share corrections', () {
    final original = sample([row('同名包')]);
    var overrides = empty().withOverride(
      'unicom',
      original,
      original.buckets.single,
      BucketKind.general,
    );
    overrides = overrides.withOverride(
      'unicom_2',
      original,
      original.buckets.single,
      BucketKind.directed,
    );
    expect(
      overrides.apply('unicom', original).buckets.single.effectiveKind,
      BucketKind.general,
    );
    expect(
      overrides.apply('unicom_2', original).buckets.single.effectiveKind,
      BucketKind.directed,
    );
    expect(
      overrides.apply('unicom_3', original).buckets.single.manualKind,
      isNull,
    );
    expect(
      overrides.apply('mobile', original).buckets.single.manualKind,
      isNull,
    );
    expect(
      overrides
          .withoutAccount('unicom')
          .apply('unicom', original)
          .buckets
          .single
          .manualKind,
      isNull,
    );
    expect(
      overrides
          .withoutAccount('unicom')
          .apply('unicom_2', original)
          .buckets
          .single
          .effectiveKind,
      BucketKind.directed,
    );
    expect(
      overrides.apply('unicom', original).buckets.single.manualKind,
      BucketKind.general,
    );
  });

  test('reordered refresh follows exact name, never index or amount', () {
    final original = sample([row(' 包A '), row('包B', remaining: 20)]);
    final overrides = empty().withOverride(
      'unicom',
      original,
      original.buckets.first,
      BucketKind.general,
    );
    final next = sample([row('包B'), row('包A', remaining: 30)]);
    final adjusted = overrides.apply('unicom', next);
    expect(adjusted.buckets.first.manualKind, isNull);
    expect(adjusted.buckets.last.effectiveKind, BucketKind.general);
    expect(adjusted.generalRemainingBytes, 30);
    expect(
      overrides.apply('unicom', sample([row('包a')])).buckets.single.manualKind,
      isNull,
    );
    // Temporarily absent packages retain their settings for a later refresh.
    overrides.apply('unicom', sample([row('包B')]));
    expect(
      overrides.apply('unicom', next).buckets.last.manualKind,
      BucketKind.general,
    );
  });

  test('restore automatic removes setting and stale cached manual kind', () {
    final original = sample([row('视频包', kind: BucketKind.directed)]);
    final corrected = empty().withOverride(
      'unicom',
      original,
      original.buckets.single,
      BucketKind.general,
    );
    final cached = corrected.apply('unicom', original);
    final reset = corrected.withOverride(
      'unicom',
      cached,
      cached.buckets.single,
      null,
    );
    expect(reset.apply('unicom', cached).buckets.single.manualKind, isNull);
    expect(
      reset.apply('unicom', cached).buckets.single.effectiveKind,
      BucketKind.directed,
    );
    expect((reset.toJson()['accounts'] as Map), isEmpty);
    expect(
      corrected.apply('unicom', cached).buckets.single.manualKind,
      BucketKind.general,
    );
  });

  test('duplicate, empty, absent and aggregate identities are rejected', () {
    final duplicate = sample([row('同名'), row(' 同名 ')]);
    expect(
      TrafficClassificationOverrides.canOverride(
        duplicate,
        duplicate.buckets.first,
      ),
      isFalse,
    );
    expect(
      TrafficClassificationOverrides.unavailableReason(
        duplicate,
        duplicate.buckets.first,
      ),
      contains('同名'),
    );
    final noName = sample([row(' ')]);
    expect(
      TrafficClassificationOverrides.canOverride(noName, noName.buckets.single),
      isFalse,
    );
    expect(
      TrafficClassificationOverrides.canOverride(sample([row('A')]), row('B')),
      isFalse,
    );
    for (final entry in {
      Carrier.mobile: ['流量总览'],
      Carrier.unicom: ['官网套餐余量', '官网不限量套餐'],
    }.entries) {
      for (final name in entry.value) {
        final aggregate = sample([row(' $name ')], carrier: entry.key);
        expect(
          TrafficClassificationOverrides.canOverride(
            aggregate,
            aggregate.buckets.single,
          ),
          isFalse,
        );
        final rejected = empty().withOverride(
          entry.key.name,
          aggregate,
          aggregate.buckets.single,
          BucketKind.general,
        );
        expect((rejected.toJson()['accounts'] as Map), isEmpty);
      }
    }
  });

  test(
    'duplicate refresh clears old manual kinds without pruning saved rule',
    () {
      final original = sample([row('A')]);
      final overrides = empty().withOverride(
        'unicom',
        original,
        original.buckets.single,
        BucketKind.general,
      );
      final duplicate = sample([
        row('A', manualKind: BucketKind.general),
        row(' A ', manualKind: BucketKind.directed),
      ]);
      final adjusted = overrides.apply('unicom', duplicate);
      expect(
        adjusted.buckets.every((bucket) => bucket.manualKind == null),
        isTrue,
      );
      expect(adjusted.generalRemainingBytes, isNull);
      expect(overrides.apply('unicom', original).generalRemainingBytes, 1024);
    },
  );

  test(
    'storage round trip excludes phone and survives unrelated invalid rows',
    () {
      final decoded = {
        'schema': 1,
        'accounts': {
          'unicom': {'A': 'general', 'bad': 4, 'unknown': 'unknown'},
          'unicom_4': {'B': 'directed'},
          '13012345678': {'A': 'general'},
          'unicom_5': {'A': 'general'},
          'telecom': 'bad',
        },
      };
      final restored = TrafficClassificationOverrides.restore(
        jsonEncode(decoded),
      );
      final roundTrip = TrafficClassificationOverrides.restore(
        jsonEncode(restored.toJson()),
      );
      expect(
        roundTrip.apply('unicom', sample([row('A')])).generalRemainingBytes,
        1024,
      );
      expect(
        roundTrip
            .apply('unicom_4', sample([row('B')]))
            .buckets
            .single
            .manualKind,
        BucketKind.directed,
      );
      final serialized = jsonEncode(roundTrip.toJson());
      expect(serialized, isNot(contains('13012345678')));
      expect(serialized, isNot(contains('phone')));
      expect(serialized, isNot(contains('queriedAt')));
      expect(serialized, isNot(contains('remaining')));
      expect((roundTrip.toJson()['accounts'] as Map).length, 2);
      for (final bad in ['null', '[]', '{', '{"schema":2,"accounts":{}}']) {
        expect(
          (TrafficClassificationOverrides.restore(bad).toJson()['accounts']
              as Map),
          isEmpty,
        );
      }
    },
  );

  test('conflicting normalized stored names do not choose a correction', () {
    final restored = TrafficClassificationOverrides.restore(
      jsonEncode({
        'schema': 1,
        'accounts': {
          'unicom': {'A': 'general', ' A ': 'directed', 'B': 'general'},
        },
      }),
    );
    final adjusted = restored.apply('unicom', sample([row('A'), row('B')]));
    expect(adjusted.buckets.first.manualKind, isNull);
    expect(adjusted.buckets.last.manualKind, BucketKind.general);
  });

  test(
    'bucket cache is backward compatible and nullable copy clears override',
    () {
      final original = row('A', kind: BucketKind.directed);
      expect(TrafficBucket.fromJson(original.toJson()).manualKind, isNull);
      final corrected = original.copyWith(manualKind: BucketKind.general);
      final restored = TrafficBucket.fromJson(corrected.toJson());
      expect(restored.kind, BucketKind.directed);
      expect(restored.effectiveKind, BucketKind.general);
      expect(restored.copyWith().manualKind, BucketKind.general);
      expect(
        restored.copyWith(manualKind: null).effectiveKind,
        BucketKind.directed,
      );
      for (final bad in ['unknown', 'GENERAL', 1, true, {}]) {
        expect(
          TrafficBucket.fromJson({
            ...corrected.toJson(),
            'manualKind': bad,
          }).manualKind,
          isNull,
        );
      }
    },
  );

  test(
    'manual labels never make invalid amounts or units verified balances',
    () {
      for (final bucket in [
        row('A', remaining: -1),
        row('A', remaining: null),
        row('A', unit: '?'),
        row('A', unit: null),
      ]) {
        final original = sample([bucket]);
        final adjusted = empty()
            .withOverride('unicom', original, bucket, BucketKind.general)
            .apply('unicom', original);
        expect(adjusted.buckets.single.effectiveKind, BucketKind.general);
        expect(adjusted.generalRemainingBytes, isNull);
        expect(summarizeTraffic(adjusted), isNull);
        expect(
          summarizeTrafficGroup(adjusted, BucketKind.general).isComplete,
          isFalse,
        );
      }
    },
  );

  test('manual unlimited stays unlimited and verified zero stays zero', () {
    final original = sample([row('无限包', unlimited: true)]);
    final adjusted = empty()
        .withOverride(
          'unicom',
          original,
          original.buckets.single,
          BucketKind.general,
        )
        .apply('unicom', original);
    expect(adjusted.buckets.single.isUnlimited, isTrue);
    expect(adjusted.generalRemainingBytes, isNull);
    expect(summarizeTraffic(adjusted), isNull);
    expect(
      summarizeTrafficGroup(adjusted, BucketKind.general).state,
      'unlimited',
    );
    final zero = sample([row('零包', remaining: 0)]);
    final correctedZero = empty()
        .withOverride('unicom', zero, zero.buckets.single, BucketKind.general)
        .apply('unicom', zero);
    expect(correctedZero.generalRemainingBytes, 0);
    expect(summarizeTraffic(correctedZero)?.remainingBytes, 0);
  });

  test('tampered cached aggregates never join corrected general totals', () {
    final original = sample([
      row('通用流量', kind: BucketKind.general, remaining: 10),
      row('流量总览', remaining: 40, manualKind: BucketKind.general),
      row('其他流量', remaining: 30),
    ], carrier: Carrier.mobile);
    expect(original.generalRemainingBytes, 10);
    expect(summarizeTraffic(original)?.remainingBytes, 10);
    expect(
      summarizeTrafficGroup(original, BucketKind.general).remainingBytes,
      10,
    );
    final overrides = empty().withOverride(
      'mobile',
      original,
      original.buckets.last,
      BucketKind.general,
    );
    final adjusted = overrides.apply('mobile', original);
    expect(adjusted.generalRemainingBytes, 40);
    expect(adjusted.buckets[1].manualKind, isNull);
    expect(summarizeTraffic(adjusted)?.remainingBytes, 40);
    expect(
      summarizeTrafficGroup(adjusted, BucketKind.general).remainingBytes,
      40,
    );
  });

  test('widget category fields and headline share the corrected snapshot', () {
    final selection = CarrierSelection.complete([Carrier.unicom]);
    final accounts = CarrierAccounts.fromSelection(selection);
    final original = sample([row('A', remaining: 10), row('B', remaining: 20)]);
    var overrides = empty().withOverride(
      'unicom',
      original,
      original.buckets.first,
      BucketKind.general,
    );
    overrides = overrides.withOverride(
      'unicom',
      original,
      original.buckets.last,
      BucketKind.directed,
    );
    final adjusted = overrides.apply('unicom', original);
    final payload = buildWidgetPayload(
      [adjusted],
      thresholdGb: 5,
      accounts: accounts,
      selection: selection,
      accountSnapshots: {'unicom': adjusted},
    );
    final instance = (payload['instances'] as List).single as Map;
    expect(instance['generalRemainingBytes'], adjusted.generalRemainingBytes);
    expect(instance['generalRemainingBytes'], 10);
    expect(instance['directedRemainingBytes'], 20);
    expect(instance['otherState'], 'unavailable');
    expect(
      instance['primaryValue'],
      summarizeTraffic(adjusted)?.remainingBytes,
    );
    expect(instance['primaryValue'], 10);
    expect(instance['primaryLabel'], '通用剩余');
    expect(instance['queriedAt'], time.millisecondsSinceEpoch);
    expect(payload.toString(), isNot(contains('manualKind')));
  });
}
