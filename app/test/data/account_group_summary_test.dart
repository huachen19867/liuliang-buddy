import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/traffic_summary.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/services/widget_bridge.dart';

void main() {
  final time = DateTime.utc(2026, 10, 1);
  CarrierSnapshot sample(
    List<TrafficBucket> buckets, {
    Carrier carrier = Carrier.mobile,
    List<ServiceAllowance> allowances = const [],
  }) => CarrierSnapshot(
    carrier: carrier,
    status: QueryStatus.success,
    queriedAt: time,
    buckets: buckets,
    allowances: allowances,
  );
  test(
    'group totals exclude the Mobile aggregate and preserve unknown purpose',
    () {
      final snapshot = sample(const [
        TrafficBucket(
          name: '通用流量',
          kind: BucketKind.general,
          remainingBytes: 10,
          rawUnit: 'MB',
        ),
        TrafficBucket(
          name: '定向流量',
          kind: BucketKind.directed,
          remainingBytes: 20,
          rawUnit: 'MB',
        ),
        TrafficBucket(
          name: '其他流量',
          kind: BucketKind.unknown,
          remainingBytes: 3,
          rawUnit: 'MB',
        ),
        TrafficBucket(
          name: '流量总览',
          kind: BucketKind.unknown,
          remainingBytes: 33,
          rawUnit: 'MB',
        ),
      ]);
      expect(
        summarizeTrafficGroup(snapshot, BucketKind.general).remainingBytes,
        10,
      );
      expect(
        summarizeTrafficGroup(snapshot, BucketKind.directed).remainingBytes,
        20,
      );
      expect(
        summarizeTrafficGroup(snapshot, BucketKind.unknown).remainingBytes,
        3,
      );
    },
  );
  test(
    'incomplete, absent and unlimited groups have no numerical subtotal',
    () {
      final partial = sample(const [
        TrafficBucket(
          name: 'A',
          kind: BucketKind.general,
          remainingBytes: 12,
          rawUnit: 'MB',
        ),
        TrafficBucket(name: 'B', kind: BucketKind.general, rawUnit: 'MB'),
      ]);
      expect(
        summarizeTrafficGroup(partial, BucketKind.general).state,
        'unavailable',
      );
      expect(
        summarizeTrafficGroup(partial, BucketKind.general).remainingBytes,
        isNull,
      );
      expect(
        summarizeTrafficGroup(partial, BucketKind.directed).state,
        'unavailable',
      );
      final unlimited = sample(const [
        TrafficBucket(
          name: '不限量',
          kind: BucketKind.directed,
          isUnlimited: true,
        ),
      ]);
      expect(
        summarizeTrafficGroup(unlimited, BucketKind.directed).state,
        'unlimited',
      );
      expect(
        summarizeTrafficGroup(unlimited, BucketKind.directed).remainingBytes,
        isNull,
      );
      final unicom = sample(const [
        TrafficBucket(
          name: '官网套餐余量',
          kind: BucketKind.unknown,
          remainingBytes: 12,
          rawUnit: 'MB',
        ),
      ], carrier: Carrier.unicom);
      expect(
        summarizeTrafficGroup(unicom, BucketKind.unknown).state,
        'unavailable',
      );
      expect(summarizeTraffic(unicom)!.remainingBytes, 12);
    },
  );
  test(
    'voice summary selects official aggregate and never blindly adds packages',
    () {
      const a = ServiceAllowance(
        kind: AllowanceKind.voice,
        label: 'A',
        remaining: 20,
      );
      const b = ServiceAllowance(
        kind: AllowanceKind.voice,
        label: 'B',
        remaining: 30,
      );
      const total = ServiceAllowance(
        kind: AllowanceKind.voice,
        label: '汇总',
        scope: '官网汇总',
        remaining: 40,
      );
      expect(summarizeVoice(sample([], allowances: [a, b])), isNull);
      expect(
        summarizeVoice(sample([], allowances: [a, b, total]))!.remaining,
        40,
      );
      expect(summarizeVoice(sample([], allowances: [a]))!.remaining, 20);
    },
  );
  test(
    'widget identity uses only masked hints and separate unavailable fields',
    () {
      final selection = CarrierSelection.complete([Carrier.mobile]);
      final records = CarrierAccounts.fromSelection(
        selection,
      ).updateIdentity('mobile', note: '主卡', phoneNumber: '13812345678');
      final snapshot = sample(const [
        TrafficBucket(
          name: '通用流量',
          kind: BucketKind.general,
          remainingBytes: 0,
          rawUnit: 'MB',
        ),
      ]);
      final payload = buildWidgetPayload(
        [snapshot],
        thresholdGb: 5,
        selection: selection,
        accounts: records,
        accountSnapshots: {'mobile': snapshot},
      );
      final row = (payload['instances'] as List).single as Map;
      expect(row['name'], '主卡');
      expect(row['phoneHint'], '138****5678');
      expect(row['balanceYuan'], isNull);
      expect(row['generalRemainingBytes'], 0);
      expect(row['generalState'], 'provided');
      expect(row['directedRemainingBytes'], isNull);
      expect(row['directedState'], 'unavailable');
      expect(row.containsKey('phoneNumber'), isFalse);
      expect(payload.toString(), isNot(contains('13812345678')));
    },
  );
}
