import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/traffic_summary.dart';

void main() {
  final queriedAt = DateTime.utc(2026, 9, 30, 9, 10);
  const gib = 1024 * 1024 * 1024;

  CarrierSnapshot telecom(List<TrafficBucket> buckets) => CarrierSnapshot(
    carrier: Carrier.telecom,
    status: QueryStatus.success,
    queriedAt: queriedAt,
    buckets: buckets,
  );
  const readableOther = TrafficBucket(
    name: '国内上网含5G',
    kind: BucketKind.unknown,
    remainingBytes: 5 * gib,
    rawUnit: 'GB',
  );
  const pendingOther = TrafficBucket(
    name: '国内上网流量',
    kind: BucketKind.unknown,
    rawRemaining: '待确认',
  );

  test(
    'Telecom other sums readable amounts while retaining the pending row',
    () {
      final snapshot = telecom(const [
        readableOther,
        readableOther,
        pendingOther,
      ]);
      final summary = summarizeTrafficGroup(snapshot, BucketKind.unknown);
      expect(summary.remainingBytes, 10 * gib);
      expect(summary.state, 'partial');
      expect(summary.isPartial, isTrue);
      expect(summary.isComplete, isFalse);
      expect(summary.isEstimated, isTrue);
      expect(summary.pendingCount, 1);
      expect(summarizeTraffic(snapshot), isNull);
      expect(snapshot.buckets, const [
        readableOther,
        readableOther,
        pendingOther,
      ]);
      expect(
        summarizeTelecomNamedGroup([
          readableOther,
          readableOther.copyWith(remainingBytes: null),
        ]).remainingBytes,
        isNull,
      );
    },
  );

  test(
    'Telecom other differentiates complete, zero partial and wholly pending',
    () {
      final complete = summarizeTrafficGroup(
        telecom(const [readableOther, readableOther]),
        BucketKind.unknown,
      );
      expect(complete.remainingBytes, 10 * gib);
      expect(complete.state, 'provided');
      expect(complete.pendingCount, 0);
      expect(complete.isPartial, isFalse);
      final zero = summarizeTrafficGroup(
        telecom([readableOther.copyWith(remainingBytes: 0), pendingOther]),
        BucketKind.unknown,
      );
      expect(zero.remainingBytes, 0);
      expect(zero.state, 'partial');
      expect(zero.pendingCount, 1);
      final pending = summarizeTrafficGroup(
        telecom(const [pendingOther, pendingOther]),
        BucketKind.unknown,
      );
      expect(pending.remainingBytes, isNull);
      expect(pending.state, 'unavailable');
      expect(pending.pendingCount, 2);
    },
  );

  test(
    'Telecom other skips unverified and contradictory amounts without guessing',
    () {
      final invalid = [
        pendingOther.copyWith(remainingBytes: 7 * gib),
        readableOther.copyWith(rawUnit: '分钟'),
        readableOther.copyWith(name: ' '),
        readableOther.copyWith(remainingBytes: -1),
        readableOther.copyWith(totalBytes: 4 * gib),
        readableOther.copyWith(isUnlimited: true),
        const TrafficBucket(
          name: '不限量',
          kind: BucketKind.unknown,
          isUnlimited: true,
        ),
      ];
      final summary = summarizeTrafficGroup(
        telecom([readableOther, ...invalid]),
        BucketKind.unknown,
      );
      expect(summary.remainingBytes, 5 * gib);
      expect(summary.pendingCount, invalid.length);
      expect(summary.state, 'partial');
      expect(summary.isUnlimited, isFalse);
      final unlimited = summarizeTrafficGroup(
        telecom([invalid.last]),
        BucketKind.unknown,
      );
      expect(unlimited.state, 'unlimited');
      expect(unlimited.remainingBytes, isNull);
      final conflicting = summarizeTrafficGroup(
        telecom([invalid[5]]),
        BucketKind.unknown,
      );
      expect(conflicting.state, 'unavailable');
      expect(conflicting.remainingBytes, isNull);
    },
  );

  test('Telecom other overflow is unavailable regardless of row ordering', () {
    final largest = readableOther.copyWith(remainingBytes: 9223372036854775807);
    for (final rows in [
      [largest, readableOther, pendingOther],
      [readableOther, pendingOther, largest],
    ]) {
      final summary = summarizeTrafficGroup(telecom(rows), BucketKind.unknown);
      expect(summary.remainingBytes, isNull);
      expect(summary.state, 'unavailable');
      expect(summary.pendingCount, 1);
    }
  });

  test('partial other respects manual classifications and snapshot gates', () {
    final snapshot = telecom([
      readableOther,
      readableOther.copyWith(manualKind: BucketKind.general),
      pendingOther.copyWith(manualKind: BucketKind.directed),
      pendingOther,
    ]);
    final other = summarizeTrafficGroup(snapshot, BucketKind.unknown);
    expect(other.remainingBytes, 5 * gib);
    expect(other.pendingCount, 1);
    expect(
      summarizeTrafficGroup(snapshot, BucketKind.general).remainingBytes,
      5 * gib,
    );
    expect(
      summarizeTrafficGroup(snapshot, BucketKind.directed).state,
      'unavailable',
    );
    expect(snapshot.buckets[1].kind, BucketKind.unknown);
    expect(snapshot.buckets[1].manualKind, BucketKind.general);
    for (final status in [
      QueryStatus.loading,
      QueryStatus.error,
      QueryStatus.authExpired,
    ]) {
      final cached = summarizeTrafficGroup(
        snapshot.copyWith(status: status),
        BucketKind.unknown,
      );
      expect(cached.remainingBytes, 5 * gib);
      expect(cached.state, 'partial');
    }
    for (final gated in [
      snapshot.copyWith(status: QueryStatus.notConnected),
      snapshot.copyWith(queriedAt: null),
    ]) {
      final summary = summarizeTrafficGroup(gated, BucketKind.unknown);
      expect(summary.remainingBytes, isNull);
      expect(summary.pendingCount, 0);
    }
  });

  test(
    'other carriers and Telecom general or directed keep complete-sum rules',
    () {
      for (final carrier in [
        Carrier.mobile,
        Carrier.unicom,
        Carrier.broadnet,
      ]) {
        final snapshot = telecom(const [
          readableOther,
          pendingOther,
        ]).copyWith(carrier: carrier);
        final summary = summarizeTrafficGroup(snapshot, BucketKind.unknown);
        expect(summary.state, 'unavailable');
        expect(summary.remainingBytes, isNull);
        expect(summary.isPartial, isFalse);
      }
      for (final kind in [BucketKind.general, BucketKind.directed]) {
        final snapshot = telecom([
          readableOther.copyWith(manualKind: kind),
          pendingOther.copyWith(manualKind: kind),
        ]);
        final summary = summarizeTrafficGroup(snapshot, kind);
        expect(summary.state, 'unavailable');
        expect(summary.remainingBytes, isNull);
        expect(summary.isPartial, isFalse);
      }
    },
  );

  test('one App unknown package is visible without becoming general', () {
    final snapshot = CarrierSnapshot(
      carrier: Carrier.unicom,
      status: QueryStatus.success,
      queriedAt: queriedAt,
      buckets: const [
        TrafficBucket(
          name: '国内流量包',
          kind: BucketKind.unknown,
          remainingBytes: 0,
          totalBytes: gib,
          rawUnit: 'MB',
        ),
      ],
    );
    expect(summarizeTraffic(snapshot)?.remainingBytes, 0);
    expect(summarizeTraffic(snapshot)?.label, '套餐余量');
    expect(snapshot.generalRemainingBytes, isNull);
    expect(summarizeTraffic(snapshot)?.detailNotice, contains('国内流量包'));
    expect(
      summarizeTraffic(
        snapshot.copyWith(
          buckets: const [
            TrafficBucket(
              name: '国内流量包',
              kind: BucketKind.unknown,
              remainingBytes: gib,
              rawUnit: 'MB',
            ),
            TrafficBucket(
              name: '视频包',
              kind: BucketKind.directed,
              remainingBytes: gib,
              rawUnit: 'MB',
            ),
          ],
        ),
      ),
      isNull,
    );
  });

  test('Broadnet shows an honest sum of three verified package rows', () {
    final snapshot = CarrierSnapshot(
      carrier: Carrier.broadnet,
      status: QueryStatus.success,
      queriedAt: queriedAt,
      buckets: const [
        TrafficBucket(
          name: '30GB升卿卡',
          kind: BucketKind.unknown,
          remainingBytes: 30 * gib,
          totalBytes: 30 * gib,
          rawUnit: 'KB',
        ),
        TrafficBucket(
          name: '首充赠送',
          kind: BucketKind.unknown,
          remainingBytes: 113 * gib,
          totalBytes: 120 * gib,
          rawUnit: 'KB',
        ),
        TrafficBucket(
          name: '结转',
          kind: BucketKind.unknown,
          remainingBytes: 0,
          totalBytes: 2 * gib,
          rawUnit: 'KB',
        ),
      ],
    );
    final summary = summarizeTraffic(snapshot)!;
    expect(summary.remainingBytes, 143 * gib);
    expect(summary.totalBytes, 152 * gib);
    expect(summary.label, '套餐明细合计');
    expect(summary.detailNotice, contains('套餐规则'));
    expect(snapshot.generalRemainingBytes, isNull);
  });

  test('verified general has priority and directed is excluded', () {
    final snapshot = CarrierSnapshot(
      carrier: Carrier.broadnet,
      status: QueryStatus.success,
      queriedAt: queriedAt,
      buckets: const [
        TrafficBucket(
          name: '国内通用流量',
          kind: BucketKind.general,
          remainingBytes: 3 * gib,
          totalBytes: 5 * gib,
          rawUnit: 'KB',
        ),
        TrafficBucket(
          name: '视频定向流量',
          kind: BucketKind.directed,
          remainingBytes: 20 * gib,
          rawUnit: 'KB',
        ),
      ],
    );
    final summary = summarizeTraffic(snapshot)!;
    expect(summary.remainingBytes, 3 * gib);
    expect(summary.totalBytes, 5 * gib);
    expect(summary.label, '通用剩余');
    expect(summary.detailNotice, isNull);
  });

  test('incomplete Broadnet rows are never partially summed', () {
    for (final incomplete in [
      const TrafficBucket(
        name: '缺单位',
        kind: BucketKind.unknown,
        remainingBytes: gib,
      ),
      const TrafficBucket(name: '缺余额', kind: BucketKind.unknown, rawUnit: 'KB'),
      const TrafficBucket(
        name: '未知单位',
        kind: BucketKind.unknown,
        remainingBytes: gib,
        rawUnit: '?',
      ),
    ]) {
      expect(
        summarizeTraffic(
          CarrierSnapshot(
            carrier: Carrier.broadnet,
            status: QueryStatus.success,
            queriedAt: queriedAt,
            buckets: [
              const TrafficBucket(
                name: '已确认',
                kind: BucketKind.unknown,
                remainingBytes: 2 * gib,
                rawUnit: 'KB',
              ),
              incomplete,
            ],
          ),
        ),
        isNull,
      );
    }
  });

  test('missing total keeps verified remaining but not an invented total', () {
    final summary = summarizeTraffic(
      CarrierSnapshot(
        carrier: Carrier.broadnet,
        status: QueryStatus.success,
        queriedAt: queriedAt,
        buckets: const [
          TrafficBucket(
            name: '套餐A',
            kind: BucketKind.unknown,
            remainingBytes: gib,
            rawUnit: 'KB',
          ),
        ],
      ),
    )!;
    expect(summary.remainingBytes, gib);
    expect(summary.totalBytes, isNull);
  });

  test('Mobile unknown totalInfo never participates in fallback', () {
    final summary = summarizeTraffic(
      CarrierSnapshot(
        carrier: Carrier.mobile,
        status: QueryStatus.success,
        queriedAt: queriedAt,
        buckets: const [
          TrafficBucket(
            name: '流量总览',
            kind: BucketKind.unknown,
            remainingBytes: 20 * gib,
            rawUnit: '04',
          ),
          TrafficBucket(
            name: '定向流量',
            kind: BucketKind.directed,
            remainingBytes: 10 * gib,
            rawUnit: '04',
          ),
        ],
      ),
    );
    expect(summary, isNull);
  });

  test('cached failures retain the original number and query-time gate', () {
    final expired = CarrierSnapshot(
      carrier: Carrier.broadnet,
      status: QueryStatus.authExpired,
      queriedAt: queriedAt,
      buckets: const [
        TrafficBucket(
          name: '套餐A',
          kind: BucketKind.unknown,
          remainingBytes: gib,
          rawUnit: 'KB',
        ),
      ],
    );
    expect(summarizeTraffic(expired)?.remainingBytes, gib);
    expect(
      summarizeTraffic(expired.copyWith(status: QueryStatus.notConnected)),
      isNull,
    );
    expect(summarizeTraffic(expired.copyWith(queriedAt: null)), isNull);
  });
}
