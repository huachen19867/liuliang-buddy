import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/services/widget_bridge.dart';

void main() {
  final time = DateTime.utc(2026, 9, 30, 6, 30);
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
      expect(payload['selectedCarriers'], ['mobile', 'broadnet']);
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
}
