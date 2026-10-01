import 'models.dart';

class TrafficGroupSummary {
  const TrafficGroupSummary({
    this.remainingBytes,
    this.isUnlimited = false,
    this.isComplete = false,
    this.isEstimated = false,
  });

  final int? remainingBytes;
  final bool isUnlimited;
  final bool isComplete;
  final bool isEstimated;
  String get state => isUnlimited
      ? 'unlimited'
      : isComplete
      ? 'provided'
      : 'unavailable';
}

/// Keeps unknown purposes separate. Mobile's official aggregate includes other
/// categories already, so it never joins the "other" package sum.
TrafficGroupSummary summarizeTrafficGroup(
  CarrierSnapshot snapshot,
  BucketKind kind,
) {
  if (snapshot.queriedAt == null ||
      snapshot.status == QueryStatus.notConnected) {
    return const TrafficGroupSummary();
  }
  final rows = snapshot.buckets
      .where(
        (bucket) =>
            bucket.kind == kind &&
            !(snapshot.carrier == Carrier.mobile && bucket.name == '流量总览'),
      )
      .toList();
  if (rows.isEmpty) return const TrafficGroupSummary();
  // The single Unicom unknown row is explicitly an official package aggregate.
  // It may include the general and directed portions and cannot mean "other".
  if (snapshot.carrier == Carrier.unicom &&
      rows.any(
        (bucket) => bucket.name == '官网套餐余量' || bucket.name == '官网不限量套餐',
      )) {
    return const TrafficGroupSummary();
  }
  if (rows.any((bucket) => bucket.isUnlimited)) {
    return const TrafficGroupSummary(isUnlimited: true);
  }
  if (rows.any((bucket) => !_hasVerifiedUnit(bucket.rawUnit))) {
    return const TrafficGroupSummary();
  }
  final sum = _completeSum(rows, (bucket) => bucket.remainingBytes);
  return TrafficGroupSummary(
    remainingBytes: sum,
    isComplete: sum != null,
    isEstimated: snapshot.carrier == Carrier.telecom,
  );
}

/// Voice packages can share an allowance; do not add rows without evidence.
ServiceAllowance? summarizeVoice(CarrierSnapshot snapshot) {
  if (snapshot.queriedAt == null ||
      snapshot.status == QueryStatus.notConnected) {
    return null;
  }
  final rows = snapshot.allowances
      .where((row) => row.kind == AllowanceKind.voice)
      .toList();
  final official = rows.where((row) => row.scope == '官网汇总').toList();
  if (official.length == 1) return official.single;
  return rows.length == 1 ? rows.single : null;
}

/// A number for presentation. It never changes the carrier's general balance.
class TrafficSummary {
  const TrafficSummary({
    required this.remainingBytes,
    required this.label,
    this.totalBytes,
    this.detailNotice,
    this.isEstimate = false,
  });

  final int remainingBytes;
  final int? totalBytes;
  final String label;
  final String? detailNotice;
  final bool isEstimate;
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

  // The official E5 response exposes one aggregate, without a general label.
  if (snapshot.carrier == Carrier.unicom && snapshot.buckets.length == 1) {
    final bucket = snapshot.buckets.single;
    if (bucket.name == '官网套餐余量' &&
        bucket.kind == BucketKind.unknown &&
        bucket.remainingBytes != null &&
        bucket.remainingBytes! >= 0 &&
        _hasVerifiedUnit(bucket.rawUnit)) {
      return TrafficSummary(
        remainingBytes: bucket.remainingBytes!,
        label: '套餐余量',
        detailNotice: '官网套餐剩余额，适用范围以套餐规则为准',
      );
    }
  }

  // H5 qryUserRes returns flow-package rows, not a verified general bucket.
  // This sum describes those rows only. No Mobile fallback: its totalInfo may
  // already contain the other categories, so adding them would double count.
  if ((snapshot.carrier != Carrier.broadnet &&
          snapshot.carrier != Carrier.telecom) ||
      snapshot.buckets.isEmpty) {
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
    label: snapshot.carrier == Carrier.telecom ? '套餐估算余量' : '套餐明细合计',
    isEstimate: snapshot.carrier == Carrier.telecom,
    detailNotice: snapshot.carrier == Carrier.telecom
        ? '按官网已用/总量显示值估算后相加，有舍入误差；共享或重叠额度请以套餐规则为准'
        : '仅将已查询套餐的余额相加，适用范围以各套餐规则为准',
  );
}

int? _completeSum(
  Iterable<TrafficBucket> buckets,
  int? Function(TrafficBucket) select,
) {
  var sum = 0;
  for (final bucket in buckets) {
    if (bucket.isUnlimited) return null;
    final value = select(bucket);
    if (value == null || value < 0) return null;
    if (value > 9223372036854775807 - sum) return null;
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
