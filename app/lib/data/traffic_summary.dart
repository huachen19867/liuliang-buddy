import 'models.dart';

/// A number for presentation. It never changes the carrier's general balance.
class TrafficSummary {
  const TrafficSummary({
    required this.remainingBytes,
    required this.label,
    this.totalBytes,
    this.detailNotice,
  });

  final int remainingBytes;
  final int? totalBytes;
  final String label;
  final String? detailNotice;
}

/// Chooses a truthful headline from an already verified carrier snapshot.
/// Old snapshots keep their original query time; the caller displays status.
TrafficSummary? summarizeTraffic(CarrierSnapshot snapshot) {
  if (snapshot.status == QueryStatus.notConnected ||
      snapshot.queriedAt == null) {
    return null;
  }

  final general = snapshot.buckets
      .where((bucket) => bucket.kind == BucketKind.general)
      .toList();
  if (general.isNotEmpty) {
    final remaining = _completeSum(general, (bucket) => bucket.remainingBytes);
    if (remaining == null) return null;
    return TrafficSummary(
      remainingBytes: remaining,
      totalBytes: _completeSum(general, (bucket) => bucket.totalBytes),
      label: '通用剩余',
    );
  }

  // H5 qryUserRes returns flow-package rows, not a verified general bucket.
  // This sum describes those rows only. No Mobile fallback: its totalInfo may
  // already contain the other categories, so adding them would double count.
  if (snapshot.carrier != Carrier.broadnet || snapshot.buckets.isEmpty) {
    return null;
  }
  if (snapshot.buckets.any(
    (bucket) => bucket.name.trim().isEmpty || !_hasVerifiedUnit(bucket.rawUnit),
  )) {
    return null;
  }
  final remaining = _completeSum(
    snapshot.buckets,
    (bucket) => bucket.remainingBytes,
  );
  if (remaining == null) return null;
  return TrafficSummary(
    remainingBytes: remaining,
    totalBytes: _completeSum(snapshot.buckets, (bucket) => bucket.totalBytes),
    label: '套餐明细合计',
    detailNotice: '仅将已查询套餐的余额相加，适用范围以各套餐规则为准',
  );
}

int? _completeSum(
  Iterable<TrafficBucket> buckets,
  int? Function(TrafficBucket) select,
) {
  var sum = 0;
  for (final bucket in buckets) {
    final value = select(bucket);
    if (value == null || value < 0) return null;
    sum += value;
  }
  return sum;
}

bool _hasVerifiedUnit(String? rawUnit) =>
    switch (rawUnit?.trim().toUpperCase()) {
      'B' ||
      'BYTE' ||
      'BYTES' ||
      'KB' ||
      'K' ||
      'MB' ||
      'M' ||
      'GB' ||
      'G' ||
      '03' ||
      '04' => true,
      _ => false,
    };
