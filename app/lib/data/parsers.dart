import 'models.dart';
import 'telecom_name_classification.dart';

/// Billing DOM contains rounded used/total strings. Their difference is an
/// estimate, not an exact network response or a verified general allowance.
CarrierSnapshot parseTelecomRendered(
  Map<String, dynamic> response, {
  DateTime? queriedAt,
}) {
  CarrierSnapshot fail() => const CarrierSnapshot(
    carrier: Carrier.telecom,
    status: QueryStatus.error,
    message: '电信官网明细或单位尚无法确认，请打开官方查询页查看',
  );
  final rows = response['rows'];
  final rawAllowances = response['allowanceRows'];
  if (response['source'] != 'officialRendered' ||
      rows is! List ||
      rows.length > 200 ||
      rawAllowances != null &&
          (rawAllowances is! List || rawAllowances.length > 200) ||
      rows.isEmpty && (rawAllowances is! List || rawAllowances.isEmpty)) {
    return fail();
  }
  int? displayedBytes(Object? value) {
    if (value is! String || value.length > 60) return null;
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(GB|MB|KB|B)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    final amount = num.tryParse(match.group(1)!);
    // Huge sentinel/unlimited values must not be treated as finite balances.
    if (amount == null || !amount.isFinite || amount > 1000000000) return null;
    final bytes = _toBytes(match.group(1), match.group(2));
    return bytes != null && bytes <= 1099511627776 ? bytes : null;
  }

  final buckets = <TrafficBucket>[];
  for (final row in rows) {
    if (row is! Map) return fail();
    final name = row['name'] is String ? (row['name'] as String).trim() : '';
    final used = displayedBytes(row['used']);
    final total = displayedBytes(row['total']);
    final unlimited = name.isNotEmpty && _isUnlimitedValue(row['total']);
    final valid =
        name.isNotEmpty &&
        used != null &&
        total != null &&
        total > 0 &&
        used <= total;
    buckets.add(
      TrafficBucket(
        name: name,
        kind: classifyTelecomTrafficName(name),
        remainingBytes: valid ? total - used : null,
        totalBytes: valid ? total : null,
        isUnlimited: unlimited,
        rawRemaining: unlimited
            ? '不限量'
            : valid
            ? '${total - used}'
            : '剩余额无法确认',
        rawUnit: valid ? 'B' : null,
      ),
    );
  }
  final allowances = <ServiceAllowance>[];
  for (final row in rawAllowances is List ? rawAllowances : const []) {
    if (row is! Map) continue;
    final name = row['name'] is String ? (row['name'] as String).trim() : '';
    if (name.isEmpty || name.length > 200) continue;
    final kind = switch (row['kind']) {
      'voice' => AllowanceKind.voice,
      'sms' when RegExp(r'短信|短、彩信|短彩信').hasMatch(name) => AllowanceKind.sms,
      _ => null,
    };
    if (kind == null) continue;
    final used = _telecomAmount(row['used'], kind);
    final total = _telecomAmount(row['total'], kind);
    final unlimited = _isUnlimitedValue(row['total']);
    final comparable = used != null && total != null && used.$2 == total.$2;
    // Only values displayed with the same unit can be subtracted.
    final remaining = comparable ? total.$1 - used.$1 : null;
    allowances.add(
      ServiceAllowance(
        kind: kind,
        label: name,
        remaining: remaining != null && remaining >= 0 ? remaining : null,
        total: comparable ? total.$1 : null,
        overage: remaining != null && remaining < 0 ? -remaining : null,
        rawRemaining: unlimited ? '不限量' : _text(row['total']),
        rawUnit: used?.$2 ?? (kind == AllowanceKind.voice ? '分钟' : null),
        isUnlimited: unlimited,
        isEstimated: comparable,
      ),
    );
  }
  if (buckets.every(
        (bucket) => bucket.remainingBytes == null && !bucket.isUnlimited,
      ) &&
      !allowances.any(
        (item) =>
            item.remaining != null || item.overage != null || item.isUnlimited,
      )) {
    return fail();
  }
  return CarrierSnapshot(
    carrier: Carrier.telecom,
    status: QueryStatus.success,
    queriedAt: queriedAt ?? DateTime.now(),
    balanceYuan: _renderedYuan(response['balanceText']),
    buckets: buckets,
    allowances: allowances,
    message: buckets.isEmpty
        ? '官网仅返回通话或短信套餐明细；显示值为估算，适用范围以官网为准'
        : buckets.any((bucket) => bucket.isUnlimited)
        ? '官网标记含不限量套餐，达量限速和适用范围以套餐规则为准'
        : buckets.any((bucket) => bucket.remainingBytes == null)
        ? '部分官网明细无法估算，暂不显示合计；请核对官方查询页'
        : '根据官网已用量和总量的显示值估算，存在舍入误差，套餐适用范围以官网为准',
  );
}

// The archived Account component labels #mobileBalance in yuan. No generic
// `balance` field is accepted: Broadnet uses that field for traffic in KB.
num? _renderedYuan(Object? raw) {
  if (raw is! String || raw.length > 50) return null;
  final match = RegExp(r'^(-?\d+(?:\.\d{1,2})?)\s*元$').firstMatch(raw.trim());
  if (match == null) return null;
  final value = num.tryParse(match.group(1)!);
  return value != null && value.isFinite && value.abs() <= 1000000000
      ? value
      : null;
}

(num, String)? _telecomAmount(Object? raw, AllowanceKind kind) {
  if (raw is! String || raw.length > 60) return null;
  final match = RegExp(
    kind == AllowanceKind.voice
        ? r'^(\d+(?:\.\d+)?)\s*(分钟|分)$'
        : r'^(\d+)\s*(次|条)$',
  ).firstMatch(raw.trim());
  if (match == null) return null;
  final value = _allowanceAmount(match.group(1), kind);
  if (value == null) return null;
  return (value, kind == AllowanceKind.voice ? '分钟' : match.group(2)!);
}

/// Official iservice E5 resource summary; commonsFormat.getFlow takes MB.
/// This is a package summary, not evidence that every byte is general-purpose.
CarrierSnapshot parseUnicomWeb(
  Map<String, dynamic> response, {
  DateTime? queriedAt,
  int? httpStatus,
}) {
  CarrierSnapshot fail(QueryStatus status, String message) => CarrierSnapshot(
    carrier: Carrier.unicom,
    status: status,
    message: message,
  );
  if (httpStatus == 401 || httpStatus == 403 || _isAuthFailure(response)) {
    return fail(QueryStatus.authExpired, '中国联通登录已失效，请在官网重新验证');
  }
  if (httpStatus != null && (httpStatus < 200 || httpStatus >= 300)) {
    return fail(QueryStatus.error, '中国联通查询失败（HTTP $httpStatus）');
  }
  final resource = _map(response['resource']);
  if (resource == null) {
    return fail(QueryStatus.error, '联通官网未返回可确认的流量余量');
  }
  final allowances = <ServiceAllowance>[
    if (_officialFlag(resource['voiceFlag']))
      _unicomAllowance(
        kind: AllowanceKind.voice,
        label: '语音',
        remaining: resource['remainVoice'],
        overage: resource['overVoice'],
      ),
    if (_officialFlag(resource['smsFlag']))
      _unicomAllowance(
        kind: AllowanceKind.sms,
        label: '短、彩信',
        remaining: resource['remainSms'],
        overage: resource['overSms'],
      ),
  ];
  CarrierSnapshot noFlow(String message) {
    if (!allowances.any(
      (allowance) =>
          allowance.remaining != null ||
          allowance.overage != null ||
          allowance.isUnlimited,
    )) {
      return fail(QueryStatus.error, message);
    }
    return CarrierSnapshot(
      carrier: Carrier.unicom,
      status: QueryStatus.success,
      queriedAt: queriedAt ?? DateTime.now(),
      allowances: allowances,
      message: '$message；通话或短彩结果已更新',
    );
  }

  if (resource['successFlow'] == false || resource['successFlow'] == 'false') {
    return fail(QueryStatus.error, '联通官网流量查询失败，请在官方查询页确认套餐');
  }
  final unlimited = resource['hasNolimitedFlow'];
  // The official page checks JavaScript truthiness, including string flags.
  if (unlimited != null &&
      unlimited != false &&
      unlimited != 0 &&
      unlimited != '') {
    return CarrierSnapshot(
      carrier: Carrier.unicom,
      status: QueryStatus.success,
      queriedAt: queriedAt ?? DateTime.now(),
      buckets: const [
        TrafficBucket(
          name: '官网不限量套餐',
          kind: BucketKind.unknown,
          isUnlimited: true,
          rawRemaining: '不限量',
        ),
      ],
      allowances: allowances,
      message: '官网按不限量套餐展示已用流量，达量限速和适用范围请在官方页面确认',
    );
  }
  if (!_officialFlag(resource['flowFlag'])) {
    return noFlow('联通官网没有可确认的流量额度，请查看官方查询页');
  }
  final over = num.tryParse(resource['overFlow']?.toString() ?? '');
  final remaining = resource['remainFlow'];
  final amount = num.tryParse(remaining?.toString() ?? '');
  if (over != null && (!over.isFinite || over < 0)) {
    return noFlow('联通官网超额字段无法确认');
  }
  final exhausted = over != null && over > 0;
  if (!exhausted &&
      (amount == null ||
          !amount.isFinite ||
          amount < 0 ||
          amount > 1000000000)) {
    return noFlow('联通官网剩余额无法确认');
  }
  final bytes = exhausted ? 0 : _toBytes(remaining, 'MB');
  if (bytes == null) return noFlow('联通官网剩余额格式无法确认');
  return CarrierSnapshot(
    carrier: Carrier.unicom,
    status: QueryStatus.success,
    queriedAt: queriedAt ?? DateTime.now(),
    buckets: [
      TrafficBucket(
        name: '官网套餐余量',
        kind: BucketKind.unknown,
        remainingBytes: bytes,
        rawRemaining: exhausted ? '0' : remaining.toString(),
        rawUnit: 'MB',
      ),
    ],
    allowances: allowances,
    message: exhausted ? '官网显示流量已超出套餐额度，适用规则请查看官网' : '官网套餐余量，用途以套餐规则为准',
  );
}

bool _officialFlag(Object? value) =>
    value == true || value == 1 || value == '1' || value == 'true';

ServiceAllowance _unicomAllowance({
  required AllowanceKind kind,
  required String label,
  required Object? remaining,
  required Object? overage,
}) {
  final over = _allowanceAmount(overage, kind);
  final exceeded = over != null && over > 0;
  final unlimited = !exceeded && _isUnlimitedValue(remaining);
  return ServiceAllowance(
    kind: kind,
    label: label,
    remaining: exceeded || unlimited ? null : _allowanceAmount(remaining, kind),
    overage: exceeded ? over : null,
    rawRemaining: exceeded ? null : _text(remaining),
    rawUnit: kind == AllowanceKind.voice ? '分钟' : '条',
    isUnlimited: unlimited,
  );
}

num? _allowanceAmount(Object? raw, AllowanceKind kind) {
  if (raw is bool || raw == null) return null;
  final text = raw.toString().trim();
  if (text.length > 80 ||
      !RegExp(
        kind == AllowanceKind.sms ? r'^\d+$' : r'^\d+(?:\.\d+)?$',
      ).hasMatch(text)) {
    return null;
  }
  final value = num.tryParse(text);
  return value != null && value.isFinite && value <= 1000000000 ? value : null;
}

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

  final authFailure = _isAuthFailure(response);
  if (httpStatus == 401 || (httpStatus == 403 && authFailure)) {
    return failed(QueryStatus.authExpired, '中国移动登录已失效');
  }
  if (httpStatus == 403) {
    return failed(QueryStatus.error, '中国移动查询暂不可用（HTTP 403）');
  }
  if (httpStatus != null && (httpStatus < 200 || httpStatus >= 300)) {
    return failed(QueryStatus.error, '中国移动查询失败（HTTP $httpStatus）');
  }
  if (authFailure) {
    return failed(QueryStatus.authExpired, '中国移动登录已失效');
  }

  final resultData = _map(_map(response['data'])?['resultData']);
  final flow = _map(resultData?['planRemianFlowInfo']);
  final allowances = <ServiceAllowance>[];
  void addAllowanceGroup(
    String source,
    AllowanceKind kind,
    List<(String, String)> fields,
  ) {
    final group = _map(resultData?[source]);
    if (group == null) return;
    final groupRows = <ServiceAllowance>[];
    for (final (field, label) in fields) {
      final entry = _map(group[field]);
      if (entry == null) continue;
      final unit = _text(entry['unit']);
      if (unit != (kind == AllowanceKind.voice ? '01' : '02')) continue;
      final remaining = _allowanceAmount(entry['remainNum'], kind);
      final total = _allowanceAmount(entry['sumNum'], kind);
      final isUnlimited =
          _isUnlimitedValue(entry['remainNum']) ||
          _isUnlimitedValue(entry['sumNum']);
      if (remaining == null && !isUnlimited) continue;
      groupRows.add(
        ServiceAllowance(
          kind: kind,
          label: label,
          scope: field == 'totalInfo' ? '官网汇总' : '套餐明细',
          remaining: isUnlimited ? null : remaining,
          total: isUnlimited ? null : total,
          rawRemaining: _text(entry['remainNum']),
          rawUnit: kind == AllowanceKind.voice ? '分钟' : '条',
          isUnlimited: isUnlimited,
        ),
      );
    }
    final summaries = groupRows.where((row) => row.scope == '官网汇总');
    allowances.addAll(summaries.isNotEmpty ? summaries : groupRows);
  }

  addAllowanceGroup('planRemianVoiceInfo', AllowanceKind.voice, const [
    ('planRemian', '套餐内通话'),
    ('otherRemian', '其他通话'),
    ('totalInfo', '通话汇总'),
  ]);
  addAllowanceGroup('planRemianMSGInfo', AllowanceKind.sms, const [
    ('notePlanRemian', '套餐短信'),
    ('totalInfo', '短信汇总'),
  ]);
  if (flow == null && allowances.isEmpty) {
    return failed(
      _isAuthFailure(response) ? QueryStatus.authExpired : QueryStatus.error,
      _isAuthFailure(response) ? '中国移动登录已失效' : '未识别中国移动流量响应',
    );
  }

  final buckets = <TrafficBucket>[];
  void add(String field, String name, BucketKind kind) {
    final raw = _map(flow?[field]);
    if (raw == null) return;
    final remaining = raw['remainNum'];
    final unit = _text(raw['unit']);
    final unlimited =
        (unit == null || _toBytes('1', unit) != null) &&
        (_isUnlimitedValue(remaining) ||
            (_toBytes(remaining, unit) == null &&
                _isUnlimitedValue(raw['sumNum'])));
    // 01/02 are voice/SMS. Unknown units must never become GB by default.
    if (!unlimited && (remaining == null || unit == null)) return;
    buckets.add(
      TrafficBucket(
        name: name,
        kind: kind,
        rawRemaining: _text(remaining),
        rawUnit: unit,
        isUnlimited: unlimited,
        remainingBytes: unlimited ? null : _toBytes(remaining, unit),
        totalBytes: unlimited ? null : _toBytes(raw['sumNum'], unit),
      ),
    );
  }

  if (flow != null) {
    add('planRemian', '通用流量', BucketKind.general);
    add('directionalFlowInfo', '定向流量', BucketKind.directed);
    add('otherRemian', '其他流量', BucketKind.unknown);
    // This is the official aggregate and may already include all other buckets.
    add('totalInfo', '流量总览', BucketKind.unknown);
  }

  if ((buckets.isEmpty ||
          buckets.every(
            (bucket) => bucket.remainingBytes == null && !bucket.isUnlimited,
          )) &&
      allowances.isEmpty) {
    return failed(QueryStatus.error, '中国移动流量单位或剩余额无法确认');
  }
  return CarrierSnapshot(
    carrier: Carrier.mobile,
    status: QueryStatus.success,
    queriedAt: queriedAt ?? DateTime.now(),
    phoneMasked: phoneMasked,
    buckets: buckets,
    allowances: allowances,
    message:
        !buckets.any(
          (bucket) => bucket.remainingBytes != null || bucket.isUnlimited,
        )
        ? '官网仅返回通话或短信余量，尚未返回可确认的流量额度'
        : buckets.any((bucket) => bucket.isUnlimited)
        ? '官网标记含不限量套餐，达量限速和适用范围以套餐规则为准'
        : null,
  );
}

/// Only the current official homepage's labelled yuan balance is accepted.
/// Callers must first validate its page, URL and mobileBalanceRendered stage.
/// The flow response's curFeeTotal/realFee fields do not establish a balance.
num? parseMobileBalanceRendered(Map<String, dynamic> response) {
  if (response['source'] != 'officialRendered') return null;
  return _renderedYuan(response['balanceText']);
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

  final explicitAuthFailure =
      _text(response['status']) == '701' || _isAuthFailure(response);
  if (httpStatus == 401 || (httpStatus == 403 && explicitAuthFailure)) {
    return failed(QueryStatus.authExpired, '中国广电登录已失效');
  }
  if (httpStatus == 403) {
    return failed(QueryStatus.error, '中国广电查询暂不可用（HTTP 403）');
  }
  if (httpStatus != null && (httpStatus < 200 || httpStatus >= 300)) {
    return failed(QueryStatus.error, '中国广电查询失败（HTTP $httpStatus）');
  }
  if (response['status'] != '000000') {
    return failed(
      explicitAuthFailure ? QueryStatus.authExpired : QueryStatus.error,
      explicitAuthFailure ? '中国广电登录已失效' : '中国广电接口返回异常',
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
    final unlimited =
        (unit == null || _toBytes('1', unit) != null) &&
        _isUnlimitedValue(entry['balance']);
    buckets.add(
      TrafficBucket(
        name: name,
        kind: _broadnetKind(name),
        rawRemaining: rawRemaining,
        rawUnit: unit,
        isUnlimited: unlimited,
        remainingBytes: unlimited ? null : _toBytes(entry['balance'], unit),
        totalBytes: unlimited ? null : _toBytes(entry['highFee'], unit),
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

  final outerStatus = _text(response['status']);
  final responseBusiness = _map(response['data']);
  final explicitAuthFailure =
      outerStatus == '701' ||
      _isAuthFailure(response) ||
      (responseBusiness != null && _isAuthFailure(responseBusiness));
  if (httpStatus == 401 || (httpStatus == 403 && explicitAuthFailure)) {
    return failed(QueryStatus.authExpired, '中国广电登录已失效');
  }
  if (httpStatus == 403) {
    return failed(QueryStatus.error, '中国广电查询暂不可用（HTTP 403）');
  }
  if (httpStatus != null && (httpStatus < 200 || httpStatus >= 300)) {
    return failed(QueryStatus.error, '中国广电查询失败（HTTP $httpStatus）');
  }

  if (explicitAuthFailure) {
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
  final allowances = <ServiceAllowance>[];
  for (final item in items) {
    final entry = _map(item);
    if (entry == null) continue;
    final busiType = _text(entry['busiType']);
    if (busiType != '5') {
      final name = _text(entry['discntName']);
      final kind = busiType == '1'
          ? AllowanceKind.voice
          : name != null && RegExp(r'短信|短、彩信|短彩信').hasMatch(name)
          ? AllowanceKind.sms
          : null;
      if (kind == null || name == null || name.isEmpty) continue;
      final remaining = _allowanceAmount(entry['balance'], kind);
      final total = _allowanceAmount(entry['highFee'], kind);
      final unlimited = _isUnlimitedValue(entry['balance']);
      if (remaining == null && !unlimited) continue;
      allowances.add(
        ServiceAllowance(
          kind: kind,
          label: name,
          remaining: unlimited ? null : remaining,
          total: unlimited ? null : total,
          rawRemaining: _text(entry['balance']),
          rawUnit: kind == AllowanceKind.voice ? '分钟' : '条',
          isUnlimited: unlimited,
        ),
      );
      continue;
    }
    final name = _text(entry['discntName']);
    final named = name != null && name.isNotEmpty;
    final rawRemaining = _text(entry['balance']);
    final unlimited = named && _isUnlimitedValue(entry['balance']);
    final remainingBytes = named && !unlimited
        ? _toBytes(entry['balance'], 'KB')
        : null;
    buckets.add(
      TrafficBucket(
        name: named ? name : '未命名流量套餐',
        kind: named ? _broadnetKind(name) : BucketKind.unknown,
        remainingBytes: remainingBytes,
        isUnlimited: unlimited,
        totalBytes: named && !unlimited
            ? _toBytes(entry['highFee'], 'KB')
            : null,
        rawUnit: 'KB',
        rawRemaining: rawRemaining,
      ),
    );
  }

  if ((buckets.isEmpty ||
          buckets.every(
            (bucket) => bucket.remainingBytes == null && !bucket.isUnlimited,
          )) &&
      allowances.isEmpty) {
    return failed(QueryStatus.error, '中国广电未返回可确认的流量套餐');
  }
  final incomplete = buckets.any((bucket) => bucket.remainingBytes == null);
  return CarrierSnapshot(
    carrier: Carrier.broadnet,
    status: QueryStatus.success,
    queriedAt: queriedAt ?? DateTime.now(),
    phoneMasked: phoneMasked,
    buckets: buckets,
    allowances: allowances,
    message: buckets.any((bucket) => bucket.isUnlimited)
        ? '官网标记含不限量套餐，达量限速和适用范围以套餐规则为准'
        : incomplete
        ? '部分流量套餐余额未确认，暂不显示明细合计'
        : null,
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

bool _isUnlimitedValue(Object? value) =>
    value is String &&
    RegExp(
      r'^(不限量|无限量|无限|不限|不限制|unlimited|no\s*limit)\s*(GB|MB|KB|B)?$',
      caseSensitive: false,
    ).hasMatch(value.trim());

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
      text.contains('登录已过期') ||
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
  final rawText = rawValue.toString().trim();
  if (rawText.length > 80) return null;
  final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(rawText);
  if (match == null) return null;
  final whole = match.group(1)!;
  final fraction = match.group(2) ?? '';
  final denominator = BigInt.from(10).pow(fraction.length);
  final numerator = BigInt.parse('$whole$fraction') * multiplier;
  final bytes = (numerator + denominator ~/ BigInt.two) ~/ denominator;
  if (bytes > BigInt.parse('9223372036854775807')) return null;
  return bytes.toInt();
}
