enum Carrier {
  mobile,
  broadnet,
  unicom,
  telecom;

  String get label => switch (this) {
    Carrier.mobile => '中国移动',
    Carrier.broadnet => '中国广电',
    Carrier.unicom => '中国联通',
    Carrier.telecom => '中国电信',
  };

  String get loginUrl => switch (this) {
    Carrier.mobile => 'https://wx.10086.cn/website/spa/main/newHome',
    Carrier.broadnet => 'https://www.10099.com.cn/login.html',
    Carrier.unicom => 'https://iservice.10010.com/',
    Carrier.telecom => 'https://e.dlife.cn/portal/web/index.html#/login',
  };
}

enum QueryStatus { notConnected, loading, success, authExpired, error }

enum BucketKind { general, directed, unknown }

enum AllowanceKind { voice, sms }

/// Voice values are minutes; SMS values retain the official count unit (条 or
/// 次). Each row is an official package or summary, never implicitly summed.
class ServiceAllowance {
  const ServiceAllowance({
    required this.kind,
    required this.label,
    this.scope,
    this.remaining,
    this.total,
    this.overage,
    this.rawRemaining,
    this.rawUnit,
    this.isUnlimited = false,
    this.isEstimated = false,
  });

  final AllowanceKind kind;
  final String label;
  final String? scope;
  final num? remaining;
  final num? total;
  final num? overage;
  final String? rawRemaining;
  final String? rawUnit;
  final bool isUnlimited;
  final bool isEstimated;

  String get canonicalUnit => kind == AllowanceKind.voice
      ? '分钟'
      : rawUnit == '次'
      ? '次'
      : '条';

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'label': label,
    'scope': scope,
    'remaining': remaining,
    'total': total,
    'overage': overage,
    'rawRemaining': rawRemaining,
    'rawUnit': rawUnit,
    'isUnlimited': isUnlimited,
    'isEstimated': isEstimated,
  };

  factory ServiceAllowance.fromJson(Map<String, dynamic> json) {
    final kind = AllowanceKind.values.where(
      (value) => value.name == json['kind'],
    );
    final label = json['label'];
    if (kind.isEmpty || label is! String || label.trim().isEmpty) {
      throw const FormatException('Invalid service allowance');
    }
    num? value(String key) {
      final raw = json[key];
      if (raw == null) return null;
      if (raw is! num ||
          !raw.isFinite ||
          raw < 0 ||
          raw > 1000000000 ||
          (kind.first == AllowanceKind.sms && raw != raw.roundToDouble())) {
        throw const FormatException('Invalid service allowance amount');
      }
      return raw;
    }

    final remaining = value('remaining');
    final total = value('total');
    final overage = value('overage');
    final unlimited = json['isUnlimited'] == true;
    if ((unlimited || overage != null) && remaining != null) {
      throw const FormatException('Conflicting service allowance amounts');
    }
    return ServiceAllowance(
      kind: kind.first,
      label: label,
      scope: json['scope'] is String ? json['scope'] as String : null,
      remaining: remaining,
      total: total,
      overage: overage,
      rawRemaining: json['rawRemaining'] is String
          ? json['rawRemaining'] as String
          : null,
      rawUnit: json['rawUnit'] is String ? json['rawUnit'] as String : null,
      isUnlimited: unlimited,
      isEstimated: json['isEstimated'] == true,
    );
  }
}

class TrafficBucket {
  const TrafficBucket({
    required this.name,
    required this.kind,
    this.remainingBytes,
    this.totalBytes,
    this.rawUnit,
    this.rawRemaining,
    this.isUnlimited = false,
  });

  final String name;
  final BucketKind kind;
  final int? remainingBytes;
  final int? totalBytes;
  final String? rawUnit;
  final String? rawRemaining;

  /// An explicit official unlimited marker, never inferred from a large number.
  final bool isUnlimited;

  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind.name,
    'remainingBytes': remainingBytes,
    'totalBytes': totalBytes,
    'rawUnit': rawUnit,
    'rawRemaining': rawRemaining,
    'isUnlimited': isUnlimited,
  };

  factory TrafficBucket.fromJson(Map<String, dynamic> json) => TrafficBucket(
    name: json['name'] is String ? json['name'] as String : '',
    kind: BucketKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => BucketKind.unknown,
    ),
    remainingBytes: json['remainingBytes'] is int
        ? json['remainingBytes'] as int
        : null,
    totalBytes: json['totalBytes'] is int ? json['totalBytes'] as int : null,
    rawUnit: json['rawUnit'] is String ? json['rawUnit'] as String : null,
    rawRemaining: json['rawRemaining'] is String
        ? json['rawRemaining'] as String
        : null,
    isUnlimited: json['isUnlimited'] == true,
  );
}

const _unset = Object();

class CarrierSnapshot {
  const CarrierSnapshot({
    required this.carrier,
    required this.status,
    this.queriedAt,
    this.phoneMasked,
    this.buckets = const [],
    this.allowances = const [],
    this.message,
  });

  final Carrier carrier;
  final QueryStatus status;
  final DateTime? queriedAt;
  final String? phoneMasked;
  final List<TrafficBucket> buckets;
  final List<ServiceAllowance> allowances;
  final String? message;

  bool get hasUnlimitedAllowance => buckets.any((bucket) => bucket.isUnlimited);

  // null means there is no verified general balance, while zero is a real zero.
  int? get generalRemainingBytes =>
      _sumGeneral((bucket) => bucket.remainingBytes);
  int? get generalTotalBytes => _sumGeneral((bucket) => bucket.totalBytes);

  int? _sumGeneral(int? Function(TrafficBucket) select) {
    if (status != QueryStatus.success) return null;
    final values = buckets.where((bucket) => bucket.kind == BucketKind.general);
    if (values.isEmpty) return null;
    var sum = 0;
    for (final bucket in values) {
      if (bucket.isUnlimited) return null;
      final value = select(bucket);
      if (value == null) return null;
      sum += value;
    }
    return sum;
  }

  CarrierSnapshot copyWith({
    Carrier? carrier,
    QueryStatus? status,
    Object? queriedAt = _unset,
    Object? phoneMasked = _unset,
    List<TrafficBucket>? buckets,
    List<ServiceAllowance>? allowances,
    Object? message = _unset,
  }) => CarrierSnapshot(
    carrier: carrier ?? this.carrier,
    status: status ?? this.status,
    queriedAt: identical(queriedAt, _unset)
        ? this.queriedAt
        : queriedAt as DateTime?,
    phoneMasked: identical(phoneMasked, _unset)
        ? this.phoneMasked
        : phoneMasked as String?,
    buckets: buckets ?? this.buckets,
    allowances: allowances ?? this.allowances,
    message: identical(message, _unset) ? this.message : message as String?,
  );

  Map<String, dynamic> toJson() => {
    'carrier': carrier.name,
    'status': status.name,
    'queriedAt': queriedAt?.toIso8601String(),
    'phoneMasked': phoneMasked,
    'buckets': buckets.map((bucket) => bucket.toJson()).toList(),
    'allowances': allowances.map((allowance) => allowance.toJson()).toList(),
    'message': message,
  };

  factory CarrierSnapshot.fromJson(Map<String, dynamic> json) {
    final rawBuckets = json['buckets'];
    final rawAllowances = json['allowances'];
    final carrierName = json['carrier'];
    if (!Carrier.values.any((carrier) => carrier.name == carrierName)) {
      throw const FormatException('Unknown carrier in saved snapshot');
    }
    return CarrierSnapshot(
      carrier: Carrier.values.firstWhere(
        (value) => value.name == json['carrier'],
      ),
      status: QueryStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => QueryStatus.notConnected,
      ),
      queriedAt: json['queriedAt'] is String
          ? DateTime.tryParse(json['queriedAt'] as String)
          : null,
      phoneMasked: json['phoneMasked'] is String
          ? json['phoneMasked'] as String
          : null,
      buckets: rawBuckets is List
          ? rawBuckets
                .whereType<Map>()
                .map(
                  (item) =>
                      TrafficBucket.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      allowances: rawAllowances is List
          ? rawAllowances
                .whereType<Map>()
                .map((item) {
                  try {
                    return ServiceAllowance.fromJson(
                      Map<String, dynamic>.from(item),
                    );
                  } on FormatException {
                    return null;
                  }
                })
                .whereType<ServiceAllowance>()
                .toList()
          : const [],
      message: json['message'] is String ? json['message'] as String : null,
    );
  }
}
