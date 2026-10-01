import 'dart:convert';

import 'carrier_selection.dart';
import 'models.dart';

/// One official-web session. IDs are stable storage keys, never phone numbers.
class CarrierAccount {
  const CarrierAccount({
    required this.id,
    required this.carrier,
    required this.label,
  });

  final String id;
  final Carrier carrier;
  final String label;

  bool get isPrimary => id == carrier.name;
  String? get profileName => isPrimary ? null : 'liuliang_$id';
  String get snapshotKey => 'snapshot_$id';
  String get connectedKey => 'connected_$id';
  String get broadnetSessionKey =>
      isPrimary ? 'broadnet_session' : 'broadnet_session_$id';

  Map<String, String> toJson() => {
    'id': id,
    'carrier': carrier.name,
    'label': label,
  };

  static CarrierAccount? fromJson(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        value['carrier'] is! String ||
        value['label'] is! String) {
      return null;
    }
    final carrier = Carrier.values.where((c) => c.name == value['carrier']);
    if (carrier.isEmpty) return null;
    final found = carrier.first;
    final id = value['id'] as String;
    if (id != found.name && id != '${found.name}_2') return null;
    final label = value['label'] as String;
    if (label.trim().isEmpty || label.length > 40) return null;
    return CarrierAccount(id: id, carrier: found, label: label);
  }
}

class CarrierAccounts {
  CarrierAccounts._(Iterable<CarrierAccount> values)
    : accounts = List.unmodifiable(values);

  static const storageKey = 'carrier_accounts_v1';
  static const schemaVersion = 1;
  final List<CarrierAccount> accounts;

  factory CarrierAccounts.fromSelection(CarrierSelection selection) =>
      CarrierAccounts._([
        for (final carrier in Carrier.values)
          if (selection.allows(carrier))
            CarrierAccount(
              id: carrier.name,
              carrier: carrier,
              label: '${carrier.label} 1',
            ),
      ]);

  factory CarrierAccounts.restore({
    required String? savedJson,
    required CarrierSelection selection,
  }) {
    if (savedJson == null) return CarrierAccounts.fromSelection(selection);
    try {
      final decoded = jsonDecode(savedJson);
      if (decoded is! Map ||
          decoded['schemaVersion'] != schemaVersion ||
          decoded['accounts'] is! List) {
        return CarrierAccounts.fromSelection(selection);
      }
      final values = <CarrierAccount>[];
      final seen = <String>{};
      for (final raw in decoded['accounts'] as List) {
        final account = CarrierAccount.fromJson(raw);
        if (account == null || !seen.add(account.id)) {
          return CarrierAccounts.fromSelection(selection);
        }
        values.add(account);
      }
      // Restore a legacy primary even if a partially written record omitted it.
      for (final carrier in selection.selectedCarriers) {
        if (!seen.contains(carrier.name)) {
          values.add(
            CarrierAccount(
              id: carrier.name,
              carrier: carrier,
              label: '${carrier.label} 1',
            ),
          );
        }
      }
      if (values.length > 8) return CarrierAccounts.fromSelection(selection);
      return CarrierAccounts._(_ordered(values));
    } catch (_) {
      return CarrierAccounts.fromSelection(selection);
    }
  }

  CarrierAccounts ensureSelection(CarrierSelection selection) {
    final values = [...accounts];
    for (final carrier in selection.selectedCarriers) {
      if (!values.any((a) => a.id == carrier.name)) {
        values.add(
          CarrierAccount(
            id: carrier.name,
            carrier: carrier,
            label: '${carrier.label} 1',
          ),
        );
      }
    }
    return CarrierAccounts._(_ordered(values));
  }

  CarrierAccounts addSecond(Carrier carrier) {
    if (!accounts.any((a) => a.id == carrier.name)) {
      throw StateError('Select the carrier first');
    }
    if (accounts.any((a) => a.id == '${carrier.name}_2')) return this;
    if (accounts.length >= 8) {
      throw StateError('At most eight stored account records');
    }
    return CarrierAccounts._(
      _ordered([
        ...accounts,
        CarrierAccount(
          id: '${carrier.name}_2',
          carrier: carrier,
          label: '${carrier.label} 2',
        ),
      ]),
    );
  }

  /// Removes the card from the app layout while preserving its stored record.
  CarrierAccounts removeSecond(String id) {
    final account = find(id);
    if (account == null || account.isPrimary) return this;
    return CarrierAccounts._(accounts.where((a) => a.id != id));
  }

  List<CarrierAccount> visibleAccounts(CarrierSelection selection) => accounts
      .where((a) => selection.allows(a.carrier))
      .take(4)
      .toList(growable: false);

  int visibleCount(CarrierSelection selection) =>
      accounts.where((a) => selection.allows(a.carrier)).length;

  CarrierAccount? find(String id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  String toStorageString() => jsonEncode({
    'schemaVersion': schemaVersion,
    'accounts': [for (final account in accounts) account.toJson()],
  });

  static List<CarrierAccount> _ordered(Iterable<CarrierAccount> values) => [
    for (final carrier in Carrier.values) ...[
      ...values.where((a) => a.carrier == carrier && a.isPrimary),
      ...values.where((a) => a.carrier == carrier && !a.isPrimary),
    ],
  ];
}
