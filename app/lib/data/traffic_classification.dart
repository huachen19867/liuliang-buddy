import 'dart:convert';

import 'models.dart';

/// Local purpose corrections, isolated by stable account ID and exact trimmed
/// package name. Query values and timestamps never enter this storage.
class TrafficClassificationOverrides {
  TrafficClassificationOverrides._(Map<String, Map<String, BucketKind>> values)
    : _accounts = Map.unmodifiable({
        for (final entry in values.entries)
          entry.key: Map<String, BucketKind>.unmodifiable(entry.value),
      });

  static const storageKey = 'traffic_classification_overrides';
  static const schemaVersion = 1;
  final Map<String, Map<String, BucketKind>> _accounts;

  factory TrafficClassificationOverrides.restore(String? savedJson) {
    final accounts = <String, Map<String, BucketKind>>{};
    if (savedJson == null) return TrafficClassificationOverrides._(accounts);
    try {
      final decoded = jsonDecode(savedJson);
      if (decoded is! Map ||
          decoded['schema'] != schemaVersion ||
          decoded['accounts'] is! Map) {
        return TrafficClassificationOverrides._(accounts);
      }
      for (final entry in (decoded['accounts'] as Map).entries) {
        final accountId = entry.key;
        final raw = entry.value;
        if (accountId is! String ||
            !_validAccountId(accountId) ||
            raw is! Map) {
          continue;
        }
        final values = <String, BucketKind>{};
        final ambiguous = <String>{};
        for (final row in raw.entries) {
          if (row.key is! String) continue;
          final name = (row.key as String).trim();
          final kind = switch (row.value) {
            'general' => BucketKind.general,
            'directed' => BucketKind.directed,
            _ => null,
          };
          if (name.isEmpty || kind == null || ambiguous.contains(name)) {
            continue;
          }
          // Invalid JSON containing competing whitespace aliases must not pick
          // an arbitrary winner for the same exact normalized identity.
          if (values.containsKey(name)) {
            values.remove(name);
            ambiguous.add(name);
          } else {
            values[name] = kind;
          }
        }
        if (values.isNotEmpty) accounts[accountId] = values;
      }
    } on FormatException {
      // Corrupt settings must not make snapshot restoration or startup fail.
    }
    return TrafficClassificationOverrides._(accounts);
  }

  Map<String, Object?> toJson() => {
    'schema': schemaVersion,
    'accounts': {
      for (final entry in _accounts.entries)
        entry.key: {
          for (final row in entry.value.entries) row.key: row.value.name,
        },
    },
  };

  CarrierSnapshot apply(String accountId, CarrierSnapshot snapshot) {
    final overrides = _accountMatches(accountId, snapshot.carrier)
        ? _accounts[accountId]
        : null;
    final counts = <String, int>{};
    for (final bucket in snapshot.buckets) {
      final name = bucket.name.trim();
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return snapshot.copyWith(
      buckets: List<TrafficBucket>.unmodifiable([
        for (final bucket in snapshot.buckets)
          bucket.copyWith(
            // Always remove cached classifications before applying this
            // authoritative account map, including duplicates and aggregates.
            manualKind:
                bucket.name.trim().isNotEmpty &&
                    counts[bucket.name.trim()] == 1 &&
                    !isUnclassifiableTrafficAggregate(snapshot.carrier, bucket)
                ? (overrides?[bucket.name.trim()])
                : null,
          ),
      ]),
    );
  }

  TrafficClassificationOverrides withOverride(
    String accountId,
    CarrierSnapshot snapshot,
    TrafficBucket bucket,
    BucketKind? kind,
  ) {
    final values = _copyAccounts();
    if (!_accountMatches(accountId, snapshot.carrier) ||
        !canOverride(snapshot, bucket) ||
        kind == BucketKind.unknown) {
      return TrafficClassificationOverrides._(values);
    }
    final name = bucket.name.trim();
    if (kind == null) {
      values[accountId]?.remove(name);
      if (values[accountId]?.isEmpty == true) values.remove(accountId);
    } else {
      (values[accountId] ??= {})[name] = kind;
    }
    return TrafficClassificationOverrides._(values);
  }

  TrafficClassificationOverrides withoutAccount(String accountId) =>
      TrafficClassificationOverrides._(_copyAccounts()..remove(accountId));

  static bool canOverride(CarrierSnapshot snapshot, TrafficBucket bucket) =>
      unavailableReason(snapshot, bucket) == null;

  static String? unavailableReason(
    CarrierSnapshot snapshot,
    TrafficBucket bucket,
  ) {
    final name = bucket.name.trim();
    if (name.isEmpty) return '套餐名称为空，暂时无法保存分类';
    if (isUnclassifiableTrafficAggregate(snapshot.carrier, bucket)) {
      return '这是运营商汇总，不能当作单个套餐分类';
    }
    final count = snapshot.buckets
        .where((row) => row.name.trim() == name)
        .length;
    if (count == 0) return '该套餐已不在当前明细中，请重新打开';
    if (count != 1) return '存在同名套餐，暂时无法准确区分';
    return null;
  }

  Map<String, Map<String, BucketKind>> _copyAccounts() => {
    for (final entry in _accounts.entries)
      entry.key: Map<String, BucketKind>.of(entry.value),
  };

  static bool _validAccountId(String id) =>
      Carrier.values.any((carrier) => _accountMatches(id, carrier));

  static bool _accountMatches(String id, Carrier carrier) =>
      id == carrier.name ||
      [2, 3, 4].any((slot) => id == '${carrier.name}_$slot');
}
