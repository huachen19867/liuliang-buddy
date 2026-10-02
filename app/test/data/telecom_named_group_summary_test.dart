import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/traffic_summary.dart';

void main() {
  const gib = 1024 * 1024 * 1024;
  TrafficBucket row({
    String name = '国内上网流量',
    BucketKind kind = BucketKind.unknown,
    BucketKind? manualKind,
    int? remaining = gib,
    String? unit = 'B',
    bool unlimited = false,
  }) => TrafficBucket(
    name: name,
    kind: kind,
    manualKind: manualKind,
    remainingBytes: remaining,
    rawUnit: unit,
    isUnlimited: unlimited,
  );

  test(
    'same exact trimmed name sums distinct amounts as a display estimate',
    () {
      final rows = [row(remaining: 2 * gib), row(remaining: 3 * gib)];
      final before = rows.map((bucket) => bucket.toJson()).toList();
      final summary = summarizeTelecomNamedGroup(rows);
      expect(summary.remainingBytes, 5 * gib);
      expect(summary.isComplete, isTrue);
      expect(summary.isEstimated, isTrue);
      expect(summary.state, 'provided');
      expect(rows.map((bucket) => bucket.toJson()).toList(), before);
      expect(rows, hasLength(2));
      expect(
        summarizeTelecomNamedGroup([
          row(name: ' 国内上网流量 ', remaining: 0),
          row(remaining: gib),
        ]).remainingBytes,
        gib,
      );
    },
  );

  test('missing other traffic balance prevents a partial same-name sum', () {
    final summary = summarizeTelecomNamedGroup([
      row(remaining: gib),
      row(remaining: null),
    ]);
    expect(summary.remainingBytes, isNull);
    expect(summary.isComplete, isFalse);
    expect(summary.state, 'unavailable');
  });

  test('empty names, different exact names and purposes cannot join', () {
    for (final rows in <List<TrafficBucket>>[
      [],
      [row(name: ' ')],
      [row(), row(name: '国内上网含5GB')],
      [row(), row(kind: BucketKind.directed)],
      [row(), row(manualKind: BucketKind.general)],
    ]) {
      final summary = summarizeTelecomNamedGroup(rows);
      expect(summary.remainingBytes, isNull);
      expect(summary.isComplete, isFalse);
      expect(summary.isUnlimited, isFalse);
    }
    expect(
      summarizeTelecomNamedGroup([
        row(kind: BucketKind.directed),
        row(kind: BucketKind.unknown, manualKind: BucketKind.directed),
      ]).remainingBytes,
      2 * gib,
    );
  });

  test('negative values and unknown units never become a grouped amount', () {
    for (final invalid in [
      row(remaining: -1),
      row(unit: null),
      row(unit: '?'),
    ]) {
      final summary = summarizeTelecomNamedGroup([row(), invalid]);
      expect(summary.remainingBytes, isNull);
      expect(summary.isComplete, isFalse);
    }
  });

  test(
    '64-bit overflow fails the whole group and the exact limit survives',
    () {
      const maximum = 9223372036854775807;
      final overflow = summarizeTelecomNamedGroup([
        row(remaining: maximum),
        row(remaining: 1),
      ]);
      expect(overflow.remainingBytes, isNull);
      expect(overflow.isComplete, isFalse);
      final exact = summarizeTelecomNamedGroup([
        row(remaining: maximum),
        row(remaining: 0),
      ]);
      expect(exact.remainingBytes, maximum);
      expect(exact.isComplete, isTrue);
      expect(exact.isEstimated, isTrue);
    },
  );

  test(
    'all explicit unlimited rows remain unlimited without a finite total',
    () {
      expect(
        summarizeTelecomNamedGroup([row(unlimited: true, remaining: 1)]).state,
        'unavailable',
      );
      final summary = summarizeTelecomNamedGroup([
        row(unlimited: true, remaining: null, unit: null),
        row(unlimited: true, remaining: null, unit: null),
      ]);
      expect(summary.isUnlimited, isTrue);
      expect(summary.remainingBytes, isNull);
      expect(summary.state, 'unlimited');
    },
  );

  test(
    'mixed finite and unlimited rows are unavailable rather than unlimited',
    () {
      final summary = summarizeTelecomNamedGroup([
        row(),
        row(unlimited: true, remaining: null),
      ]);
      expect(summary.isUnlimited, isFalse);
      expect(summary.remainingBytes, isNull);
      expect(summary.isComplete, isFalse);
      expect(summary.state, 'unavailable');
    },
  );
}
