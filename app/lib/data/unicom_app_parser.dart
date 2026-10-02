import 'dart:convert';

import 'models.dart';

/// Parses only queryOcsPackageFlowLeftContentRevisedInJune, whose unlabelled
/// flow detail amounts use MB in the researched clients. Do not reuse this
/// default for another endpoint. Explicit unknown units never inherit MB.
CarrierSnapshot parseUnicomAppPackage(
  Map<String, dynamic> response, {
  DateTime? queriedAt,
  String? phoneMasked,
  int? httpStatus,
}) {
  CarrierSnapshot fail(QueryStatus status, String message) => CarrierSnapshot(
    carrier: Carrier.unicom,
    status: status,
    message: message,
  );
  if (httpStatus == 401 || httpStatus == 403 || _authFailure(response)) {
    return fail(QueryStatus.authExpired, '联通 App 会话已失效，请重新连接');
  }
  if (httpStatus != null && (httpStatus < 200 || httpStatus >= 300)) {
    return fail(QueryStatus.error, '联通 App 查询失败（HTTP $httpStatus）');
  }
  if (response['code'] != '0000') {
    return fail(QueryStatus.error, '联通 App 未返回成功的套餐查询结果');
  }
  final resources = response['resources'];
  if (resources is! List || resources.length > 100) {
    return fail(QueryStatus.error, '联通 App 套餐明细缺失或格式异常');
  }

  final buckets = <TrafficBucket>[];
  final seen = <String>{};
  final positions = <String, int>{};
  var derived = false;
  var overlap = false;
  var rowCount = 0;
  for (final resource in resources) {
    if (resource is! Map) {
      return fail(QueryStatus.error, '联通 App 套餐资源格式异常');
    }
    final type = resource['type'];
    if (type != 'flow' && type != 'MlFlowdetailsList') continue;
    final details = resource['details'];
    if (details is! List) {
      return fail(QueryStatus.error, '联通 App 流量明细格式异常');
    }
    rowCount += details.length;
    if (rowCount > 500) {
      return fail(QueryStatus.error, '联通 App 套餐明细数量异常');
    }
    // Resource-level totals cover their details; they must never be added.
    for (final item in details) {
      if (item is! Map) {
        return fail(QueryStatus.error, '联通 App 流量明细格式异常');
      }
      final policy = _text(item['feePolicyName']);
      final addition = _text(item['addUpItemName']);
      final names = <String>{?policy, ?addition};
      final name = names.isEmpty ? '未命名流量套餐' : names.join(' · ');
      final kind = _kind(names.join(' '));
      final rawUnit = item.containsKey('unit')
          ? _text(item['unit'])
          : resource.containsKey('unit')
          ? _text(resource['unit'])
          : 'MB';
      final unlimited = _unlimited(item['total']) || _unlimited(item['remain']);
      final fingerprint = jsonEncode([
        policy,
        addition,
        rawUnit,
        _scalar(item['total']),
        _scalar(item['use']),
        _scalar(item['remain']),
      ]);
      // Some clients expose the same detail in both resource lists.
      if (!seen.add(fingerprint)) continue;
      var total = unlimited ? null : _bytes(item['total'], rawUnit);
      var remaining = unlimited ? null : _bytes(item['remain'], rawUnit);
      final used = _bytes(item['use'], rawUnit);
      if (!unlimited &&
          item['remain'] == null &&
          total != null &&
          used != null &&
          used <= total) {
        remaining = total - used;
        derived = true;
      }
      // A supplied zero is authoritative. Do not replace it with total - use.
      if (total != null && remaining != null && remaining > total) {
        total = null;
        remaining = null;
      }
      final identity = names.isEmpty ? null : jsonEncode([policy, addition]);
      final previous = identity == null ? null : positions[identity];
      if (previous != null) {
        final earlier = buckets[previous];
        // Conflicting duplicate names do not prove separate allowances. Keep
        // an incomplete row so a partial category cannot become a false sum.
        buckets[previous] = TrafficBucket(
          name: earlier.name,
          kind: earlier.kind,
          rawRemaining: '重复套餐数据不一致',
          rawUnit: earlier.rawUnit,
        );
        overlap = true;
        continue;
      }
      if (identity != null) positions[identity] = buckets.length;
      buckets.add(
        TrafficBucket(
          name: name,
          kind: names.isEmpty ? BucketKind.unknown : kind,
          remainingBytes: remaining,
          totalBytes: total,
          rawUnit: rawUnit,
          rawRemaining: unlimited ? '不限量' : _text(item['remain']),
          isUnlimited: unlimited,
        ),
      );
    }
  }
  if (buckets.isEmpty ||
      !buckets.any((row) => row.remainingBytes != null || row.isUnlimited)) {
    return fail(QueryStatus.error, '联通 App 未返回可确认的流量余量');
  }
  final notices = <String>[
    if (overlap) '重复套餐数据不一致，暂不显示对应分类合计',
    if (buckets.any((row) => row.remainingBytes == null && !row.isUnlimited))
      '部分套餐余量或单位未确认',
    if (derived) '部分剩余量按套餐总量减已用量计算',
    if (buckets.any((row) => row.isUnlimited)) '包含官方不限量标记，达量限速以套餐规则为准',
    '分类按明确套餐名称识别，适用范围与共享关系以联通 App 为准',
  ];
  return CarrierSnapshot(
    carrier: Carrier.unicom,
    status: QueryStatus.success,
    queriedAt: queriedAt ?? DateTime.now(),
    phoneMasked: phoneMasked,
    buckets: buckets,
    message: notices.join('；'),
  );
}

/// accountBalancenew.htm labels curntbalancecust in yuan. Other balances and
/// monthly spending fields have different meanings and are never substituted.
num? parseUnicomAppBalance(Map<String, dynamic> response, {int? httpStatus}) {
  if (httpStatus != null && (httpStatus < 200 || httpStatus >= 300) ||
      response['code'] != '0000' ||
      _authFailure(response)) {
    return null;
  }
  final text = _text(response['curntbalancecust']);
  if (text == null || !RegExp(r'^-?\d+(?:\.\d{1,2})?$').hasMatch(text)) {
    return null;
  }
  final value = num.tryParse(text);
  return value != null && value.isFinite && value.abs() <= 1000000000
      ? value
      : null;
}

BucketKind _kind(String name) {
  // Directed wording wins even if its package title also mentions general.
  if (RegExp(r'定向|专属|免流').hasMatch(name)) return BucketKind.directed;
  if (name.contains('通用')) return BucketKind.general;
  return BucketKind.unknown;
}

String? _text(Object? value) {
  if (value is! String && value is! num) return null;
  final text = value.toString().trim();
  return text.isEmpty || text.length > 300 ? null : text;
}

Object? _scalar(Object? value) =>
    value is String || value is bool || value is num && value.isFinite
    ? value
    : null;

bool _unlimited(Object? value) =>
    value is String &&
    RegExp(
      r'^(不限量|无限量|无限|不限|不限制|unlimited|no\s*limit)\s*(GB|MB|KB|B)?$',
      caseSensitive: false,
    ).hasMatch(value.trim());

bool _authFailure(Map<String, dynamic> response) {
  if (const {
    '999999',
    '999998',
    'AUTH_FAILED',
    'LOGIN_REQUIRED',
  }.contains(response['code']?.toString())) {
    return true;
  }
  final message = [
    response['dsc'],
    response['message'],
    response['msg'],
  ].whereType<String>().join(' ').toLowerCase();
  return RegExp(
    r'登录已?失效|登录过期|未登录|重新登录|认证失败|认证失效|token expired|session expired|unauthorized',
  ).hasMatch(message);
}

int? _bytes(Object? raw, String? unit) {
  final factor = switch (unit?.toUpperCase()) {
    'B' || 'BYTE' || 'BYTES' => 1,
    'KB' => 1024,
    'MB' => 1024 * 1024,
    'GB' => 1024 * 1024 * 1024,
    _ => null,
  };
  final text = _text(raw);
  if (factor == null || text == null || text.length > 80) return null;
  final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(text);
  if (match == null) return null;
  final fraction = match.group(2) ?? '';
  final divisor = BigInt.from(10).pow(fraction.length);
  final numerator =
      BigInt.parse('${match.group(1)}$fraction') * BigInt.from(factor);
  final bytes = (numerator + divisor ~/ BigInt.two) ~/ divisor;
  // Reject sentinels and implausible allowance sizes rather than overflow or
  // treating a very large numeric value as an unlimited marker.
  return bytes <= BigInt.from(1099511627776) ? bytes.toInt() : null;
}
