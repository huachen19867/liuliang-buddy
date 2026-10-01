import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/services/query_state.dart';

void main() {
  test('cancelled loading keeps prior balance and time but can retry', () {
    final at = DateTime(2026, 10, 1, 12);
    final loading = CarrierSnapshot(
      carrier: Carrier.unicom,
      status: QueryStatus.loading,
      queriedAt: at,
      buckets: const [
        TrafficBucket(
          name: '官网套餐余量',
          kind: BucketKind.unknown,
          remainingBytes: 1024 * 1024 * 1024,
        ),
      ],
    );
    final settled = settleInterruptedQuery(loading);
    expect(settled.status, QueryStatus.error);
    expect(settled.queriedAt, at);
    expect(settled.buckets, same(loading.buckets));
    expect(settled.message, contains('重新刷新'));
  });

  test('completed background success survives configuration normalization', () {
    final success = CarrierSnapshot(
      carrier: Carrier.unicom,
      status: QueryStatus.success,
      queriedAt: DateTime(2026, 10, 1, 12),
    );
    expect(settleInterruptedQuery(success), same(success));
  });
}
