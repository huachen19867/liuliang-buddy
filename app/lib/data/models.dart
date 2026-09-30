enum Carrier {
  mobile,
  broadnet;

  String get label => switch (this) {
    Carrier.mobile => '中国移动',
    Carrier.broadnet => '中国广电',
  };

  String get loginUrl => switch (this) {
    Carrier.mobile => 'https://wx.10086.cn/website/spa/main/newHome',
    Carrier.broadnet => 'https://www.10099.com.cn/login.html',
  };
}

enum QueryStatus { notConnected, loading, success, authExpired, error }

enum BucketKind { general, directed, unknown }

class TrafficBucket {
  const TrafficBucket({
    required this.name,
    required this.kind,
    this.remainingBytes,
    this.totalBytes,
    this.rawUnit,
    this.rawRemaining,
  });

  final String name;
  final BucketKind kind;
  final int? remainingBytes;
  final int? totalBytes;
  final String? rawUnit;
  final String? rawRemaining;

  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind.name,
    'remainingBytes': remainingBytes,
    'totalBytes': totalBytes,
    'rawUnit': rawUnit,
    'rawRemaining': rawRemaining,
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
    this.message,
  });

  final Carrier carrier;
  final QueryStatus status;
  final DateTime? queriedAt;
  final String? phoneMasked;
  final List<TrafficBucket> buckets;
  final String? message;

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
    message: identical(message, _unset) ? this.message : message as String?,
  );

  Map<String, dynamic> toJson() => {
    'carrier': carrier.name,
    'status': status.name,
    'queriedAt': queriedAt?.toIso8601String(),
    'phoneMasked': phoneMasked,
    'buckets': buckets.map((bucket) => bucket.toJson()).toList(),
    'message': message,
  };

  factory CarrierSnapshot.fromJson(Map<String, dynamic> json) {
    final rawBuckets = json['buckets'];
    final carrierName = json['carrier'];
    if (carrierName != Carrier.mobile.name &&
        carrierName != Carrier.broadnet.name) {
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
      message: json['message'] is String ? json['message'] as String : null,
    );
  }
}
