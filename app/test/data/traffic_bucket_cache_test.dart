import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/traffic_summary.dart';

void main() {
  Map<String, Object?> bucket(Object? remaining, {Object? total = 2048}) => {
    'name': '通用套餐',
    'kind': 'general',
    'remainingBytes': remaining,
    'totalBytes': total,
    'rawUnit': 'B',
    'rawRemaining': '$remaining',
  };

  CarrierSnapshot restore(List<Map<String, Object?>> rows) =>
      CarrierSnapshot.fromJson({
        'carrier': 'mobile',
        'status': 'success',
        'queriedAt': '2026-10-02T00:00:00.000Z',
        'buckets': rows,
      });

  test('invalid cached remaining stays as a row and blocks partial sums', () {
    for (final bad in <Object?>[-1, null, 1.5, double.infinity, true, '1024']) {
      final snapshot = restore([bucket(1024), bucket(bad)]);
      expect(snapshot.buckets, hasLength(2));
      expect(snapshot.buckets.last.remainingBytes, isNull);
      expect(snapshot.buckets.last.rawRemaining, '$bad');
      expect(snapshot.generalRemainingBytes, isNull);
      expect(summarizeTraffic(snapshot), isNull);
      expect(
        summarizeTrafficGroup(snapshot, BucketKind.general).isComplete,
        isFalse,
      );
    }
  });

  test('invalid cached total preserves independently verified remaining', () {
    final snapshot = restore([bucket(1024, total: -1)]);
    expect(snapshot.generalRemainingBytes, 1024);
    expect(snapshot.generalTotalBytes, isNull);
    expect(summarizeTraffic(snapshot)?.remainingBytes, 1024);
    expect(summarizeTraffic(snapshot)?.totalBytes, isNull);
  });

  test('finite cached zero survives restoration and serialization', () {
    final snapshot = restore([bucket(0, total: 0)]);
    expect(snapshot.generalRemainingBytes, 0);
    expect(snapshot.generalTotalBytes, 0);
    expect(snapshot.buckets.single.isUnlimited, isFalse);
    final roundTrip = CarrierSnapshot.fromJson(snapshot.toJson());
    expect(roundTrip.generalRemainingBytes, 0);
    expect(roundTrip.queriedAt, snapshot.queriedAt);
  });

  test(
    'remaining exceeding cached total becomes unknown without losing row',
    () {
      final snapshot = restore([bucket(1024), bucket(2049, total: 2048)]);
      expect(snapshot.buckets, hasLength(2));
      expect(snapshot.buckets.last.remainingBytes, isNull);
      expect(snapshot.buckets.last.totalBytes, isNull);
      expect(snapshot.generalRemainingBytes, isNull);
      expect(snapshot.generalTotalBytes, isNull);
    },
  );

  test(
    'explicit unlimited flag overrides conflicting cached finite amounts',
    () {
      final snapshot = restore([
        {...bucket(1024), 'isUnlimited': true},
      ]);
      expect(snapshot.hasUnlimitedAllowance, isTrue);
      expect(snapshot.buckets.single.remainingBytes, isNull);
      expect(snapshot.buckets.single.totalBytes, isNull);
      expect(snapshot.generalRemainingBytes, isNull);
      expect(
        summarizeTrafficGroup(snapshot, BucketKind.general).isUnlimited,
        isTrue,
      );
      final unconfirmed = TrafficBucket.fromJson({
        ...bucket(1024),
        'isUnlimited': 'true',
      });
      expect(unconfirmed.isUnlimited, isFalse);
      expect(unconfirmed.remainingBytes, 1024);
    },
  );

  test(
    'model getters reject negative directly constructed traffic amounts',
    () {
      final snapshot = CarrierSnapshot(
        carrier: Carrier.mobile,
        status: QueryStatus.success,
        queriedAt: DateTime.utc(2026, 10, 2),
        buckets: const [
          TrafficBucket(
            name: '异常套餐',
            kind: BucketKind.general,
            remainingBytes: -1,
            totalBytes: -1,
            rawUnit: 'B',
          ),
        ],
      );
      expect(snapshot.generalRemainingBytes, isNull);
      expect(snapshot.generalTotalBytes, isNull);
    },
  );

  test(
    'model getters stop 64-bit overflow while accepting the exact limit',
    () {
      const maximum = 9223372036854775807;
      final atLimit = restore([bucket(maximum, total: maximum)]);
      expect(atLimit.generalRemainingBytes, maximum);
      expect(atLimit.generalTotalBytes, maximum);
      final overflowing = restore([
        bucket(maximum, total: maximum),
        bucket(1, total: 1),
      ]);
      expect(overflowing.buckets, hasLength(2));
      expect(overflowing.generalRemainingBytes, isNull);
      expect(overflowing.generalTotalBytes, isNull);
      expect(summarizeTraffic(overflowing), isNull);
      expect(
        summarizeTrafficGroup(overflowing, BucketKind.general).isComplete,
        isFalse,
      );
    },
  );

  test('cache validation preserves query failures and original query time', () {
    final snapshot = restore([bucket(1024)]);
    final stale = CarrierSnapshot.fromJson(
      snapshot.copyWith(status: QueryStatus.authExpired).toJson(),
    );
    expect(stale.status, QueryStatus.authExpired);
    expect(stale.queriedAt, snapshot.queriedAt);
    expect(stale.generalRemainingBytes, isNull);
    expect(summarizeTraffic(stale)?.remainingBytes, 1024);
  });
}
