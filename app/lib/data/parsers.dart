import 'models.dart';

/// Parses a decoded getNewMarginInfo response from wx.10086.cn.
/// The caller must verify the response URL and decrypt it before calling this.
CarrierSnapshot parseMobile(
  Map<String, dynamic> response, {
  DateTime? queriedAt,
  String? phoneMasked,
  int? httpStatus,
}) {
  CarrierSnapshot failed(QueryStatus status, String message) => CarrierSnapshot(
    carrier: Carrier.mobile,
    status: status,
    phoneMasked: phoneMasked,
    message: message,
  );

  if (httpStatus == 401 || httpStatus == 403) {
    return failed(QueryStatus.authExpired, '中国移动登录已失效');
  }
  if (httpStatus != null && (httpStatus < 200 || httpStatus >= 300)) {
    return failed(QueryStatus.error, '中国移动查询失败（HTTP $httpStatus）');
  }

  final resultData = _map(_map(response['data'])?['resultData']);
  final flow = _map(resultData?['planRemianFlowInfo']);
  if (flow == null) {
    return failed(
      _isAuthFailure(response) ? QueryStatus.authExpired : QueryStatus.error,
      _isAuthFailure(response) ? '中国移动登录已失效' : '未识别中国移动流量响应',
    );
  }

  final buckets = <TrafficBucket>[];
  void add(String field, String name, BucketKind kind) {
    final raw = _map(flow[field]);
    if (raw == null) return;
    final remaining = raw['remainNum'];
    final unit = _text(raw['unit']);
    // 01/02 are voice/SMS. Unknown units must never become GB by default.
    if (remaining == null || unit == null) return;
    buckets.add(
      TrafficBucket(
        name: name,
        kind: kind,
        rawRemaining: _text(remaining),
        rawUnit: unit,
        remainingBytes: _toBytes(remaining, unit),
        totalBytes: _toBytes(raw['sumNum'], unit),
      ),
    );
  }

  add('planRemian', '通用流量', BucketKind.general);
  add('directionalFlowInfo', '定向流量', BucketKind.directed);
  add('otherRemian', '其他流量', BucketKind.unknown);
  // This is the official aggregate and may already include all other buckets.
  add('totalInfo', '流量总览', BucketKind.unknown);

  if (buckets.isEmpty ||
      buckets.every((bucket) => bucket.remainingBytes == null)) {
    return failed(QueryStatus.error, '中国移动流量单位或剩余额无法确认');
  }
  return CarrierSnapshot(
    carrier: Carrier.mobile,
    status: QueryStatus.success,
    queriedAt: queriedAt ?? DateTime.now(),
    phoneMasked: phoneMasked,
    buckets: buckets,
  );
}

/// Parses a decoded qryUserRes response from wx.10099.com.cn.
/// The referenced API has no documented unit field. Unlabelled numeric
/// balances are retained as raw values rather than guessed to be KB.
CarrierSnapshot parseBroadnet(
  Map<String, dynamic> response, {
  DateTime? queriedAt,
  String? phoneMasked,
  int? httpStatus,
}) {
  CarrierSnapshot failed(QueryStatus status, String message) => CarrierSnapshot(
    carrier: Carrier.broadnet,
    status: status,
    phoneMasked: phoneMasked,
    message: message,
  );

  if (httpStatus == 401 || httpStatus == 403) {
    return failed(QueryStatus.authExpired, '中国广电登录已失效');
  }
  if (httpStatus != null && (httpStatus < 200 || httpStatus >= 300)) {
    return failed(QueryStatus.error, '中国广电查询失败（HTTP $httpStatus）');
  }
  if (response['status'] != '000000') {
    return failed(
      _isAuthFailure(response) ? QueryStatus.authExpired : QueryStatus.error,
      _isAuthFailure(response) ? '中国广电登录已失效' : '中国广电接口返回异常',
    );
  }

  final items = _map(_map(response['data'])?['intfResultBean'])?['userResList'];
  if (items is! List || items.isEmpty) {
    return failed(QueryStatus.error, '中国广电未返回可识别的流量明细');
  }

  final buckets = <TrafficBucket>[];
  for (final item in items) {
    final entry = _map(item);
    if (entry == null) continue;
    final name = _text(entry['itemName']);
    final rawRemaining = _text(entry['balance']);
    if (name == null || name.isEmpty || rawRemaining == null) continue;
    final unit = _text(entry['unit']);
    buckets.add(
      TrafficBucket(
        name: name,
        kind: _broadnetKind(name),
        rawRemaining: rawRemaining,
        rawUnit: unit,
        remainingBytes: _toBytes(entry['balance'], unit),
        totalBytes: _toBytes(entry['highFee'], unit),
      ),
    );
  }

  if (buckets.isEmpty) {
    return failed(QueryStatus.error, '中国广电流量明细缺少名称或剩余额');
  }
  final unitsMissing = buckets.any((bucket) => bucket.remainingBytes == null);
  return CarrierSnapshot(
    carrier: Carrier.broadnet,
    status: QueryStatus.success,
    queriedAt: queriedAt ?? DateTime.now(),
    phoneMasked: phoneMasked,
    buckets: buckets,
    message: unitsMissing ? '部分流量明细无可确认单位，仅显示原始数值' : null,
  );
}

/// Parses the official web hall's decoded qryUserRes response.
/// Only this H5 path has source evidence that busiType 5 balances are KB.
CarrierSnapshot parseBroadnetH5(
  Map<String, dynamic> response, {
  DateTime? queriedAt,
  String? phoneMasked,
  int? httpStatus,
}) {
  CarrierSnapshot failed(QueryStatus status, String message) => CarrierSnapshot(
    carrier: Carrier.broadnet,
    status: status,
    phoneMasked: phoneMasked,
    message: message,
  );

  if (httpStatus == 401 || httpStatus == 403) {
    return failed(QueryStatus.authExpired, '中国广电登录已失效');
  }
  if (httpStatus != null && (httpStatus < 200 || httpStatus >= 300)) {
    return failed(QueryStatus.error, '中国广电查询失败（HTTP $httpStatus）');
  }

  final outerStatus = _text(response['status']);
  if (outerStatus == '701' || _isAuthFailure(response)) {
    return failed(QueryStatus.authExpired, '中国广电登录已失效');
  }
  if (outerStatus != null && outerStatus != '000000') {
    return failed(QueryStatus.error, '中国广电接口返回异常');
  }

  // jQuery ajaxSuccess receives the already unwrapped business object. Raw
  // transport capture may instead still include the outer status/data pair.
  final business = outerStatus == null ? response : _map(response['data']);
  if (business == null) {
    return failed(QueryStatus.error, '未识别中国广电流量响应');
  }
  if (business['respCode'] != '000000') {
    return failed(
      _isAuthFailure(business) ? QueryStatus.authExpired : QueryStatus.error,
      _isAuthFailure(business) ? '中国广电登录已失效' : '中国广电业务查询失败',
    );
  }

  final items = _map(business['intfResultBean'])?['userResList'];
  if (items is! List) {
    return failed(QueryStatus.error, '中国广电响应缺少套餐明细');
  }

  final buckets = <TrafficBucket>[];
  for (final item in items) {
    final entry = _map(item);
    if (entry == null || _text(entry['busiType']) != '5') continue;
    final name = _text(entry['discntName']);
    final named = name != null && name.isNotEmpty;
    final rawRemaining = _text(entry['balance']);
    final remainingBytes = named ? _toBytes(entry['balance'], 'KB') : null;
    buckets.add(
      TrafficBucket(
        name: named ? name : '未命名流量套餐',
        kind: named ? _broadnetKind(name) : BucketKind.unknown,
        remainingBytes: remainingBytes,
        totalBytes: named ? _toBytes(entry['highFee'], 'KB') : null,
        rawUnit: 'KB',
        rawRemaining: rawRemaining,
      ),
    );
  }

  if (buckets.isEmpty ||
      buckets.every((bucket) => bucket.remainingBytes == null)) {
    return failed(QueryStatus.error, '中国广电未返回可确认的流量套餐');
  }
  final incomplete = buckets.any((bucket) => bucket.remainingBytes == null);
  return CarrierSnapshot(
    carrier: Carrier.broadnet,
    status: QueryStatus.success,
    queriedAt: queriedAt ?? DateTime.now(),
    phoneMasked: phoneMasked,
    buckets: buckets,
    message: incomplete ? '部分流量套餐余额未确认，暂不显示明细合计' : null,
  );
}

BucketKind _broadnetKind(String name) {
  if (!name.contains('流量')) return BucketKind.unknown;
  if (name.contains('定向') || name.contains('专属')) return BucketKind.directed;
  if (name.contains('通用')) return BucketKind.general;
  return BucketKind.unknown;
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

String? _text(Object? value) => value?.toString().trim();

bool _isAuthFailure(Map<String, dynamic> response) {
  final text = [
    response['status'],
    response['code'],
    response['message'],
    response['msg'],
    response['respDesc'],
  ].whereType<Object>().join(' ').toLowerCase();
  return text.contains('登录失效') ||
      text.contains('登录已失效') ||
      text.contains('登录过期') ||
      text.contains('未登录') ||
      text.contains('重新登录') ||
      text.contains('认证失败') ||
      text.contains('token expired') ||
      text.contains('session expired') ||
      text.contains('unauthorized');
}

int? _toBytes(Object? rawValue, String? rawUnit) {
  if (rawValue == null || rawUnit == null) return null;
  final multiplier = switch (rawUnit.trim().toUpperCase()) {
    'KB' || 'K' => BigInt.from(1024),
    'MB' || 'M' || '03' => BigInt.from(1024 * 1024),
    'GB' || 'G' || '04' => BigInt.from(1024 * 1024 * 1024),
    'B' || 'BYTE' || 'BYTES' => BigInt.one,
    _ => null,
  };
  if (multiplier == null) return null;
  final match = RegExp(
    r'^(\d+)(?:\.(\d+))?$',
  ).firstMatch(rawValue.toString().trim());
  if (match == null) return null;
  final whole = match.group(1)!;
  final fraction = match.group(2) ?? '';
  final denominator = BigInt.from(10).pow(fraction.length);
  final numerator = BigInt.parse('$whole$fraction') * multiplier;
  final bytes = (numerator + denominator ~/ BigInt.two) ~/ denominator;
  return bytes.toInt();
}
