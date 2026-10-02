import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/traffic_summary.dart';

void main() {
  final queriedAt = DateTime.utc(2026, 9, 30, 9, 10);
  const gib = 1024 * 1024 * 1024;

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
