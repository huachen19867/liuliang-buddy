import 'package:flutter_test/flutter_test.dart';
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
    },
  );

  test('unknown packages are never summed into a widget total', () {
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

  test('single unclassified package is shown with its limitation', () {
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
          ),
        ],
      ),
    ], thresholdGb: 5);
    expect((payload['broadnet'] as Map)['remainingBytes'], 42);
    expect((payload['broadnet'] as Map)['label'], contains('用途待确认'));
  });
}
